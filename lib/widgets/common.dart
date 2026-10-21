import 'dart:math';

import 'package:flutter/material.dart';

import '../logic/subjects.dart';
import '../theme.dart';

/// "8,7"
String fmtScore(double v) => v.toStringAsFixed(1).replaceAll('.', ',');

/// "1.240"
String fmtInt(int v) {
  final s = v.abs().toString();
  final buf = StringBuffer(v < 0 ? '-' : '');
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) buf.write('.');
    buf.write(s[i]);
  }
  return buf.toString();
}

void showSnack(BuildContext context, String message, {bool error = false}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: error ? AppColors.bad : AppColors.ink,
    ));
}

Future<bool> confirm(BuildContext context, String title, String message,
    {String ok = 'Đồng ý', String cancel = 'Hủy'}) async {
  final r = await showDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      title: Text(title, style: display(20)),
      content: Text(message),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c, false), child: Text(cancel)),
        FilledButton(onPressed: () => Navigator.pop(c, true), child: Text(ok)),
      ],
    ),
  );
  return r == true;
}

/// Gà Chíp – linh vật của Học Vui.
class Mascot extends StatelessWidget {
  const Mascot({super.key, this.size = 96, this.cap = true});
  final double size;
  final bool cap;

  @override
  Widget build(BuildContext context) =>
      CustomPaint(size: Size.square(size), painter: _ChickPainter(cap));
}

class _ChickPainter extends CustomPainter {
  _ChickPainter(this.cap);
  final bool cap;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 100;
    Paint p(Color c) => Paint()..color = c;
    canvas.drawCircle(Offset(50 * s, 56 * s), 34 * s, p(const Color(0xFFFFC93C)));
    final tuft = Path()
      ..moveTo(44 * s, 22 * s)
      ..quadraticBezierTo(50 * s, 8 * s, 56 * s, 22 * s)
      ..close();
    canvas.drawPath(tuft, p(const Color(0xFFFFC93C)));
    canvas.drawCircle(Offset(38 * s, 50 * s), 7 * s, p(AppColors.ink));
    canvas.drawCircle(Offset(62 * s, 50 * s), 7 * s, p(AppColors.ink));
    canvas.drawCircle(Offset(40 * s, 48 * s), 2.4 * s, p(Colors.white));
    canvas.drawCircle(Offset(64 * s, 48 * s), 2.4 * s, p(Colors.white));
    final beak = Path()
      ..moveTo(44 * s, 62 * s)
      ..lineTo(56 * s, 62 * s)
      ..lineTo(50 * s, 71 * s)
      ..close();
    canvas.drawPath(beak, p(const Color(0xFFFF7A3D)));
    final blush = p(const Color(0x99FF9A86));
    canvas.drawCircle(Offset(27 * s, 64 * s), 5 * s, blush);
    canvas.drawCircle(Offset(73 * s, 64 * s), 5 * s, blush);
    if (cap) {
      canvas.drawRRect(
          RRect.fromRectAndRadius(Rect.fromLTWH(30 * s, 28 * s, 40 * s, 10 * s), Radius.circular(3 * s)),
          p(AppColors.leaf));
      canvas.drawRect(Rect.fromLTWH(46 * s, 20 * s, 8 * s, 10 * s), p(AppColors.leaf));
    }
  }

  @override
  bool shouldRepaint(covariant _ChickPainter old) => old.cap != cap;
}

class CoinDot extends StatelessWidget {
  const CoinDot({super.key, this.size = 15});
  final double size;
  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: AppColors.sun,
          shape: BoxShape.circle,
          border: Border.all(color: const Color(0xFFD99400), width: size / 10),
        ),
      );
}

class FlameDot extends StatelessWidget {
  const FlameDot({super.key, this.size = 15});
  final double size;
  @override
  Widget build(BuildContext context) =>
      Icon(Icons.local_fire_department_rounded, size: size + 3, color: AppColors.flame);
}

class Pill extends StatelessWidget {
  const Pill(this.text, {super.key, this.bg = AppColors.page, this.fg = AppColors.ink, this.leading, this.size = 13});
  final String text;
  final Color bg;
  final Color fg;
  final Widget? leading;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(99)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (leading != null) ...[leading!, const SizedBox(width: 5)],
          Text(text,
              style: TextStyle(
                  color: fg,
                  fontWeight: FontWeight.w700,
                  fontSize: size,
                  fontFeatures: const [FontFeature.tabularFigures()])),
        ]),
      );
}

class CoinPill extends StatelessWidget {
  const CoinPill(this.coins, {super.key, this.prefix = ''});
  final int coins;
  final String prefix;
  @override
  Widget build(BuildContext context) => Pill('$prefix${fmtInt(coins)}',
      bg: AppColors.sunSoft, fg: AppColors.sunInk, leading: const CoinDot(size: 14));
}

class SubjectBadge extends StatelessWidget {
  const SubjectBadge(this.subject, {super.key, this.size = 42});
  final Subject subject;
  final double size;
  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: subjectColor(subject), borderRadius: BorderRadius.circular(size * 0.32)),
        child: Text(subject.short,
            textAlign: TextAlign.center,
            style: display(size * (subject.short.length > 4 ? 0.24 : 0.3), color: Colors.white)),
      );
}

class Avatar extends StatelessWidget {
  const Avatar(this.initials, {super.key, this.color = AppColors.sea, this.size = 38});
  final String initials;
  final Color color;
  final double size;
  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        child: Text(initials, style: display(size * 0.36, color: Colors.white)),
      );
}

Color avatarColor(String seed) {
  const colors = [AppColors.sea, AppColors.rose, AppColors.plum, AppColors.leaf, AppColors.flame];
  return colors[seed.codeUnits.fold(0, (a, b) => a + b) % colors.length];
}

/// Nút to kiểu game, có bóng đổ phía dưới.
class BigButton extends StatelessWidget {
  const BigButton(this.label,
      {super.key, required this.onPressed, this.color = AppColors.leaf, this.shadow = AppColors.leafDark, this.loading = false, this.ghost = false, this.icon});
  final String label;
  final VoidCallback? onPressed;
  final Color color;
  final Color shadow;
  final bool loading;
  final bool ghost;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !loading;
    final bg = ghost ? AppColors.paper : (enabled ? color : AppColors.line);
    final fg = ghost ? AppColors.sea : (enabled ? Colors.white : AppColors.muted);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: enabled ? onPressed : null,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          height: 52,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(16),
            border: ghost ? Border.all(color: AppColors.line, width: 2) : null,
            boxShadow: [
              BoxShadow(color: ghost ? AppColors.line : (enabled ? shadow : AppColors.line), offset: const Offset(0, 4)),
            ],
          ),
          child: loading
              ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 3, color: Colors.white))
              : Row(mainAxisSize: MainAxisSize.min, children: [
                  if (icon != null) ...[Icon(icon, color: fg, size: 20), const SizedBox(width: 6)],
                  Flexible(child: Text(label, textAlign: TextAlign.center, style: display(18, color: fg))),
                ]),
        ),
      ),
    );
  }
}

class AppCard extends StatelessWidget {
  const AppCard({super.key, required this.child, this.color = AppColors.paper, this.border = AppColors.line, this.padding = const EdgeInsets.all(14), this.onTap});
  final Widget child;
  final Color color;
  final Color border;
  final EdgeInsets padding;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final box = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: border, width: 2),
      ),
      child: child,
    );
    if (onTap == null) return box;
    return Material(
      color: Colors.transparent,
      child: InkWell(borderRadius: BorderRadius.circular(18), onTap: onTap, child: box),
    );
  }
}

class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key, this.trailing});
  final String text;
  final Widget? trailing;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 6, bottom: 2),
        child: Row(children: [
          Expanded(
            child: Text(text.toUpperCase(),
                style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, letterSpacing: 0.8, color: AppColors.muted)),
          ),
          if (trailing != null) trailing!,
        ]),
      );
}

class Bar extends StatelessWidget {
  const Bar(this.value, {super.key, this.color = AppColors.leaf, this.height = 10});
  final double value;
  final Color color;
  final double height;
  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(99),
        child: LinearProgressIndicator(
          value: value.isNaN ? 0 : max(0, min(1, value)),
          minHeight: height,
          color: color,
          backgroundColor: AppColors.line,
        ),
      );
}

class Loading extends StatelessWidget {
  const Loading({super.key, this.text});
  final String? text;
  @override
  Widget build(BuildContext context) => Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Mascot(size: 72),
          const SizedBox(height: 12),
          const SizedBox(width: 28, height: 28, child: CircularProgressIndicator(strokeWidth: 3)),
          if (text != null) ...[const SizedBox(height: 10), Text(text!, style: const TextStyle(color: AppColors.muted))],
        ]),
      );
}

class ErrorView extends StatelessWidget {
  const ErrorView(this.message, {super.key, this.onRetry});
  final String message;
  final VoidCallback? onRetry;
  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Mascot(size: 72, cap: false),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.badInk)),
            if (onRetry != null) ...[
              const SizedBox(height: 14),
              SizedBox(width: 180, child: BigButton('Thử lại', onPressed: onRetry)),
            ],
          ]),
        ),
      );
}

class EmptyView extends StatelessWidget {
  const EmptyView(this.message, {super.key});
  final String message;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
        child: Column(children: [
          const Mascot(size: 64),
          const SizedBox(height: 10),
          Text(message, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.muted)),
        ]),
      );
}

/// Khung nội dung giữa màn hình, rộng tối đa [maxWidth] (đẹp trên bản web).
class AppPage extends StatelessWidget {
  const AppPage({super.key, required this.children, this.maxWidth = 560, this.padding = const EdgeInsets.fromLTRB(16, 8, 16, 24)});
  final List<Widget> children;
  final double maxWidth;
  final EdgeInsets padding;
  @override
  Widget build(BuildContext context) => Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: ListView(
            padding: padding,
            children: [
              for (var i = 0; i < children.length; i++) ...[
                if (i > 0) const SizedBox(height: 12),
                children[i],
              ],
            ],
          ),
        ),
      );
}

/// Ô góp ý mức độ khó (chấm màu + tên).
class LevelChip extends StatelessWidget {
  const LevelChip(this.level, {super.key});
  final int level;
  @override
  Widget build(BuildContext context) => Pill(levelName(level),
      bg: levelColor(level).withValues(alpha: 0.3), fg: AppColors.ink, size: 11.5);
}
