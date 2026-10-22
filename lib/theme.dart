import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'logic/subjects.dart';

class AppColors {
  static const page = Color(0xFFE9F3F7);
  static const paper = Color(0xFFFFFFFF);
  static const ink = Color(0xFF22314A);
  static const muted = Color(0xFF647089);
  static const line = Color(0xFFDCE6EE);
  static const leaf = Color(0xFF2FAE6B);
  static const leafDark = Color(0xFF23864F);
  static const leafSoft = Color(0xFFE2F6EA);
  static const leafInk = Color(0xFF1B7A47);
  static const sun = Color(0xFFFFB821);
  static const sunSoft = Color(0xFFFFF4D6);
  static const sunInk = Color(0xFFA06C00);
  static const flame = Color(0xFFFF6B3D);
  static const flameSoft = Color(0xFFFFE9E0);
  static const flameInk = Color(0xFFA8401A);
  static const sea = Color(0xFF2D8FD6);
  static const seaSoft = Color(0xFFE1F0FB);
  static const seaInk = Color(0xFF1C6E97);
  static const plum = Color(0xFF8A5CF0);
  static const plumSoft = Color(0xFFEEE7FE);
  static const rose = Color(0xFFEC5A8C);
  static const roseSoft = Color(0xFFFDE6EE);
  static const bad = Color(0xFFE5484D);
  static const badSoft = Color(0xFFFDE8E8);
  static const badInk = Color(0xFFA3262B);
  static const night = Color(0xFF1C2540);
}

Color subjectColor(Subject s) => switch (s) {
      Subject.toan => AppColors.sea,
      Subject.van => AppColors.rose,
      Subject.anh => AppColors.plum,
      Subject.khtn => AppColors.leaf,
      Subject.lsdl => AppColors.flame,
      Subject.tiengviet => AppColors.rose,
      Subject.tnxh => AppColors.leaf,
      Subject.khoahoc => AppColors.leaf,
    };

const levelColors = [Color(0xFF9BDDB7), Color(0xFF6FC6E8), Color(0xFFF6B44B), Color(0xFFF07856)];

Color levelColor(int level) => levelColors[(level - 1).clamp(0, 3).toInt()];

/// Chữ tiêu đề tròn trịa (Baloo 2). Không tải được phông thì dùng phông mặc định.
TextStyle display(double size, {Color color = AppColors.ink, FontWeight weight = FontWeight.w800}) {
  final base = TextStyle(fontSize: size, color: color, fontWeight: weight, height: 1.15);
  try {
    return GoogleFonts.getFont('Baloo 2', textStyle: base);
  } catch (_) {
    return base;
  }
}

ThemeData buildTheme() {
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.leaf,
      primary: AppColors.leaf,
      surface: AppColors.paper,
    ),
    scaffoldBackgroundColor: AppColors.page,
  );
  TextTheme text;
  try {
    text = GoogleFonts.getTextTheme('Be Vietnam Pro', base.textTheme);
  } catch (_) {
    text = base.textTheme;
  }
  text = text.apply(bodyColor: AppColors.ink, displayColor: AppColors.ink);
  return base.copyWith(
    textTheme: text,
    appBarTheme: AppBarTheme(
      backgroundColor: AppColors.page,
      foregroundColor: AppColors.ink,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: display(22),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.paper,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.line, width: 2),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.line, width: 2),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.sea, width: 2),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: AppColors.paper,
      indicatorColor: AppColors.leafSoft,
      labelTextStyle: WidgetStatePropertyAll(
        TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: AppColors.ink),
      ),
    ),
    snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
  );
}
