import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// Ảnh đại diện của người dùng.
///
/// Firebase Storage cần gói trả phí, nên ảnh được thu nhỏ (tối đa 256×256,
/// vài chục KB) rồi lưu dạng base64 trong Firestore: avatars/{uid}.data.
/// Ảnh tải về được giữ trong bộ nhớ để không đọc lại nhiều lần.
class AvatarStore extends ChangeNotifier {
  AvatarStore._();
  static final AvatarStore instance = AvatarStore._();

  /// Giới hạn kích thước ảnh sau khi nén (byte).
  static const maxBytes = 150 * 1024;

  final _cache = <String, Future<Uint8List?>>{};

  CollectionReference<Map<String, dynamic>> get _col => FirebaseFirestore.instance.collection('avatars');

  /// Ảnh của [uid], null nếu chưa có ảnh hoặc không tải được.
  Future<Uint8List?> get(String uid) => _cache.putIfAbsent(uid, () => _load(uid));

  Future<Uint8List?> _load(String uid) async {
    try {
      final d = await _col.doc(uid).get();
      final s = d.data()?['data'] as String?;
      if (s == null || s.isEmpty) return null;
      return base64Decode(s);
    } catch (e) {
      debugPrint('[Avatar] $uid: $e');
      return null;
    }
  }

  Future<void> set(String uid, Uint8List bytes) async {
    if (bytes.length > maxBytes) {
      throw Exception('Ảnh quá lớn (${bytes.length ~/ 1024} KB). Hãy chọn ảnh khác.');
    }
    await _col.doc(uid).set({'data': base64Encode(bytes), 'updatedAt': FieldValue.serverTimestamp()});
    _cache[uid] = Future.value(bytes);
    notifyListeners();
  }

  Future<void> remove(String uid) async {
    await _col.doc(uid).delete();
    _cache[uid] = Future.value(null);
    notifyListeners();
  }
}
