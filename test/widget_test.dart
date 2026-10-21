import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoc_vui/widgets/common.dart';

void main() {
  // Chỉ thử các widget không dùng phông Google (test không có mạng để tải phông).
  testWidgets('Gà Chíp và nhãn hiển thị được', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: Column(children: [
          Mascot(size: 80),
          Pill('12'),
        ]),
      ),
    ));
    expect(find.byType(Mascot), findsOneWidget);
    expect(find.text('12'), findsOneWidget);
  });

  test('fmtInt và fmtScore', () {
    expect(fmtInt(1240), '1.240');
    expect(fmtInt(1500000), '1.500.000');
    expect(fmtInt(80), '80');
    expect(fmtScore(8.7), '8,7');
  });
}
