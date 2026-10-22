/// Đọc file thư viện đề (assets/bank/g{lớp}/{môn}_{số}.txt).
///
/// Định dạng (mỗi dòng một mục, dòng trống bỏ qua):
///   #! HK2              bắt đầu các bài của học kỳ 2
///   # Chương I. ...     tên chương
///   ## Bài 1. ...       tên bài; các câu hỏi sau thuộc bài này
///   > ...               ngữ liệu (nhiều dòng > liên tiếp ghép thành một đoạn);
///                       dùng cho các câu tiếp theo tới khi có ngữ liệu mới, '>-' hoặc bài mới
///   ?2 Nội dung câu hỏi  câu hỏi mới, số sau ? là mức độ 1..4
///   + đáp án đúng
///   - đáp án sai        (đúng 1 dòng + và 3 dòng -; app tự xáo thứ tự khi ra đề)
///   = lời giải
///   // ghi chú          bỏ qua
/// Trong nội dung, chuỗi \n được đổi thành xuống dòng.
library;

class BankQuestion {
  BankQuestion({
    required this.lessonTitle,
    required this.indexInLesson,
    required this.level,
    required this.text,
    required this.passage,
    required this.options,
    required this.answer,
    required this.explanation,
    required this.line,
  });

  final String lessonTitle;
  final int indexInLesson;
  final int level;
  final String text;
  final String passage;
  final List<String> options;
  final int answer;
  final String explanation;
  final int line;
}

class BankFile {
  BankFile(this.name);
  final String name;

  /// Dòng mục lục theo định dạng Curriculum (chương bắt đầu bằng '#', '#! HK2').
  final curriculumLines = <String>[];
  final lessons = <String>[];
  final questions = <BankQuestion>[];
  final errors = <String>[];
}

String _clean(String s) => s.trim().replaceAll(r'\n', '\n');

BankFile parseBank(String name, String content) {
  final f = BankFile(name);
  String? lesson;
  var passage = '';
  var passageOpen = false; // đang đọc các dòng > liên tiếp
  var index = 0;

  int? qLevel;
  String? qText;
  var qLine = 0;
  final opts = <String>[];
  var answer = -1;
  var correctCount = 0;
  String? explain;

  void flush() {
    if (qText == null) return;
    final where = '${f.name}:$qLine';
    if (lesson == null) f.errors.add('$where câu hỏi nằm ngoài bài học');
    if (opts.length != 4) f.errors.add('$where cần đúng 4 phương án (đang có ${opts.length})');
    if (correctCount != 1) f.errors.add('$where cần đúng 1 phương án đúng (+), đang có $correctCount');
    if (opts.toSet().length != opts.length) f.errors.add('$where có phương án trùng nhau');
    if (explain == null || explain!.isEmpty) f.errors.add('$where thiếu lời giải (=)');
    if (qText!.isEmpty) f.errors.add('$where câu hỏi trống');
    if (lesson != null) {
      f.questions.add(BankQuestion(
        lessonTitle: lesson!,
        indexInLesson: index++,
        level: qLevel ?? 1,
        text: qText!,
        passage: passage,
        options: List.of(opts),
        answer: answer,
        explanation: explain ?? '',
        line: qLine,
      ));
    }
    qText = null;
    qLevel = null;
    opts.clear();
    answer = -1;
    correctCount = 0;
    explain = null;
  }

  final lines = content.replaceAll('\r\n', '\n').split('\n');
  for (var i = 0; i < lines.length; i++) {
    final raw = lines[i];
    final line = raw.trimRight();
    final t = line.trimLeft();
    final lineNo = i + 1;
    if (t.isEmpty || t.startsWith('//')) continue;

    if (t.startsWith('>')) {
      flush();
      if (t == '>-') {
        passage = '';
        passageOpen = false;
        continue;
      }
      final body = _clean(t.substring(1));
      passage = passageOpen ? '$passage\n$body' : body;
      passageOpen = true;
      continue;
    }
    passageOpen = false;

    if (t.startsWith('#! ')) {
      flush();
      f.curriculumLines.add('#! ${t.substring(3).trim()}');
    } else if (t.startsWith('## ')) {
      flush();
      lesson = t.substring(3).trim();
      f.lessons.add(lesson!);
      f.curriculumLines.add(lesson!);
      passage = '';
      index = 0;
    } else if (t.startsWith('# ')) {
      flush();
      f.curriculumLines.add('# ${t.substring(2).trim()}');
    } else if (t.startsWith('?')) {
      flush();
      final m = RegExp(r'^\?([1-4])\s+(.*)$').firstMatch(t);
      if (m == null) {
        f.errors.add('${f.name}:$lineNo dòng câu hỏi phải có dạng "?1 Nội dung" (mức 1–4)');
        continue;
      }
      qLevel = int.parse(m.group(1)!);
      qText = _clean(m.group(2)!);
      qLine = lineNo;
    } else if (t.startsWith('+ ') || t.startsWith('- ') || t == '+' || t == '-') {
      if (qText == null) {
        f.errors.add('${f.name}:$lineNo phương án nằm ngoài câu hỏi');
        continue;
      }
      final body = _clean(t.length > 1 ? t.substring(2) : '');
      if (t.startsWith('+')) {
        answer = opts.length;
        correctCount++;
      }
      opts.add(body);
    } else if (t.startsWith('= ')) {
      if (qText == null) {
        f.errors.add('${f.name}:$lineNo lời giải nằm ngoài câu hỏi');
        continue;
      }
      explain = _clean(t.substring(2));
    } else {
      f.errors.add('${f.name}:$lineNo không hiểu dòng: "$t"');
    }
  }
  flush();
  return f;
}

/// Mã ổn định cho câu hỏi thư viện (đổi thứ tự bài không làm đổi mã).
String bankQuestionId(int grade, String subject, String lessonTitle, int index) {
  var h = 0x811c9dc5;
  for (final c in lessonTitle.codeUnits) {
    h ^= c;
    h = (h * 0x01000193) & 0xffffffff;
  }
  return 'lib_${grade}_${subject}_${h.toRadixString(16).padLeft(8, '0')}_${index.toString().padLeft(2, '0')}';
}

/// Tên file → (lớp, môn). Ví dụ 'assets/bank/g7/toan_01.txt' → (7, 'toan').
(int, String)? bankFileKey(String path) {
  final m = RegExp(r'g([1-9])/([a-z]+)_\d+\.txt$').firstMatch(path);
  if (m == null) return null;
  return (int.parse(m.group(1)!), m.group(2)!);
}
