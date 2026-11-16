import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../models/models.dart';
import '../services/avatars.dart';
import '../theme.dart';
import 'common.dart';

/// Ảnh đại diện có thể chạm để đổi: chọn ảnh trong máy, chụp ảnh mới hoặc xóa ảnh.
class AvatarPicker extends StatefulWidget {
  const AvatarPicker({super.key, required this.profile, this.size = 64});
  final Profile profile;
  final double size;

  @override
  State<AvatarPicker> createState() => _AvatarPickerState();
}

class _AvatarPickerState extends State<AvatarPicker> {
  bool _busy = false;

  Future<void> _pick(ImageSource source) async {
    final uid = widget.profile.uid;
    try {
      // Thu nhỏ ngay khi chọn để ảnh chỉ còn vài chục KB.
      final file = await ImagePicker().pickImage(
        source: source,
        maxWidth: 256,
        maxHeight: 256,
        imageQuality: 70,
        preferredCameraDevice: CameraDevice.front,
      );
      if (file == null) return;
      setState(() => _busy = true);
      final bytes = await file.readAsBytes();
      await AvatarStore.instance.set(uid, bytes);
      if (mounted) showSnack(context, 'Đã đổi ảnh đại diện!');
    } catch (e) {
      if (mounted) showSnack(context, 'Không đổi được ảnh: $e', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _remove() async {
    setState(() => _busy = true);
    try {
      await AvatarStore.instance.remove(widget.profile.uid);
      if (mounted) showSnack(context, 'Đã xóa ảnh đại diện.');
    } catch (e) {
      if (mounted) showSnack(context, 'Không xóa được ảnh: $e', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _open() async {
    final hasPhoto = await AvatarStore.instance.get(widget.profile.uid) != null;
    if (!mounted) return;
    final choice = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (c) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('Ảnh đại diện', style: display(18)),
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 4, 20, 8),
            child: Text('Ảnh hiện ở hồ sơ, bảng xếp hạng và trong app của bố mẹ.',
                textAlign: TextAlign.center, style: TextStyle(fontSize: 12.5, color: AppColors.muted)),
          ),
          ListTile(
            leading: const Icon(Icons.photo_library_rounded, color: AppColors.sea),
            title: const Text('Chọn ảnh có sẵn'),
            onTap: () => Navigator.pop(c, 'gallery'),
          ),
          if (!kIsWeb)
            ListTile(
              leading: const Icon(Icons.photo_camera_rounded, color: AppColors.leaf),
              title: const Text('Chụp ảnh mới'),
              onTap: () => Navigator.pop(c, 'camera'),
            ),
          if (hasPhoto)
            ListTile(
              leading: const Icon(Icons.delete_outline_rounded, color: AppColors.bad),
              title: const Text('Xóa ảnh, dùng chữ cái tên'),
              onTap: () => Navigator.pop(c, 'remove'),
            ),
          const SizedBox(height: 8),
        ]),
      ),
    );
    switch (choice) {
      case 'gallery':
        await _pick(ImageSource.gallery);
      case 'camera':
        await _pick(ImageSource.camera);
      case 'remove':
        await _remove();
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.profile;
    return GestureDetector(
      onTap: _busy ? null : _open,
      child: Stack(clipBehavior: Clip.none, children: [
        Avatar(p.initials, color: avatarColor(p.uid), size: widget.size, uid: p.uid),
        if (_busy)
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(color: Colors.black38, shape: BoxShape.circle),
              alignment: Alignment.center,
              child: const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 3, color: Colors.white)),
            ),
          ),
        Positioned(
          right: -2,
          bottom: -2,
          child: Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: AppColors.sun,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
            ),
            child: const Icon(Icons.photo_camera_rounded, size: 13, color: Colors.white),
          ),
        ),
      ]),
    );
  }
}
