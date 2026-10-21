import 'dates.dart';

// ---------------- Xu thưởng ----------------

const coinsPerExam = 20;
const coinsPerLevel = [1, 2, 4, 6]; // NB, TH, VD, VDC
const coinsHighScore = 15; // đề đạt từ 9 điểm
const coinsMistakeFixed = 2;
const streakMilestones = {3: 30, 7: 80, 30: 400, 100: 1500};
const weeklyPrizes = [200, 120, 80];
const shieldPrice = 300;
const maxShields = 2;

// ---------------- Chuyên cần ----------------

const attendanceStart = 100;
const attendanceMax = 100;
const attendancePartialPenalty = 5; // mới xong một phần số đề
const attendanceMissPenalty = 10; // không làm đề nào

// ---------------- Thi đua tuần ----------------

const earlyBonusHour = 21; // xong cả ngày trước 21:00
const earlyBonusPoints = 5.0;

/// Điểm thang 10, làm tròn 1 chữ số thập phân.
double score10(int correct, int total) {
  if (total <= 0) return 0;
  return (correct * 100 / total).round() / 10;
}

/// Xu nhận được khi nộp một đề. [correctByLevel] là số câu đúng ở mỗi mức 1..4.
int examCoins(List<int> correctByLevel, double score) {
  var coins = coinsPerExam;
  for (var i = 0; i < 4 && i < correctByLevel.length; i++) {
    coins += correctByLevel[i] * coinsPerLevel[i];
  }
  if (score >= 9) coins += coinsHighScore;
  return coins;
}

/// Thống kê chuỗi và chuyên cần của một học sinh.
class Stats {
  const Stats({
    required this.streak,
    required this.bestStreak,
    required this.attendance,
    required this.shields,
    required this.coins,
    required this.lastCompletedDay,
    required this.lastClosedDay,
  });

  final int streak;
  final int bestStreak;
  final int attendance;
  final int shields;
  final int coins;
  final String? lastCompletedDay;
  final String lastClosedDay;

  Stats copyWith({
    int? streak,
    int? bestStreak,
    int? attendance,
    int? shields,
    int? coins,
    String? lastCompletedDay,
    String? lastClosedDay,
  }) =>
      Stats(
        streak: streak ?? this.streak,
        bestStreak: bestStreak ?? this.bestStreak,
        attendance: attendance ?? this.attendance,
        shields: shields ?? this.shields,
        coins: coins ?? this.coins,
        lastCompletedDay: lastCompletedDay ?? this.lastCompletedDay,
        lastClosedDay: lastClosedDay ?? this.lastClosedDay,
      );
}

/// Kết quả của một ngày đã qua: số đề phải làm và số đề đã xong.
class PastDay {
  const PastDay(this.day, {required this.required, required this.done});
  final String day;
  final int required;
  final int done;
}

/// Sự kiện khi chốt ngày, để báo cho học sinh.
class ClosingNote {
  const ClosingNote(this.day, this.text);
  final String day;
  final String text;
}

/// Chốt các ngày đã qua (từ sau [Stats.lastClosedDay] tới hôm qua).
/// Ngày không có trong [history] được coi là không làm đề nào (phải làm 2 đề).
({Stats stats, List<ClosingNote> notes}) closeDays(
    Stats s, String today, Map<String, PastDay> history,
    {int requiredDefault = 2}) {
  var st = s;
  final notes = <ClosingNote>[];
  final yesterday = addDays(today, -1);
  var d = addDays(s.lastClosedDay, 1);
  // Lâu không mở app: chỉ xét tối đa 60 ngày gần nhất.
  if (daysBetween(d, yesterday) > 60) d = addDays(yesterday, -60);
  while (daysBetween(d, yesterday) >= 0) {
    final h = history[d] ?? PastDay(d, required: requiredDefault, done: 0);
    if (h.required > 0 && h.done < h.required) {
      final penalty = h.done == 0 ? attendanceMissPenalty : attendancePartialPenalty;
      var attendance = st.attendance - penalty;
      if (attendance < 0) attendance = 0;
      if (st.shields > 0 && st.streak > 0) {
        st = st.copyWith(attendance: attendance, shields: st.shields - 1);
        notes.add(ClosingNote(d, 'Khiên bảo vệ đã giữ chuỗi ngày $d, chuyên cần −$penalty.'));
      } else {
        if (st.streak > 0) {
          notes.add(ClosingNote(d, 'Mất chuỗi ${st.streak} ngày vì chưa xong bài ngày $d, chuyên cần −$penalty.'));
        } else {
          notes.add(ClosingNote(d, 'Chưa xong bài ngày $d, chuyên cần −$penalty.'));
        }
        st = st.copyWith(attendance: attendance, streak: 0);
      }
    }
    d = addDays(d, 1);
  }
  return (stats: st.copyWith(lastClosedDay: yesterday), notes: notes);
}

/// Học sinh vừa xong toàn bộ đề hôm nay: tăng chuỗi, chuyên cần, thưởng mốc.
({Stats stats, int milestoneCoins}) completeToday(Stats s, String today) {
  if (s.lastCompletedDay == today) return (stats: s, milestoneCoins: 0);
  final streak = s.streak + 1;
  final bonus = streakMilestones[streak] ?? 0;
  var attendance = s.attendance + 1;
  if (attendance > attendanceMax) attendance = attendanceMax;
  return (
    stats: s.copyWith(
      streak: streak,
      bestStreak: streak > s.bestStreak ? streak : s.bestStreak,
      attendance: attendance,
      coins: s.coins + bonus,
      lastCompletedDay: today,
    ),
    milestoneCoins: bonus,
  );
}

// ---------------- Sổ tay lỗi sai ----------------

/// Khoảng cách ôn lại sau khi trả lời đúng ở mỗi bậc (bậc 0 → 3 ngày, ...).
/// Sai lần đầu: hỏi lại sau 1 ngày. Đúng đủ 3 lần thì "Đã thuộc".
const mistakeIntervals = [1, 3, 7];

/// Kết quả ôn một câu lỗi sai. Trả về bậc mới, ngày ôn tiếp và đã thuộc chưa.
({int stage, String nextDue, bool mastered}) reviewMistake(
    int stage, bool correct, String today) {
  if (!correct) return (stage: 0, nextDue: addDays(today, mistakeIntervals[0]), mastered: false);
  final next = stage + 1;
  if (next >= mistakeIntervals.length) {
    return (stage: next, nextDue: today, mastered: true);
  }
  return (stage: next, nextDue: addDays(today, mistakeIntervals[next]), mastered: false);
}

// ---------------- Xếp hạng tuần ----------------

class RankRow {
  const RankRow(this.uid, this.points, this.seconds);
  final String uid;
  final double points;
  final int seconds;
}

/// Sắp xếp: điểm cao đứng trên; bằng điểm thì ai làm bài nhanh hơn đứng trên.
List<RankRow> sortRanking(Iterable<RankRow> rows) {
  final list = rows.toList();
  list.sort((a, b) {
    final c = b.points.compareTo(a.points);
    return c != 0 ? c : a.seconds.compareTo(b.seconds);
  });
  return list;
}

/// Xu thưởng tuần cho [uid] theo bảng đã sắp xếp (0 nếu ngoài top 3).
int weeklyPrizeFor(String uid, List<RankRow> sorted) {
  for (var i = 0; i < weeklyPrizes.length && i < sorted.length; i++) {
    if (sorted[i].uid == uid && sorted[i].points > 0) return weeklyPrizes[i];
  }
  return 0;
}
