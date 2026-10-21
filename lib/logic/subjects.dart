import 'dates.dart';

/// 5 môn của Học Vui (CT GDPT 2018, cấp THCS).
enum Subject { toan, van, anh, khtn, lsdl }

extension SubjectInfo on Subject {
  String get id => name;

  String get label => switch (this) {
        Subject.toan => 'Toán',
        Subject.van => 'Ngữ văn',
        Subject.anh => 'Tiếng Anh',
        Subject.khtn => 'Khoa học tự nhiên',
        Subject.lsdl => 'Lịch sử và Địa lý',
      };

  /// Nhãn ngắn trên huy hiệu màu.
  String get short => switch (this) {
        Subject.toan => 'Toán',
        Subject.van => 'Văn',
        Subject.anh => 'Anh',
        Subject.khtn => 'KHTN',
        Subject.lsdl => 'LS&ĐL',
      };

  /// Số câu mỗi mức Nhận biết, Thông hiểu, Vận dụng, Vận dụng cao trong đề 30 phút.
  List<int> get blueprint => switch (this) {
        Subject.toan => const [6, 4, 3, 2],
        Subject.van => const [6, 5, 3, 2],
        Subject.anh => const [12, 9, 6, 3],
        Subject.khtn => const [8, 6, 4, 2],
        Subject.lsdl => const [10, 7, 5, 2],
      };

  int get questionCount => blueprint.fold(0, (a, b) => a + b);

  /// Môn cần tính toán thì nhắc chuẩn bị giấy nháp.
  bool get needsScratchPaper => this == Subject.toan || this == Subject.khtn;
}

Subject? subjectFromId(String? id) {
  for (final s in Subject.values) {
    if (s.id == id) return s;
  }
  return null;
}

const levelNames = ['Nhận biết', 'Thông hiểu', 'Vận dụng', 'Vận dụng cao'];

/// Tên mức độ, [level] từ 1 tới 4.
String levelName(int level) => levelNames[(level - 1).clamp(0, 3).toInt()];

const examMinutes = 30;
const examsPerDay = 2;
const grades = [6, 7, 8, 9];

/// Chu kỳ 5 ngày: mỗi môn đúng 2 đề, mỗi ngày ghép môn tính toán với môn đọc hiểu.
const rotation = <List<Subject>>[
  [Subject.toan, Subject.van],
  [Subject.anh, Subject.khtn],
  [Subject.lsdl, Subject.toan],
  [Subject.van, Subject.anh],
  [Subject.khtn, Subject.lsdl],
];

/// Mốc tính chu kỳ (thứ Hai 05/01/2026 là ngày 1 của chu kỳ).
const _rotationAnchor = '2026-01-05';

int rotationIndex(String day) {
  final n = daysBetween(_rotationAnchor, day) % rotation.length;
  return n < 0 ? n + rotation.length : n;
}

List<Subject> subjectsForDay(String day) => rotation[rotationIndex(day)];

/// Thứ tự thử thay môn khi một môn chưa đủ câu hỏi: các môn của những ngày
/// tiếp theo trong chu kỳ.
List<Subject> fallbackOrder(String day) {
  final out = <Subject>[];
  for (var i = 1; i <= rotation.length; i++) {
    for (final s in rotation[(rotationIndex(day) + i) % rotation.length]) {
      if (!out.contains(s)) out.add(s);
    }
  }
  return out;
}
