import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../logic/dates.dart';
import '../../logic/rules.dart';
import '../../logic/subjects.dart';
import '../../models/models.dart';
import '../../services/repo.dart';
import '../../state/session.dart';
import '../../theme.dart';
import '../../widgets/common.dart';

List<int> _countByLevel(Exam e) {
  final out = [0, 0, 0, 0];
  for (final q in e.questions) {
    out[q.level - 1]++;
  }
  return out;
}

// =========================== Trước khi làm đề ===========================

class ExamIntroScreen extends StatefulWidget {
  const ExamIntroScreen({super.key, required this.exam});
  final Exam exam;

  @override
  State<ExamIntroScreen> createState() => _ExamIntroScreenState();
}

class _ExamIntroScreenState extends State<ExamIntroScreen> {
  bool _busy = false;

  Future<void> _start() async {
    setState(() => _busy = true);
    final session = context.read<Session>();
    try {
      final started = await session.repo.startExam(session.profile!.uid, widget.exam);
      if (!mounted) return;
      Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => ExamScreen(exam: started)));
    } catch (e) {
      if (mounted) showSnack(context, 'Không bắt đầu được: $e', error: true);
      setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final e = widget.exam;
    final counts = _countByLevel(e);
    final total = e.questions.length;
    final maxCoins = examCoins(counts, 10);
    return Scaffold(
      appBar: AppBar(),
      body: AppPage(children: [
        Center(
          child: Container(
            width: 88,
            height: 88,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: subjectColor(e.subject),
              borderRadius: BorderRadius.circular(26),
              boxShadow: [BoxShadow(color: subjectColor(e.subject).withValues(alpha: 0.6), offset: const Offset(0, 6))],
            ),
            child: Text(e.subject.short, style: display(22, color: Colors.white)),
          ),
        ),
        Text('${e.subject.label} ${e.grade}', textAlign: TextAlign.center, style: display(24)),
        Text(e.title, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.muted)),
        Row(children: [
          _fact('$total', 'câu hỏi'),
          const SizedBox(width: 8),
          _fact("$examMinutes'", 'thời gian'),
          const SizedBox(width: 8),
          _fact('~$maxCoins', 'xu tối đa'),
        ]),
        const SectionLabel('Độ khó tăng dần'),
        ClipRRect(
          borderRadius: BorderRadius.circular(7),
          child: Row(children: [
            for (var i = 0; i < 4; i++)
              if (counts[i] > 0) Expanded(flex: counts[i], child: Container(height: 14, color: levelColors[i])),
          ]),
        ),
        Wrap(spacing: 12, runSpacing: 4, children: [
          for (var i = 0; i < 4; i++)
            if (counts[i] > 0)
              Row(mainAxisSize: MainAxisSize.min, children: [
                Container(width: 10, height: 10, decoration: BoxDecoration(color: levelColors[i], borderRadius: BorderRadius.circular(3))),
                const SizedBox(width: 4),
                Text('${counts[i]} ${levelNames[i]}', style: const TextStyle(fontSize: 12, color: AppColors.muted)),
              ]),
        ]),
        AppCard(
          color: AppColors.sunSoft,
          border: const Color(0xFFF5DFA0),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Icon(Icons.edit_note_rounded, color: AppColors.flame, size: 30),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                e.subject.needsScratchPaper
                    ? 'Chuẩn bị giấy nháp và bút. Nhiều câu cần tính ra giấy trước khi chọn. '
                        'Đồng hồ không dừng được, hết $examMinutes phút bài tự nộp.'
                    : 'Đọc kỹ từng câu trước khi chọn. Đồng hồ không dừng được, hết $examMinutes phút bài tự nộp.',
                style: const TextStyle(fontSize: 13),
              ),
            ),
          ]),
        ),
        BigButton('Bắt đầu làm bài', onPressed: _start, loading: _busy),
      ]),
    );
  }

  Widget _fact(String value, String label) => Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(color: AppColors.paper, borderRadius: BorderRadius.circular(14)),
          child: Column(children: [
            Text(value, style: display(22)),
            Text(label, style: const TextStyle(fontSize: 11, color: AppColors.muted)),
          ]),
        ),
      );
}

// =========================== Làm bài ===========================

class ExamScreen extends StatefulWidget {
  const ExamScreen({super.key, required this.exam});
  final Exam exam;

  @override
  State<ExamScreen> createState() => _ExamScreenState();
}

class _ExamScreenState extends State<ExamScreen> {
  late List<int> _answers;
  int _index = 0;
  Timer? _timer;
  Duration _left = Duration.zero;
  bool _submitting = false;

  Exam get _exam => widget.exam;

  @override
  void initState() {
    super.initState();
    _answers = [..._exam.answers];
    final firstEmpty = _answers.indexOf(-1);
    _index = firstEmpty < 0 ? 0 : firstEmpty;
    _left = _remaining();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
    WidgetsBinding.instance.addPostFrameCallback((_) => _tick());
  }

  Duration _remaining() {
    final deadline = _exam.deadline ?? DateTime.now().add(const Duration(minutes: examMinutes));
    return deadline.difference(DateTime.now());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _tick() {
    final left = _remaining();
    if (!mounted) return;
    setState(() => _left = left);
    if (left.inSeconds <= 0 && !_submitting) {
      _timer?.cancel();
      _submit(auto: true);
    }
  }

  Future<void> _choose(int option) async {
    setState(() => _answers[_index] = option);
    final session = context.read<Session>();
    try {
      await session.repo.saveAnswers(session.profile!.uid, _exam.id, _answers);
    } catch (_) {
      // Mất mạng: Firestore tự gửi lại khi có mạng.
    }
  }

  Future<void> _submit({bool auto = false}) async {
    if (_submitting) return;
    if (!auto) {
      final empty = _answers.where((a) => a < 0).length;
      final ok = await confirm(
        context,
        'Nộp bài?',
        empty > 0 ? 'Còn $empty câu chưa chọn đáp án, các câu này sẽ tính là sai.' : 'Bạn đã chọn đủ đáp án cho mọi câu.',
        ok: 'Nộp bài',
        cancel: 'Làm tiếp',
      );
      if (!ok) return;
    }
    setState(() => _submitting = true);
    final session = context.read<Session>();
    try {
      final outcome = await session.repo.submitExam(session.profile!.uid, _exam, _answers);
      await session.refresh();
      if (!mounted) return;
      Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => ResultScreen(outcome: outcome, auto: auto)));
    } on AppError catch (e) {
      if (!mounted) return;
      showSnack(context, e.message, error: true);
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      showSnack(context, 'Chưa nộp được bài, hãy kiểm tra mạng rồi bấm Nộp bài lại. ($e)', error: true);
    }
  }

  Future<bool> _confirmLeave() => confirm(
        context,
        'Tạm rời bài làm?',
        'Đồng hồ vẫn tiếp tục chạy. Hết ${clock(_left)} bài sẽ tự nộp.',
        ok: 'Rời đi',
        cancel: 'Ở lại',
      );

  @override
  Widget build(BuildContext context) {
    final q = _exam.questions[_index];
    final total = _exam.questions.length;
    final urgent = _left.inMinutes < 5;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (await _confirmLeave() && context.mounted) Navigator.of(context).pop();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text('${_exam.subject.label} ${_exam.grade}', style: display(19)),
          actions: [
            Container(
              margin: const EdgeInsets.only(right: 12),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: urgent ? AppColors.bad : AppColors.ink, borderRadius: BorderRadius.circular(10)),
              child: Row(children: [
                const Icon(Icons.timer_rounded, color: AppColors.sun, size: 16),
                const SizedBox(width: 4),
                Text(clock(_left), style: display(17, color: Colors.white)),
              ]),
            ),
          ],
        ),
        body: _submitting
            ? const Loading(text: 'Đang chấm bài...')
            : AppPage(children: [
                _progress(),
                Row(children: [
                  LevelChip(q.level),
                  const Spacer(),
                  Text('Câu ${_index + 1}/$total', style: const TextStyle(fontSize: 12.5, color: AppColors.muted)),
                ]),
                if (q.passage.isNotEmpty)
                  AppCard(
                    color: AppColors.page,
                    child: Text(q.passage, style: const TextStyle(fontSize: 14, fontStyle: FontStyle.italic, height: 1.5)),
                  ),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: AppColors.seaSoft, borderRadius: BorderRadius.circular(18)),
                  child: Text(q.text, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600, height: 1.45)),
                ),
                for (var i = 0; i < q.options.length; i++) _option(i, q.options[i]),
                Row(children: [
                  Expanded(
                    child: BigButton('Câu trước',
                        ghost: true, onPressed: _index > 0 ? () => setState(() => _index--) : null),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _index < total - 1
                        ? BigButton('Câu tiếp', onPressed: () => setState(() => _index++))
                        : BigButton('Nộp bài', color: AppColors.sea, shadow: AppColors.seaInk, onPressed: () => _submit()),
                  ),
                ]),
                if (_index < total - 1)
                  TextButton(onPressed: () => _submit(), child: const Text('Nộp bài sớm')),
              ]),
      ),
    );
  }

  Widget _progress() {
    return Wrap(spacing: 4, runSpacing: 4, children: [
      for (var i = 0; i < _exam.questions.length; i++)
        GestureDetector(
          onTap: () => setState(() => _index = i),
          child: Container(
            width: 26,
            height: 26,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: _answers[i] >= 0 ? levelColor(_exam.questions[i].level) : AppColors.paper,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: i == _index ? AppColors.ink : AppColors.line, width: 2),
            ),
            child: Text('${i + 1}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
          ),
        ),
    ]);
  }

  Widget _option(int i, String text) {
    final selected = _answers[_index] == i;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => _choose(i),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            color: selected ? AppColors.seaSoft : AppColors.paper,
            borderRadius: BorderRadius.circular(14),
            border: Border(
              top: BorderSide(color: selected ? AppColors.sea : AppColors.line, width: 2),
              left: BorderSide(color: selected ? AppColors.sea : AppColors.line, width: 2),
              right: BorderSide(color: selected ? AppColors.sea : AppColors.line, width: 2),
              bottom: BorderSide(color: selected ? AppColors.sea : AppColors.line, width: 4),
            ),
          ),
          child: Row(children: [
            Container(
              width: 28,
              height: 28,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: selected ? AppColors.sea : AppColors.page,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(String.fromCharCode(65 + i),
                  style: display(15, color: selected ? Colors.white : AppColors.ink)),
            ),
            const SizedBox(width: 10),
            Expanded(child: Text(text, style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w600))),
          ]),
        ),
      ),
    );
  }
}

// =========================== Kết quả ===========================

class ResultScreen extends StatelessWidget {
  const ResultScreen({super.key, required this.outcome, this.auto = false});
  final ExamOutcome outcome;
  final bool auto;

  @override
  Widget build(BuildContext context) {
    final o = outcome;
    final title = o.score >= 9
        ? 'Xuất sắc!'
        : o.score >= 7
            ? 'Giỏi quá!'
            : o.score >= 5
                ? 'Khá lắm!'
                : 'Cố lên nhé!';
    return Scaffold(
      appBar: AppBar(automaticallyImplyLeading: false, title: Text('Kết quả', style: display(20))),
      body: AppPage(children: [
        if (auto)
          const AppCard(
            color: AppColors.flameSoft,
            border: AppColors.flameSoft,
            child: Text('Hết giờ, bài đã được tự nộp.', style: TextStyle(color: AppColors.flameInk)),
          ),
        const Center(child: Icon(Icons.emoji_events_rounded, size: 80, color: AppColors.sun)),
        Text(title, textAlign: TextAlign.center, style: display(28)),
        Text(fmtScore(o.score), textAlign: TextAlign.center, style: display(56, color: AppColors.leaf)),
        Text(
          '${o.correct}/${o.total} câu đúng · ${o.seconds ~/ 60} phút ${o.seconds % 60} giây',
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppColors.muted),
        ),
        AppCard(
          child: Column(children: [
            _row('Hoàn thành đề', '+$coinsPerExam'),
            for (var i = 0; i < 4; i++)
              if (o.totalByLevel[i] > 0)
                _row('${o.correctByLevel[i]}/${o.totalByLevel[i]} ${levelNames[i]} × ${coinsPerLevel[i]} xu',
                    '+${o.correctByLevel[i] * coinsPerLevel[i]}'),
            if (o.score >= 9) _row('Đạt từ 9 điểm', '+$coinsHighScore'),
            const Divider(height: 18),
            Row(children: [
              const CoinDot(),
              const SizedBox(width: 6),
              const Expanded(child: Text('Tổng xu', style: TextStyle(fontWeight: FontWeight.w800))),
              Text('+${o.coins}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
            ]),
          ]),
        ),
        if (o.dayComplete)
          AppCard(
            color: AppColors.leafSoft,
            border: const Color(0xFFBFE8CF),
            child: Text(
              'Xong bài hôm nay! Chuỗi ${o.streak} ngày, +1 chuyên cần.'
              '${o.milestoneCoins > 0 ? ' Đạt mốc chuỗi, thưởng thêm ${o.milestoneCoins} xu!' : ''}'
              '${o.earlyBonus ? ' +${earlyBonusPoints.toInt()} điểm thi đua vì xong trước 21:00.' : ''}',
              style: const TextStyle(color: AppColors.leafInk, fontWeight: FontWeight.w600),
            ),
          ),
        if (o.correct < o.total)
          BigButton('Xem ${o.total - o.correct} câu sai', ghost: true, onPressed: () {
            Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => ExamReviewScreen(exam: o.exam, answersOverride: null, onlyWrong: true, outcome: o)));
          }),
        BigButton('Về trang chủ', onPressed: () => Navigator.of(context).pop()),
      ]),
    );
  }

  Widget _row(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(children: [
          Expanded(child: Text(label, style: const TextStyle(fontSize: 13.5))),
          Text(value, style: const TextStyle(fontSize: 13.5, fontFeatures: [FontFeature.tabularFigures()])),
        ]),
      );
}

// =========================== Xem lại bài ===========================

class ExamReviewScreen extends StatefulWidget {
  const ExamReviewScreen({super.key, required this.exam, this.answersOverride, this.onlyWrong = false, this.outcome});
  final Exam exam;
  final List<int>? answersOverride;
  final bool onlyWrong;
  final ExamOutcome? outcome;

  @override
  State<ExamReviewScreen> createState() => _ExamReviewScreenState();
}

class _ExamReviewScreenState extends State<ExamReviewScreen> {
  Exam? _exam;

  @override
  void initState() {
    super.initState();
    if (widget.outcome != null) _loadFresh();
  }

  /// Sau khi nộp, đọc lại đề để có đáp án đã lưu.
  Future<void> _loadFresh() async {
    final session = context.read<Session>();
    final e = await session.repo.exam(session.profile!.uid, widget.exam.id);
    if (mounted) setState(() => _exam = e);
  }

  @override
  Widget build(BuildContext context) {
    final e = _exam ?? widget.exam;
    final answers = widget.answersOverride ?? e.answers;
    final items = <int>[
      for (var i = 0; i < e.questions.length; i++)
        if (!widget.onlyWrong || i >= answers.length || answers[i] != e.questions[i].answer) i,
    ];
    return Scaffold(
      appBar: AppBar(title: Text(widget.onlyWrong ? 'Câu làm sai' : 'Xem lại bài', style: display(20))),
      body: AppPage(children: [
        if (e.submitted && !widget.onlyWrong)
          AppCard(
            child: Row(children: [
              SubjectBadge(e.subject),
              const SizedBox(width: 10),
              Expanded(
                child: Text('${e.title}\n${e.correct}/${e.questions.length} câu đúng',
                    style: const TextStyle(fontSize: 13.5)),
              ),
              Text(fmtScore(e.score), style: display(30, color: AppColors.leaf)),
            ]),
          ),
        for (final i in items) QuestionReview(number: i + 1, question: e.questions[i], chosen: i < answers.length ? answers[i] : -1),
        if (items.isEmpty) const EmptyView('Không có câu sai nào. Tuyệt vời!'),
      ]),
    );
  }
}

/// Một câu hỏi kèm đáp án đã chọn, đáp án đúng và lời giải.
class QuestionReview extends StatelessWidget {
  const QuestionReview({super.key, required this.number, required this.question, required this.chosen});
  final int number;
  final Question question;
  final int chosen;

  @override
  Widget build(BuildContext context) {
    final q = question;
    final right = chosen == q.answer;
    return AppCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text('Câu $number', style: display(15)),
          const SizedBox(width: 8),
          LevelChip(q.level),
          const Spacer(),
          Icon(right ? Icons.check_circle_rounded : Icons.cancel_rounded,
              color: right ? AppColors.leaf : AppColors.bad),
        ]),
        if (q.lessonTitle.isNotEmpty)
          Text(q.lessonTitle, style: const TextStyle(fontSize: 11.5, color: AppColors.muted)),
        if (q.passage.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(q.passage, style: const TextStyle(fontSize: 13, fontStyle: FontStyle.italic)),
        ],
        const SizedBox(height: 6),
        Text(q.text, style: const TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        for (var i = 0; i < q.options.length; i++)
          Container(
            margin: const EdgeInsets.only(top: 4),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: i == q.answer
                  ? AppColors.leafSoft
                  : i == chosen
                      ? AppColors.badSoft
                      : AppColors.page,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '${String.fromCharCode(65 + i)}. ${q.options[i]}'
              '${i == chosen ? '   (bạn chọn)' : ''}',
              style: TextStyle(
                color: i == q.answer ? AppColors.leafInk : i == chosen ? AppColors.badInk : AppColors.ink,
                fontWeight: i == q.answer || i == chosen ? FontWeight.w700 : FontWeight.w400,
              ),
            ),
          ),
        if (chosen < 0)
          const Padding(
            padding: EdgeInsets.only(top: 4),
            child: Text('Chưa chọn đáp án', style: TextStyle(color: AppColors.badInk, fontSize: 12.5)),
          ),
        if (q.explanation.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text('Lời giải: ${q.explanation}', style: const TextStyle(fontSize: 13, color: AppColors.muted)),
        ],
      ]),
    );
  }
}
