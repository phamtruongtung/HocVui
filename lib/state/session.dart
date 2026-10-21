import 'package:flutter/foundation.dart';

import '../models/models.dart';
import '../services/ai_service.dart';
import '../services/notifier.dart';
import '../services/repo.dart';

/// Trạng thái đăng nhập dùng chung toàn app.
class Session extends ChangeNotifier {
  Session({required this.repo, required this.notifier, required this.ai});

  final Repo repo;
  final Notifier notifier;
  final AiService ai;

  Profile? _profile;
  Profile? get profile => _profile;

  bool _restoring = true;
  bool get restoring => _restoring;

  /// Khôi phục phiên đăng nhập cũ khi mở app.
  Future<void> restore() async {
    try {
      final p = await repo.currentProfile();
      if (p != null && p.active) _profile = p;
    } catch (e) {
      debugPrint('[Session] restore: $e');
    }
    _restoring = false;
    notifyListeners();
  }

  Future<void> signIn(String username, String password) async {
    _profile = await repo.signIn(username, password);
    notifyListeners();
    if (_profile!.role == Role.student) await notifier.requestPermission();
  }

  Future<void> refresh() async {
    final p = await repo.currentProfile();
    if (p != null) {
      _profile = p;
      notifyListeners();
    }
  }

  void setProfile(Profile p) {
    _profile = p;
    notifyListeners();
  }

  Future<void> signOut() async {
    await notifier.cancelAll();
    await repo.signOut();
    _profile = null;
    notifyListeners();
  }
}
