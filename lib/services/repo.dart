import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

import '../logic/dates.dart';
import '../logic/exam_builder.dart';
import '../logic/rules.dart';
import '../logic/subjects.dart';
import '../models/models.dart';

/// Lỗi có câu báo bằng tiếng Việt để hiện cho người dùng.
class AppError implements Exception {
  const AppError(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Dữ liệu trang chủ của học sinh.
class HomeData {
  HomeData({required this.profile, required this.plan, required this.exams, required this.notes});
  final Profile profile;
  final DayPlan plan;
  final List<Exam> exams;
  final List<String> notes;
}

/// Kết quả sau khi nộp một đề.
class ExamOutcome {
  ExamOutcome({
    required this.exam,
    required this.correct,
    required this.total,
    required this.score,
    required this.coins,
    required this.correctByLevel,
    required this.totalByLevel,
    required this.milestoneCoins,
    required this.dayComplete,
    required this.earlyBonus,
    required this.streak,
    required this.seconds,
  });

  final Exam exam;
  final int correct;
  final int total;
  final double score;
  final int coins;
  final List<int> correctByLevel;
  final List<int> totalByLevel;
  final int milestoneCoins;
  final bool dayComplete;
  final bool earlyBonus;
  final int streak;
  final int seconds;
}

/// Toàn bộ thao tác với Firebase (đăng nhập và Firestore).
///
/// Firestore:
///   users/{uid}                          hồ sơ, xu, chuỗi, chuyên cần
///   users/{uid}/days/{yyyy-MM-dd}        2 đề của ngày, số đề đã xong
///   users/{uid}/exams/{day_subject}      câu hỏi, đáp án đã chọn, điểm
///   users/{uid}/mistakes/{questionId}    sổ tay lỗi sai
///   parentCodes/{PH-1234}                uid, name của phụ huynh
///   linkRequests/{kidUid_parentUid}      liên kết con – phụ huynh
///   curriculum/{grade_subject}           mục lục SGK, bài đang học tới
///   questions/{id}                       ngân hàng câu hỏi
///   leaderboard/{week}/scores/{uid}      điểm thi đua tuần
///   rewards/{id}, redemptions/{id}       phần thưởng thật, yêu cầu đổi
///   notifications/{id}                   thông báo cho phụ huynh
class Repo {
  static const emailDomain = 'hocvui.app';

  FirebaseFirestore get db => FirebaseFirestore.instance;
  FirebaseAuth get auth => FirebaseAuth.instance;

  CollectionReference<Map<String, dynamic>> get _users => db.collection('users');
  CollectionReference<Map<String, dynamic>> _sub(String uid, String name) =>
      _users.doc(uid).collection(name);

  static String emailFor(String username) => '${username.trim().toLowerCase()}@$emailDomain';

  static final usernamePattern = RegExp(r'^[a-z0-9._]{3,24}$');

  // ======================= Đăng nhập =======================

  Future<Profile> signIn(String username, String password) async {
    final u = username.trim().toLowerCase();
    if (u.isEmpty || password.isEmpty) throw const AppError('Hãy nhập tên đăng nhập và mật khẩu.');
    try {
      await auth.signInWithEmailAndPassword(email: emailFor(u), password: password);
    } on FirebaseAuthException catch (e) {
      throw AppError(_authMessage(e));
    }
    final p = await currentProfile();
    if (p == null) {
      await auth.signOut();
      throw const AppError('Tài khoản chưa có hồ sơ. Hãy báo quản trị viên.');
    }
    if (!p.active) {
      await auth.signOut();
      throw const AppError('Tài khoản đang bị khóa. Hãy báo quản trị viên.');
    }
    return p;
  }

  Future<Profile?> currentProfile() async {
    final user = auth.currentUser;
    if (user == null) return null;
    final doc = await _users.doc(user.uid).get();
    if (!doc.exists) return null;
    return Profile.fromDoc(doc);
  }

  Future<Profile> profile(String uid) async => Profile.fromDoc(await _users.doc(uid).get());

  Stream<Profile> watchProfile(String uid) => _users.doc(uid).snapshots().map(Profile.fromDoc);

  Future<void> signOut() => auth.signOut();

  Future<void> changePassword(String oldPassword, String newPassword) async {
    final user = auth.currentUser;
    if (user == null || user.email == null) throw const AppError('Bạn chưa đăng nhập.');
    if (newPassword.length < 6) throw const AppError('Mật khẩu mới cần ít nhất 6 ký tự.');
    try {
      await user.reauthenticateWithCredential(
          EmailAuthProvider.credential(email: user.email!, password: oldPassword));
      await user.updatePassword(newPassword);
    } on FirebaseAuthException catch (e) {
      throw AppError(_authMessage(e));
    }
  }

  String _authMessage(FirebaseAuthException e) => switch (e.code) {
        'invalid-credential' || 'wrong-password' || 'user-not-found' || 'invalid-email' =>
          'Sai tên đăng nhập hoặc mật khẩu.',
        'user-disabled' => 'Tài khoản đang bị khóa. Hãy báo quản trị viên.',
        'too-many-requests' => 'Thử sai quá nhiều lần. Hãy đợi vài phút rồi thử lại.',
        'network-request-failed' => 'Không có mạng. Hãy kiểm tra kết nối rồi thử lại.',
        'email-already-in-use' => 'Tên đăng nhập này đã có người dùng.',
        'weak-password' => 'Mật khẩu cần ít nhất 6 ký tự.',
        'requires-recent-login' => 'Hãy đăng xuất rồi đăng nhập lại trước khi đổi mật khẩu.',
        _ => 'Lỗi đăng nhập (${e.code}). Hãy thử lại.',
      };

  // ======================= Quản trị: tài khoản =======================

  Stream<List<Profile>> watchAllUsers() => _users.snapshots().map((s) {
        final list = s.docs.map(Profile.fromDoc).toList();
        list.sort((a, b) {
          final r = a.role.index.compareTo(b.role.index);
          return r != 0 ? r : a.username.compareTo(b.username);
        });
        return list;
      });

  /// Tạo tài khoản mới mà không đăng xuất quản trị viên: dùng một bản
  /// Firebase App phụ để gọi createUser.
  Future<void> createAccount({
    required Role role,
    required String username,
    required String displayName,
    required String password,
    int grade = 0,
  }) async {
    final u = username.trim().toLowerCase();
    if (!usernamePattern.hasMatch(u)) {
      throw const AppError('Tên đăng nhập 3–24 ký tự, chỉ gồm chữ thường không dấu, số, dấu chấm, gạch dưới.');
    }
    if (displayName.trim().isEmpty) throw const AppError('Hãy nhập họ tên.');
    if (password.length < 6) throw const AppError('Mật khẩu cần ít nhất 6 ký tự.');
    if (role == Role.student && !grades.contains(grade)) throw const AppError('Hãy chọn lớp 6, 7, 8 hoặc 9.');

    FirebaseApp helper;
    try {
      helper = Firebase.app('account-creator');
    } catch (_) {
      helper = await Firebase.initializeApp(name: 'account-creator', options: Firebase.app().options);
    }
    final helperAuth = FirebaseAuth.instanceFor(app: helper);
    late String uid;
    try {
      final cred = await helperAuth.createUserWithEmailAndPassword(email: emailFor(u), password: password);
      uid = cred.user!.uid;
    } on FirebaseAuthException catch (e) {
      throw AppError(_authMessage(e));
    } finally {
      await helperAuth.signOut();
    }

    final today = dayKey(DateTime.now());
    final data = <String, Object?>{
      'role': role.name,
      'username': u,
      'displayName': displayName.trim(),
      'active': true,
      'createdAt': FieldValue.serverTimestamp(),
    };
    if (role == Role.student) {
      data.addAll({
        'grade': grade,
        'coins': 0,
        'streak': 0,
        'bestStreak': 0,
        'attendance': attendanceStart,
        'shields': 0,
        'lastClosedDay': today, // ngày tạo tài khoản không bị tính chuyên cần
        'parents': <String>[],
      });
    }
    final batch = db.batch();
    if (role == Role.parent) {
      final code = await _newParentCode();
      data['parentCode'] = code;
      batch.set(db.collection('parentCodes').doc(code), {'uid': uid, 'name': displayName.trim()});
    }
    batch.set(_users.doc(uid), data);
    await batch.commit();
  }

  Future<String> _newParentCode() async {
    final r = Random();
    for (var i = 0; i < 20; i++) {
      final code = 'PH-${1000 + r.nextInt(9000)}';
      final doc = await db.collection('parentCodes').doc(code).get();
      if (!doc.exists) return code;
    }
    throw const AppError('Không tạo được mã phụ huynh, hãy thử lại.');
  }

  Future<void> updateUser(String uid, Map<String, Object?> data) => _users.doc(uid).update(data);

  // ======================= Mục lục và ngân hàng câu hỏi =======================

  Future<Curriculum> curriculum(int grade, Subject subject) async {
    final doc = await db.collection('curriculum').doc('${grade}_${subject.id}').get();
    return Curriculum.fromDoc(grade, subject, doc);
  }

  Future<void> saveCurriculum(Curriculum c) => db.collection('curriculum').doc(c.docId).set({
        'grade': c.grade,
        'subject': c.subject.id,
        'lines': c.lines,
        'upTo': c.upTo,
        'updatedAt': FieldValue.serverTimestamp(),
      });

  Stream<List<Question>> watchQuestions(int grade, Subject subject, String status) => db
      .collection('questions')
      .where('grade', isEqualTo: grade)
      .where('subject', isEqualTo: subject.id)
      .where('status', isEqualTo: status)
      .snapshots()
      .map((s) {
        final list = s.docs.map(Question.fromDoc).toList();
        list.sort((a, b) {
          final c = a.lessonOrder.compareTo(b.lessonOrder);
          return c != 0 ? c : a.level.compareTo(b.level);
        });
        return list;
      });

  Future<List<Question>> approvedQuestions(int grade, Subject subject) async {
    final s = await db
        .collection('questions')
        .where('grade', isEqualTo: grade)
        .where('subject', isEqualTo: subject.id)
        .where('status', isEqualTo: 'approved')
        .get();
    return s.docs.map(Question.fromDoc).toList();
  }

  Future<void> addQuestions(List<Question> qs) async {
    for (var i = 0; i < qs.length; i += 400) {
      final batch = db.batch();
      for (final q in qs.skip(i).take(400)) {
        batch.set(db.collection('questions').doc(), {
          ...q.toMap(),
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
      await batch.commit();
    }
  }

  Future<void> updateQuestion(String id, Map<String, Object?> data) =>
      db.collection('questions').doc(id).update({...data, 'updatedAt': FieldValue.serverTimestamp()});

  Future<void> setQuestionsStatus(Iterable<String> ids, String status) async {
    final list = ids.toList();
    for (var i = 0; i < list.length; i += 400) {
      final batch = db.batch();
      for (final id in list.skip(i).take(400)) {
        batch.update(db.collection('questions').doc(id), {'status': status});
      }
      await batch.commit();
    }
  }

  Future<void> deleteQuestion(String id) => db.collection('questions').doc(id).delete();

  // ======================= Học sinh: trang chủ =======================

  /// Chốt các ngày đã qua, nhận thưởng tuần, hoàn xu bị từ chối, cập nhật
  /// liên kết phụ huynh, rồi tạo (hoặc đọc) 2 đề của hôm nay.
  Future<HomeData> loadStudentHome(String uid) async {
    final now = DateTime.now();
    final today = dayKey(now);
    var p = await profile(uid);
    var stats = p.stats;
    final notes = <String>[];
    final updates = <String, Object?>{};

    // 1. Chốt ngày.
    if (daysBetween(p.lastClosedDay, addDays(today, -1)) > 0) {
      final snap = await _sub(uid, 'days')
          .where(FieldPath.documentId, isGreaterThan: p.lastClosedDay)
          .where(FieldPath.documentId, isLessThan: today)
          .get();
      final history = <String, PastDay>{};
      for (final d in snap.docs) {
        final plan = DayPlan.fromDoc(d);
        history[d.id] = PastDay(d.id, required: plan.required, done: plan.done);
      }
      final r = closeDays(stats, today, history);
      stats = r.stats;
      notes.addAll(r.notes.map((n) => n.text));
    }

    // 2. Thưởng xếp hạng tuần trước.
    final prevWeek = prevWeekKey(now);
    if (p.prizeClaimedWeek != prevWeek) {
      final s = await db
          .collection('leaderboard')
          .doc(prevWeek)
          .collection('scores')
          .orderBy('points', descending: true)
          .limit(10)
          .get();
      final rows = sortRanking(s.docs.map((d) => LeaderRow.fromDoc(d).rank));
      final prize = weeklyPrizeFor(uid, rows);
      if (prize > 0) {
        stats = stats.copyWith(coins: stats.coins + prize);
        final place = rows.indexWhere((r) => r.uid == uid) + 1;
        notes.add('Bạn đứng hạng $place tuần trước, được thưởng $prize xu!');
      }
      updates['prizeClaimedWeek'] = prevWeek;
    }

    // 3. Hoàn xu cho yêu cầu đổi thưởng bị từ chối.
    final reds = await db.collection('redemptions').where('kidUid', isEqualTo: uid).get();
    final refundBatch = db.batch();
    var refunds = 0;
    for (final d in reds.docs) {
      final r = Redemption.fromDoc(d);
      if (r.status == 'rejected' && !r.refunded) {
        stats = stats.copyWith(coins: stats.coins + r.cost);
        refundBatch.update(d.reference, {'refunded': true});
        notes.add('Bố mẹ chưa đồng ý đổi "${r.name}", đã hoàn ${r.cost} xu.');
        refunds++;
      }
    }

    // 4. Danh sách phụ huynh đã đồng ý liên kết.
    final links = await db.collection('linkRequests').where('kidUid', isEqualTo: uid).get();
    final parents = links.docs
        .map(LinkRequest.fromDoc)
        .where((l) => l.status == 'accepted')
        .map((l) => l.parentUid)
        .toList()
      ..sort();
    final oldParents = [...p.parents]..sort();
    if (parents.join(',') != oldParents.join(',')) updates['parents'] = parents;

    updates.addAll(Profile.statsToMap(stats));
    await _users.doc(uid).update(updates);
    if (refunds > 0) await refundBatch.commit();
    p = await profile(uid);

    // 5. Đề hôm nay.
    final dayRef = _sub(uid, 'days').doc(today);
    var dayDoc = await dayRef.get();
    if (!dayDoc.exists) {
      await _createDayPlan(p, today);
      dayDoc = await dayRef.get();
    }
    final plan = DayPlan.fromDoc(dayDoc);
    final exams = <Exam>[];
    for (final id in plan.examIds) {
      final e = await _sub(uid, 'exams').doc(id).get();
      if (e.exists) exams.add(Exam.fromDoc(e));
    }
    return HomeData(profile: p, plan: plan, exams: exams, notes: notes);
  }

  Future<void> _createDayPlan(Profile p, String today) async {
    final primary = subjectsForDay(today);
    final order = [...primary, ...fallbackOrder(today)];
    final chosen = <(Subject, List<Question>)>[];
    final skipped = <Subject>[];
    for (final s in order) {
      if (chosen.length >= examsPerDay) break;
      if (chosen.any((c) => c.$1 == s)) continue;
      final pool = await approvedQuestions(p.grade, s);
      final cur = await curriculum(p.grade, s);
      final recent = await _recentQuestionIds(p.uid, s);
      final rng = Random();
      final qs = buildExam(
        pool: pool,
        levelCounts: s.blueprint,
        recentIds: recent,
        upTo: cur.lessons.isEmpty ? 0 : cur.effectiveUpTo(DateTime.now()),
        rng: rng,
      ).map((q) => shuffleOptions(q, rng)).toList();
      if (qs.length >= minQuestionsPerExam) {
        chosen.add((s, qs));
      } else if (primary.contains(s)) {
        skipped.add(s);
      }
    }

    final batch = db.batch();
    final ids = <String>[];
    for (final (s, qs) in chosen) {
      final id = '${today}_${s.id}';
      ids.add(id);
      batch.set(_sub(p.uid, 'exams').doc(id), {
        'day': today,
        'subject': s.id,
        'grade': p.grade,
        'title': examTitle(qs),
        'questions': qs.map((q) => q.snapshot()).toList(),
        'answers': List.filled(qs.length, -1),
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
    var note = '';
    if (skipped.isNotEmpty) {
      note = 'Môn ${skipped.map((s) => s.label).join(', ')} chưa có đủ câu hỏi nên được đổi sang môn khác.';
    }
    if (chosen.isEmpty) note = 'Hôm nay chưa có câu hỏi nào được duyệt cho lớp ${p.grade}, nên không tính chuyên cần.';
    batch.set(_sub(p.uid, 'days').doc(today), {
      'examIds': ids,
      'subjects': chosen.map((c) => c.$1.id).toList(),
      'required': chosen.length,
      'done': 0,
      'note': note,
      'createdAt': FieldValue.serverTimestamp(),
    });
    await batch.commit();
  }

  /// Câu hỏi trong 4 đề gần nhất của môn này, để tránh lặp lại.
  Future<Set<String>> _recentQuestionIds(String uid, Subject s) async {
    final snap = await _sub(uid, 'exams').where('subject', isEqualTo: s.id).get();
    final exams = snap.docs.map(Exam.fromDoc).toList()..sort((a, b) => b.day.compareTo(a.day));
    return exams.take(4).expand((e) => e.questions.map((q) => q.id)).toSet();
  }

  // ======================= Học sinh: làm bài =======================

  Future<Exam> exam(String uid, String examId) async => Exam.fromDoc(await _sub(uid, 'exams').doc(examId).get());

  Future<Exam> startExam(String uid, Exam e) async {
    if (e.started) return e;
    await _sub(uid, 'exams').doc(e.id).update({'startedAt': Timestamp.fromDate(DateTime.now())});
    return exam(uid, e.id);
  }

  Future<void> saveAnswers(String uid, String examId, List<int> answers) =>
      _sub(uid, 'exams').doc(examId).update({'answers': answers});

  Future<ExamOutcome> submitExam(String uid, Exam e, List<int> answers) async {
    final fresh = await exam(uid, e.id);
    if (fresh.submitted) throw const AppError('Đề này đã nộp rồi.');
    final now = DateTime.now();
    final today = dayKey(now);
    final total = e.questions.length;
    final correctByLevel = [0, 0, 0, 0];
    final totalByLevel = [0, 0, 0, 0];
    final wrong = <int>[];
    for (var i = 0; i < total; i++) {
      final q = e.questions[i];
      totalByLevel[q.level - 1]++;
      if (i < answers.length && answers[i] == q.answer) {
        correctByLevel[q.level - 1]++;
      } else {
        wrong.add(i);
      }
    }
    final correct = correctByLevel.fold(0, (a, b) => a + b);
    final score = score10(correct, total);
    final coins = examCoins(correctByLevel, score);
    final started = fresh.startedAt ?? now;
    var seconds = now.difference(started).inSeconds;
    if (seconds > examMinutes * 60) seconds = examMinutes * 60;
    if (seconds < 0) seconds = 0;

    final dayRef = _sub(uid, 'days').doc(e.day);
    final plan = DayPlan.fromDoc(await dayRef.get());
    final done = plan.done + 1;
    final dayComplete = done >= plan.required;

    final p = await profile(uid);
    var stats = p.stats.copyWith(coins: p.coins + coins);
    var milestone = 0;
    if (dayComplete) {
      final r = completeToday(stats, e.day);
      stats = r.stats;
      milestone = r.milestoneCoins;
    }
    final early = dayComplete && e.day == today && now.hour < earlyBonusHour;

    final batch = db.batch();
    batch.update(_sub(uid, 'exams').doc(e.id), {
      'answers': answers,
      'submittedAt': Timestamp.fromDate(now),
      'correct': correct,
      'score': score,
      'coins': coins,
      'correctByLevel': correctByLevel,
      'seconds': seconds,
    });
    batch.update(dayRef, {
      'done': FieldValue.increment(1),
      if (dayComplete) 'completedAt': Timestamp.fromDate(now),
    });
    batch.update(_users.doc(uid), Profile.statsToMap(stats));
    batch.set(
      db.collection('leaderboard').doc(weekKey(parseDay(e.day))).collection('scores').doc(uid),
      {
        'name': p.shortName,
        'grade': p.grade,
        'points': FieldValue.increment(score + (early ? earlyBonusPoints : 0)),
        'seconds': FieldValue.increment(seconds),
        'exams': FieldValue.increment(1),
      },
      SetOptions(merge: true),
    );

    final wrongByLesson = <String, int>{};
    for (final i in wrong) {
      final q = e.questions[i];
      final id = q.id.isNotEmpty ? q.id : '${e.id}_$i';
      batch.set(_sub(uid, 'mistakes').doc(id), {
        'subject': e.subject.id,
        'grade': e.grade,
        'question': q.snapshot(),
        'chosen': i < answers.length ? answers[i] : -1,
        'stage': 0,
        'nextDue': addDays(today, mistakeIntervals[0]),
        'mastered': false,
        'wrongAt': Timestamp.fromDate(now),
      });
      final key = q.lessonTitle.isEmpty ? e.subject.label : q.lessonTitle;
      wrongByLesson[key] = (wrongByLesson[key] ?? 0) + 1;
    }

    for (final parent in p.parents) {
      if (wrong.isNotEmpty) {
        _addNotice(batch, parent, uid, 'mistakes', '${p.shortName} sai ${wrong.length} câu ${e.subject.label}',
            wrongByLesson.entries.map((x) => '${x.key} (${x.value})').join(', '));
      }
      if (dayComplete) {
        _addNotice(batch, parent, uid, 'done', '${p.shortName} đã xong bài hôm nay',
            '${e.subject.label}: ${_fmt(score)} điểm. Chuỗi ${stats.streak} ngày.');
      }
    }
    await batch.commit();

    return ExamOutcome(
      exam: e,
      correct: correct,
      total: total,
      score: score,
      coins: coins,
      correctByLevel: correctByLevel,
      totalByLevel: totalByLevel,
      milestoneCoins: milestone,
      dayComplete: dayComplete,
      earlyBonus: early,
      streak: stats.streak,
      seconds: seconds,
    );
  }

  static String _fmt(double v) => v.toStringAsFixed(1).replaceAll('.', ',');

  void _addNotice(WriteBatch batch, String toUid, String fromUid, String kind, String title, String body) {
    batch.set(db.collection('notifications').doc(), {
      'toUid': toUid,
      'fromUid': fromUid,
      'kind': kind,
      'title': title,
      'body': body,
      'read': false,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  // ======================= Sổ tay lỗi sai =======================

  Stream<List<Mistake>> watchMistakes(String uid) => _sub(uid, 'mistakes')
      .where('mastered', isEqualTo: false)
      .snapshots()
      .map((s) => s.docs.map(Mistake.fromDoc).toList()
        ..sort((a, b) => (b.wrongAt ?? DateTime(2000)).compareTo(a.wrongAt ?? DateTime(2000))));

  Future<void> answerMistake(String uid, Mistake m, bool correct) async {
    final r = reviewMistake(m.stage, correct, dayKey(DateTime.now()));
    final batch = db.batch();
    batch.update(_sub(uid, 'mistakes').doc(m.id), {
      'stage': r.stage,
      'nextDue': r.nextDue,
      'mastered': r.mastered,
    });
    if (correct) batch.update(_users.doc(uid), {'coins': FieldValue.increment(coinsMistakeFixed)});
    await batch.commit();
  }

  // ======================= Xếp hạng =======================

  Stream<List<LeaderRow>> watchLeaderboard(String week) => db
      .collection('leaderboard')
      .doc(week)
      .collection('scores')
      .orderBy('points', descending: true)
      .limit(50)
      .snapshots()
      .map((s) {
        final rows = s.docs.map(LeaderRow.fromDoc).toList();
        rows.sort((a, b) {
          final c = b.points.compareTo(a.points);
          return c != 0 ? c : a.seconds.compareTo(b.seconds);
        });
        return rows;
      });

  // ======================= Cửa hàng =======================

  Stream<List<Reward>> watchRewardsForKid(String uid) => db
      .collection('rewards')
      .where('kidUids', arrayContains: uid)
      .snapshots()
      .map((s) => s.docs.map(Reward.fromDoc).where((r) => r.active).toList()
        ..sort((a, b) => a.cost.compareTo(b.cost)));

  Stream<List<Redemption>> watchKidRedemptions(String uid) => db
      .collection('redemptions')
      .where('kidUid', isEqualTo: uid)
      .snapshots()
      .map((s) => s.docs.map(Redemption.fromDoc).toList()
        ..sort((a, b) => (b.createdAt ?? DateTime(2100)).compareTo(a.createdAt ?? DateTime(2100))));

  Future<void> redeem(Profile kid, Reward reward) async {
    final p = await profile(kid.uid);
    if (p.coins < reward.cost) throw AppError('Chưa đủ xu: cần ${reward.cost}, bạn có ${p.coins}.');
    final week = weekKey(DateTime.now());
    final same = await db.collection('redemptions').where('kidUid', isEqualTo: kid.uid).get();
    final used = same.docs
        .map(Redemption.fromDoc)
        .where((r) => r.rewardId == reward.id && r.week == week && r.status != 'rejected')
        .length;
    if (used >= reward.perWeek) {
      throw AppError('Tuần này đã đổi "${reward.name}" đủ ${reward.perWeek} lần.');
    }
    final batch = db.batch();
    batch.update(_users.doc(kid.uid), {'coins': FieldValue.increment(-reward.cost)});
    batch.set(db.collection('redemptions').doc(), {
      'kidUid': kid.uid,
      'kidName': p.shortName,
      'parentUids': [reward.parentUid],
      'rewardId': reward.id,
      'name': reward.name,
      'cost': reward.cost,
      'status': 'pending',
      'week': week,
      'refunded': false,
      'createdAt': FieldValue.serverTimestamp(),
    });
    _addNotice(batch, reward.parentUid, kid.uid, 'redeem', '${p.shortName} xin đổi "${reward.name}"',
        '${reward.cost} xu. Vào mục Phần thưởng để duyệt.');
    await batch.commit();
  }

  Future<void> buyShield(Profile kid) async {
    final p = await profile(kid.uid);
    if (p.shields >= maxShields) throw const AppError('Bạn đã có tối đa $maxShields khiên.');
    if (p.coins < shieldPrice) throw AppError('Chưa đủ xu: cần $shieldPrice, bạn có ${p.coins}.');
    await _users.doc(kid.uid).update({
      'coins': FieldValue.increment(-shieldPrice),
      'shields': FieldValue.increment(1),
    });
  }

  // ======================= Liên kết con – phụ huynh =======================

  Future<void> requestLink(Profile kid, String code) async {
    final c = code.trim().toUpperCase().replaceAll(' ', '');
    final normalized = c.startsWith('PH-') ? c : 'PH-${c.replaceAll('PH', '')}';
    final doc = await db.collection('parentCodes').doc(normalized).get();
    if (!doc.exists) throw const AppError('Không tìm thấy mã phụ huynh này. Hãy kiểm tra lại.');
    final parentUid = doc.data()!['uid'] as String;
    final parentName = (doc.data()!['name'] ?? '') as String;
    final batch = db.batch();
    batch.set(db.collection('linkRequests').doc('${kid.uid}_$parentUid'), {
      'kidUid': kid.uid,
      'kidName': kid.displayName,
      'kidGrade': kid.grade,
      'parentUid': parentUid,
      'parentName': parentName,
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
    });
    _addNotice(batch, parentUid, kid.uid, 'link', '${kid.displayName} muốn liên kết tài khoản',
        'Vào mục Cài đặt để xác nhận.');
    await batch.commit();
  }

  Stream<List<LinkRequest>> watchKidLinks(String kidUid) => db
      .collection('linkRequests')
      .where('kidUid', isEqualTo: kidUid)
      .snapshots()
      .map((s) => s.docs.map(LinkRequest.fromDoc).toList());

  Stream<List<LinkRequest>> watchParentLinks(String parentUid) => db
      .collection('linkRequests')
      .where('parentUid', isEqualTo: parentUid)
      .snapshots()
      .map((s) => s.docs.map(LinkRequest.fromDoc).toList()..sort((a, b) => a.kidName.compareTo(b.kidName)));

  Future<void> respondLink(LinkRequest r, bool accept) =>
      db.collection('linkRequests').doc(r.id).update({'status': accept ? 'accepted' : 'rejected'});

  // ======================= Phụ huynh =======================

  Stream<DayPlan?> watchDay(String kidUid, String day) =>
      _sub(kidUid, 'days').doc(day).snapshots().map((d) => d.exists ? DayPlan.fromDoc(d) : null);

  Future<List<Exam>> kidExamsSince(String kidUid, String fromDay) async {
    final s = await _sub(kidUid, 'exams').where('day', isGreaterThanOrEqualTo: fromDay).get();
    return s.docs.map(Exam.fromDoc).toList()..sort((a, b) => b.day.compareTo(a.day));
  }

  Stream<List<Notice>> watchNotices(String uid) => db
      .collection('notifications')
      .where('toUid', isEqualTo: uid)
      .snapshots()
      .map((s) => s.docs.map(Notice.fromDoc).toList()
        ..sort((a, b) => (b.createdAt ?? DateTime(2100)).compareTo(a.createdAt ?? DateTime(2100))));

  Future<void> markNoticesRead(Iterable<Notice> notices) async {
    final unread = notices.where((n) => !n.read).toList();
    if (unread.isEmpty) return;
    final batch = db.batch();
    for (final n in unread.take(400)) {
      batch.update(db.collection('notifications').doc(n.id), {'read': true});
    }
    await batch.commit();
  }

  Stream<List<Reward>> watchParentRewards(String parentUid) => db
      .collection('rewards')
      .where('parentUid', isEqualTo: parentUid)
      .snapshots()
      .map((s) => s.docs.map(Reward.fromDoc).where((r) => r.active).toList()
        ..sort((a, b) => a.cost.compareTo(b.cost)));

  Future<void> saveReward({
    String? id,
    required String parentUid,
    required String name,
    required int cost,
    required int perWeek,
    required List<String> kidUids,
  }) async {
    if (name.trim().isEmpty) throw const AppError('Hãy nhập tên phần thưởng.');
    if (cost <= 0) throw const AppError('Giá xu phải lớn hơn 0.');
    if (perWeek <= 0) throw const AppError('Số lần mỗi tuần phải từ 1 trở lên.');
    if (kidUids.isEmpty) throw const AppError('Hãy chọn ít nhất một con.');
    final ref = id == null ? db.collection('rewards').doc() : db.collection('rewards').doc(id);
    await ref.set({
      'parentUid': parentUid,
      'name': name.trim(),
      'cost': cost,
      'perWeek': perWeek,
      'kidUids': kidUids,
      'active': true,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> removeReward(String id) => db.collection('rewards').doc(id).update({'active': false});

  Stream<List<Redemption>> watchParentRedemptions(String parentUid) => db
      .collection('redemptions')
      .where('parentUids', arrayContains: parentUid)
      .snapshots()
      .map((s) => s.docs.map(Redemption.fromDoc).toList()
        ..sort((a, b) => (b.createdAt ?? DateTime(2100)).compareTo(a.createdAt ?? DateTime(2100))));

  Future<void> decideRedemption(Redemption r, bool approve) => db
      .collection('redemptions')
      .doc(r.id)
      .update({'status': approve ? 'approved' : 'rejected', 'decidedAt': FieldValue.serverTimestamp()});
}
