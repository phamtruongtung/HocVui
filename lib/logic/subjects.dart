import 'dates.dart';

/// Các môn của Học Vui (CT GDPT 2018).
/// THCS (lớp 6–9): Toán, Ngữ văn, Tiếng Anh, KHTN, Lịch sử và Địa lý.
/// Tiểu học: Toán, Tiếng Việt, Tiếng Anh (lớp 3–5), Tự nhiên và Xã hội (lớp 1–3),
/// Khoa học và Lịch sử và Địa lý (lớp 4–5).
/// Thêm môn mới luôn đặt ở cuối để không đổi thứ tự cũ.
enum Subject { toan, van, anh, khtn, lsdl, tiengviet, tnxh, khoahoc }

extension SubjectInfo on Subject {
  String get id => name;

  String get label => switch (this) {
        Subject.toan => 'Toán',
        Subject.van => 'Ngữ văn',
        Subject.anh => 'Tiếng Anh',
        Subject.khtn => 'Khoa học tự nhiên',
        Subject.lsdl => 'Lịch sử và Địa lý',
        Subject.tiengviet => 'Tiếng Việt',
        Subject.tnxh => 'Tự nhiên và Xã hội',
        Subject.khoahoc => 'Khoa học',
      };

  /// Nhãn ngắn trên huy hiệu màu.
  String get short => switch (this) {
        Subject.toan => 'Toán',
        Subject.van => 'Văn',
        Subject.anh => 'Anh',
        Subject.khtn => 'KHTN',
        Subject.lsdl => 'LS&ĐL',
        Subject.tiengviet => 'TV',
        Subject.tnxh => 'TN&XH',
        Subject.khoahoc => 'KH',
      };

  /// Số câu mỗi mức (THCS, đề 30 phút). Dùng [blueprintFor] để có số câu theo lớp.
  List<int> get blueprint => switch (this) {
        Subject.toan => const [6, 4, 3, 2],
        Subject.van => const [6, 5, 3, 2],
        Subject.anh => const [12, 9, 6, 3],
        Subject.khtn => const [8, 6, 4, 2],
        Subject.lsdl => const [10, 7, 5, 2],
        Subject.tiengviet => const [6, 5, 3, 1],
        Subject.tnxh => const [6, 5, 3, 1],
        Subject.khoahoc => const [6, 5, 3, 1],
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

const examsPerDay = 2;
const grades = [1, 2, 3, 4, 5, 6, 7, 8, 9];

bool isPrimary(int grade) => grade <= 5;

/// Thời gian làm một đề (phút): lớp 1–2: 15, lớp 3: 20, lớp 4–5: 25, lớp 6–9: 30.
int examMinutesFor(int grade) => switch (grade) {
      <= 2 => 15,
      3 => 20,
      <= 5 => 25,
      _ => 30,
    };

/// Số câu mỗi mức Nhận biết, Thông hiểu, Vận dụng, Vận dụng cao của một đề.
List<int> blueprintFor(Subject s, int grade) => switch (grade) {
      <= 2 => const [4, 3, 2, 1], // 10 câu / 15 phút
      3 => const [5, 4, 2, 1], // 12 câu / 20 phút
      <= 5 => const [6, 5, 3, 1], // 15 câu / 25 phút
      _ => s.blueprint,
    };

/// Các môn của một lớp.
List<Subject> subjectsForGrade(int grade) => switch (grade) {
      <= 2 => const [Subject.toan, Subject.tiengviet, Subject.tnxh],
      3 => const [Subject.toan, Subject.tiengviet, Subject.anh, Subject.tnxh],
      <= 5 => const [Subject.toan, Subject.tiengviet, Subject.anh, Subject.khoahoc, Subject.lsdl],
      _ => const [Subject.toan, Subject.van, Subject.anh, Subject.khtn, Subject.lsdl],
    };

/// THCS: chu kỳ 5 ngày, mỗi môn đúng 2 đề, mỗi ngày ghép môn tính toán với môn đọc hiểu.
const rotation = <List<Subject>>[
  [Subject.toan, Subject.van],
  [Subject.anh, Subject.khtn],
  [Subject.lsdl, Subject.toan],
  [Subject.van, Subject.anh],
  [Subject.khtn, Subject.lsdl],
];

/// Lớp 4–5: cùng nhịp với THCS.
const _rotation45 = <List<Subject>>[
  [Subject.toan, Subject.tiengviet],
  [Subject.anh, Subject.khoahoc],
  [Subject.lsdl, Subject.toan],
  [Subject.tiengviet, Subject.anh],
  [Subject.khoahoc, Subject.lsdl],
];

/// Lớp 3: chu kỳ 2 ngày.
const _rotation3 = <List<Subject>>[
  [Subject.toan, Subject.tiengviet],
  [Subject.anh, Subject.tnxh],
];

/// Lớp 1–2: chu kỳ 3 ngày, mỗi môn 2 đề.
const _rotation12 = <List<Subject>>[
  [Subject.toan, Subject.tiengviet],
  [Subject.tnxh, Subject.toan],
  [Subject.tiengviet, Subject.tnxh],
];

List<List<Subject>> rotationFor(int grade) => switch (grade) {
      <= 2 => _rotation12,
      3 => _rotation3,
      <= 5 => _rotation45,
      _ => rotation,
    };

/// Mốc tính chu kỳ (thứ Hai 05/01/2026 là ngày 1 của chu kỳ).
const _rotationAnchor = '2026-01-05';

int rotationIndex(String day, [int grade = 6]) {
  final len = rotationFor(grade).length;
  final n = daysBetween(_rotationAnchor, day) % len;
  return n < 0 ? n + len : n;
}

List<Subject> subjectsForDay(String day, [int grade = 6]) => rotationFor(grade)[rotationIndex(day, grade)];

/// Thứ tự thử thay môn khi một môn chưa đủ câu hỏi: các môn của những ngày
/// tiếp theo trong chu kỳ.
List<Subject> fallbackOrder(String day, [int grade = 6]) {
  final rot = rotationFor(grade);
  final out = <Subject>[];
  for (var i = 1; i <= rot.length; i++) {
    for (final s in rot[(rotationIndex(day, grade) + i) % rot.length]) {
      if (!out.contains(s)) out.add(s);
    }
  }
  return out;
}
