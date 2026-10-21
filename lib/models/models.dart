import 'package:cloud_firestore/cloud_firestore.dart';

import '../logic/dates.dart';
import '../logic/rules.dart';
import '../logic/subjects.dart';

enum Role { admin, student, parent }

Role roleFromId(String? id) => switch (id) {
      'admin' => Role.admin,
      'parent' => Role.parent,
      _ => Role.student,
    };

String roleLabel(Role r) => switch (r) {
      Role.admin => 'Quản trị',
      Role.student => 'Học sinh',
      Role.parent => 'Phụ huynh',
    };

int _int(Object? v, [int def = 0]) => v is num ? v.toInt() : def;
double _double(Object? v) => v is num ? v.toDouble() : 0;
List<String> _strings(Object? v) => v is List ? v.map((e) => '$e').toList() : <String>[];
DateTime? _time(Object? v) => v is Timestamp ? v.toDate() : (v is int ? DateTime.fromMillisecondsSinceEpoch(v) : null);

/// users/{uid}
class Profile {
  Profile({
    required this.uid,
    required this.role,
    required this.username,
    required this.displayName,
    this.grade = 0,
    this.parentCode,
    this.coins = 0,
    this.streak = 0,
    this.bestStreak = 0,
    this.attendance = attendanceStart,
    this.shields = 0,
    this.lastCompletedDay,
    required this.lastClosedDay,
    this.prizeClaimedWeek,
    this.parents = const [],
    this.active = true,
  });

  final String uid;
  final Role role;
  final String username;
  final String displayName;
  final int grade;
  final String? parentCode;
  final int coins;
  final int streak;
  final int bestStreak;
  final int attendance;
  final int shields;
  final String? lastCompletedDay;
  final String lastClosedDay;
  final String? prizeClaimedWeek;
  final List<String> parents;
  final bool active;

  factory Profile.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? const {};
    return Profile(
      uid: doc.id,
      role: roleFromId(d['role'] as String?),
      username: (d['username'] ?? '') as String,
      displayName: (d['displayName'] ?? d['username'] ?? '') as String,
      grade: _int(d['grade']),
      parentCode: d['parentCode'] as String?,
      coins: _int(d['coins']),
      streak: _int(d['streak']),
      bestStreak: _int(d['bestStreak']),
      attendance: _int(d['attendance'], attendanceStart),
      shields: _int(d['shields']),
      lastCompletedDay: d['lastCompletedDay'] as String?,
      lastClosedDay: (d['lastClosedDay'] ?? dayKey(DateTime.now())) as String,
      prizeClaimedWeek: d['prizeClaimedWeek'] as String?,
      parents: _strings(d['parents']),
      active: d['active'] != false,
    );
  }

  Stats get stats => Stats(
        streak: streak,
        bestStreak: bestStreak,
        attendance: attendance,
        shields: shields,
        coins: coins,
        lastCompletedDay: lastCompletedDay,
        lastClosedDay: lastClosedDay,
      );

  static Map<String, Object?> statsToMap(Stats s) => {
        'streak': s.streak,
        'bestStreak': s.bestStreak,
        'attendance': s.attendance,
        'shields': s.shields,
        'coins': s.coins,
        'lastCompletedDay': s.lastCompletedDay,
        'lastClosedDay': s.lastClosedDay,
      };

  /// Tên gọi ngắn (từ cuối của họ tên), dùng trên bảng xếp hạng.
  String get shortName {
    final parts = displayName.trim().split(RegExp(r'\s+'));
    if (parts.length >= 2) return '${parts[parts.length - 2]} ${parts.last}';
    return displayName;
  }

  String get initials {
    final parts = displayName.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts[parts.length - 2].substring(0, 1) + parts.last.substring(0, 1)).toUpperCase();
  }
}

/// Một câu hỏi trắc nghiệm 4 đáp án. Lưu ở questions/{id}; bản sao nằm trong đề.
class Question {
  Question({
    this.id = '',
    required this.grade,
    required this.subject,
    required this.lessonOrder,
    required this.lessonTitle,
    required this.level,
    required this.text,
    this.passage = '',
    required this.options,
    required this.answer,
    this.explanation = '',
    this.status = 'pending',
    this.source = 'ai',
  });

  final String id;
  final int grade;
  final Subject subject;
  final int lessonOrder;
  final String lessonTitle;
  final int level; // 1..4
  final String text;
  final String passage;
  final List<String> options;
  final int answer;
  final String explanation;
  final String status; // pending | approved | rejected
  final String source;

  factory Question.fromMap(String id, Map<String, dynamic> d) => Question(
        id: id,
        grade: _int(d['grade']),
        subject: subjectFromId(d['subject'] as String?) ?? Subject.toan,
        lessonOrder: _int(d['lessonOrder']),
        lessonTitle: (d['lessonTitle'] ?? '') as String,
        level: _int(d['level'], 1).clamp(1, 4).toInt(),
        text: (d['text'] ?? '') as String,
        passage: (d['passage'] ?? '') as String,
        options: _strings(d['options']),
        answer: _int(d['answer']),
        explanation: (d['explanation'] ?? '') as String,
        status: (d['status'] ?? 'pending') as String,
        source: (d['source'] ?? 'ai') as String,
      );

  factory Question.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) =>
      Question.fromMap(doc.id, doc.data() ?? const {});

  Map<String, Object?> toMap() => {
        'grade': grade,
        'subject': subject.id,
        'lessonOrder': lessonOrder,
        'lessonTitle': lessonTitle,
        'level': level,
        'text': text,
        'passage': passage,
        'options': options,
        'answer': answer,
        'explanation': explanation,
        'status': status,
        'source': source,
      };

  /// Bản sao gọn để lưu trong đề và sổ lỗi sai.
  Map<String, Object?> snapshot() => {
        'id': id,
        'level': level,
        'lessonTitle': lessonTitle,
        'text': text,
        'passage': passage,
        'options': options,
        'answer': answer,
        'explanation': explanation,
      };

  factory Question.fromSnapshot(Map<String, dynamic> d, {required int grade, required Subject subject}) =>
      Question.fromMap((d['id'] ?? '') as String, {...d, 'grade': grade, 'subject': subject.id});

  Question copyWith({
    String? text,
    String? passage,
    List<String>? options,
    int? answer,
    String? explanation,
    int? level,
    String? status,
  }) =>
      Question(
        id: id,
        grade: grade,
        subject: subject,
        lessonOrder: lessonOrder,
        lessonTitle: lessonTitle,
        level: level ?? this.level,
        text: text ?? this.text,
        passage: passage ?? this.passage,
        options: options ?? this.options,
        answer: answer ?? this.answer,
        explanation: explanation ?? this.explanation,
        status: status ?? this.status,
        source: source,
      );
}

/// users/{uid}/exams/{id}
class Exam {
  Exam({
    required this.id,
    required this.day,
    required this.subject,
    required this.grade,
    required this.title,
    required this.questions,
    required this.answers,
    this.startedAt,
    this.submittedAt,
    this.correct = 0,
    this.score = 0,
    this.coins = 0,
    this.correctByLevel = const [0, 0, 0, 0],
    this.seconds = 0,
  });

  final String id;
  final String day;
  final Subject subject;
  final int grade;
  final String title;
  final List<Question> questions;
  final List<int> answers; // -1 = chưa chọn
  final DateTime? startedAt;
  final DateTime? submittedAt;
  final int correct;
  final double score;
  final int coins;
  final List<int> correctByLevel;
  final int seconds;

  bool get submitted => submittedAt != null;
  bool get started => startedAt != null;
  DateTime? get deadline => startedAt?.add(const Duration(minutes: examMinutes));

  factory Exam.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? const {};
    final subject = subjectFromId(d['subject'] as String?) ?? Subject.toan;
    final grade = _int(d['grade']);
    final qs = (d['questions'] as List? ?? const [])
        .map((e) => Question.fromSnapshot(Map<String, dynamic>.from(e as Map), grade: grade, subject: subject))
        .toList();
    final ans = (d['answers'] as List? ?? const []).map((e) => _int(e, -1)).toList();
    while (ans.length < qs.length) {
      ans.add(-1);
    }
    return Exam(
      id: doc.id,
      day: (d['day'] ?? '') as String,
      subject: subject,
      grade: grade,
      title: (d['title'] ?? '') as String,
      questions: qs,
      answers: ans,
      startedAt: _time(d['startedAt']),
      submittedAt: _time(d['submittedAt']),
      correct: _int(d['correct']),
      score: _double(d['score']),
      coins: _int(d['coins']),
      correctByLevel: (d['correctByLevel'] as List? ?? const [0, 0, 0, 0]).map((e) => _int(e)).toList(),
      seconds: _int(d['seconds']),
    );
  }
}

/// users/{uid}/days/{yyyy-MM-dd}
class DayPlan {
  DayPlan({
    required this.day,
    required this.examIds,
    required this.subjects,
    required this.required,
    required this.done,
    this.completedAt,
    this.note = '',
  });

  final String day;
  final List<String> examIds;
  final List<Subject> subjects;
  final int required;
  final int done;
  final DateTime? completedAt;
  final String note;

  bool get complete => done >= required;

  factory DayPlan.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? const {};
    return DayPlan(
      day: doc.id,
      examIds: _strings(d['examIds']),
      subjects: _strings(d['subjects']).map(subjectFromId).whereType<Subject>().toList(),
      required: _int(d['required'], 2),
      done: _int(d['done']),
      completedAt: _time(d['completedAt']),
      note: (d['note'] ?? '') as String,
    );
  }
}

/// users/{uid}/mistakes/{questionId}
class Mistake {
  Mistake({
    required this.id,
    required this.subject,
    required this.grade,
    required this.question,
    required this.chosen,
    required this.stage,
    required this.nextDue,
    required this.mastered,
    this.wrongAt,
  });

  final String id;
  final Subject subject;
  final int grade;
  final Question question;
  final int chosen;
  final int stage;
  final String nextDue;
  final bool mastered;
  final DateTime? wrongAt;

  factory Mistake.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? const {};
    final subject = subjectFromId(d['subject'] as String?) ?? Subject.toan;
    final grade = _int(d['grade']);
    return Mistake(
      id: doc.id,
      subject: subject,
      grade: grade,
      question: Question.fromSnapshot(Map<String, dynamic>.from((d['question'] ?? const {}) as Map),
          grade: grade, subject: subject),
      chosen: _int(d['chosen'], -1),
      stage: _int(d['stage']),
      nextDue: (d['nextDue'] ?? '') as String,
      mastered: d['mastered'] == true,
      wrongAt: _time(d['wrongAt']),
    );
  }
}

/// curriculum/{grade}_{subject}: mục lục SGK và bài đang học tới.
class Curriculum {
  Curriculum({required this.grade, required this.subject, required this.lines, this.upTo = 0});

  final int grade;
  final Subject subject;

  /// Mỗi dòng là một bài; dòng bắt đầu bằng '#' là tên chương.
  final List<String> lines;

  /// Thứ tự bài đang học tới (0 = dùng mọi bài).
  final int upTo;

  String get docId => '${grade}_${subject.id}';

  factory Curriculum.fromDoc(int grade, Subject subject, DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? const {};
    return Curriculum(grade: grade, subject: subject, lines: _strings(d['lines']), upTo: _int(d['upTo']));
  }

  /// Danh sách bài (bỏ dòng chương), mỗi bài có thứ tự từ 1 và tên chương.
  List<Lesson> get lessons {
    final out = <Lesson>[];
    var chapter = '';
    for (final raw in lines) {
      final line = raw.trim();
      if (line.isEmpty || line.startsWith('#!')) continue;
      if (line.startsWith('#')) {
        chapter = line.substring(1).trim();
      } else {
        out.add(Lesson(out.length + 1, line, chapter));
      }
    }
    return out;
  }

  /// Thứ tự bài đầu tiên của học kỳ 2 (dòng '#! HK2'), 0 nếu không đánh dấu.
  int get hk2Start {
    var count = 0;
    for (final raw in lines) {
      final line = raw.trim();
      if (line.isEmpty) continue;
      if (line.toUpperCase().startsWith('#! HK2')) return count + 1;
      if (!line.startsWith('#')) count++;
    }
    return 0;
  }

  /// Bài đang học tới, ước tính theo tuần của năm học (học kỳ 1: 18 tuần từ 05/9,
  /// học kỳ 2: 17 tuần). Dùng khi quản trị viên chưa chọn bài cụ thể ([upTo] = 0).
  int autoUpTo(DateTime now) {
    final total = lessons.length;
    if (total == 0) return 0;
    final year = now.month >= 8 ? now.year : now.year - 1;
    final start = DateTime(year, 9, 5);
    final days = now.difference(start).inDays;
    // Hè (từ 01/6 tới 04/9): ôn toàn bộ chương trình.
    if (days < 0 || now.month == 6 || now.month == 7 || (now.month == 8)) return total;
    final week = days ~/ 7 + 1;
    final hk2 = hk2Start > 1 ? hk2Start : (total / 2).ceil() + 1;
    final hk1Count = hk2 - 1;
    final hk2Count = total - hk1Count;
    int upTo;
    if (week <= 18) {
      upTo = (hk1Count * week / 18).ceil();
    } else {
      upTo = hk1Count + (hk2Count * (week - 18) / 17).ceil();
    }
    if (upTo < 1) upTo = 1;
    if (upTo > total) upTo = total;
    return upTo;
  }

  /// Bài học tới dùng để ra đề: bài quản trị viên chọn, hoặc tự động theo tuần.
  int effectiveUpTo(DateTime now) => upTo > 0 ? upTo : autoUpTo(now);
}

class Lesson {
  const Lesson(this.order, this.title, this.chapter);
  final int order;
  final String title;
  final String chapter;
}

/// rewards/{id}: phần thưởng thật do phụ huynh đặt.
class Reward {
  Reward({
    required this.id,
    required this.parentUid,
    required this.name,
    required this.cost,
    required this.perWeek,
    required this.kidUids,
    this.active = true,
  });

  final String id;
  final String parentUid;
  final String name;
  final int cost;
  final int perWeek;
  final List<String> kidUids;
  final bool active;

  factory Reward.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? const {};
    return Reward(
      id: doc.id,
      parentUid: (d['parentUid'] ?? '') as String,
      name: (d['name'] ?? '') as String,
      cost: _int(d['cost']),
      perWeek: _int(d['perWeek'], 1),
      kidUids: _strings(d['kidUids']),
      active: d['active'] != false,
    );
  }
}

/// redemptions/{id}: yêu cầu đổi thưởng của con.
class Redemption {
  Redemption({
    required this.id,
    required this.kidUid,
    required this.kidName,
    required this.parentUids,
    required this.rewardId,
    required this.name,
    required this.cost,
    required this.status,
    required this.week,
    this.refunded = false,
    this.createdAt,
  });

  final String id;
  final String kidUid;
  final String kidName;
  final List<String> parentUids;
  final String rewardId;
  final String name;
  final int cost;
  final String status; // pending | approved | rejected
  final String week;
  final bool refunded;
  final DateTime? createdAt;

  factory Redemption.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? const {};
    return Redemption(
      id: doc.id,
      kidUid: (d['kidUid'] ?? '') as String,
      kidName: (d['kidName'] ?? '') as String,
      parentUids: _strings(d['parentUids']),
      rewardId: (d['rewardId'] ?? '') as String,
      name: (d['name'] ?? '') as String,
      cost: _int(d['cost']),
      status: (d['status'] ?? 'pending') as String,
      week: (d['week'] ?? '') as String,
      refunded: d['refunded'] == true,
      createdAt: _time(d['createdAt']),
    );
  }
}

/// notifications/{id}: thông báo trong app cho phụ huynh.
class Notice {
  Notice({
    required this.id,
    required this.toUid,
    required this.kind,
    required this.title,
    required this.body,
    required this.read,
    this.createdAt,
  });

  final String id;
  final String toUid;
  final String kind; // mistakes | done | redeem | link
  final String title;
  final String body;
  final bool read;
  final DateTime? createdAt;

  factory Notice.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? const {};
    return Notice(
      id: doc.id,
      toUid: (d['toUid'] ?? '') as String,
      kind: (d['kind'] ?? '') as String,
      title: (d['title'] ?? '') as String,
      body: (d['body'] ?? '') as String,
      read: d['read'] == true,
      createdAt: _time(d['createdAt']),
    );
  }
}

/// linkRequests/{kidUid}_{parentUid}
class LinkRequest {
  LinkRequest({
    required this.kidUid,
    required this.kidName,
    required this.kidGrade,
    required this.parentUid,
    required this.parentName,
    required this.status,
  });

  final String kidUid;
  final String kidName;
  final int kidGrade;
  final String parentUid;
  final String parentName;
  final String status; // pending | accepted | rejected

  String get id => '${kidUid}_$parentUid';

  factory LinkRequest.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? const {};
    return LinkRequest(
      kidUid: (d['kidUid'] ?? '') as String,
      kidName: (d['kidName'] ?? '') as String,
      kidGrade: _int(d['kidGrade']),
      parentUid: (d['parentUid'] ?? '') as String,
      parentName: (d['parentName'] ?? '') as String,
      status: (d['status'] ?? 'pending') as String,
    );
  }
}

/// leaderboard/{week}/scores/{uid}
class LeaderRow {
  LeaderRow({
    required this.uid,
    required this.name,
    required this.grade,
    required this.points,
    required this.seconds,
  });

  final String uid;
  final String name;
  final int grade;
  final double points;
  final int seconds;

  factory LeaderRow.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? const {};
    return LeaderRow(
      uid: doc.id,
      name: (d['name'] ?? '') as String,
      grade: _int(d['grade']),
      points: _double(d['points']),
      seconds: _int(d['seconds']),
    );
  }

  RankRow get rank => RankRow(uid, points, seconds);
}
