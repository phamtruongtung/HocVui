import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:hoc_vui/logic/dates.dart';
import 'package:hoc_vui/logic/exam_builder.dart';
import 'package:hoc_vui/logic/rules.dart';
import 'package:hoc_vui/logic/subjects.dart';
import 'package:hoc_vui/models/models.dart';

Stats _stats({int streak = 0, int attendance = 100, int shields = 0, int coins = 0, String closed = '2026-10-12', String? completed}) =>
    Stats(
      streak: streak,
      bestStreak: streak,
      attendance: attendance,
      shields: shields,
      coins: coins,
      lastCompletedDay: completed,
      lastClosedDay: closed,
    );

Question _q(String id, int level, int lesson) => Question(
      id: id,
      grade: 7,
      subject: Subject.toan,
      lessonOrder: lesson,
      lessonTitle: 'Bài $lesson',
      level: level,
      text: 'Câu $id',
      options: const ['a', 'b', 'c', 'd'],
      answer: 0,
    );

void main() {
  group('dates', () {
    test('weekKey là thứ Hai', () {
      expect(weekKey(DateTime(2026, 10, 13)), '2026-10-12'); // thứ Ba
      expect(weekKey(DateTime(2026, 10, 18)), '2026-10-12'); // Chủ nhật
      expect(weekKey(DateTime(2026, 10, 19)), '2026-10-19');
      expect(prevWeekKey(DateTime(2026, 10, 13)), '2026-10-05');
    });

    test('addDays và daysBetween qua tháng, năm', () {
      expect(addDays('2026-12-31', 1), '2027-01-01');
      expect(addDays('2026-03-01', -1), '2026-02-28');
      expect(daysBetween('2026-10-01', '2026-10-13'), 12);
    });
  });

  group('lịch ôn xoay vòng', () {
    test('mỗi ngày 2 môn khác nhau', () {
      for (var i = 0; i < 30; i++) {
        final s = subjectsForDay(addDays('2026-10-01', i));
        expect(s.length, 2);
        expect(s[0] == s[1], isFalse);
      }
    });

    test('cứ 5 ngày mỗi môn đúng 2 đề', () {
      for (var start = 0; start < 5; start++) {
        final counts = <Subject, int>{};
        for (var i = 0; i < 5; i++) {
          for (final s in subjectsForDay(addDays('2026-10-01', start + i))) {
            counts[s] = (counts[s] ?? 0) + 1;
          }
        }
        expect(counts.values.every((c) => c == 2), isTrue);
        expect(counts.length, 5);
      }
    });

    test('số câu mỗi đề', () {
      expect(Subject.toan.questionCount, 15);
      expect(Subject.anh.questionCount, 30);
    });
  });

  group('xu và điểm', () {
    test('score10', () {
      expect(score10(13, 15), 8.7);
      expect(score10(15, 15), 10);
      expect(score10(0, 15), 0);
    });

    test('examCoins theo ví dụ trong tài liệu', () {
      // 6 NB, 4 TH, 2 VD, 1 VDC đúng; điểm 8,7 → 20 + 6 + 8 + 8 + 6 = 48
      expect(examCoins([6, 4, 2, 1], 8.7), 48);
      expect(examCoins([6, 4, 3, 2], 10), 20 + 6 + 8 + 12 + 12 + 15);
    });
  });

  group('chuyên cần và chuỗi', () {
    test('xong đủ đề thì không bị trừ', () {
      final r = closeDays(_stats(streak: 5, closed: '2026-10-11'), '2026-10-13',
          {'2026-10-12': const PastDay('2026-10-12', required: 2, done: 2)});
      expect(r.stats.streak, 5);
      expect(r.stats.attendance, 100);
      expect(r.stats.lastClosedDay, '2026-10-12');
    });

    test('không làm thì −10 và mất chuỗi; làm một nửa thì −5', () {
      final r = closeDays(_stats(streak: 5, closed: '2026-10-10'), '2026-10-13',
          {'2026-10-11': const PastDay('2026-10-11', required: 2, done: 1)});
      // 11/10: −5, mất chuỗi; 12/10: không có dữ liệu → −10
      expect(r.stats.attendance, 85);
      expect(r.stats.streak, 0);
      expect(r.notes.length, 2);
    });

    test('khiên giữ chuỗi', () {
      final r = closeDays(_stats(streak: 8, shields: 1, closed: '2026-10-11'), '2026-10-13', {});
      expect(r.stats.streak, 8);
      expect(r.stats.shields, 0);
      expect(r.stats.attendance, 90);
    });

    test('ngày không có đề (required 0) không bị tính', () {
      final r = closeDays(_stats(streak: 3, closed: '2026-10-11'), '2026-10-13',
          {'2026-10-12': const PastDay('2026-10-12', required: 0, done: 0)});
      expect(r.stats.streak, 3);
      expect(r.stats.attendance, 100);
    });

    test('đã chốt tới hôm qua thì không làm gì', () {
      final r = closeDays(_stats(streak: 3, closed: '2026-10-12'), '2026-10-13', {});
      expect(r.stats.streak, 3);
      expect(r.notes, isEmpty);
    });

    test('completeToday tăng chuỗi và thưởng mốc', () {
      final r = completeToday(_stats(streak: 6, attendance: 99, coins: 10), '2026-10-13');
      expect(r.stats.streak, 7);
      expect(r.milestoneCoins, 80);
      expect(r.stats.coins, 90);
      expect(r.stats.attendance, 100);
      final again = completeToday(r.stats, '2026-10-13');
      expect(again.stats.streak, 7);
      expect(again.milestoneCoins, 0);
    });
  });

  group('sổ tay lỗi sai', () {
    test('đúng 3 lần thì thuộc, sai thì về đầu', () {
      var r = reviewMistake(0, true, '2026-10-13');
      expect((r.stage, r.nextDue, r.mastered), (1, '2026-10-16', false));
      r = reviewMistake(1, true, '2026-10-16');
      expect((r.stage, r.nextDue, r.mastered), (2, '2026-10-23', false));
      r = reviewMistake(2, true, '2026-10-23');
      expect(r.mastered, isTrue);
      r = reviewMistake(2, false, '2026-10-23');
      expect((r.stage, r.nextDue, r.mastered), (0, '2026-10-24', false));
    });
  });

  group('xếp hạng', () {
    test('bằng điểm thì ai nhanh hơn đứng trên', () {
      final rows = sortRanking(const [RankRow('a', 30, 900), RankRow('b', 35, 2000), RankRow('c', 30, 600)]);
      expect(rows.map((r) => r.uid).toList(), ['b', 'c', 'a']);
      expect(weeklyPrizeFor('c', rows), 120);
      expect(weeklyPrizeFor('x', rows), 0);
    });
  });

  group('tạo đề', () {
    final pool = <Question>[
      for (var lesson = 1; lesson <= 8; lesson++)
        for (var level = 1; level <= 4; level++)
          for (var k = 0; k < 3; k++) _q('L${lesson}_$level$k', level, lesson),
    ];

    test('đủ số câu theo từng mức, xếp từ dễ tới khó', () {
      final qs = buildExam(pool: pool, levelCounts: const [6, 4, 3, 2], rng: Random(1));
      expect(qs.length, 15);
      expect(qs.where((q) => q.level == 1).length, 6);
      expect(qs.where((q) => q.level == 4).length, 2);
      for (var i = 1; i < qs.length; i++) {
        expect(qs[i].level >= qs[i - 1].level, isTrue);
      }
      expect(qs.map((q) => q.id).toSet().length, 15);
    });

    test('chỉ lấy bài đã học tới upTo', () {
      final qs = buildExam(pool: pool, levelCounts: const [6, 4, 3, 2], upTo: 3, rng: Random(2));
      expect(qs.every((q) => q.lessonOrder <= 3), isTrue);
    });

    test('ưu tiên câu chưa gặp', () {
      final recent = pool.where((q) => q.lessonOrder <= 6).map((q) => q.id).toSet();
      final qs = buildExam(pool: pool, levelCounts: const [2, 2, 2, 2], recentIds: recent, rng: Random(3));
      expect(qs.where((q) => recent.contains(q.id)), isEmpty);
    });

    test('thiếu câu ở một mức thì bù bằng mức gần nhất', () {
      final small = pool.where((q) => q.level != 4).toList();
      final qs = buildExam(pool: small, levelCounts: const [6, 4, 3, 2], rng: Random(4));
      expect(qs.length, 15);
    });

    test('ngân hàng trống thì không có đề', () {
      expect(buildExam(pool: const [], levelCounts: const [6, 4, 3, 2]), isEmpty);
    });
  });

  group('mục lục', () {
    test('đọc chương và bài', () {
      final c = Curriculum(grade: 7, subject: Subject.toan, lines: const [
        '# Chương I. Số hữu tỉ',
        'Bài 1. Tập hợp các số hữu tỉ',
        'Bài 2. Cộng, trừ, nhân, chia số hữu tỉ',
        '# Chương II. Số thực',
        'Bài 5. Làm quen với số thập phân vô hạn tuần hoàn',
      ]);
      final ls = c.lessons;
      expect(ls.length, 3);
      expect(ls[2].order, 3);
      expect(ls[2].chapter, 'Chương II. Số thực');
    });
  });
}
