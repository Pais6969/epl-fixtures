import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/team_model.dart';
import '../models/user_location.dart';

/// Pengaturan dan preferensi pengguna yang disimpan di perangkat.
///
/// Berupa [ChangeNotifier] sehingga halaman yang memakai
/// `ListenableBuilder(listenable: AppSettings.instance, ...)` otomatis
/// diperbarui ketika pengaturan berubah.
class AppSettings extends ChangeNotifier {
  AppSettings._();

  static final AppSettings instance = AppSettings._();

  static const _kTheme = 'set:themeMode';
  static const _kFavTeam = 'set:favTeam';
  static const _kAutoRemind = 'set:autoRemind';
  static const _kRemindMinutes = 'set:remindMinutes';
  static const _kManualReminders = 'set:manualReminders';
  static const _kAutoReminders = 'set:autoReminders';
  static const _kLocation = 'set:location';

  late SharedPreferences _prefs;

  ThemeMode themeMode = ThemeMode.system;
  TeamModel? favoriteTeam;
  bool autoRemindFavorite = true;
  int reminderMinutes = 30;

  /// Id pertandingan yang pengingatnya dipasang manual oleh pengguna.
  Set<int> manualReminders = {};

  /// Id pertandingan klub favorit yang pengingatnya dipasang otomatis.
  Set<int> autoReminders = {};

  UserLocation? location;

  int? get favoriteTeamId => favoriteTeam?.id;

  bool hasReminder(int matchId) =>
      manualReminders.contains(matchId) || autoReminders.contains(matchId);

  Future<void> load() async {
    _prefs = await SharedPreferences.getInstance();
    themeMode = ThemeMode.values.firstWhere(
      (m) => m.name == _prefs.getString(_kTheme),
      orElse: () => ThemeMode.system,
    );
    final fav = _prefs.getString(_kFavTeam);
    if (fav != null) {
      favoriteTeam = TeamModel.fromJson(jsonDecode(fav) as Map<String, dynamic>);
    }
    autoRemindFavorite = _prefs.getBool(_kAutoRemind) ?? true;
    reminderMinutes = _prefs.getInt(_kRemindMinutes) ?? 30;
    manualReminders = _readIds(_kManualReminders);
    autoReminders = _readIds(_kAutoReminders);
    final loc = _prefs.getString(_kLocation);
    if (loc != null) {
      location = UserLocation.fromJson(jsonDecode(loc) as Map<String, dynamic>);
    }
  }

  Set<int> _readIds(String key) =>
      (_prefs.getStringList(key) ?? const <String>[])
          .map(int.tryParse)
          .whereType<int>()
          .toSet();

  Future<void> _writeIds(String key, Set<int> ids) =>
      _prefs.setStringList(key, ids.map((e) => '$e').toList());

  Future<void> setThemeMode(ThemeMode mode) async {
    themeMode = mode;
    await _prefs.setString(_kTheme, mode.name);
    notifyListeners();
  }

  Future<void> setFavoriteTeam(TeamModel? team) async {
    favoriteTeam = team;
    if (team == null) {
      await _prefs.remove(_kFavTeam);
    } else {
      await _prefs.setString(
        _kFavTeam,
        jsonEncode({
          'id': team.id,
          'name': team.name,
          'shortName': team.shortName,
          'tla': team.tla,
          'crest': team.crest,
        }),
      );
    }
    notifyListeners();
  }

  Future<void> setAutoRemindFavorite(bool value) async {
    autoRemindFavorite = value;
    await _prefs.setBool(_kAutoRemind, value);
    notifyListeners();
  }

  Future<void> setReminderMinutes(int minutes) async {
    reminderMinutes = minutes;
    await _prefs.setInt(_kRemindMinutes, minutes);
    notifyListeners();
  }

  Future<void> setManualReminders(Set<int> ids) async {
    manualReminders = ids;
    await _writeIds(_kManualReminders, ids);
    notifyListeners();
  }

  Future<void> setAutoReminders(Set<int> ids) async {
    autoReminders = ids;
    await _writeIds(_kAutoReminders, ids);
    notifyListeners();
  }

  Future<void> setLocation(UserLocation? value) async {
    location = value;
    if (value == null) {
      await _prefs.remove(_kLocation);
    } else {
      await _prefs.setString(_kLocation, jsonEncode(value.toJson()));
    }
    notifyListeners();
  }
}
