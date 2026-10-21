import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hoc_vui/version.dart';

void main() {
  test('kAppVersion matches the version in pubspec.yaml', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final m = RegExp(r'^version:\s*([0-9.]+)\+(\d+)', multiLine: true).firstMatch(pubspec);
    expect(m, isNotNull, reason: 'pubspec.yaml must have "version: x.y.z+n"');
    expect(m!.group(1), kAppVersion, reason: 'Update kAppVersion in lib/version.dart to match pubspec.yaml');
  });
}
