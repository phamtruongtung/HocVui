import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/repo.dart';
import '../state/session.dart';
import '../theme.dart';
import '../version.dart';
import '../widgets/common.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _user = TextEditingController();
  final _pass = TextEditingController();
  bool _parent = false;
  bool _busy = false;
  bool _hide = true;
  String? _error;

  @override
  void dispose() {
    _user.dispose();
    _pass.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await context.read<Session>().signIn(_user.text, _pass.text);
    } on AppError catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = 'Không đăng nhập được: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _segment(String label, bool parent) {
    final on = _parent == parent;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _parent = parent),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: on ? AppColors.paper : Colors.transparent,
            borderRadius: BorderRadius.circular(11),
            boxShadow: on ? const [BoxShadow(color: AppColors.line, offset: Offset(0, 2))] : null,
          ),
          alignment: Alignment.center,
          child: Text(label,
              style: TextStyle(fontWeight: FontWeight.w600, color: on ? AppColors.ink : AppColors.muted)),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.paper,
      body: SafeArea(
        child: AppPage(
          maxWidth: 420,
          padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
          children: [
            const Center(child: Mascot(size: 110)),
            Center(child: Text('Học Vui', style: display(34, color: AppColors.leaf))),
            Center(
              child: Text(_parent ? 'Theo dõi việc học của con mỗi ngày' : 'Gà Chíp chờ bạn học bài nè!',
                  style: const TextStyle(color: AppColors.muted)),
            ),
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(color: AppColors.page, borderRadius: BorderRadius.circular(14)),
              child: Row(children: [_segment('Con', false), const SizedBox(width: 4), _segment('Phụ huynh', true)]),
            ),
            TextField(
              controller: _user,
              autocorrect: false,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(labelText: 'Tên đăng nhập', prefixIcon: Icon(Icons.person_rounded)),
            ),
            TextField(
              controller: _pass,
              obscureText: _hide,
              onSubmitted: (_) => _submit(),
              decoration: InputDecoration(
                labelText: 'Mật khẩu',
                prefixIcon: const Icon(Icons.lock_rounded),
                suffixIcon: IconButton(
                  icon: Icon(_hide ? Icons.visibility_rounded : Icons.visibility_off_rounded),
                  onPressed: () => setState(() => _hide = !_hide),
                ),
              ),
            ),
            if (_error != null)
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: AppColors.badSoft, borderRadius: BorderRadius.circular(12)),
                child: Text(_error!, style: const TextStyle(color: AppColors.badInk)),
              ),
            BigButton(_parent ? 'Đăng nhập' : 'Vào học thôi!', onPressed: _submit, loading: _busy),
            const Text(
              'Tài khoản do quản trị viên cấp. Quên mật khẩu thì nhờ bố mẹ báo quản trị viên.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12.5, color: AppColors.muted),
            ),
            const Text('Phiên bản $kAppVersion',
                textAlign: TextAlign.center, style: TextStyle(fontSize: 11, color: AppColors.muted)),
          ],
        ),
      ),
    );
  }
}
