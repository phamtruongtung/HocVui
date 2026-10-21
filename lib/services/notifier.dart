import 'dart:ui' show Color;

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../logic/dates.dart';

/// Một lần nhắc học: giờ, phút và mức độ (1 nhẹ → 4 khẩn cấp).
class ReminderSlot {
  const ReminderSlot(this.hour, this.minute, this.level);
  final int hour;
  final int minute;
  final int level;
}

/// Lịch nhắc trong ngày khi con chưa xong bài (hạn chót 23:59):
/// 19:00, 20:00 nhẹ; 21:00, 21:30 nhắc nhở; 22:00–22:45 mỗi 15 phút;
/// 23:00–23:55 mỗi 5 phút.
List<ReminderSlot> reminderSlots() {
  final out = <ReminderSlot>[
    const ReminderSlot(19, 0, 1),
    const ReminderSlot(20, 0, 1),
    const ReminderSlot(21, 0, 2),
    const ReminderSlot(21, 30, 2),
  ];
  for (var m = 0; m < 60; m += 15) {
    out.add(ReminderSlot(22, m, 3));
  }
  for (var m = 0; m < 60; m += 5) {
    out.add(ReminderSlot(23, m, 4));
  }
  return out;
}

/// Nội dung nhắc theo mức độ.
({String title, String body}) reminderText(ReminderSlot s, {required int left, required int streak}) {
  final minutesLeft = (23 * 60 + 59) - (s.hour * 60 + s.minute);
  final remain = minutesLeft >= 60 ? '${minutesLeft ~/ 60} giờ ${minutesLeft % 60} phút' : '$minutesLeft phút';
  final deCon = left == 1 ? 'Còn 1 đề' : 'Còn $left đề';
  final keep = streak > 0 ? 'Chuỗi $streak ngày đang chờ bạn.' : 'Bắt đầu một chuỗi mới nào!';
  return switch (s.level) {
    1 => (title: 'Gà Chíp nhắc học', body: '$deCon tối nay, mỗi đề 30 phút. Nhớ chuẩn bị giấy nháp nhé!'),
    2 => (title: '$deCon chưa làm', body: '$keep Xong trước 21:00 được thêm điểm thi đua.'),
    3 => (title: 'Chỉ còn $remain!', body: '$deCon chưa làm, mỗi đề cần 30 phút. Bắt đầu ngay để kịp.'),
    _ => (
        title: 'KHẨN: còn $remain!',
        body: '$deCon chưa xong. Quá 23:59 sẽ mất chuỗi và bị trừ chuyên cần. Mở app làm ngay!'
      ),
  };
}

/// Thông báo nhắc học trên Android, hẹn giờ ngay trên máy (không cần máy chủ).
/// Bản web không có nhắc học.
class Notifier {
  final _plugin = FlutterLocalNotificationsPlugin();
  bool _ready = false;
  late tz.Location _vn;

  static const _daysAhead = 7;

  Future<void> init() async {
    if (kIsWeb) return;
    try {
      tzdata.initializeTimeZones();
      _vn = tz.getLocation('Asia/Ho_Chi_Minh');
      await _plugin.initialize(const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ));
      _ready = true;
    } catch (e) {
      debugPrint('[Notifier] $e');
    }
  }

  Future<bool> requestPermission() async {
    if (!_ready) return false;
    final android = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    return await android?.requestNotificationsPermission() ?? false;
  }

  NotificationDetails _details(int level) => NotificationDetails(
        android: AndroidNotificationDetails(
          level >= 3 ? 'hocvui_urgent' : 'hocvui_remind',
          level >= 3 ? 'Nhắc học gấp' : 'Nhắc học',
          channelDescription: 'Nhắc làm bài ôn tập mỗi tối',
          importance: level >= 3 ? Importance.max : Importance.defaultImportance,
          priority: level >= 3 ? Priority.max : Priority.defaultPriority,
          color: level >= 4 ? const Color(0xFFE5484D) : const Color(0xFF2FAE6B),
          category: AndroidNotificationCategory.reminder,
        ),
      );

  int _id(int dayOffset, int slot) => 1000 + dayOffset * 100 + slot;

  /// Hẹn nhắc cho hôm nay (nếu còn [leftToday] đề) và 6 ngày tới.
  /// Gọi lại mỗi lần mở trang chủ hoặc nộp bài.
  Future<void> scheduleReminders({required int leftToday, required int streak}) async {
    if (!_ready) return;
    try {
      await _plugin.cancelAll();
      final now = tz.TZDateTime.now(_vn);
      final slots = reminderSlots();
      for (var d = 0; d < _daysAhead; d++) {
        final left = d == 0 ? leftToday : 2;
        if (left <= 0) continue;
        final day = DateTime(now.year, now.month, now.day + d);
        for (var i = 0; i < slots.length; i++) {
          final s = slots[i];
          final when = tz.TZDateTime(_vn, day.year, day.month, day.day, s.hour, s.minute);
          if (!when.isAfter(now)) continue;
          final text = reminderText(s, left: left, streak: d == 0 ? streak : 0);
          await _plugin.zonedSchedule(
            _id(d, i),
            text.title,
            text.body,
            when,
            _details(s.level),
            androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
            uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
          );
        }
      }
    } catch (e) {
      debugPrint('[Notifier] schedule: $e');
    }
  }

  Future<void> cancelAll() async {
    if (!_ready) return;
    await _plugin.cancelAll();
  }

  /// Thông báo ngay (dùng cho phụ huynh khi app đang mở).
  Future<void> showNow(int id, String title, String body) async {
    if (!_ready) return;
    await _plugin.show(id, title, body, _details(2));
  }

  static String todayKey() => dayKey(DateTime.now());
}
