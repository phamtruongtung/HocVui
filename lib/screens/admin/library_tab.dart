import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../logic/subjects.dart';
import '../../services/library.dart';
import '../../state/session.dart';
import '../../theme.dart';
import '../../widgets/common.dart';

/// Nạp thư viện đề soạn sẵn (đóng gói trong app) lên Firebase.
class LibraryTab extends StatefulWidget {
  const LibraryTab({super.key});

  @override
  State<LibraryTab> createState() => _LibraryTabState();
}

class _LibraryTabState extends State<LibraryTab> {
  final _library = Library();
  late Future<List<LibrarySet>> _sets;
  bool _approve = true;
  final _busy = <String>{};
  final _done = <String, int>{};

  /// Số câu thư viện đang có trên Firebase của từng bộ (null: chưa đếm xong).
  final _onServer = <String, int?>{};

  @override
  void initState() {
    super.initState();
    _sets = _library.load();
    _sets.then(_countAll);
  }

  String _key(LibrarySet s) => '${s.grade}_${s.subject.id}';

  Future<void> _countAll(List<LibrarySet> sets) async {
    if (!mounted) return;
    final repo = context.read<Session>().repo;
    for (final s in sets) {
      try {
        final n = await _library.countOnServer(repo, s.grade, s.subject);
        if (mounted) setState(() => _onServer[_key(s)] = n);
      } catch (_) {
        // Không đếm được thì thôi, không ảnh hưởng việc nạp/xóa.
      }
    }
  }

  Future<void> _recount(LibrarySet s) async {
    if (!mounted) return;
    try {
      final n = await _library.countOnServer(context.read<Session>().repo, s.grade, s.subject);
      if (mounted) setState(() => _onServer[_key(s)] = n);
    } catch (_) {}
  }

  Future<void> _import(List<LibrarySet> sets) async {
    final repo = context.read<Session>().repo;
    for (final s in sets) {
      if (!mounted) return;
      setState(() => _busy.add(_key(s)));
      try {
        final n = await _library.importSet(repo, s, approve: _approve);
        if (mounted) setState(() => _done[_key(s)] = n);
        await _recount(s);
      } catch (e) {
        if (mounted) showSnack(context, 'Lỗi khi nạp lớp ${s.grade} ${s.subject.label}: $e', error: true);
      }
      if (mounted) setState(() => _busy.remove(_key(s)));
    }
    if (mounted) showSnack(context, 'Đã nạp xong.');
  }

  Future<void> _delete(List<LibrarySet> sets, String what) async {
    final ok = await confirm(
      context,
      'Xóa $what?',
      'Mọi câu hỏi thư viện của $what sẽ bị xóa khỏi Firebase, kể cả câu đã duyệt. '
          'Câu sinh bằng AI, mục lục, đề con đã làm và sổ lỗi sai vẫn giữ nguyên. '
          'Muốn dùng lại thì bấm "Nạp" lần nữa.',
      ok: 'Xóa',
    );
    if (!ok || !mounted) return;
    final repo = context.read<Session>().repo;
    var total = 0;
    for (final s in sets) {
      if (!mounted) return;
      setState(() => _busy.add(_key(s)));
      try {
        total += await _library.deleteSet(repo, s.grade, s.subject);
        if (mounted) {
          setState(() {
            _done.remove(_key(s));
            _onServer[_key(s)] = 0;
          });
        }
      } catch (e) {
        if (mounted) showSnack(context, 'Lỗi khi xóa lớp ${s.grade} ${s.subject.label}: $e', error: true);
      }
      if (mounted) setState(() => _busy.remove(_key(s)));
    }
    if (mounted) showSnack(context, 'Đã xóa $total câu.');
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<LibrarySet>>(
      future: _sets,
      builder: (context, snap) {
        if (snap.hasError) return ErrorView('Không đọc được thư viện: ${snap.error}');
        if (!snap.hasData) return const Loading();
        final sets = snap.data!;
        final total = sets.fold(0, (a, s) => a + s.questions.length);
        final errors = sets.expand((s) => s.errors).toList();
        return AppPage(maxWidth: 1000, children: [
          Text('Thư viện đề', style: display(26)),
          Text(
            'Bộ câu hỏi soạn sẵn theo SGK Kết nối tri thức, đóng gói trong app: $total câu, ${sets.length} bộ. '
            'Bấm "Nạp" để đưa mục lục và câu hỏi lên Firebase. Nạp lại nhiều lần không bị trùng câu; '
            'câu đã duyệt hoặc đã loại giữ nguyên trạng thái, nội dung được cập nhật theo bản mới.',
            style: const TextStyle(fontSize: 12.5, color: AppColors.muted),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _approve,
            onChanged: (v) => setState(() => _approve = v),
            title: const Text('Duyệt luôn khi nạp'),
            subtitle: const Text('Tắt nếu muốn đọc từng câu ở tab Câu hỏi trước khi cho vào đề.'),
          ),
          if (errors.isNotEmpty)
            AppCard(
              color: AppColors.badSoft,
              border: AppColors.badSoft,
              child: Text('Có ${errors.length} lỗi định dạng (các câu lỗi bị bỏ qua):\n${errors.take(10).join('\n')}',
                  style: const TextStyle(color: AppColors.badInk, fontSize: 12)),
            ),
          for (final g in grades) ...[
            SectionLabel('Lớp $g',
                trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                  TextButton(
                    onPressed: _busy.isNotEmpty ? null : () => _import(sets.where((s) => s.grade == g).toList()),
                    child: Text('Nạp cả lớp $g'),
                  ),
                  TextButton(
                    style: TextButton.styleFrom(foregroundColor: AppColors.bad),
                    onPressed: _busy.isNotEmpty
                        ? null
                        : () => _delete(sets.where((s) => s.grade == g).toList(), 'thư viện lớp $g'),
                    child: const Text('Xóa'),
                  ),
                ])),
            for (final s in sets.where((s) => s.grade == g)) _row(s),
            if (!sets.any((s) => s.grade == g))
              const Text('Chưa có bộ đề nào.', style: TextStyle(color: AppColors.muted)),
          ],
          BigButton('Nạp tất cả (${sets.length} bộ)',
              onPressed: _busy.isNotEmpty || sets.isEmpty ? null : () => _import(sets), loading: _busy.isNotEmpty),
          const SizedBox(height: 4),
          BigButton('Xóa toàn bộ thư viện trên Firebase',
              ghost: true,
              onPressed: _busy.isNotEmpty || sets.isEmpty ? null : () => _delete(sets, 'toàn bộ thư viện (mọi lớp, mọi môn)')),
        ]);
      },
    );
  }

  Widget _row(LibrarySet s) {
    final key = _key(s);
    final busy = _busy.contains(key);
    final done = _done[key];
    final onServer = _onServer[key];
    final lessons = s.curriculum.lessons.length;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: AppCard(
        padding: const EdgeInsets.all(10),
        child: Row(children: [
          SubjectBadge(s.subject, size: 34),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${s.subject.label} ${s.grade}', style: const TextStyle(fontWeight: FontWeight.w700)),
              Text('$lessons bài · ${s.questions.length} câu${done != null ? ' · đã nạp $done câu' : ''}',
                  style: const TextStyle(fontSize: 12, color: AppColors.muted)),
              if (onServer != null)
                Text(onServer == 0 ? 'Chưa có trên Firebase' : 'Trên Firebase: $onServer câu',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: onServer == 0 ? AppColors.muted : AppColors.leaf)),
            ]),
          ),
          if (busy)
            const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 3))
          else ...[
            TextButton(onPressed: _busy.isNotEmpty ? null : () => _import([s]), child: const Text('Nạp')),
            IconButton(
              tooltip: 'Xóa bộ này khỏi Firebase',
              icon: const Icon(Icons.delete_outline_rounded),
              color: AppColors.bad,
              onPressed: _busy.isNotEmpty || onServer == 0
                  ? null
                  : () => _delete([s], 'bộ ${s.subject.label} ${s.grade}'),
            ),
          ],
        ]),
      ),
    );
  }
}
