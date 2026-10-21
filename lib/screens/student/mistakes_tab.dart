import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../logic/dates.dart';
import '../../logic/rules.dart';
import '../../logic/subjects.dart';
import '../../models/models.dart';
import '../../services/sound.dart';
import '../../state/session.dart';
import '../../theme.dart';
import '../../widgets/common.dart';

class MistakesTab extends StatefulWidget {
  const MistakesTab({super.key});

  @override
  State<MistakesTab> createState() => _MistakesTabState();
}

class _MistakesTabState extends State<MistakesTab> {
  bool _dueOnly = true;
  late final Stream<List<Mistake>> _stream;

  @override
  void initState() {
    super.initState();
    final session = context.read<Session>();
    _stream = session.repo.watchMistakes(session.profile!.uid);
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Mistake>>(
      stream: _stream,
      builder: (context, snap) {
        if (snap.hasError) return ErrorView('Không tải được sổ lỗi sai: ${snap.error}');
        if (!snap.hasData) return const Loading();
        final today = dayKey(DateTime.now());
        final all = snap.data!;
        final due = all.where((m) => m.nextDue.compareTo(today) <= 0).toList();
        final shown = _dueOnly ? due : all;
        return AppPage(children: [
          Row(children: [
            Expanded(child: Text('Sổ tay lỗi sai', style: display(24))),
            Pill('${all.length} câu', bg: AppColors.badSoft, fg: AppColors.badInk),
          ]),
          const Text(
            'Câu sai được hỏi lại sau 1, 3 và 7 ngày. Trả lời đúng đủ 3 lần là thuộc. '
            'Mỗi câu sửa đúng được +$coinsMistakeFixed xu.',
            style: TextStyle(fontSize: 12.5, color: AppColors.muted),
          ),
          SegmentedButton<bool>(
            segments: [
              ButtonSegment(value: true, label: Text('Đến hạn ôn (${due.length})')),
              ButtonSegment(value: false, label: Text('Tất cả (${all.length})')),
            ],
            selected: {_dueOnly},
            onSelectionChanged: (s) => setState(() => _dueOnly = s.first),
          ),
          if (due.isNotEmpty)
            BigButton('Ôn ${due.length} câu đến hạn', onPressed: () {
              Navigator.of(context).push(MaterialPageRoute(builder: (_) => MistakeReviewScreen(items: due)));
            }),
          for (final m in shown) _card(m, today),
          if (shown.isEmpty)
            EmptyView(_dueOnly ? 'Hôm nay không có câu nào cần ôn lại.' : 'Chưa có lỗi sai nào. Giỏi lắm!'),
        ]);
      },
    );
  }

  Widget _card(Mistake m, String today) {
    final q = m.question;
    final overdue = m.nextDue.compareTo(today) <= 0;
    return AppCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          SubjectBadge(m.subject, size: 30),
          const SizedBox(width: 8),
          Expanded(
            child: Text('${q.lessonTitle.isEmpty ? m.subject.label : q.lessonTitle} · ${levelName(q.level)}',
                style: const TextStyle(fontSize: 12, color: AppColors.muted)),
          ),
        ]),
        const SizedBox(height: 6),
        Text(q.text, style: const TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        Wrap(spacing: 6, runSpacing: 4, children: [
          if (m.chosen >= 0 && m.chosen < q.options.length)
            Pill('Đã chọn: ${q.options[m.chosen]}', bg: AppColors.badSoft, fg: AppColors.badInk, size: 12),
          if (q.answer < q.options.length)
            Pill('Đúng: ${q.options[q.answer]}', bg: AppColors.leafSoft, fg: AppColors.leafInk, size: 12),
        ]),
        if (q.explanation.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(q.explanation, style: const TextStyle(fontSize: 12.5, color: AppColors.muted)),
        ],
        const SizedBox(height: 8),
        Row(children: [
          const Text('Ôn lại: ', style: TextStyle(fontSize: 11.5, color: AppColors.muted)),
          for (var i = 0; i < mistakeIntervals.length; i++) ...[
            Icon(i < m.stage ? Icons.circle : Icons.circle_outlined,
                size: 14, color: i < m.stage ? AppColors.leaf : AppColors.line),
            Text(' ${mistakeIntervals[i]} ngày  ', style: const TextStyle(fontSize: 11.5, color: AppColors.muted)),
          ],
          const Spacer(),
          Text(overdue ? 'Đến hạn' : 'Ôn ngày ${_short(m.nextDue)}',
              style: TextStyle(fontSize: 11.5, color: overdue ? AppColors.flame : AppColors.muted, fontWeight: FontWeight.w700)),
        ]),
      ]),
    );
  }

  String _short(String key) {
    final d = parseDay(key);
    return '${d.day}/${d.month}';
  }
}

/// Ôn lần lượt các câu đến hạn: chọn đáp án, xem ngay đúng sai và lời giải.
class MistakeReviewScreen extends StatefulWidget {
  const MistakeReviewScreen({super.key, required this.items});
  final List<Mistake> items;

  @override
  State<MistakeReviewScreen> createState() => _MistakeReviewScreenState();
}

class _MistakeReviewScreenState extends State<MistakeReviewScreen> {
  int _index = 0;
  int? _chosen;
  int _right = 0;
  bool _saving = false;

  Future<void> _choose(int i) async {
    if (_chosen != null || _saving) return;
    final m = widget.items[_index];
    final correct = i == m.question.answer;
    Sound.instance.play(correct ? Sfx.correct : Sfx.wrong);
    setState(() {
      _chosen = i;
      _saving = true;
      if (correct) _right++;
    });
    final session = context.read<Session>();
    try {
      await session.repo.answerMistake(session.profile!.uid, m, correct);
    } catch (e) {
      if (mounted) showSnack(context, 'Chưa lưu được kết quả: $e', error: true);
    }
    if (mounted) setState(() => _saving = false);
  }

  void _next() => setState(() {
        _index++;
        _chosen = null;
      });

  @override
  Widget build(BuildContext context) {
    final total = widget.items.length;
    if (_index >= total) {
      return Scaffold(
        appBar: AppBar(),
        body: AppPage(children: [
          const Center(child: Mascot(size: 100)),
          Text('Xong rồi!', textAlign: TextAlign.center, style: display(28)),
          Text('Đúng $_right/$total câu, được +${_right * coinsMistakeFixed} xu.',
              textAlign: TextAlign.center, style: const TextStyle(color: AppColors.muted)),
          BigButton('Quay lại', onPressed: () => Navigator.of(context).pop()),
        ]),
      );
    }
    final m = widget.items[_index];
    final q = m.question;
    return Scaffold(
      appBar: AppBar(title: Text('Ôn lỗi sai ${_index + 1}/$total', style: display(19))),
      body: AppPage(children: [
        Bar((_index) / total, color: AppColors.flame),
        Row(children: [
          SubjectBadge(m.subject, size: 30),
          const SizedBox(width: 8),
          Expanded(child: Text(q.lessonTitle, style: const TextStyle(fontSize: 12, color: AppColors.muted))),
          LevelChip(q.level),
        ]),
        if (q.passage.isNotEmpty)
          AppCard(color: AppColors.page, child: Text(q.passage, style: const TextStyle(fontStyle: FontStyle.italic))),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: AppColors.seaSoft, borderRadius: BorderRadius.circular(18)),
          child: Text(q.text, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600, height: 1.45)),
        ),
        for (var i = 0; i < q.options.length; i++) _option(q, i),
        if (_chosen != null) ...[
          AppCard(
            color: _chosen == q.answer ? AppColors.leafSoft : AppColors.badSoft,
            border: _chosen == q.answer ? const Color(0xFFBFE8CF) : AppColors.badSoft,
            child: Text(
              (_chosen == q.answer ? 'Chính xác! +$coinsMistakeFixed xu. ' : 'Chưa đúng, câu này sẽ được hỏi lại ngày mai. ') +
                  q.explanation,
              style: TextStyle(color: _chosen == q.answer ? AppColors.leafInk : AppColors.badInk),
            ),
          ),
          BigButton(_index < total - 1 ? 'Câu tiếp' : 'Xem kết quả', onPressed: _saving ? null : _next),
        ],
      ]),
    );
  }

  Widget _option(Question q, int i) {
    Color bg = AppColors.paper, border = AppColors.line, fg = AppColors.ink;
    if (_chosen != null) {
      if (i == q.answer) {
        bg = AppColors.leafSoft;
        border = AppColors.leaf;
        fg = AppColors.leafInk;
      } else if (i == _chosen) {
        bg = AppColors.badSoft;
        border = AppColors.bad;
        fg = AppColors.badInk;
      }
    }
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () => _choose(i),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: border, width: 2),
        ),
        child: Text('${String.fromCharCode(65 + i)}. ${q.options[i]}',
            style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w600, color: fg)),
      ),
    );
  }
}
