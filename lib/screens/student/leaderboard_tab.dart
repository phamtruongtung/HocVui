import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../logic/dates.dart';
import '../../logic/rules.dart';
import '../../models/models.dart';
import '../../state/session.dart';
import '../../theme.dart';
import '../../widgets/common.dart';

class LeaderboardTab extends StatelessWidget {
  const LeaderboardTab({super.key});

  @override
  Widget build(BuildContext context) {
    final session = context.read<Session>();
    final me = session.profile!.uid;
    final now = DateTime.now();
    final week = weekKey(now);
    final monday = parseDay(week);
    final sunday = DateTime(monday.year, monday.month, monday.day + 6);
    final daysLeft = 7 - now.weekday;
    return StreamBuilder<List<LeaderRow>>(
      stream: session.repo.watchLeaderboard(week),
      builder: (context, snap) {
        if (snap.hasError) return ErrorView('Không tải được bảng xếp hạng: ${snap.error}');
        if (!snap.hasData) return const Loading();
        final rows = snap.data!;
        return AppPage(children: [
          Row(children: [
            Expanded(child: Text('Xếp hạng tuần', style: display(24))),
            Pill(daysLeft == 0 ? 'Chốt tối nay' : 'Còn $daysLeft ngày', bg: AppColors.seaSoft, fg: AppColors.seaInk),
          ]),
          Text('Tuần ${monday.day}/${monday.month} – ${sunday.day}/${sunday.month} · xếp chung các lớp',
              style: const TextStyle(fontSize: 12.5, color: AppColors.muted)),
          if (rows.length >= 3) _podium(rows),
          for (var i = 0; i < rows.length; i++) _row(i + 1, rows[i], rows[i].uid == me),
          if (rows.isEmpty) const EmptyView('Tuần này chưa ai làm bài. Làm đề đầu tiên để đứng đầu bảng!'),
          Text(
            'Điểm thi đua = tổng điểm các đề trong tuần (mỗi đề tối đa 10) + ${earlyBonusPoints.toInt()} điểm '
            'mỗi ngày xong cả bài trước 21:00. Bằng điểm thì ai làm nhanh hơn đứng trên. '
            'Top 3 nhận ${weeklyPrizes.join(' / ')} xu vào thứ Hai.',
            style: const TextStyle(fontSize: 12, color: AppColors.muted),
          ),
        ]);
      },
    );
  }

  Widget _podium(List<LeaderRow> rows) {
    Widget col(LeaderRow r, int place, double height, Color color) => Expanded(
          child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
            Avatar(_initials(r.name), color: avatarColor(r.uid), size: place == 1 ? 44 : 36),
            const SizedBox(height: 4),
            Text(r.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5)),
            Text('L${r.grade} · ${fmtScore(r.points)}', style: const TextStyle(fontSize: 11, color: AppColors.muted)),
            const SizedBox(height: 4),
            Container(
              height: height,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: color, borderRadius: const BorderRadius.vertical(top: Radius.circular(12))),
              child: Text('$place', style: display(22, color: Colors.white)),
            ),
          ]),
        );
    return SizedBox(
      height: 170,
      child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
        col(rows[1], 2, 56, const Color(0xFF9AA9BF)),
        const SizedBox(width: 6),
        col(rows[0], 1, 80, AppColors.sun),
        const SizedBox(width: 6),
        col(rows[2], 3, 42, const Color(0xFFD98B5A)),
      ]),
    );
  }

  Widget _row(int place, LeaderRow r, bool me) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: me ? AppColors.leafSoft : AppColors.paper,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: me ? const Color(0xFFBFE8CF) : AppColors.line, width: 2),
        ),
        child: Row(children: [
          SizedBox(width: 24, child: Text('$place', style: display(17, color: AppColors.muted))),
          Avatar(_initials(r.name), color: avatarColor(r.uid), size: 30),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(me ? '${r.name} (bạn)' : r.name, style: const TextStyle(fontWeight: FontWeight.w700)),
              Text('Lớp ${r.grade}', style: const TextStyle(fontSize: 11, color: AppColors.muted)),
            ]),
          ),
          Text(fmtScore(r.points), style: display(18)),
        ]),
      );

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts[parts.length - 2][0] + parts.last[0]).toUpperCase();
  }
}
