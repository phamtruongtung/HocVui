import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/models.dart';
import '../../services/repo.dart';
import '../../services/sound.dart';
import '../../state/session.dart';
import '../../theme.dart';
import '../../version.dart';
import '../../widgets/common.dart';

class ProfileTab extends StatefulWidget {
  const ProfileTab({super.key});

  @override
  State<ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<ProfileTab> {
  final _code = TextEditingController();
  bool _busy = false;
  late final Stream<List<LinkRequest>> _links;

  @override
  void initState() {
    super.initState();
    final s = context.read<Session>();
    _links = s.repo.watchKidLinks(s.profile!.uid);
  }

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _link() async {
    final s = context.read<Session>();
    setState(() => _busy = true);
    try {
      await s.repo.requestLink(s.profile!, _code.text);
      _code.clear();
      if (mounted) showSnack(context, 'Đã gửi yêu cầu. Chờ bố mẹ xác nhận nhé!');
    } on AppError catch (e) {
      if (mounted) showSnack(context, e.message, error: true);
    } catch (e) {
      if (mounted) showSnack(context, 'Không gửi được: $e', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<Session>().profile!;
    return AppPage(children: [
      Row(children: [
        Avatar(p.initials, color: avatarColor(p.uid), size: 52),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(p.displayName, style: display(21)),
            Text('${p.username} · Lớp ${p.grade}', style: const TextStyle(color: AppColors.muted)),
          ]),
        ),
      ]),
      AppCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('Liên kết với phụ huynh', style: display(17)),
          const Text('Nhập mã số trong ứng dụng của bố hoặc mẹ, ví dụ PH-4821.',
              style: TextStyle(fontSize: 12.5, color: AppColors.muted)),
          const SizedBox(height: 10),
          TextField(
            controller: _code,
            textCapitalization: TextCapitalization.characters,
            textAlign: TextAlign.center,
            style: display(22),
            decoration: const InputDecoration(hintText: 'PH-0000'),
          ),
          const SizedBox(height: 10),
          BigButton('Gửi yêu cầu liên kết', onPressed: _link, loading: _busy),
        ]),
      ),
      const SectionLabel('Phụ huynh'),
      StreamBuilder<List<LinkRequest>>(
        stream: _links,
        builder: (context, snap) {
          final list = snap.data ?? const [];
          if (list.isEmpty) return const Text('Chưa liên kết với ai.', style: TextStyle(color: AppColors.muted));
          return Column(children: [
            for (final l in list)
              Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: l.status == 'accepted' ? AppColors.leafSoft : AppColors.paper,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(children: [
                  Avatar(l.parentName.isEmpty ? '?' : l.parentName.characters.first.toUpperCase(), color: AppColors.leaf),
                  const SizedBox(width: 10),
                  Expanded(child: Text(l.parentName, style: const TextStyle(fontWeight: FontWeight.w700))),
                  Text(
                    switch (l.status) {
                      'accepted' => 'Đã xác nhận',
                      'rejected' => 'Bị từ chối',
                      _ => 'Chờ xác nhận',
                    },
                    style: const TextStyle(fontSize: 12, color: AppColors.muted),
                  ),
                ]),
              ),
          ]);
        },
      ),
      AppCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Nhắc học', style: display(17)),
          const SizedBox(height: 4),
          Text(
            kIsWeb
                ? 'Bản web không có nhắc học. Hãy cài app Android để được nhắc mỗi tối.'
                : 'Chưa xong bài thì app nhắc từ 19:00, càng gần 23:59 càng nhắc dày hơn. '
                    'Hạn chót mỗi ngày: 23:59.',
            style: const TextStyle(fontSize: 13, color: AppColors.muted),
          ),
          if (!kIsWeb)
            TextButton(
              onPressed: () async {
                final ok = await context.read<Session>().notifier.requestPermission();
                if (context.mounted) {
                  showSnack(context, ok ? 'Đã bật thông báo.' : 'Hãy bật thông báo cho Học Vui trong Cài đặt của điện thoại.');
                }
              },
              child: const Text('Bật thông báo'),
            ),
        ]),
      ),
      const _SoundCard(),
      const PasswordAndLogout(),
    ]);
  }
}

/// Bật/tắt nhạc nền và tiếng hiệu ứng (lưu trên máy này).
class _SoundCard extends StatelessWidget {
  const _SoundCard();

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: Sound.instance,
        builder: (context, _) => AppCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Âm thanh', style: display(17)),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: Sound.instance.musicOn,
              onChanged: Sound.instance.setMusicOn,
              title: const Text('Nhạc nền'),
              subtitle: const Text('Tự tắt khi đang làm bài.', style: TextStyle(fontSize: 12)),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: Sound.instance.sfxOn,
              onChanged: Sound.instance.setSfxOn,
              title: const Text('Tiếng hiệu ứng'),
              subtitle: const Text('Chọn đáp án, đúng/sai, nhận xu, nộp bài.', style: TextStyle(fontSize: 12)),
            ),
          ]),
        ),
      );
}

/// Đổi mật khẩu, đăng xuất, phiên bản app (dùng chung cho mọi vai trò).
class PasswordAndLogout extends StatelessWidget {
  const PasswordAndLogout({super.key});

  Future<void> _changePassword(BuildContext context) async {
    final oldC = TextEditingController();
    final newC = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text('Đổi mật khẩu', style: display(20)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: oldC, obscureText: true, decoration: const InputDecoration(labelText: 'Mật khẩu hiện tại')),
          const SizedBox(height: 10),
          TextField(controller: newC, obscureText: true, decoration: const InputDecoration(labelText: 'Mật khẩu mới (ít nhất 6 ký tự)')),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Hủy')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Đổi')),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    try {
      await context.read<Session>().repo.changePassword(oldC.text, newC.text);
      if (context.mounted) showSnack(context, 'Đã đổi mật khẩu.');
    } on AppError catch (e) {
      if (context.mounted) showSnack(context, e.message, error: true);
    }
  }

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        BigButton('Đổi mật khẩu', ghost: true, onPressed: () => _changePassword(context)),
        const SizedBox(height: 12),
        BigButton('Đăng xuất', color: AppColors.bad, shadow: AppColors.badInk, onPressed: () async {
          if (await confirm(context, 'Đăng xuất?', 'Bạn sẽ cần nhập lại mật khẩu để vào app.', ok: 'Đăng xuất')) {
            if (context.mounted) await context.read<Session>().signOut();
          }
        }),
        const SizedBox(height: 10),
        const Text('Học Vui phiên bản $kAppVersion',
            textAlign: TextAlign.center, style: TextStyle(fontSize: 11, color: AppColors.muted)),
      ]);
}
