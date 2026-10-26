import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AccentColorOption {
  final String name;
  final Color color;

  const AccentColorOption(this.name, this.color);
}

class SettingsService extends ChangeNotifier {
  static const _keyAccentColor = 'settings_accent_color';
  static const _keyAmoledBlack = 'settings_amoled_black';
  static const _keyWavySeekBar = 'settings_wavy_seek_bar';
  static const _keyMinDuration = 'settings_min_duration_seconds';
  static const _keyCleanTitles = 'settings_clean_titles';
  static const _keyPlaybackSpeed = 'settings_playback_speed';
  static const _keySeekStep = 'settings_seek_step_seconds';

  static const List<AccentColorOption> availableAccentColors = [
    AccentColorOption('Verde Spotify', Color(0xFF1DB954)),
    AccentColorOption('Ciano Elettrico', Color(0xFF00E5FF)),
    AccentColorOption('Viola Synthwave', Color(0xFFBD00FF)),
    AccentColorOption('Arancio Fuoco', Color(0xFFFF6D00)),
    AccentColorOption('Rosso Corallo', Color(0xFFFF3B30)),
    AccentColorOption('Giallo Oro', Color(0xFFFFD600)),
    AccentColorOption('Rosa Neon', Color(0xFFFF4081)),
    AccentColorOption('Blu Elettrico', Color(0xFF2979FF)),
  ];

  final SharedPreferences _prefs;

  late Color _accentColor;
  late bool _isAmoledBlack;
  late bool _isWavySeekBar;
  late int _minDurationSeconds;
  late bool _cleanTitlesEnabled;
  late double _playbackSpeed;
  late int _seekStepSeconds;

  SettingsService(this._prefs) {
    _loadSettings();
  }

  static Future<SettingsService> init() async {
    final prefs = await SharedPreferences.getInstance();
    return SettingsService(prefs);
  }

  void _loadSettings() {
    final savedColor = _prefs.getInt(_keyAccentColor);
    _accentColor = savedColor != null ? Color(savedColor) : const Color(0xFF1DB954);

    _isAmoledBlack = _prefs.getBool(_keyAmoledBlack) ?? false;
    _isWavySeekBar = _prefs.getBool(_keyWavySeekBar) ?? true;
    _minDurationSeconds = _prefs.getInt(_keyMinDuration) ?? 0;
    _cleanTitlesEnabled = _prefs.getBool(_keyCleanTitles) ?? true;
    _playbackSpeed = _prefs.getDouble(_keyPlaybackSpeed) ?? 1.0;
    _seekStepSeconds = _prefs.getInt(_keySeekStep) ?? 10;
  }

  // Getters
  Color get accentColor => _accentColor;
  bool get isAmoledBlack => _isAmoledBlack;
  bool get isWavySeekBar => _isWavySeekBar;
  int get minDurationSeconds => _minDurationSeconds;
  bool get cleanTitlesEnabled => _cleanTitlesEnabled;
  double get playbackSpeed => _playbackSpeed;
  int get seekStepSeconds => _seekStepSeconds;

  Color get backgroundColor => _isAmoledBlack ? Colors.black : const Color(0xFF121212);
  Color get surfaceColor => _isAmoledBlack ? const Color(0xFF101010) : const Color(0xFF1E1E1E);
  Color get cardColor => _isAmoledBlack ? const Color(0xFF161616) : const Color(0xFF242424);

  // Setters with persistent save
  Future<void> setAccentColor(Color color) async {
    _accentColor = color;
    await _prefs.setInt(_keyAccentColor, color.toARGB32());
    notifyListeners();
  }

  Future<void> setAmoledBlack(bool enabled) async {
    _isAmoledBlack = enabled;
    await _prefs.setBool(_keyAmoledBlack, enabled);
    notifyListeners();
  }

  Future<void> setWavySeekBar(bool enabled) async {
    _isWavySeekBar = enabled;
    await _prefs.setBool(_keyWavySeekBar, enabled);
    notifyListeners();
  }

  Future<void> setMinDurationSeconds(int seconds) async {
    _minDurationSeconds = seconds;
    await _prefs.setInt(_keyMinDuration, seconds);
    notifyListeners();
  }

  Future<void> setCleanTitlesEnabled(bool enabled) async {
    _cleanTitlesEnabled = enabled;
    await _prefs.setBool(_keyCleanTitles, enabled);
    notifyListeners();
  }

  Future<void> setPlaybackSpeed(double speed) async {
    _playbackSpeed = speed;
    await _prefs.setDouble(_keyPlaybackSpeed, speed);
    notifyListeners();
  }

  Future<void> setSeekStepSeconds(int seconds) async {
    _seekStepSeconds = seconds;
    await _prefs.setInt(_keySeekStep, seconds);
    notifyListeners();
  }
}
