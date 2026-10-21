import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../logic/subjects.dart';
import '../../models/models.dart';
import '../../services/repo.dart';
import '../../state/session.dart';
import '../../theme.dart';
import '../../widgets/common.dart';
import '../student/exam_screens.dart';
import '../student/profile_tab.dart';
import 'library_tab.dart';

class AdminShell extends StatefulWidget {
  const AdminShell({super.key});

  @override
  State<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends State<AdminShell> {
  int _tab = 0;

  static const _items = [
    (Icons.people_alt_rounded, 'Tài khoản'),
    (Icons.list_alt_rounded, 'Mục lục'),
    (Icons.quiz_rounded, 'Câu hỏi'),
    (Icons.local_library_rounded, 'Thư viện'),
    (Icons.auto_awesome_rounded, 'Sinh bằng AI'),
    (Icons.settings_rounded, 'Cài đặt'),
  ];

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.of(context).size.width >= 900;
    final body = IndexedStack(index: _tab, children: const [
      AccountsTab(),
      CurriculumTab(),
      QuestionsTab(),
      LibraryTab(),
      GenerateTab(),
      AdminSettingsTab(),
    ]);
    if (wide) {
      return Scaffold(
        body: SafeArea(
          child: Row(children: [
            NavigationRail(
              selectedIndex: _tab,
              onDestinationSelected: (i) => setState(() => _tab = i),
              labelType: NavigationRailLabelType.all,
              leading: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Column(children: [
                  const Mascot(size: 48),
                  Text('Quản trị', style: display(15, color: AppColors.leaf)),
                ]),
              ),
              destinations: [
                for (final it in _items) NavigationRailDestination(icon: Icon(it.$1), label: Text(it.$2)),
              ],
            ),
            const VerticalDivider(width: 1),
            Expanded(child: body),
          ]),
        ),
      );
    }
    return Scaffold(
      body: SafeArea(child: body),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: [for (final it in _items) NavigationDestination(icon: Icon(it.$1), label: it.$2)],
      ),
    );
  }
}

/// Chọn lớp và môn (dùng ở nhiều tab).
class GradeSubjectPicker extends StatelessWidget {
  const GradeSubjectPicker({super.key, required this.grade, required this.subject, required this.onChanged});
  final int grade;
  final Subject subject;
  final void Function(int grade, Subject subject) onChanged;

  @override
  Widget build(BuildContext context) => Wrap(spacing: 12, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
        SegmentedButton<int>(
          segments: [for (final g in grades) ButtonSegment(value: g, label: Text('Lớp $g'))],
          selected: {grade},
          showSelectedIcon: false,
          onSelectionChanged: (s) => onChanged(s.first, subject),
        ),
        DropdownButton<Subject>(
          value: subject,
          items: [for (final s in Subject.values) DropdownMenuItem(value: s, child: Text(s.label))],
          onChanged: (s) => onChanged(grade, s ?? subject),
        ),
      ]);
}

// =========================== Tài khoản ===========================

class AccountsTab extends StatefulWidget {
  const AccountsTab({super.key});

  @override
  State<AccountsTab> createState() => _AccountsTabState();
}

class _AccountsTabState extends State<AccountsTab> {
  late final Stream<List<Profile>> _users;

  @override
  void initState() {
    super.initState();
    _users = context.read<Session>().repo.watchAllUsers();
  }

  Future<void> _create() async {
    final created = await showDialog<bool>(context: context, builder: (_) => const _CreateAccountDialog());
    if (created == true && mounted) showSnack(context, 'Đã tạo tài khoản.');
  }

  Future<void> _edit(Profile p) async {
    final repo = context.read<Session>().repo;
    var grade = p.grade;
    var active = p.active;
    final name = TextEditingController(text: p.displayName);
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, setD) => AlertDialog(
          title: Text(p.username, style: display(20)),
          content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            TextField(controller: name, decoration: const InputDecoration(labelText: 'Họ tên')),
            if (p.role == Role.student) ...[
              const SizedBox(height: 10),
              DropdownButton<int>(
                value: grades.contains(grade) ? grade : 6,
                items: [for (final g in grades) DropdownMenuItem(value: g, child: Text('Lớp $g'))],
                onChanged: (g) => setD(() => grade = g ?? grade),
              ),
            ],
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: active,
              title: const Text('Cho phép đăng nhập'),
              onChanged: (v) => setD(() => active = v),
            ),
            const Text(
              'Đặt lại mật khẩu: chạy workflow "Reset password" trên GitHub (xem README).',
              style: TextStyle(fontSize: 12, color: AppColors.muted),
            ),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Hủy')),
            FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Lưu')),
          ],
        ),
      ),
    );
    if (ok != true) return;
    try {
      await repo.updateUser(p.uid, {
        'displayName': name.text.trim(),
        'active': active,
        if (p.role == Role.student) 'grade': grade,
      });
      if (mounted) showSnack(context, 'Đã lưu.');
    } catch (e) {
      if (mounted) showSnack(context, 'Lỗi: $e', error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Profile>>(
      stream: _users,
      builder: (context, snap) {
        if (snap.hasError) return ErrorView('Không tải được tài khoản: ${snap.error}');
        if (!snap.hasData) return const Loading();
        final users = snap.data!;
        final byUid = {for (final u in users) u.uid: u};
        return AppPage(maxWidth: 1000, children: [
          Row(children: [
            Expanded(child: Text('Tài khoản', style: display(26))),
            FilledButton.icon(onPressed: _create, icon: const Icon(Icons.add_rounded), label: const Text('Tạo tài khoản')),
          ]),
          Text('${users.where((u) => u.role == Role.student).length} học sinh · '
              '${users.where((u) => u.role == Role.parent).length} phụ huynh',
              style: const TextStyle(color: AppColors.muted)),
          for (final u in users)
            AppCard(
              onTap: u.role == Role.admin ? null : () => _edit(u),
              padding: const EdgeInsets.all(10),
              child: Row(children: [
                Avatar(u.initials, color: avatarColor(u.uid), size: 34),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('${u.displayName}  ·  ${u.username}', style: const TextStyle(fontWeight: FontWeight.w700)),
                    Text(
                      switch (u.role) {
                        Role.student => 'Lớp ${u.grade} · ${u.parents.isEmpty ? 'chưa liên kết phụ huynh' : '→ ${u.parents.map((x) => byUid[x]?.parentCode ?? '?').join(', ')}'}'
                            ' · ${fmtInt(u.coins)} xu · chuỗi ${u.streak}',
                        Role.parent => 'Mã ${u.parentCode ?? '—'}',
                        Role.admin => 'Quản trị viên',
                      },
                      style: const TextStyle(fontSize: 12.5, color: AppColors.muted),
                    ),
                  ]),
                ),
                Pill(roleLabel(u.role),
                    bg: switch (u.role) {
                      Role.student => AppColors.sunSoft,
                      Role.parent => AppColors.seaSoft,
                      Role.admin => AppColors.plumSoft,
                    },
                    size: 12),
                const SizedBox(width: 6),
                if (!u.active) const Pill('Đã khóa', bg: AppColors.badSoft, fg: AppColors.badInk, size: 12),
              ]),
            ),
        ]);
      },
    );
  }
}

class _CreateAccountDialog extends StatefulWidget {
  const _CreateAccountDialog();

  @override
  State<_CreateAccountDialog> createState() => _CreateAccountDialogState();
}

class _CreateAccountDialogState extends State<_CreateAccountDialog> {
  Role _role = Role.student;
  int _grade = 6;
  final _user = TextEditingController();
  final _name = TextEditingController();
  final _pass = TextEditingController();
  bool _busy = false;
  String? _error;

  Future<void> _submit() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await context.read<Session>().repo.createAccount(
            role: _role,
            username: _user.text,
            displayName: _name.text,
            password: _pass.text,
            grade: _grade,
          );
      if (mounted) Navigator.pop(context, true);
    } on AppError catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = 'Lỗi: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Tạo tài khoản', style: display(21)),
      content: SizedBox(
        width: 380,
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          SegmentedButton<Role>(
            segments: const [
              ButtonSegment(value: Role.student, label: Text('Học sinh')),
              ButtonSegment(value: Role.parent, label: Text('Phụ huynh')),
            ],
            selected: {_role},
            onSelectionChanged: (s) => setState(() => _role = s.first),
          ),
          const SizedBox(height: 12),
          TextField(controller: _name, decoration: const InputDecoration(labelText: 'Họ tên, ví dụ: Phạm Minh An')),
          const SizedBox(height: 10),
          TextField(
            controller: _user,
            autocorrect: false,
            decoration: const InputDecoration(labelText: 'Tên đăng nhập, ví dụ: minhan.7a', helperText: 'Chữ thường không dấu, số, dấu chấm'),
          ),
          const SizedBox(height: 10),
          TextField(controller: _pass, decoration: const InputDecoration(labelText: 'Mật khẩu (ít nhất 6 ký tự)')),
          if (_role == Role.student) ...[
            const SizedBox(height: 10),
            DropdownButtonFormField<int>(
              value: _grade,
              decoration: const InputDecoration(labelText: 'Lớp'),
              items: [for (final g in grades) DropdownMenuItem(value: g, child: Text('Lớp $g'))],
              onChanged: (g) => setState(() => _grade = g ?? 6),
            ),
          ],
          if (_role == Role.parent)
            const Padding(
              padding: EdgeInsets.only(top: 10),
              child: Text('Mã phụ huynh (PH-xxxx) được tạo tự động.', style: TextStyle(fontSize: 12, color: AppColors.muted)),
            ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text(_error!, style: const TextStyle(color: AppColors.badInk)),
            ),
        ]),
      ),
      actions: [
        TextButton(onPressed: _busy ? null : () => Navigator.pop(context, false), child: const Text('Hủy')),
        FilledButton(
          onPressed: _busy ? null : _submit,
          child: _busy ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Tạo'),
        ),
      ],
    );
  }
}

// =========================== Mục lục ===========================

class CurriculumTab extends StatefulWidget {
  const CurriculumTab({super.key});

  @override
  State<CurriculumTab> createState() => _CurriculumTabState();
}

class _CurriculumTabState extends State<CurriculumTab> {
  int _grade = 6;
  Subject _subject = Subject.toan;
  final _text = TextEditingController();
  int _upTo = 0;
  bool _loading = true;
  bool _busy = false;
  Map<int, int> _counts = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final repo = context.read<Session>().repo;
    try {
      final c = await repo.curriculum(_grade, _subject);
      final qs = await repo.approvedQuestions(_grade, _subject);
      final counts = <int, int>{};
      for (final q in qs) {
        counts[q.lessonOrder] = (counts[q.lessonOrder] ?? 0) + 1;
      }
      setState(() {
        _text.text = c.lines.join('\n');
        _upTo = c.upTo;
        _counts = counts;
      });
    } catch (e) {
      if (mounted) showSnack(context, 'Lỗi tải mục lục: $e', error: true);
    }
    if (mounted) setState(() => _loading = false);
  }

  String _autoLabel() {
    final c = _current;
    final n = c.autoUpTo(DateTime.now());
    final ls = c.lessons;
    if (n <= 0 || ls.isEmpty) return 'Tự động theo tuần học';
    return 'Tự động theo tuần (hiện tới: ${ls[n - 1].title})';
  }

  Curriculum get _current => Curriculum(
        grade: _grade,
        subject: _subject,
        lines: _text.text.split('\n').map((l) => l.trimRight()).where((l) => l.trim().isNotEmpty).toList(),
        upTo: _upTo,
      );

  Future<void> _save() async {
    setState(() => _busy = true);
    try {
      final c = _current;
      final n = c.lessons.length;
      await context.read<Session>().repo.saveCurriculum(
          Curriculum(grade: c.grade, subject: c.subject, lines: c.lines, upTo: _upTo > n ? n : _upTo));
      if (mounted) showSnack(context, 'Đã lưu mục lục $n bài.');
    } catch (e) {
      if (mounted) showSnack(context, 'Lỗi: $e', error: true);
    }
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _suggest() async {
    if (_text.text.trim().isNotEmpty &&
        !await confirm(context, 'Thay mục lục hiện tại?', 'Nội dung đang có trong ô sẽ bị thay bằng gợi ý của AI.', ok: 'Thay')) {
      return;
    }
    setState(() => _busy = true);
    try {
      final lines = await context.read<Session>().ai.suggestCurriculum(_grade, _subject);
      setState(() => _text.text = lines.join('\n'));
      if (mounted) {
        showSnack(context, 'AI đã gợi ý ${lines.length} dòng. Hãy đối chiếu với mục lục SGK thật trước khi lưu.');
      }
    } on AppError catch (e) {
      if (mounted) showSnack(context, e.message, error: true);
    }
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final lessons = _current.lessons;
    return AppPage(maxWidth: 1000, children: [
      Text('Mục lục SGK', style: display(26)),
      const Text(
        'Mỗi dòng một bài, đúng thứ tự trong sách "Kết nối tri thức với cuộc sống". '
        'Dòng tên chương bắt đầu bằng dấu #. Ví dụ:\n# Chương I. Số hữu tỉ\nBài 1. Tập hợp các số hữu tỉ',
        style: TextStyle(fontSize: 12.5, color: AppColors.muted),
      ),
      GradeSubjectPicker(
        grade: _grade,
        subject: _subject,
        onChanged: (g, s) {
          setState(() {
            _grade = g;
            _subject = s;
          });
          _load();
        },
      ),
      if (_loading)
        const LinearProgressIndicator()
      else ...[
        TextField(
          controller: _text,
          minLines: 10,
          maxLines: 24,
          onChanged: (_) => setState(() {}),
          decoration: const InputDecoration(hintText: '# Chương I. ...\nBài 1. ...'),
        ),
        Row(children: [
          const Text('Con đang học tới: '),
          const SizedBox(width: 8),
          Expanded(
            child: DropdownButton<int>(
              isExpanded: true,
              value: _upTo > lessons.length ? 0 : _upTo,
              items: [
                DropdownMenuItem(value: 0, child: Text(_autoLabel())),
                for (final l in lessons) DropdownMenuItem(value: l.order, child: Text(l.title, overflow: TextOverflow.ellipsis)),
              ],
              onChanged: (v) => setState(() => _upTo = v ?? 0),
            ),
          ),
        ]),
        const Text(
          'Đề hằng ngày chỉ lấy câu hỏi của các bài từ đầu tới bài này. Để "Tự động" thì app ước tính theo tuần '
          'của năm học; chọn bài cụ thể nếu lớp của con học nhanh hoặc chậm hơn.',
          style: TextStyle(fontSize: 12, color: AppColors.muted),
        ),
        Row(children: [
          Expanded(child: BigButton('Lưu mục lục', onPressed: _save, loading: _busy)),
          const SizedBox(width: 10),
          Expanded(child: BigButton('Gợi ý bằng AI', ghost: true, onPressed: _busy ? null : _suggest)),
        ]),
        const SectionLabel('Số câu đã duyệt theo bài'),
        for (final l in lessons)
          Row(children: [
            Expanded(
              child: Text('${l.order}. ${l.title}',
                  style: TextStyle(fontSize: 13, color: _upTo > 0 && l.order > _upTo ? AppColors.muted : AppColors.ink)),
            ),
            Pill('${_counts[l.order] ?? 0} câu',
                bg: (_counts[l.order] ?? 0) >= 20 ? AppColors.leafSoft : AppColors.sunSoft, size: 12),
          ]),
      ],
    ]);
  }
}

// =========================== Ngân hàng câu hỏi ===========================

class QuestionsTab extends StatefulWidget {
  const QuestionsTab({super.key});

  @override
  State<QuestionsTab> createState() => _QuestionsTabState();
}

class _QuestionsTabState extends State<QuestionsTab> {
  int _grade = 6;
  Subject _subject = Subject.toan;
  String _status = 'pending';
  late Stream<List<Question>> _stream;

  @override
  void initState() {
    super.initState();
    _subscribe();
  }

  void _subscribe() {
    _stream = context.read<Session>().repo.watchQuestions(_grade, _subject, _status);
  }

  Future<void> _set(Question q, String status) async {
    try {
      await context.read<Session>().repo.updateQuestion(q.id, {'status': status});
    } catch (e) {
      if (mounted) showSnack(context, 'Lỗi: $e', error: true);
    }
  }

  Future<void> _edit(Question q) async {
    final updated = await showDialog<Question>(context: context, builder: (_) => QuestionEditor(question: q));
    if (updated == null || !mounted) return;
    try {
      await context.read<Session>().repo.updateQuestion(q.id, updated.toMap());
      if (mounted) showSnack(context, 'Đã lưu câu hỏi.');
    } catch (e) {
      if (mounted) showSnack(context, 'Lỗi: $e', error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Question>>(
      stream: _stream,
      builder: (context, snap) {
        final list = snap.data ?? const <Question>[];
        return AppPage(maxWidth: 1000, children: [
          Text('Ngân hàng câu hỏi', style: display(26)),
          GradeSubjectPicker(
            grade: _grade,
            subject: _subject,
            onChanged: (g, s) => setState(() {
              _grade = g;
              _subject = s;
              _subscribe();
            }),
          ),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'pending', label: Text('Chờ duyệt')),
              ButtonSegment(value: 'approved', label: Text('Đã duyệt')),
              ButtonSegment(value: 'rejected', label: Text('Đã loại')),
            ],
            selected: {_status},
            onSelectionChanged: (s) => setState(() {
              _status = s.first;
              _subscribe();
            }),
          ),
          if (snap.hasError) Text('Lỗi: ${snap.error}', style: const TextStyle(color: AppColors.badInk)),
          if (!snap.hasData && !snap.hasError) const LinearProgressIndicator(),
          if (snap.hasData)
            Row(children: [
              Expanded(child: Text('${list.length} câu', style: const TextStyle(color: AppColors.muted))),
              if (_status == 'pending' && list.isNotEmpty)
                FilledButton.icon(
                  icon: const Icon(Icons.done_all_rounded),
                  label: Text('Duyệt cả ${list.length} câu'),
                  onPressed: () async {
                    if (await confirm(context, 'Duyệt tất cả?',
                        'Duyệt ${list.length} câu đang hiển thị. Hãy chắc là bạn đã đọc kỹ.', ok: 'Duyệt')) {
                      if (context.mounted) {
                        await context.read<Session>().repo.setQuestionsStatus(list.map((q) => q.id), 'approved');
                      }
                    }
                  },
                ),
            ]),
          for (final (i, q) in list.indexed)
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              QuestionReview(number: i + 1, question: q, chosen: q.answer),
              Wrap(alignment: WrapAlignment.end, spacing: 4, children: [
                TextButton.icon(onPressed: () => _edit(q), icon: const Icon(Icons.edit_rounded), label: const Text('Sửa')),
                if (q.status != 'approved')
                  TextButton.icon(
                      onPressed: () => _set(q, 'approved'), icon: const Icon(Icons.check_rounded), label: const Text('Duyệt')),
                if (q.status != 'rejected')
                  TextButton.icon(
                      onPressed: () => _set(q, 'rejected'), icon: const Icon(Icons.block_rounded), label: const Text('Loại')),
                TextButton.icon(
                  onPressed: () async {
                    if (await confirm(context, 'Xóa câu hỏi?', 'Xóa hẳn câu này khỏi ngân hàng.', ok: 'Xóa')) {
                      if (context.mounted) await context.read<Session>().repo.deleteQuestion(q.id);
                    }
                  },
                  icon: const Icon(Icons.delete_outline_rounded),
                  label: const Text('Xóa'),
                ),
              ]),
            ]),
          if (snap.hasData && list.isEmpty) const EmptyView('Không có câu hỏi nào ở mục này.'),
        ]);
      },
    );
  }
}

/// Hộp sửa một câu hỏi.
class QuestionEditor extends StatefulWidget {
  const QuestionEditor({super.key, required this.question});
  final Question question;

  @override
  State<QuestionEditor> createState() => _QuestionEditorState();
}

class _QuestionEditorState extends State<QuestionEditor> {
  late final _text = TextEditingController(text: widget.question.text);
  late final _passage = TextEditingController(text: widget.question.passage);
  late final _explain = TextEditingController(text: widget.question.explanation);
  late final _options = [
    for (var i = 0; i < 4; i++)
      TextEditingController(text: i < widget.question.options.length ? widget.question.options[i] : ''),
  ];
  late int _answer = widget.question.answer;
  late int _level = widget.question.level;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Sửa câu hỏi', style: display(20)),
      content: SizedBox(
        width: 560,
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            DropdownButton<int>(
              value: _level,
              items: [for (var l = 1; l <= 4; l++) DropdownMenuItem(value: l, child: Text(levelName(l)))],
              onChanged: (v) => setState(() => _level = v ?? _level),
            ),
            TextField(controller: _passage, maxLines: 4, minLines: 1, decoration: const InputDecoration(labelText: 'Ngữ liệu (có thể để trống)')),
            const SizedBox(height: 8),
            TextField(controller: _text, maxLines: 5, minLines: 2, decoration: const InputDecoration(labelText: 'Câu hỏi')),
            for (var i = 0; i < 4; i++)
              RadioListTile<int>(
                contentPadding: EdgeInsets.zero,
                value: i,
                groupValue: _answer,
                onChanged: (v) => setState(() => _answer = v ?? _answer),
                title: TextField(
                  controller: _options[i],
                  decoration: InputDecoration(labelText: 'Phương án ${String.fromCharCode(65 + i)}'),
                ),
              ),
            TextField(controller: _explain, maxLines: 4, minLines: 1, decoration: const InputDecoration(labelText: 'Lời giải')),
            const Text('Chấm tròn bên trái là đáp án đúng.', style: TextStyle(fontSize: 12, color: AppColors.muted)),
          ]),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Hủy')),
        FilledButton(
          onPressed: () => Navigator.pop(
            context,
            widget.question.copyWith(
              text: _text.text.trim(),
              passage: _passage.text.trim(),
              options: _options.map((c) => c.text.trim()).toList(),
              answer: _answer,
              explanation: _explain.text.trim(),
              level: _level,
            ),
          ),
          child: const Text('Lưu'),
        ),
      ],
    );
  }
}

// =========================== Sinh câu hỏi bằng AI ===========================

class GenerateTab extends StatefulWidget {
  const GenerateTab({super.key});

  @override
  State<GenerateTab> createState() => _GenerateTabState();
}

class _GenerateTabState extends State<GenerateTab> {
  int _grade = 6;
  Subject _subject = Subject.toan;
  Curriculum? _curriculum;
  int? _lesson;
  final _counts = [4, 3, 2, 1];
  bool _busy = false;
  List<Question> _draft = [];
  final _keep = <int>{};

  @override
  void initState() {
    super.initState();
    _loadCurriculum();
  }

  Future<void> _loadCurriculum() async {
    final c = await context.read<Session>().repo.curriculum(_grade, _subject);
    if (!mounted) return;
    setState(() {
      _curriculum = c;
      final ls = c.lessons;
      _lesson = ls.isEmpty ? null : (c.upTo > 0 && c.upTo <= ls.length ? c.upTo : 1);
    });
  }

  Lesson? get _selectedLesson {
    final ls = _curriculum?.lessons ?? const <Lesson>[];
    for (final l in ls) {
      if (l.order == _lesson) return l;
    }
    return null;
  }

  Future<void> _generate() async {
    final lesson = _selectedLesson;
    if (lesson == null) return;
    setState(() {
      _busy = true;
      _draft = [];
      _keep.clear();
    });
    final s = context.read<Session>();
    try {
      final existing = <String>[];
      for (final st in ['approved', 'pending']) {
        final qs = await s.repo.watchQuestions(_grade, _subject, st).first;
        existing.addAll(qs.where((q) => q.lessonOrder == lesson.order).map((q) => q.text));
      }
      final qs = await s.ai.generateQuestions(
        grade: _grade,
        subject: _subject,
        lesson: lesson,
        counts: _counts,
        existing: existing,
      );
      setState(() {
        _draft = qs;
        _keep.addAll(List.generate(qs.length, (i) => i));
      });
    } on AppError catch (e) {
      if (mounted) showSnack(context, e.message, error: true);
    } catch (e) {
      if (mounted) showSnack(context, 'Lỗi: $e', error: true);
    }
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _save(bool approve) async {
    final chosen = [for (var i = 0; i < _draft.length; i++) if (_keep.contains(i)) _draft[i].copyWith(status: approve ? 'approved' : 'pending')];
    if (chosen.isEmpty) return;
    try {
      await context.read<Session>().repo.addQuestions(chosen);
      if (!mounted) return;
      showSnack(context, approve ? 'Đã lưu và duyệt ${chosen.length} câu.' : 'Đã lưu ${chosen.length} câu vào mục Chờ duyệt.');
      setState(() {
        _draft = [];
        _keep.clear();
      });
    } catch (e) {
      if (mounted) showSnack(context, 'Lỗi: $e', error: true);
    }
  }

  Future<void> _edit(int i) async {
    final updated = await showDialog<Question>(context: context, builder: (_) => QuestionEditor(question: _draft[i]));
    if (updated != null) setState(() => _draft[i] = updated);
  }

  @override
  Widget build(BuildContext context) {
    final lessons = _curriculum?.lessons ?? const <Lesson>[];
    final total = _counts.fold(0, (a, b) => a + b);
    return AppPage(maxWidth: 1000, children: [
      Text('Sinh câu hỏi bằng AI', style: display(26)),
      const Text(
        'Claude soạn câu hỏi theo từng bài trong SGK. Đọc kỹ từng câu, sửa nếu cần, bỏ chọn câu chưa tốt rồi mới lưu.',
        style: TextStyle(fontSize: 12.5, color: AppColors.muted),
      ),
      GradeSubjectPicker(
        grade: _grade,
        subject: _subject,
        onChanged: (g, s) {
          setState(() {
            _grade = g;
            _subject = s;
            _curriculum = null;
            _draft = [];
          });
          _loadCurriculum();
        },
      ),
      if (_curriculum == null)
        const LinearProgressIndicator()
      else if (lessons.isEmpty)
        const AppCard(
          color: AppColors.sunSoft,
          child: Text('Chưa có mục lục cho lớp và môn này. Hãy nhập ở tab Mục lục trước.'),
        )
      else ...[
        DropdownButton<int>(
          isExpanded: true,
          value: _lesson,
          items: [
            for (final l in lessons)
              DropdownMenuItem(value: l.order, child: Text('${l.order}. ${l.title}', overflow: TextOverflow.ellipsis)),
          ],
          onChanged: (v) => setState(() => _lesson = v),
        ),
        Wrap(spacing: 10, runSpacing: 8, children: [
          for (var i = 0; i < 4; i++)
            SizedBox(
              width: 150,
              child: Row(children: [
                Expanded(child: Text(levelNames[i], style: const TextStyle(fontSize: 13))),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  onPressed: _counts[i] > 0 ? () => setState(() => _counts[i]--) : null,
                  icon: const Icon(Icons.remove_circle_outline_rounded),
                ),
                Text('${_counts[i]}', style: display(17)),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  onPressed: total < 30 ? () => setState(() => _counts[i]++) : null,
                  icon: const Icon(Icons.add_circle_outline_rounded),
                ),
              ]),
            ),
        ]),
        BigButton(_busy ? 'Claude đang soạn (có thể mất 1–3 phút)...' : 'Sinh $total câu hỏi',
            icon: Icons.auto_awesome_rounded, onPressed: _busy || total == 0 ? null : _generate, loading: _busy),
      ],
      if (_draft.isNotEmpty) ...[
        SectionLabel('Bản nháp: chọn ${_keep.length}/${_draft.length} câu'),
        for (var i = 0; i < _draft.length; i++)
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Checkbox(
              value: _keep.contains(i),
              onChanged: (v) => setState(() => v == true ? _keep.add(i) : _keep.remove(i)),
            ),
            Expanded(child: QuestionReview(number: i + 1, question: _draft[i], chosen: _draft[i].answer)),
            IconButton(onPressed: () => _edit(i), icon: const Icon(Icons.edit_rounded)),
          ]),
        Row(children: [
          Expanded(child: BigButton('Lưu, để duyệt sau', ghost: true, onPressed: () => _save(false))),
          const SizedBox(width: 10),
          Expanded(child: BigButton('Lưu và duyệt luôn', onPressed: () => _save(true))),
        ]),
      ],
    ]);
  }
}

// =========================== Cài đặt ===========================

class AdminSettingsTab extends StatefulWidget {
  const AdminSettingsTab({super.key});

  @override
  State<AdminSettingsTab> createState() => _AdminSettingsTabState();
}

class _AdminSettingsTabState extends State<AdminSettingsTab> {
  final _key = TextEditingController();
  bool _hasKey = false;

  @override
  void initState() {
    super.initState();
    context.read<Session>().ai.loadKey().then((k) {
      if (mounted) setState(() => _hasKey = k != null);
    });
  }

  @override
  void dispose() {
    _key.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppPage(children: [
      Text('Cài đặt', style: display(26)),
      AppCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('Claude API key', style: display(18)),
          Text(
            _hasKey ? 'Đã lưu khóa trên máy này.' : 'Chưa có khóa. Tạo khóa ở console.anthropic.com → API Keys.',
            style: TextStyle(color: _hasKey ? AppColors.leafInk : AppColors.flameInk),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _key,
            obscureText: true,
            decoration: const InputDecoration(labelText: 'Dán khóa sk-ant-... vào đây'),
          ),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(
              child: BigButton('Lưu khóa', onPressed: () async {
                await context.read<Session>().ai.saveKey(_key.text);
                _key.clear();
                setState(() => _hasKey = true);
                if (context.mounted) showSnack(context, 'Đã lưu khóa trên máy này.');
              }),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: BigButton('Xóa khóa', ghost: true, onPressed: () async {
                await context.read<Session>().ai.saveKey('');
                setState(() => _hasKey = false);
              }),
            ),
          ]),
          const SizedBox(height: 8),
          const Text(
            'Khóa chỉ lưu trên máy (hoặc trình duyệt) đang dùng, không gửi lên Firebase. '
            'Mỗi lần sinh 10 câu tốn khoảng vài nghìn đồng tiền API.',
            style: TextStyle(fontSize: 12, color: AppColors.muted),
          ),
        ]),
      ),
      const PasswordAndLogout(),
    ]);
  }
}
