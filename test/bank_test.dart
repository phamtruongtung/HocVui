import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hoc_vui/logic/bank_parser.dart';
import 'package:hoc_vui/logic/subjects.dart';

/// Kiểm tra toàn bộ thư viện đề trong assets/bank mỗi lần build.
void main() {
  final dir = Directory('assets/bank');
  final files = dir.existsSync()
      ? (dir.listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.txt')).toList()
        ..sort((a, b) => a.path.compareTo(b.path)))
      : <File>[];

  test('định dạng file thư viện hợp lệ', () {
    final errors = <String>[];
    final titles = <String, Set<String>>{};
    final counts = <String, int>{};
    for (final f in files) {
      final path = f.path.replaceAll('\\', '/');
      final key = bankFileKey(path);
      expect(key, isNotNull, reason: 'Tên file sai quy ước g{lớp}/{môn}_{số}.txt: $path');
      expect(subjectFromId(key!.$2), isNotNull, reason: 'Môn không hợp lệ trong $path');
      final b = parseBank(path, f.readAsStringSync());
      errors.addAll(b.errors);
      final setKey = '${key.$1}_${key.$2}';
      final seen = titles.putIfAbsent(setKey, () => <String>{});
      for (final l in b.lessons) {
        if (!seen.add(l)) errors.add('$path: tên bài bị trùng "$l"');
      }
      for (final l in b.lessons) {
        final n = b.questions.where((q) => q.lessonTitle == l).length;
        if (n < 4) errors.add('$path: bài "$l" mới có $n câu (cần ít nhất 4)');
      }
      counts[setKey] = (counts[setKey] ?? 0) + b.questions.length;
    }
    // In ra số câu mỗi bộ để xem trong log của GitHub Actions.
    final summary = counts.entries.map((e) => '${e.key}: ${e.value}').join(', ');
    // ignore: avoid_print
    print('Thư viện đề: ${counts.values.fold(0, (a, b) => a + b)} câu ($summary)');
    expect(errors, isEmpty, reason: errors.take(30).join('\n'));
  });

  test('parser đọc đúng định dạng mẫu', () {
    final b = parseBank('mau.txt', '''
#! HK1
# Chương I. Số hữu tỉ
## Bài 1. Tập hợp các số hữu tỉ
?1 Số nào là số hữu tỉ âm?
- 0
+ −3/4
- 5/2
- 1
= Số hữu tỉ âm là số hữu tỉ nhỏ hơn 0.
> Đoạn văn mẫu
> dòng hai
?2 Câu có ngữ liệu
+ a
- b
- c
- d
= vì a
''');
    expect(b.errors, isEmpty);
    expect(b.questions.length, 2);
    expect(b.questions[0].answer, 1);
    expect(b.questions[0].passage, '');
    expect(b.questions[1].passage, 'Đoạn văn mẫu\ndòng hai');
    expect(b.curriculumLines, ['#! HK1', '# Chương I. Số hữu tỉ', 'Bài 1. Tập hợp các số hữu tỉ']);
  });
}
