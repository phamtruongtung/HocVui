import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../logic/dates.dart';
import '../../logic/subjects.dart';
import '../../models/models.dart';
import '../../services/repo.dart';
import '../../state/session.dart';
import '../../theme.dart';
import '../../widgets/common.dart';
import '../student/exam_screens.dart';
import '../student/profile_tab.dart';

class ParentShell extends StatefulWidget {
  const ParentShell({super.key});

  @override
  State<ParentShell> createState() => _ParentShellState();
}

class _ParentShellState extends State<ParentShell> {
  int _tab = 0;
  int _unread = 0;
  StreamSubscription<List<Notice>>? _sub;
  final _seen = <String>{};
  bool _first = true;

  @override
  void initState() {
    super.initState();
    final s = context.read<Session>();
    _sub = s.repo.watchNotices(s.profile!.uid).listen((list) {
      // Có thông báo mới khi app đang mở: hiện lên thanh thông báo (Android).
      for (final n in list) {
        if (_seen.add(n.id) && !_first && !n.read) {
          s.notifier.showNow(n.id.hashCode & 0x7fffffff, n.title, n.body);
        }
      }
      _first = false;
      if (mounted) setState(() => _unread = list.where((n) => !n.read).length);
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: IndexedStack(index: _tab, children: const [
          ParentOverviewTab(),
          ParentNoticesTab(),
          ParentRewardsTab(),
          ParentSettingsTab(),
        ]),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: [
          const NavigationDestination(icon: Icon(Icons.insights_rounded), label: 'Tổng quan'),
          NavigationDestination(
            icon: Badge(isLabelVisible: _unread > 0, label: Text('$_unread'), child: const Icon(Icons.notifications_rounded)),
            label: 'Thông báo',
          ),
          const NavigationDestination(icon: Icon(Icons.redeem_rounded), label: 'Phần thưởng'),
          const NavigationDestination(icon: Icon(Icons.settings_rounded), label: 'Cài đặt'),
        ],
      ),
    );
  }
}

// =========================== Tổng quan ===========================

class ParentOverviewTab extends StatefulWidget {
  const ParentOverviewTab({super.key});

  @override
  State<ParentOverviewTab> createState() => _ParentOverviewTabState();
}

class _ParentOverviewTabState extends State<ParentOverviewTab> {
  late final Stream<List<LinkRequest>> _links;
  String? _kid;

  @override
  void initState() {
    super.initState();
    final s = context.read<Session>();
    _links = s.repo.watchParentLinks(s.profile!.uid);
  }

  @override
  Widget build(BuildContext context) {
    final me = context.read<Session>().profile!;
    return StreamBuilder<List<LinkRequest>>(
      stream: _links,
      builder: (context, snap) {
        if (snap.hasError) return ErrorView('Không tải được danh sách con: ${snap.error}');
        if (!snap.hasData) return const Loading();
        final kids = snap.data!.where((l) => l.status == 'accepted').toList();
        final pending = snap.data!.where((l) => l.status == 'pending').length;
        if (kids.isEmpty) {
          return AppPage(children: [
            Text('Chào ${me.displayName}', style: display(24)),
            AppCard(
              child: Column(children: [
                const Text('Mã phụ huynh của bạn', style: TextStyle(color: AppColors.muted)),
                Text(me.parentCode ?? '—', style: display(34)),
                const Text('Đưa mã này cho con nhập ở mục "Tôi" trong app của con, rồi xác nhận ở mục Cài đặt.',
                    textAlign: TextAlign.center, style: TextStyle(fontSize: 13, color: AppColors.muted)),
              ]),
            ),
            if (pending > 0)
              AppCard(
                color: AppColors.sunSoft,
                border: const Color(0xFFF5DFA0),
                child: Text('Có $pending yêu cầu liên kết đang chờ. Vào mục Cài đặt để xác nhận.'),
              ),
          ]);
        }
        final selected = kids.any((k) => k.kidUid == _kid) ? _kid! : kids.first.kidUid;
        return AppPage(children: [
          Row(children: [
            Expanded(child: Text('Tổng quan', style: display(24))),
            Pill(me.parentCode ?? '', bg: AppColors.paper),
          ]),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: [
              for (final k in kids)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    selected: k.kidUid == selected,
                    onSelected: (_) => setState(() => _kid = k.kidUid),
                    avatar: Avatar(_ini(k.kidName), color: avatarColor(k.kidUid), size: 26),
                    label: Text('${k.kidName.split(' ').last} · Lớp ${k.kidGrade}'),
                  ),
                ),
            ]),
          ),
          KidDashboard(key: ValueKey(selected), kidUid: selected),
        ]);
      },
    );
  }

  String _ini(String name) {
    final p = name.trim().split(RegExp(r'\s+'));
    if (p.length < 2) return name.isEmpty ? '?' : name[0].toUpperCase();
    return (p[p.length - 2][0] + p.last[0]).toUpperCase();
  }
}

/// Bảng theo dõi một con: hôm nay, chuỗi, điểm theo môn, 7 ngày qua, lỗi sai.
class KidDashboard extends StatefulWidget {
  const KidDashboard({super.key, required this.kidUid});
  final String kidUid;

  @override
  State<KidDashboard> createState() => _KidDashboardState();
}

class _KidDashboardState extends State<KidDashboard> {
  late final Stream<Profile> _profile;
  late final Stream<DayPlan?> _today;
  late final Stream<List<Mistake>> _mistakes;
  late final Stream<List<LeaderRow>> _board;
  late Future<List<Exam>> _exams;
  final _todayKey = dayKey(DateTime.now());

  @override
  void initState() {
    super.initState();
    final repo = context.read<Session>().repo;
    _profile = repo.watchProfile(widget.kidUid);
    _today = repo.watchDay(widget.kidUid, _todayKey);
    _mistakes = repo.watchMistakes(widget.kidUid);
    _board = repo.watchLeaderboard(weekKey(DateTime.now()));
    _exams = repo.kidExamsSince(widget.kidUid, addDays(_todayKey, -6));
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Profile>(
      stream: _profile,
      builder: (context, ps) {
        if (ps.hasError) return Text('Không xem được dữ liệu của con: ${ps.error}');
        if (!ps.hasData) return const LinearProgressIndicator();
        final kid = ps.data!;
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          StreamBuilder<DayPlan?>(
            stream: _today,
            builder: (context, ds) {
              final plan = ds.data;
              final String text;
              final bool good;
              if (plan == null) {
                text = '${kid.shortName} chưa mở app hôm nay.';
                good = false;
              } else if (plan.required == 0) {
                text = 'Hôm nay chưa có đề (ngân hàng câu hỏi chưa đủ).';
                good = true;
              } else if (plan.complete) {
                text = '${kid.shortName} đã xong ${plan.required}/${plan.required} đề hôm nay.';
                good = true;
              } else {
                final left = plan.subjects.length > plan.done ? plan.required - plan.done : 0;
                text = '${kid.shortName} mới xong ${plan.done}/${plan.required} đề hôm nay, còn $left đề. Hạn chót 23:59.';
                good = false;
              }
              return Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: good ? AppColors.leafSoft : AppColors.flameSoft,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(text, style: TextStyle(color: good ? AppColors.leafInk : AppColors.flameInk, fontWeight: FontWeight.w600)),
              );
            },
          ),
          const SizedBox(height: 12),
          StreamBuilder<List<LeaderRow>>(
            stream: _board,
            builder: (context, bs) {
              final rows = bs.data ?? const <LeaderRow>[];
              final idx = rows.indexWhere((r) => r.uid == kid.uid);
              return Row(children: [
                _stat('${kid.streak}', 'ngày chuỗi'),
                const SizedBox(width: 8),
                _stat('${kid.attendance}', 'chuyên cần'),
                const SizedBox(width: 8),
                _stat(idx < 0 ? '—' : '#${idx + 1}', 'hạng tuần'),
                const SizedBox(width: 8),
                _stat(fmtInt(kid.coins), 'xu'),
              ]);
            },
          ),
          const SizedBox(height: 12),
          FutureBuilder<List<Exam>>(
            future: _exams,
            builder: (context, es) {
              if (es.hasError) return Text('Lỗi tải bài làm: ${es.error}');
              if (!es.hasData) return const LinearProgressIndicator();
              return _examsSection(es.data!.where((e) => e.submitted).toList());
            },
          ),
          const SizedBox(height: 12),
          StreamBuilder<List<Mistake>>(
            stream: _mistakes,
            builder: (context, ms) {
              final list = ms.data ?? const <Mistake>[];
              return AppCard(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  SectionLabel('Lỗi sai chưa sửa',
                      trailing: Pill('${list.length} câu', bg: AppColors.badSoft, fg: AppColors.badInk, size: 12)),
                  if (list.isEmpty) const Text('Không có lỗi sai nào.', style: TextStyle(color: AppColors.muted)),
                  for (final m in list.take(8))
                    InkWell(
                      onTap: () => _showMistake(m),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Row(children: [
                          SubjectBadge(m.subject, size: 28),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(m.question.lessonTitle.isEmpty ? m.question.text : m.question.lessonTitle,
                                maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13)),
                          ),
                          Text(m.wrongAt == null ? '' : prettyTime(m.wrongAt!),
                              style: const TextStyle(fontSize: 11, color: AppColors.muted)),
                        ]),
                      ),
                    ),
                  if (list.length > 8)
                    Text('và ${list.length - 8} câu khác', style: const TextStyle(fontSize: 12, color: AppColors.muted)),
                ]),
              );
            },
          ),
        ]);
      },
    );
  }

  void _showMistake(Mistake m) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (c) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: QuestionReview(number: 1, question: m.question, chosen: m.chosen),
        ),
      ),
    );
  }

  Widget _stat(String value, String label) => Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(color: AppColors.paper, borderRadius: BorderRadius.circular(12)),
          child: Column(children: [
            Text(value, style: display(20)),
            Text(label, style: const TextStyle(fontSize: 10.5, color: AppColors.muted)),
          ]),
        ),
      );

  Widget _examsSection(List<Exam> exams) {
    // Số đề xong theo ngày (7 ngày qua).
    final days = [for (var i = 6; i >= 0; i--) addDays(_todayKey, -i)];
    final perDay = {for (final d in days) d: exams.where((e) => e.day == d).length};
    final maxDay = perDay.values.fold(2, (a, b) => a > b ? a : b);
    // Điểm trung bình theo môn.
    final bySubject = <Subject, List<double>>{};
    for (final e in exams) {
      bySubject.putIfAbsent(e.subject, () => []).add(e.score);
    }
    final avgAll = exams.isEmpty ? 0.0 : exams.map((e) => e.score).reduce((a, b) => a + b) / exams.length;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      AppCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SectionLabel('Số đề đã làm 7 ngày qua',
              trailing: Text('TB ${fmtScore(avgAll)} điểm', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700))),
          const SizedBox(height: 8),
          SizedBox(
            height: 96,
            child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
              for (final d in days)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
                      Text(perDay[d] == 0 ? 'nghỉ' : '${perDay[d]}',
                          style: TextStyle(fontSize: 10.5, color: perDay[d] == 0 ? AppColors.bad : AppColors.muted)),
                      const SizedBox(height: 2),
                      Container(
                        height: perDay[d] == 0 ? 5.0 : 56.0 * perDay[d]! / maxDay,
                        decoration: BoxDecoration(
                          color: perDay[d] == 0 ? AppColors.bad : AppColors.sea,
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(6), bottom: Radius.circular(3)),
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(weekdayShort(parseDay(d)), style: const TextStyle(fontSize: 10.5, color: AppColors.muted)),
                    ]),
                  ),
                ),
            ]),
          ),
        ]),
      ),
      const SizedBox(height: 12),
      AppCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const SectionLabel('Điểm trung bình theo môn (7 ngày)'),
          const SizedBox(height: 6),
          for (final s in Subject.values)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(children: [
                SizedBox(width: 74, child: Text(s.short, style: const TextStyle(fontSize: 13))),
                Expanded(
                  child: Bar(bySubject[s] == null ? 0 : _avg(bySubject[s]!) / 10, color: subjectColor(s)),
                ),
                SizedBox(
                  width: 40,
                  child: Text(bySubject[s] == null ? '—' : fmtScore(_avg(bySubject[s]!)),
                      textAlign: TextAlign.right, style: const TextStyle(fontWeight: FontWeight.w700)),
                ),
              ]),
            ),
        ]),
      ),
    ]);
  }

  double _avg(List<double> v) => v.reduce((a, b) => a + b) / v.length;
}

// =========================== Thông báo ===========================

class ParentNoticesTab extends StatefulWidget {
  const ParentNoticesTab({super.key});

  @override
  State<ParentNoticesTab> createState() => _ParentNoticesTabState();
}

class _ParentNoticesTabState extends State<ParentNoticesTab> {
  late final Stream<List<Notice>> _stream;

  @override
  void initState() {
    super.initState();
    final s = context.read<Session>();
    _stream = s.repo.watchNotices(s.profile!.uid);
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Notice>>(
      stream: _stream,
      builder: (context, snap) {
        if (snap.hasError) return ErrorView('Không tải được thông báo: ${snap.error}');
        if (!snap.hasData) return const Loading();
        final list = snap.data!;
        final unread = list.where((n) => !n.read).length;
        return AppPage(children: [
          Row(children: [
            Expanded(child: Text('Thông báo', style: display(24))),
            if (unread > 0)
              TextButton(
                onPressed: () => context.read<Session>().repo.markNoticesRead(list),
                child: Text('Đánh dấu đã đọc ($unread)'),
              ),
          ]),
          for (final n in list.take(100))
            AppCard(
              color: n.read ? AppColors.paper : AppColors.seaSoft,
              border: n.read ? AppColors.line : const Color(0xFFBFDDF3),
              padding: const EdgeInsets.all(12),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Icon(_icon(n.kind), color: _color(n.kind)),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(n.title, style: const TextStyle(fontWeight: FontWeight.w700)),
                    if (n.body.isNotEmpty) Text(n.body, style: const TextStyle(fontSize: 13)),
                    if (n.createdAt != null)
                      Text(prettyTime(n.createdAt!), style: const TextStyle(fontSize: 11, color: AppColors.muted)),
                  ]),
                ),
              ]),
            ),
          if (list.isEmpty) const EmptyView('Chưa có thông báo nào.'),
        ]);
      },
    );
  }

  IconData _icon(String kind) => switch (kind) {
        'mistakes' => Icons.error_outline_rounded,
        'done' => Icons.check_circle_rounded,
        'redeem' => Icons.redeem_rounded,
        'link' => Icons.link_rounded,
        _ => Icons.notifications_rounded,
      };

  Color _color(String kind) => switch (kind) {
        'mistakes' => AppColors.bad,
        'done' => AppColors.leaf,
        'redeem' => AppColors.sun,
        _ => AppColors.sea,
      };
}

// =========================== Phần thưởng ===========================

class ParentRewardsTab extends StatefulWidget {
  const ParentRewardsTab({super.key});

  @override
  State<ParentRewardsTab> createState() => _ParentRewardsTabState();
}

class _ParentRewardsTabState extends State<ParentRewardsTab> {
  late final Stream<List<Reward>> _rewards;
  late final Stream<List<Redemption>> _requests;
  late final Stream<List<LinkRequest>> _links;

  @override
  void initState() {
    super.initState();
    final s = context.read<Session>();
    final uid = s.profile!.uid;
    _rewards = s.repo.watchParentRewards(uid);
    _requests = s.repo.watchParentRedemptions(uid);
    _links = s.repo.watchParentLinks(uid);
  }

  Future<void> _decide(Redemption r, bool approve) async {
    try {
      await context.read<Session>().repo.decideRedemption(r, approve);
    } catch (e) {
      if (mounted) showSnack(context, 'Lỗi: $e', error: true);
    }
  }

  Future<void> _edit(List<LinkRequest> kids, [Reward? old]) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _RewardForm(kids: kids, old: old),
    );
    if (saved == true && mounted) showSnack(context, 'Đã lưu phần thưởng.');
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<LinkRequest>>(
      stream: _links,
      builder: (context, ls) {
        final kids = (ls.data ?? const <LinkRequest>[]).where((l) => l.status == 'accepted').toList();
        return AppPage(children: [
          Text('Phần thưởng', style: display(24)),
          const SectionLabel('Chờ duyệt'),
          StreamBuilder<List<Redemption>>(
            stream: _requests,
            builder: (context, rs) {
              final list = rs.data ?? const <Redemption>[];
              final pending = list.where((r) => r.status == 'pending').toList();
              if (pending.isEmpty) return const Text('Không có yêu cầu nào.', style: TextStyle(color: AppColors.muted));
              return Column(children: [
                for (final r in pending)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: AppCard(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                        Text('${r.kidName} muốn đổi "${r.name}"', style: const TextStyle(fontWeight: FontWeight.w700)),
                        Row(children: [
                          CoinPill(r.cost),
                          const Spacer(),
                          if (r.createdAt != null)
                            Text(prettyTime(r.createdAt!), style: const TextStyle(fontSize: 11, color: AppColors.muted)),
                        ]),
                        const SizedBox(height: 8),
                        Row(children: [
                          Expanded(child: OutlinedButton(onPressed: () => _decide(r, false), child: const Text('Từ chối, hoàn xu'))),
                          const SizedBox(width: 8),
                          Expanded(child: FilledButton(onPressed: () => _decide(r, true), child: const Text('Duyệt'))),
                        ]),
                      ]),
                    ),
                  ),
              ]);
            },
          ),
          SectionLabel('Phần thưởng đã đặt',
              trailing: TextButton.icon(
                onPressed: kids.isEmpty ? null : () => _edit(kids),
                icon: const Icon(Icons.add_rounded),
                label: const Text('Thêm'),
              )),
          if (kids.isEmpty) const Text('Hãy liên kết với con trước (mục Cài đặt).', style: TextStyle(color: AppColors.muted)),
          StreamBuilder<List<Reward>>(
            stream: _rewards,
            builder: (context, rs) {
              final list = rs.data ?? const <Reward>[];
              if (list.isEmpty) return const Text('Chưa có phần thưởng nào.', style: TextStyle(color: AppColors.muted));
              return Column(children: [
                for (final r in list)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: AppCard(
                      onTap: () => _edit(kids, r),
                      padding: const EdgeInsets.all(10),
                      child: Row(children: [
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(r.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                            Text(
                              'Tối đa ${r.perWeek} lần/tuần · '
                              '${kids.where((k) => r.kidUids.contains(k.kidUid)).map((k) => k.kidName.split(' ').last).join(', ')}',
                              style: const TextStyle(fontSize: 12, color: AppColors.muted),
                            ),
                          ]),
                        ),
                        CoinPill(r.cost),
                        IconButton(
                          icon: const Icon(Icons.delete_outline_rounded),
                          onPressed: () async {
                            if (await confirm(context, 'Xóa phần thưởng?', 'Con sẽ không thấy "${r.name}" nữa.', ok: 'Xóa')) {
                              if (context.mounted) await context.read<Session>().repo.removeReward(r.id);
                            }
                          },
                        ),
                      ]),
                    ),
                  ),
              ]);
            },
          ),
          const Text(
            'Gợi ý giá: một ngày làm tốt cả 2 đề được khoảng 80–120 xu, nên 500 xu tương đương khoảng 5 ngày học chăm.',
            style: TextStyle(fontSize: 12, color: AppColors.muted),
          ),
        ]);
      },
    );
  }
}

class _RewardForm extends StatefulWidget {
  const _RewardForm({required this.kids, this.old});
  final List<LinkRequest> kids;
  final Reward? old;

  @override
  State<_RewardForm> createState() => _RewardFormState();
}

class _RewardFormState extends State<_RewardForm> {
  late final _name = TextEditingController(text: widget.old?.name ?? '');
  late final _cost = TextEditingController(text: '${widget.old?.cost ?? 500}');
  late final _perWeek = TextEditingController(text: '${widget.old?.perWeek ?? 1}');
  late final Set<String> _kids = {...(widget.old?.kidUids ?? widget.kids.map((k) => k.kidUid))};
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    _cost.dispose();
    _perWeek.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _busy = true);
    final s = context.read<Session>();
    try {
      await s.repo.saveReward(
        id: widget.old?.id,
        parentUid: s.profile!.uid,
        name: _name.text,
        cost: int.tryParse(_cost.text.replaceAll('.', '').trim()) ?? 0,
        perWeek: int.tryParse(_perWeek.text.trim()) ?? 0,
        kidUids: _kids.toList(),
      );
      if (mounted) Navigator.pop(context, true);
    } on AppError catch (e) {
      if (mounted) showSnack(context, e.message, error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(widget.old == null ? 'Thêm phần thưởng' : 'Sửa phần thưởng', style: display(21)),
          const SizedBox(height: 12),
          TextField(controller: _name, decoration: const InputDecoration(labelText: 'Tên phần thưởng, ví dụ: Đi xem phim')),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(
              child: TextField(controller: _cost, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Giá xu')),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(controller: _perWeek, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Số lần/tuần')),
            ),
          ]),
          const SizedBox(height: 10),
          const Text('Áp dụng cho', style: TextStyle(fontWeight: FontWeight.w600)),
          for (final k in widget.kids)
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: _kids.contains(k.kidUid),
              title: Text('${k.kidName} (lớp ${k.kidGrade})'),
              onChanged: (v) => setState(() => v == true ? _kids.add(k.kidUid) : _kids.remove(k.kidUid)),
            ),
          const SizedBox(height: 8),
          BigButton('Lưu phần thưởng', onPressed: _save, loading: _busy),
        ]),
      ),
    );
  }
}

// =========================== Cài đặt ===========================

class ParentSettingsTab extends StatefulWidget {
  const ParentSettingsTab({super.key});

  @override
  State<ParentSettingsTab> createState() => _ParentSettingsTabState();
}

class _ParentSettingsTabState extends State<ParentSettingsTab> {
  late final Stream<List<LinkRequest>> _links;

  @override
  void initState() {
    super.initState();
    final s = context.read<Session>();
    _links = s.repo.watchParentLinks(s.profile!.uid);
  }

  Future<void> _respond(LinkRequest r, bool accept) async {
    try {
      await context.read<Session>().repo.respondLink(r, accept);
      if (mounted) showSnack(context, accept ? 'Đã liên kết với ${r.kidName}.' : 'Đã từ chối.');
    } catch (e) {
      if (mounted) showSnack(context, 'Lỗi: $e', error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final me = context.read<Session>().profile!;
    return AppPage(children: [
      Text('Cài đặt', style: display(24)),
      AppCard(
        child: Column(children: [
          Text(me.displayName, style: display(19)),
          const SizedBox(height: 6),
          const Text('Mã phụ huynh', style: TextStyle(color: AppColors.muted)),
          Text(me.parentCode ?? '—', style: display(34)),
          const Text('Con nhập mã này ở mục "Tôi" để gửi yêu cầu liên kết.',
              textAlign: TextAlign.center, style: TextStyle(fontSize: 12.5, color: AppColors.muted)),
        ]),
      ),
      const SectionLabel('Các con'),
      StreamBuilder<List<LinkRequest>>(
        stream: _links,
        builder: (context, snap) {
          final list = snap.data ?? const <LinkRequest>[];
          if (list.isEmpty) return const Text('Chưa có yêu cầu liên kết nào.', style: TextStyle(color: AppColors.muted));
          return Column(children: [
            for (final r in list)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: AppCard(
                  padding: const EdgeInsets.all(10),
                  child: Row(children: [
                    Avatar(r.kidName.isEmpty ? '?' : r.kidName.characters.first.toUpperCase(), color: avatarColor(r.kidUid)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(r.kidName, style: const TextStyle(fontWeight: FontWeight.w700)),
                        Text('Lớp ${r.kidGrade}', style: const TextStyle(fontSize: 12, color: AppColors.muted)),
                      ]),
                    ),
                    if (r.status == 'pending') ...[
                      TextButton(onPressed: () => _respond(r, false), child: const Text('Từ chối')),
                      FilledButton(onPressed: () => _respond(r, true), child: const Text('Xác nhận')),
                    ] else
                      Text(r.status == 'accepted' ? 'Đã liên kết' : 'Đã từ chối',
                          style: const TextStyle(fontSize: 12, color: AppColors.muted)),
                  ]),
                ),
              ),
          ]);
        },
      ),
      const AppCard(
        child: Text(
          'Thông báo về lỗi sai, đổi thưởng và tình trạng làm bài của con hiện trong mục Thông báo. '
          'Trên Android, thông báo mới hiện lên điện thoại khi app Học Vui đang mở.',
          style: TextStyle(fontSize: 13, color: AppColors.muted),
        ),
      ),
      const PasswordAndLogout(),
    ]);
  }
}
