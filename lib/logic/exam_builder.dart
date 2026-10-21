import 'dart:math';

import '../models/models.dart';

/// Số câu tối thiểu để một môn đủ ra đề trong ngày.
const minQuestionsPerExam = 5;

/// Chọn câu hỏi cho một đề.
///
/// - Chỉ lấy bài đã học tới [upTo] (0 = mọi bài).
/// - Mỗi mức lấy đúng số câu trong [levelCounts]; khoảng một nửa lấy từ
///   4 bài học gần nhất, phần còn lại từ các bài trước đó.
/// - Ưu tiên câu chưa gặp gần đây (không nằm trong [recentIds]).
/// - Mức nào thiếu câu thì bù bằng câu của mức gần nhất.
/// - Kết quả xếp từ dễ tới khó.
List<Question> buildExam({
  required List<Question> pool,
  required List<int> levelCounts,
  Set<String> recentIds = const {},
  int upTo = 0,
  Random? rng,
}) {
  final r = rng ?? Random();
  final usable = pool.where((q) => upTo <= 0 || q.lessonOrder <= upTo).toList();
  if (usable.isEmpty) return const [];
  final newestLesson = usable.map((q) => q.lessonOrder).reduce(max);
  bool isRecentLesson(Question q) => q.lessonOrder > newestLesson - 4;

  final byLevel = <int, List<Question>>{};
  for (var lv = 1; lv <= 4; lv++) {
    final list = usable.where((q) => q.level == lv).toList()..shuffle(r);
    // Câu chưa gặp lên trước, trong đó câu của bài gần nhất lên trước nữa.
    final fresh = list.where((q) => !recentIds.contains(q.id)).toList();
    final seen = list.where((q) => recentIds.contains(q.id)).toList();
    byLevel[lv] = [...fresh, ...seen];
  }

  final picked = <Question>[];
  final shortfall = <int, int>{};
  for (var lv = 1; lv <= 4; lv++) {
    final need = lv - 1 < levelCounts.length ? levelCounts[lv - 1] : 0;
    final cands = byLevel[lv]!;
    final recentHalf = (need + 1) ~/ 2;
    final chosen = <Question>[];
    for (final q in cands) {
      if (chosen.length >= recentHalf) break;
      if (isRecentLesson(q) && !recentIds.contains(q.id)) chosen.add(q);
    }
    for (final q in cands) {
      if (chosen.length >= need) break;
      if (!chosen.contains(q)) chosen.add(q);
    }
    for (final q in chosen) {
      cands.remove(q);
    }
    picked.addAll(chosen);
    if (chosen.length < need) shortfall[lv] = need - chosen.length;
  }

  // Bù câu thiếu bằng mức gần nhất (ưu tiên mức dễ hơn liền kề, rồi khó hơn).
  for (final entry in shortfall.entries) {
    var missing = entry.value;
    for (final d in [1, -1, 2, -2, 3, -3]) {
      if (missing == 0) break;
      final lv = entry.key - d;
      if (lv < 1 || lv > 4) continue;
      final cands = byLevel[lv]!;
      while (missing > 0 && cands.isNotEmpty) {
        picked.add(cands.removeAt(0));
        missing--;
      }
    }
  }

  picked.sort((a, b) => a.level.compareTo(b.level));
  return picked;
}

/// Xáo thứ tự 4 phương án (đáp án đúng đổi vị trí theo).
Question shuffleOptions(Question q, Random rng) {
  if (q.options.length < 2 || q.answer < 0 || q.answer >= q.options.length) return q;
  final order = List.generate(q.options.length, (i) => i)..shuffle(rng);
  return q.copyWith(
    options: [for (final i in order) q.options[i]],
    answer: order.indexOf(q.answer),
  );
}

/// Tiêu đề đề thi từ danh sách bài có trong đề.
String examTitle(List<Question> qs) {
  final lessons = <String>[];
  for (final q in qs) {
    if (q.lessonTitle.isNotEmpty && !lessons.contains(q.lessonTitle)) lessons.add(q.lessonTitle);
  }
  if (lessons.isEmpty) return 'Ôn tập tổng hợp';
  if (lessons.length == 1) return lessons.first;
  return '${lessons.last} và ${lessons.length - 1} bài khác';
}
