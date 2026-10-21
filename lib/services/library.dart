import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';

import '../logic/bank_parser.dart';
import '../logic/subjects.dart';
import '../models/models.dart';
import 'repo.dart';

/// Bộ đề soạn sẵn của một lớp, một môn (ghép từ các file assets/bank/g{lớp}/{môn}_*.txt).
class LibrarySet {
  LibrarySet(this.grade, this.subject);
  final int grade;
  final Subject subject;
  final files = <String>[];
  final curriculumLines = <String>[];
  final questions = <BankQuestion>[];
  final errors = <String>[];

  Curriculum get curriculum => Curriculum(grade: grade, subject: subject, lines: curriculumLines);
}

/// Thư viện đề đóng gói sẵn trong app, nạp vào Firestore bằng một nút bấm.
class Library {
  static const _prefix = 'assets/bank/';

  Future<List<LibrarySet>> load() async {
    final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
    final paths = manifest.listAssets().where((p) => p.startsWith(_prefix) && p.endsWith('.txt')).toList()..sort();
    final sets = <String, LibrarySet>{};
    for (final path in paths) {
      final key = bankFileKey(path);
      if (key == null) continue;
      final subject = subjectFromId(key.$2);
      if (subject == null) continue;
      final set = sets.putIfAbsent('${key.$1}_${subject.id}', () => LibrarySet(key.$1, subject));
      final f = parseBank(path.split('/').last, await rootBundle.loadString(path));
      set.files.add(path);
      set.curriculumLines.addAll(f.curriculumLines);
      set.questions.addAll(f.questions);
      set.errors.addAll(f.errors);
    }
    final list = sets.values.toList()
      ..sort((a, b) => a.grade != b.grade ? a.grade.compareTo(b.grade) : a.subject.index.compareTo(b.subject.index));
    return list;
  }

  /// Nạp một bộ đề: ghi mục lục (giữ nguyên bài "đang học tới") và mọi câu hỏi.
  /// Câu đã có giữ nguyên trạng thái duyệt; câu mới là 'approved' nếu [approve], ngược lại 'pending'.
  Future<int> importSet(Repo repo, LibrarySet set, {required bool approve}) async {
    final db = repo.db;
    final old = await repo.curriculum(set.grade, set.subject);
    await repo.saveCurriculum(Curriculum(grade: set.grade, subject: set.subject, lines: set.curriculumLines, upTo: old.upTo));

    final order = {for (final l in set.curriculum.lessons) l.title: l.order};
    final existing = await db
        .collection('questions')
        .where('grade', isEqualTo: set.grade)
        .where('subject', isEqualTo: set.subject.id)
        .where('source', isEqualTo: 'lib')
        .get();
    final status = {for (final d in existing.docs) d.id: (d.data()['status'] ?? 'pending') as String};

    var written = 0;
    for (var i = 0; i < set.questions.length; i += 400) {
      final batch = db.batch();
      for (final b in set.questions.skip(i).take(400)) {
        final id = bankQuestionId(set.grade, set.subject.id, b.lessonTitle, b.indexInLesson);
        var st = status[id] ?? (approve ? 'approved' : 'pending');
        if (approve && st == 'pending') st = 'approved';
        final q = Question(
          grade: set.grade,
          subject: set.subject,
          lessonOrder: order[b.lessonTitle] ?? 0,
          lessonTitle: b.lessonTitle,
          level: b.level,
          text: b.text,
          passage: b.passage,
          options: b.options,
          answer: b.answer,
          explanation: b.explanation,
          status: st,
          source: 'lib',
        );
        batch.set(db.collection('questions').doc(id), {...q.toMap(), 'updatedAt': FieldValue.serverTimestamp()});
        written++;
      }
      await batch.commit();
    }
    return written;
  }
}
