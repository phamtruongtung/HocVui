import 'dart:ui' show PlatformDispatcher;

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'firebase_web_options.dart';
import 'models/models.dart';
import 'screens/admin/admin_shell.dart';
import 'screens/login_screen.dart';
import 'screens/parent/parent_shell.dart';
import 'screens/student/student_shell.dart';
import 'services/ai_service.dart';
import 'services/notifier.dart';
import 'services/repo.dart';
import 'services/sound.dart';
import 'state/session.dart';
import 'theme.dart';
import 'widgets/common.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Lỗi khi vẽ giao diện: hiện nội dung lỗi thay vì màn hình trắng/xám.
  ErrorWidget.builder = (details) => _ErrorBox(details.exceptionAsString());
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    debugPrint('[Error] ${details.exceptionAsString()}\n${details.stack}');
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    debugPrint('[Error] $error\n$stack');
    return true;
  };

  try {
    if (kIsWeb) {
      if (!webFirebaseConfigured) {
        runApp(const _SetupNeeded('Bản web chưa có cấu hình Firebase (lib/firebase_web_options.dart).'));
        return;
      }
      await Firebase.initializeApp(options: webFirebaseOptions);
    } else {
      await Firebase.initializeApp();
    }
  } catch (e) {
    runApp(_SetupNeeded('Chưa cấu hình Firebase cho app Android (android/app/google-services.json).\n\n$e'));
    return;
  }

  try {
    final notifier = Notifier();
    await notifier.init();
    await Sound.instance.init();
    final session = Session(repo: Repo(), notifier: notifier, ai: AiService());
    runApp(ChangeNotifierProvider.value(value: session, child: const HocVuiApp()));
    await session.restore();
  } catch (e, s) {
    debugPrint('[Startup] $e\n$s');
    runApp(MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(backgroundColor: AppColors.page, body: _ErrorBox('$e')),
    ));
  }
}

class HocVuiApp extends StatelessWidget {
  const HocVuiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Học Vui',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      locale: const Locale('vi'),
      supportedLocales: const [Locale('vi'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: const _RootGate(),
    );
  }
}

class _RootGate extends StatelessWidget {
  const _RootGate();

  @override
  Widget build(BuildContext context) {
    final session = context.watch<Session>();
    if (session.restoring) return const Scaffold(body: Loading());
    final p = session.profile;
    if (p == null) return const LoginScreen();
    return switch (p.role) {
      Role.admin => AdminShell(key: ValueKey(p.uid)),
      Role.parent => ParentShell(key: ValueKey(p.uid)),
      Role.student => StudentShell(key: ValueKey(p.uid)),
    };
  }
}

class _SetupNeeded extends StatelessWidget {
  const _SetupNeeded(this.message);
  final String message;

  @override
  Widget build(BuildContext context) => MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: buildTheme(),
        home: Scaffold(
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const Mascot(size: 96),
                const SizedBox(height: 12),
                Text('Học Vui chưa sẵn sàng', style: display(24)),
                const SizedBox(height: 8),
                Text(message, textAlign: TextAlign.center),
                const SizedBox(height: 8),
                const Text('Xem hướng dẫn trong README.md, mục "Cấu hình Firebase".',
                    textAlign: TextAlign.center, style: TextStyle(color: AppColors.muted)),
              ]),
            ),
          ),
        ),
      );
}

/// Hộp báo lỗi thân thiện (thay cho màn hình trắng khi có lỗi).
class _ErrorBox extends StatelessWidget {
  const _ErrorBox(this.message);
  final String message;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.page,
      child: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Mascot(size: 72, cap: false),
              const SizedBox(height: 8),
              const Text('Ôi, Học Vui gặp lỗi',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: AppColors.ink)),
              const SizedBox(height: 8),
              const Text('Hãy chụp màn hình này gửi cho bố mẹ, rồi mở lại app.',
                  textAlign: TextAlign.center, style: TextStyle(color: AppColors.ink)),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.bad),
                ),
                child: SelectableText(message, style: const TextStyle(fontSize: 13, color: AppColors.bad)),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}
