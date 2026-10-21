import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../logic/subjects.dart';
import '../models/models.dart';
import 'repo.dart';

/// Sinh câu hỏi bằng Claude API (gọi thẳng từ trang quản trị).
///
/// Khóa API do quản trị viên nhập, chỉ lưu trên máy của quản trị viên
/// (shared_preferences), không lưu lên Firestore và không nằm trong mã nguồn.
class AiService {
  static const _keyPref = 'claude_api_key';
  static const model = 'claude-opus-5-5';
  static const _url = 'https://api.anthropic.com/v1/messages';

  Future<String?> loadKey() async {
    final prefs = await SharedPreferences.getInstance();
    final k = prefs.getString(_keyPref);
    return (k == null || k.isEmpty) ? null : k;
  }

  Future<void> saveKey(String key) async {
    final prefs = await SharedPreferences.getInstance();
    if (key.trim().isEmpty) {
      await prefs.remove(_keyPref);
    } else {
      await prefs.setString(_keyPref, key.trim());
    }
  }

  static const _system = '''
Bạn là giáo viên THCS giàu kinh nghiệm ở Việt Nam, soạn câu hỏi trắc nghiệm ôn tập
theo Chương trình giáo dục phổ thông 2018 và bộ sách giáo khoa "Kết nối tri thức với cuộc sống"
(NXB Giáo dục Việt Nam).

Yêu cầu chung cho mọi câu hỏi:
- Đúng kiến thức và đúng phạm vi bài học được giao, phù hợp lứa tuổi và lớp học.
- Mỗi câu có đúng 4 phương án, chỉ 1 phương án đúng. Không dùng "Cả A, B, C đều đúng".
- Phương án sai phải hợp lý, lấy từ những lỗi học sinh hay mắc (sai dấu, thiếu nghiệm,
  nhầm khái niệm, nhầm năm...). Với câu cần tính toán, học sinh phải tính ra nháp mới chọn đúng.
- Mức độ: 1 = Nhận biết, 2 = Thông hiểu, 3 = Vận dụng, 4 = Vận dụng cao.
- Viết câu hỏi mới, không chép nguyên văn sách giáo khoa.
- Không dùng LaTeX. Viết công thức bằng ký tự thường: phân số a/b, lũy thừa dùng ký tự mũ
  (x², 2³, 10⁻³) hoặc dấu ^, căn bậc hai √, nhân ·, chia :, dấu trừ −.
- Trường "explanation": lời giải ngắn 1–3 câu, nêu cách làm hoặc lý do đáp án đúng.
- Trường "passage": để chuỗi rỗng, trừ câu đọc hiểu cần ngữ liệu (tối đa 150 chữ).
- Môn Tiếng Anh: câu hỏi và phương án viết bằng tiếng Anh, lời giải bằng tiếng Việt.
- Các môn khác viết bằng tiếng Việt có dấu, chuẩn chính tả.
- Thứ tự phương án đúng phân bố ngẫu nhiên, không dồn vào một vị trí.''';

  static const _questionSchema = {
    'type': 'object',
    'properties': {
      'questions': {
        'type': 'array',
        'items': {
          'type': 'object',
          'properties': {
            'level': {'type': 'integer'},
            'passage': {'type': 'string'},
            'text': {'type': 'string'},
            'options': {
              'type': 'array',
              'items': {'type': 'string'},
            },
            'answer': {'type': 'integer'},
            'explanation': {'type': 'string'},
          },
          'required': ['level', 'passage', 'text', 'options', 'answer', 'explanation'],
          'additionalProperties': false,
        },
      },
    },
    'required': ['questions'],
    'additionalProperties': false,
  };

  static const _linesSchema = {
    'type': 'object',
    'properties': {
      'lines': {
        'type': 'array',
        'items': {'type': 'string'},
      },
    },
    'required': ['lines'],
    'additionalProperties': false,
  };

  /// Sinh câu hỏi cho một bài. [counts] là số câu mỗi mức 1..4.
  Future<List<Question>> generateQuestions({
    required int grade,
    required Subject subject,
    required Lesson lesson,
    required List<int> counts,
    List<String> existing = const [],
  }) async {
    final total = counts.fold(0, (a, b) => a + b);
    if (total <= 0) throw const AppError('Hãy chọn số câu cần sinh.');
    if (total > 30) throw const AppError('Mỗi lần sinh tối đa 30 câu.');
    final avoid = existing.take(40).map((t) => '- $t').join('\n');
    final prompt = '''
Môn: ${subject.label}, lớp $grade.
${lesson.chapter.isEmpty ? '' : 'Chương: ${lesson.chapter}\n'}Bài: ${lesson.title}

Hãy soạn $total câu hỏi trắc nghiệm cho bài này:
- ${counts[0]} câu mức 1 (Nhận biết)
- ${counts[1]} câu mức 2 (Thông hiểu)
- ${counts[2]} câu mức 3 (Vận dụng)
- ${counts[3]} câu mức 4 (Vận dụng cao)
${avoid.isEmpty ? '' : '\nNgân hàng đã có các câu sau, đừng soạn trùng ý:\n$avoid\n'}
Trả về JSON đúng cấu trúc đã cho; "answer" là chỉ số 0–3 của phương án đúng trong "options".''';

    final json = await _call(prompt, _questionSchema);
    final raw = (json['questions'] as List?) ?? const [];
    final out = <Question>[];
    for (final item in raw) {
      if (item is! Map) continue;
      final options = (item['options'] as List? ?? const []).map((e) => '$e'.trim()).toList();
      final answer = (item['answer'] as num?)?.toInt() ?? -1;
      final level = (item['level'] as num?)?.toInt() ?? 0;
      final text = '${item['text'] ?? ''}'.trim();
      if (text.isEmpty || options.length != 4 || answer < 0 || answer > 3 || level < 1 || level > 4) continue;
      if (options.toSet().length != 4) continue;
      out.add(Question(
        grade: grade,
        subject: subject,
        lessonOrder: lesson.order,
        lessonTitle: lesson.title,
        level: level,
        text: text,
        passage: '${item['passage'] ?? ''}'.trim(),
        options: options,
        answer: answer,
        explanation: '${item['explanation'] ?? ''}'.trim(),
        status: 'pending',
        source: 'ai',
      ));
    }
    if (out.isEmpty) throw const AppError('Claude không trả về câu hỏi hợp lệ. Hãy thử lại.');
    return out;
  }

  /// Gợi ý mục lục SGK (cần quản trị viên đối chiếu lại với sách thật).
  Future<List<String>> suggestCurriculum(int grade, Subject subject) async {
    final prompt = '''
Liệt kê mục lục sách giáo khoa ${subject.label} $grade, bộ "Kết nối tri thức với cuộc sống".
Mỗi phần tử là một dòng: dòng tên chương (hoặc chủ đề, phần) bắt đầu bằng "# ",
các dòng sau là tên từng bài học theo đúng thứ tự trong sách, ví dụ "Bài 1. Tập hợp các số hữu tỉ".
Bỏ qua các bài luyện tập chung, ôn tập cuối chương, hoạt động trải nghiệm.
Nếu không chắc tên bài nào, vẫn ghi tên gần đúng nhất và thêm "(?)" ở cuối dòng.''';
    final json = await _call(prompt, _linesSchema);
    return ((json['lines'] as List?) ?? const []).map((e) => '$e'.trim()).where((e) => e.isNotEmpty).toList();
  }

  Future<Map<String, dynamic>> _call(String prompt, Map<String, Object> schema) async {
    final key = await loadKey();
    if (key == null) throw const AppError('Chưa có Claude API key. Hãy nhập ở mục Cài đặt AI.');
    late http.Response res;
    try {
      res = await http
          .post(
            Uri.parse(_url),
            headers: {
              'content-type': 'application/json',
              'x-api-key': key,
              'anthropic-version': '2023-06-01',
              // Tự chuyển sang model dự phòng nếu bộ lọc an toàn từ chối nhầm.
              'anthropic-beta': 'server-side-fallback-2026-07-01',
              // Cho phép gọi thẳng từ trình duyệt (trang quản trị bản web).
              'anthropic-dangerous-direct-browser-access': 'true',
            },
            body: jsonEncode({
              'model': model,
              'max_tokens': 32000,
              'fallbacks': 'default',
              'system': _system,
              'output_config': {
                'effort': 'high',
                'format': {'type': 'json_schema', 'schema': schema},
              },
              'messages': [
                {'role': 'user', 'content': prompt},
              ],
            }),
          )
          .timeout(const Duration(minutes: 10));
    } catch (e) {
      throw AppError('Không gọi được Claude API: $e');
    }
    final body = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    if (res.statusCode != 200) {
      final msg = (body['error'] as Map?)?['message'] ?? res.body;
      throw AppError(switch (res.statusCode) {
        401 => 'Claude API key không đúng.',
        429 => 'Gọi Claude quá nhanh hoặc hết hạn mức. Hãy đợi một lúc rồi thử lại.',
        _ => 'Claude API lỗi ${res.statusCode}: $msg',
      });
    }
    final stop = body['stop_reason'];
    if (stop == 'refusal') throw const AppError('Claude từ chối yêu cầu này. Hãy đổi cách mô tả bài học.');
    if (stop == 'max_tokens') throw const AppError('Câu trả lời quá dài bị cắt. Hãy giảm số câu mỗi lần sinh.');
    final text = ((body['content'] as List?) ?? const [])
        .whereType<Map>()
        .where((b) => b['type'] == 'text')
        .map((b) => '${b['text']}')
        .join();
    try {
      return jsonDecode(text) as Map<String, dynamic>;
    } catch (_) {
      throw const AppError('Claude trả về dữ liệu không đọc được. Hãy thử lại.');
    }
  }
}
