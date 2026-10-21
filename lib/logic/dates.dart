/// Ngày dạng 'yyyy-MM-dd' theo giờ máy (app dùng giờ Việt Nam, không có giờ mùa hè).
String dayKey(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${_2(d.month)}-${_2(d.day)}';

String _2(int n) => n.toString().padLeft(2, '0');

DateTime parseDay(String key) {
  final p = key.split('-').map(int.parse).toList();
  return DateTime(p[0], p[1], p[2]);
}

DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

String addDays(String key, int days) {
  final d = parseDay(key);
  return dayKey(DateTime(d.year, d.month, d.day + days));
}

/// Số ngày từ [a] tới [b] (b - a), tính theo lịch.
int daysBetween(String a, String b) {
  final da = parseDay(a), db = parseDay(b);
  return DateTime.utc(db.year, db.month, db.day)
      .difference(DateTime.utc(da.year, da.month, da.day))
      .inDays;
}

/// Tuần bắt đầu thứ Hai; khóa tuần là ngày thứ Hai đó.
String weekKey(DateTime d) {
  final day = dateOnly(d);
  return dayKey(DateTime(day.year, day.month, day.day - (day.weekday - 1)));
}

String prevWeekKey(DateTime d) {
  final day = dateOnly(d);
  return weekKey(DateTime(day.year, day.month, day.day - 7));
}

const _weekdayShort = ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'];
const _weekdayLong = ['Thứ Hai', 'Thứ Ba', 'Thứ Tư', 'Thứ Năm', 'Thứ Sáu', 'Thứ Bảy', 'Chủ nhật'];

String weekdayShort(DateTime d) => _weekdayShort[d.weekday - 1];

/// Ví dụ: "Thứ Ba 13/10".
String prettyDay(DateTime d) => '${_weekdayLong[d.weekday - 1]} ${d.day}/${d.month}';

/// Ví dụ: "13/10 · 20:41".
String prettyTime(DateTime d) => '${d.day}/${d.month} · ${_2(d.hour)}:${_2(d.minute)}';

/// mm:ss
String clock(Duration d) {
  final s = d.inSeconds < 0 ? 0 : d.inSeconds;
  return '${_2(s ~/ 60)}:${_2(s % 60)}';
}
