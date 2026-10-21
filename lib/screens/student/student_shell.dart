import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../logic/dates.dart';
import '../../logic/subjects.dart';
import '../../models/models.dart';
import '../../services/repo.dart';
import '../../services/sound.dart';
import '../../state/session.dart';
import '../../theme.dart';
import '../../widgets/common.dart';
import 'exam_screens.dart';
import 'leaderboard_tab.dart';
import 'mistakes_tab.dart';
import 'profile_tab.dart';
import 'shop_tab.dart';

class StudentShell extends StatefulWidget {
  const StudentShell({super.key});

  @override
  State<StudentShell> createState() => _StudentShellState();
}

class _StudentShellState extends State<StudentShell> with WidgetsBindingObserver {
  int _tab = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    Sound.instance.startMusic();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    Sound.instance.stopMusic();
    super.dispose();
  }

  // Tắt nhạc khi app chạy nền (bấm Home, khóa màn hình), phát lại khi mở lên.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      Sound.instance.resumeMusic();
    } else if (state == AppLifecycleState.paused || state == AppLifecycleState.hidden) {
      Sound.instance.pauseMusic();
    }
  }

  @override
  Widget build(BuildContext context) {
    final tabs = const [HomeTab(), MistakesTab(), LeaderboardTab(), ShopTab(), ProfileTab()];
    return Listener(
      onPointerDown: (_) => Sound.instance.userGesture(),
      child: Scaffold(
      body: SafeArea(child: IndexedStack(index: _tab, children: tabs)),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) {
          Sound.instance.play(Sfx.tap);
          setState(() => _tab = i);
        },
        destinations: const [
          NavigationDestination(icon: Icon(Icons.school_rounded), label: 'Học'),
          NavigationDestination(icon: Icon(Icons.menu_book_rounded), label: 'Lỗi sai'),
          NavigationDestination(icon: Icon(Icons.emoji_events_rounded), label: 'Xếp hạng'),
          NavigationDestination(icon: Icon(Icons.storefront_rounded), label: 'Cửa hàng'),
          NavigationDestination(icon: Icon(Icons.person_rounded), label: 'Tôi'),
        ],
      ),
      ),
    );
  }
}

class HomeTab extends StatefulWidget {
  const HomeTab({super.key});

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> {
  late Future<HomeData> _future;
  final _dismissed = <String>{};

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<HomeData> _load() async {
    final session = context.read<Session>();
    final data = await session.repo.loadStudentHome(session.profile!.uid);
    session.setProfile(data.profile);
    await session.notifier.scheduleReminders(
      leftToday: data.plan.required - data.plan.done,
      streak: data.profile.streak,
    );
    return data;
  }

  Future<void> _reload() async {
    final f = _load();
    setState(() => _future = f);
    await f;
  }

  Future<void> _openExam(Exam e) async {
    final repo = context.read<Session>().repo;
    final uid = context.read<Session>().profile!.uid;
    final fresh = await repo.exam(uid, e.id);
    if (!mounted) return;
    final Widget page;
    if (fresh.submitted) {
      page = ExamReviewScreen(exam: fresh);
    } else if (fresh.started) {
      page = ExamScreen(exam: fresh);
    } else {
      page = ExamIntroScreen(exam: fresh);
    }
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
    if (mounted) _reload();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<HomeData>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) return const Loading(text: 'Đang chuẩn bị đề hôm nay...');
        if (snap.hasError) {
          final err = snap.error;
          return ErrorView(err is AppError ? err.message : 'Không tải được dữ liệu: $err', onRetry: _reload);
        }
        final d = snap.data!;
        return RefreshIndicator(onRefresh: _reload, child: _content(d));
      },
    );
  }

  Widget _content(HomeData d) {
    final p = d.profile;
    final plan = d.plan;
    final now = DateTime.now();
    final firstName = p.displayName.trim().split(RegExp(r'\s+')).last;
    final notes = d.notes.where((n) => !_dismissed.contains(n)).toList();
    return AppPage(children: [
      Row(children: [
        Pill('${p.streak}', bg: AppColors.flameSoft, fg: AppColors.flame, leading: const FlameDot(size: 14)),
        const Spacer(),
        Pill('Chuyên cần ${p.attendance}', bg: AppColors.leafSoft, fg: AppColors.leafInk),
        const Spacer(),
        CoinPill(p.coins),
      ]),
      for (final n in notes)
        AppCard(
          color: AppColors.sunSoft,
          border: const Color(0xFFF5DFA0),
          padding: const EdgeInsets.fromLTRB(12, 6, 4, 6),
          child: Row(children: [
            Expanded(child: Text(n, style: const TextStyle(fontSize: 13))),
            IconButton(
              icon: const Icon(Icons.close_rounded, size: 18),
              onPressed: () => setState(() => _dismissed.add(n)),
            ),
          ]),
        ),
      Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: AppColors.leaf, borderRadius: BorderRadius.circular(20)),
        child: Row(children: [
          const Mascot(size: 52, cap: false),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Chào $firstName!', style: display(21, color: Colors.white)),
              Text(
                '${prettyDay(now)} · Lớp ${p.grade} · '
                '${plan.required == 0 ? 'Hôm nay được nghỉ' : plan.complete ? 'Đã xong bài hôm nay, giỏi lắm!' : 'Làm xong ${plan.required} đề trước 23:59 để giữ chuỗi'}',
                style: const TextStyle(color: Colors.white, fontSize: 12.5),
              ),
            ]),
          ),
        ]),
      ),
      SectionLabel('${plan.required} đề hôm nay',
          trailing: Text('${plan.done}/${plan.required} xong',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.leaf))),
      Bar(plan.required == 0 ? 1 : plan.done / plan.required),
      if (plan.note.isNotEmpty)
        Text(plan.note, style: const TextStyle(fontSize: 12.5, color: AppColors.muted)),
      for (final e in d.exams) _examTile(e),
      if (d.exams.isEmpty)
        const EmptyView('Chưa có đề nào cho hôm nay. Quản trị viên cần duyệt thêm câu hỏi cho lớp của bạn.'),
      _weekPlan(now),
    ]);
  }

  Widget _examTile(Exam e) {
    final done = e.submitted;
    String status;
    if (done) {
      status = '${e.questions.length} câu · ${fmtScore(e.score)} điểm · +${e.coins} xu';
    } else if (e.started) {
      final left = e.deadline!.difference(DateTime.now());
      status = left.isNegative ? 'Hết giờ, chạm để nộp bài' : 'Đang làm · còn ${clock(left)}';
    } else {
      status = '${e.questions.length} câu · $examMinutes phút${e.subject.needsScratchPaper ? ' · cần giấy nháp' : ''}';
    }
    return AppCard(
      onTap: () => _openExam(e),
      color: done ? AppColors.leafSoft : AppColors.paper,
      border: done ? const Color(0xFFBFE8CF) : AppColors.line,
      padding: const EdgeInsets.all(10),
      child: Row(children: [
        SubjectBadge(e.subject),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(e.title, maxLines: 2, overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5)),
            Text('${e.subject.label} ${e.grade} · $status',
                style: const TextStyle(fontSize: 12, color: AppColors.muted)),
          ]),
        ),
        const SizedBox(width: 6),
        done
            ? const CircleAvatar(radius: 14, backgroundColor: AppColors.leaf,
                child: Icon(Icons.check_rounded, color: Colors.white, size: 18))
            : const Icon(Icons.chevron_right_rounded, color: AppColors.muted),
      ]),
    );
  }

  Widget _weekPlan(DateTime now) {
    final monday = DateTime(now.year, now.month, now.day - (now.weekday - 1));
    return AppCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const SectionLabel('Lịch ôn tuần này (tự xoay vòng)'),
        const SizedBox(height: 6),
        Row(children: [
          for (var i = 0; i < 7; i++)
            Expanded(child: _dayCell(DateTime(monday.year, monday.month, monday.day + i), now)),
        ]),
        const SizedBox(height: 8),
        Wrap(spacing: 10, runSpacing: 4, children: [
          for (final s in Subject.values)
            Row(mainAxisSize: MainAxisSize.min, children: [
              Container(width: 10, height: 10, decoration: BoxDecoration(color: subjectColor(s), borderRadius: BorderRadius.circular(3))),
              const SizedBox(width: 4),
              Text(s.short, style: const TextStyle(fontSize: 11, color: AppColors.muted)),
            ]),
        ]),
      ]),
    );
  }

  Widget _dayCell(DateTime day, DateTime now) {
    final isToday = dayKey(day) == dayKey(now);
    final subjects = subjectsForDay(dayKey(day));
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 2),
      padding: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: isToday ? AppColors.sunSoft : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(children: [
        Text(weekdayShort(day),
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: isToday ? AppColors.ink : AppColors.muted)),
        const SizedBox(height: 4),
        for (final s in subjects)
          Container(
            width: 24,
            height: 6,
            margin: const EdgeInsets.only(top: 3),
            decoration: BoxDecoration(color: subjectColor(s), borderRadius: BorderRadius.circular(3)),
          ),
      ]),
    );
  }
}
