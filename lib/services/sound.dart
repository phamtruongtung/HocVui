import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Các tiếng hiệu ứng (file trong assets/audio/).
enum Sfx { tap, correct, wrong, coin, finish }

/// Nhạc nền và âm thanh hiệu ứng. Bật/tắt riêng từng loại, lưu trên máy.
/// Mọi lỗi phát âm thanh đều bị bỏ qua để không ảnh hưởng tới việc học.
class Sound extends ChangeNotifier {
  Sound._();
  static final Sound instance = Sound._();

  static const _kMusic = 'sound_music_on';
  static const _kSfx = 'sound_sfx_on';
  static const _musicVolume = 0.3;

  bool _musicOn = true;
  bool _sfxOn = true;
  bool get musicOn => _musicOn;
  bool get sfxOn => _sfxOn;

  AudioPlayer? _music;
  final _sfx = <Sfx, AudioPlayer>{};

  /// Nhạc đang được yêu cầu phát (ở màn hình học sinh, không trong giờ làm bài).
  bool _wantMusic = false;
  bool _musicPlaying = false;
  bool _paused = false;

  // Trên Android: không giành "audio focus" để nhạc nền và tiếng hiệu ứng
  // phát cùng lúc được, cũng không làm tắt nhạc của app khác.
  static final _context = AudioContext(
    android: const AudioContextAndroid(
      audioFocus: AndroidAudioFocus.none,
      usageType: AndroidUsageType.game,
      contentType: AndroidContentType.music,
    ),
  );

  Future<void> init() async {
    try {
      final p = await SharedPreferences.getInstance();
      _musicOn = p.getBool(_kMusic) ?? true;
      _sfxOn = p.getBool(_kSfx) ?? true;
    } catch (_) {}
  }

  Future<AudioPlayer> _newPlayer() async {
    final p = AudioPlayer();
    if (!kIsWeb) {
      try {
        await p.setAudioContext(_context);
      } catch (_) {}
    }
    return p;
  }

  Future<void> play(Sfx s) async {
    if (!_sfxOn) return;
    try {
      final p = _sfx[s] ??= await _newPlayer();
      await p.stop();
      await p.play(AssetSource('audio/${s.name}.wav'), volume: s == Sfx.tap ? 0.5 : 0.9);
    } catch (e) {
      debugPrint('[Sound] ${s.name}: $e');
    }
  }

  /// Bắt đầu nhạc nền (gọi khi vào màn hình học sinh).
  Future<void> startMusic() async {
    _wantMusic = true;
    await _syncMusic();
  }

  /// Dừng hẳn nhạc nền (rời màn hình học sinh, đăng xuất).
  Future<void> stopMusic() async {
    _wantMusic = false;
    await _syncMusic();
  }

  /// Tạm dừng nhạc (khi làm bài hoặc app chạy nền) rồi phát tiếp.
  Future<void> pauseMusic() async {
    _paused = true;
    await _syncMusic();
  }

  Future<void> resumeMusic() async {
    _paused = false;
    await _syncMusic();
  }

  /// Trình duyệt chỉ cho phát nhạc sau khi người dùng chạm vào trang:
  /// gọi hàm này ở mỗi lần chạm để thử phát lại nếu lần trước bị chặn.
  void userGesture() {
    if (_wantMusic && _musicOn && !_paused && !_musicPlaying) _syncMusic();
  }

  Future<void> _syncMusic() async {
    final should = _wantMusic && _musicOn && !_paused;
    try {
      if (should && !_musicPlaying) {
        final p = _music ??= await _newPlayer();
        await p.setReleaseMode(ReleaseMode.loop);
        _musicPlaying = true;
        await p.play(AssetSource('audio/music.wav'), volume: _musicVolume);
      } else if (!should && _musicPlaying) {
        _musicPlaying = false;
        await _music?.pause();
      }
    } catch (e) {
      // Thường gặp trên web khi chưa chạm vào trang: lần chạm sau sẽ thử lại.
      _musicPlaying = false;
      debugPrint('[Sound] music: $e');
    }
  }

  Future<void> setMusicOn(bool v) async {
    _musicOn = v;
    notifyListeners();
    await _syncMusic();
    try {
      (await SharedPreferences.getInstance()).setBool(_kMusic, v);
    } catch (_) {}
  }

  Future<void> setSfxOn(bool v) async {
    _sfxOn = v;
    notifyListeners();
    try {
      (await SharedPreferences.getInstance()).setBool(_kSfx, v);
    } catch (_) {}
  }
}
