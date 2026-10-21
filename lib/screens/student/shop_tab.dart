import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../logic/rules.dart';
import '../../models/models.dart';
import '../../services/repo.dart';
import '../../state/session.dart';
import '../../theme.dart';
import '../../widgets/common.dart';

class ShopTab extends StatefulWidget {
  const ShopTab({super.key});

  @override
  State<ShopTab> createState() => _ShopTabState();
}

class _ShopTabState extends State<ShopTab> {
  late final Stream<Profile> _profile;
  late final Stream<List<Reward>> _rewards;
  late final Stream<List<Redemption>> _history;

  @override
  void initState() {
    super.initState();
    final s = context.read<Session>();
    final uid = s.profile!.uid;
    _profile = s.repo.watchProfile(uid);
    _rewards = s.repo.watchRewardsForKid(uid);
    _history = s.repo.watchKidRedemptions(uid);
  }

  Future<void> _redeem(Profile p, Reward r) async {
    final ok = await confirm(context, 'Đổi "${r.name}"?',
        'Dùng ${fmtInt(r.cost)} xu. Bố mẹ sẽ duyệt yêu cầu; nếu bố mẹ không đồng ý, xu được hoàn lại.',
        ok: 'Đổi thưởng');
    if (!ok || !mounted) return;
    try {
      await context.read<Session>().repo.redeem(p, r);
      if (mounted) showSnack(context, 'Đã gửi yêu cầu cho bố mẹ!');
    } on AppError catch (e) {
      if (mounted) showSnack(context, e.message, error: true);
    } catch (e) {
      if (mounted) showSnack(context, 'Không đổi được: $e', error: true);
    }
  }

  Future<void> _buyShield(Profile p) async {
    final ok = await confirm(context, 'Mua khiên chuỗi?',
        'Dùng $shieldPrice xu. Khiên tự giữ chuỗi khi bạn lỡ một ngày (vẫn bị trừ chuyên cần).',
        ok: 'Mua');
    if (!ok || !mounted) return;
    try {
      await context.read<Session>().repo.buyShield(p);
      if (mounted) showSnack(context, 'Đã mua khiên!');
    } on AppError catch (e) {
      if (mounted) showSnack(context, e.message, error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Profile>(
      stream: _profile,
      builder: (context, ps) {
        if (!ps.hasData) return const Loading();
        final p = ps.data!;
        return AppPage(children: [
          _streakCard(p),
          Row(children: [
            const Expanded(child: SectionLabel('Phần thưởng bố mẹ đặt')),
            CoinPill(p.coins),
          ]),
          StreamBuilder<List<Reward>>(
            stream: _rewards,
            builder: (context, rs) {
              if (rs.hasError) return Text('Lỗi: ${rs.error}');
              if (!rs.hasData) return const LinearProgressIndicator();
              final list = rs.data!;
              if (list.isEmpty) {
                return const EmptyView('Bố mẹ chưa đặt phần thưởng nào. Hãy liên kết tài khoản với bố mẹ ở mục Tôi.');
              }
              return Column(children: [
                for (final r in list) ...[
                  _item(
                    title: r.name,
                    sub: p.coins >= r.cost ? 'Tối đa ${r.perWeek} lần/tuần' : 'Còn thiếu ${fmtInt(r.cost - p.coins)} xu',
                    cost: r.cost,
                    color: AppColors.leaf,
                    onTap: () => _redeem(p, r),
                  ),
                  const SizedBox(height: 8),
                ],
              ]);
            },
          ),
          const SectionLabel('Đồ trong game'),
          _item(
            title: 'Khiên chuỗi (đang có ${p.shields}/$maxShields)',
            sub: 'Giữ chuỗi khi lỡ một ngày',
            cost: shieldPrice,
            color: AppColors.sea,
            onTap: () => _buyShield(p),
          ),
          const SectionLabel('Lịch sử đổi thưởng'),
          StreamBuilder<List<Redemption>>(
            stream: _history,
            builder: (context, hs) {
              if (!hs.hasData) return const SizedBox.shrink();
              final list = hs.data!;
              if (list.isEmpty) return const Text('Chưa đổi lần nào.', style: TextStyle(color: AppColors.muted));
              return Column(children: [
                for (final r in list.take(20))
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    title: Text(r.name),
                    subtitle: Text('${fmtInt(r.cost)} xu'),
                    trailing: _status(r.status),
                  ),
              ]);
            },
          ),
        ]);
      },
    );
  }

  Widget _status(String s) => switch (s) {
        'approved' => const Pill('Đã duyệt', bg: AppColors.leafSoft, fg: AppColors.leafInk, size: 12),
        'rejected' => const Pill('Không duyệt', bg: AppColors.badSoft, fg: AppColors.badInk, size: 12),
        _ => const Pill('Chờ duyệt', bg: AppColors.sunSoft, fg: AppColors.sunInk, size: 12),
      };

  Widget _streakCard(Profile p) {
    final milestones = streakMilestones.entries.toList();
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFFFF8A4C), Color(0xFFFF5A3D)], begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(children: [
        Text('${p.streak}', style: display(52, color: Colors.white)),
        const Text('ngày học liên tục', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
        Text('Kỷ lục ${p.bestStreak} ngày · Chuyên cần ${p.attendance} · Khiên ${p.shields}',
            style: const TextStyle(color: Colors.white, fontSize: 12)),
        const SizedBox(height: 10),
        Row(children: [
          for (final m in milestones)
            Expanded(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 3),
                padding: const EdgeInsets.symmetric(vertical: 6),
                decoration: BoxDecoration(
                  color: p.streak >= m.key ? Colors.white : Colors.white.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(children: [
                  Text('${m.key}', style: display(17, color: p.streak >= m.key ? AppColors.flame : Colors.white)),
                  Text('+${fmtInt(m.value)}',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: p.streak >= m.key ? AppColors.flame : Colors.white)),
                ]),
              ),
            ),
        ]),
      ]),
    );
  }

  Widget _item({required String title, required String sub, required int cost, required Color color, required VoidCallback onTap}) =>
      AppCard(
        onTap: onTap,
        padding: const EdgeInsets.all(10),
        child: Row(children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(11),
              border: Border.all(color: color, width: 3),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
              Text(sub, style: const TextStyle(fontSize: 12, color: AppColors.muted)),
            ]),
          ),
          CoinPill(cost),
        ]),
      );
}
