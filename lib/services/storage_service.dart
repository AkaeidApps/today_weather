import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/app_settings.dart';
import '../models/background_scene.dart';
import '../models/place.dart';

class StorageService {
  StorageService(this._prefs);

  final SharedPreferences _prefs;

  static const _keyPlace = 'aether_current_place';
  static const _keyFavorites = 'aether_favorites';
  static const _keyRecents = 'aether_recents';
  static const _keyTempUnit = 'aether_temp_unit';
  static const _keyWindUnit = 'aether_wind_unit';
  static const _keyPressureUnit = 'aether_pressure_unit';
  static const _keyTimeFormat = 'aether_time_format';
  static const _keyBgMode = 'aether_bg_mode';
  static const _keyReducedMotion = 'aether_reduced_motion';
  static const _keyHighContrast = 'aether_high_contrast';
  static const _keyCachedWeather = 'aether_cached_weather';
  static const _keyCachedAirQuality = 'aether_cached_air_quality';

  static Future<StorageService> init() async {
    final prefs = await SharedPreferences.getInstance();
    return StorageService(prefs);
  }

  Place loadCurrentPlace() {
    final raw = _prefs.getString(_keyPlace);
    if (raw != null) {
      final p = Place.fromSerializedString(raw);
      if (p != null) return p;
    }
    // Default place: London, United Kingdom or San Francisco
    return const Place(
      name: 'London',
      country: 'United Kingdom',
      lat: 51.5074,
      lon: -0.1278,
      timezone: 'Europe/London',
    );
  }

  Future<void> saveCurrentPlace(Place place) async {
    await _prefs.setString(_keyPlace, place.toSerializedString());
  }

  List<Place> loadFavorites() {
    final list = _prefs.getStringList(_keyFavorites) ?? [];
    return list
        .map(Place.fromSerializedString)
        .whereType<Place>()
        .toList();
  }

  Future<void> saveFavorites(List<Place> favorites) async {
    await _prefs.setStringList(
      _keyFavorites,
      favorites.map((p) => p.toSerializedString()).toList(),
    );
  }

  List<Place> loadRecents() {
    final list = _prefs.getStringList(_keyRecents) ?? [];
    return list
        .map(Place.fromSerializedString)
        .whereType<Place>()
        .toList();
  }

  Future<void> saveRecents(List<Place> recents) async {
    await _prefs.setStringList(
      _keyRecents,
      recents.map((p) => p.toSerializedString()).toList(),
    );
  }

  AppSettings loadSettings() {
    final tempIndex = _prefs.getInt(_keyTempUnit) ?? 0;
    final windIndex = _prefs.getInt(_keyWindUnit) ?? 0;
    final pressureIndex = _prefs.getInt(_keyPressureUnit) ?? 0;
    final timeFormatIndex = _prefs.getInt(_keyTimeFormat) ?? 0;
    final bgModeIndex = _prefs.getInt(_keyBgMode) ?? 0;
    final reducedMotion = _prefs.getBool(_keyReducedMotion) ?? false;
    final highContrast = _prefs.getBool(_keyHighContrast) ?? false;

    return AppSettings(
      temperatureUnit: TemperatureUnit.values.elementAtOrNull(tempIndex) ?? TemperatureUnit.celsius,
      windSpeedUnit: WindSpeedUnit.values.elementAtOrNull(windIndex) ?? WindSpeedUnit.kmh,
      pressureUnit: PressureUnit.values.elementAtOrNull(pressureIndex) ?? PressureUnit.hPa,
      timeFormat: TimeFormatSetting.values.elementAtOrNull(timeFormatIndex) ?? TimeFormatSetting.h24,
      backgroundMode: BackgroundMode.values.elementAtOrNull(bgModeIndex) ?? BackgroundMode.automatic,
      reducedMotion: reducedMotion,
      highContrast: highContrast,
    );
  }

  Future<void> saveSettings(AppSettings settings) async {
    await _prefs.setInt(_keyTempUnit, settings.temperatureUnit.index);
    await _prefs.setInt(_keyWindUnit, settings.windSpeedUnit.index);
    await _prefs.setInt(_keyPressureUnit, settings.pressureUnit.index);
    await _prefs.setInt(_keyTimeFormat, settings.timeFormat.index);
    await _prefs.setInt(_keyBgMode, settings.backgroundMode.index);
    await _prefs.setBool(_keyReducedMotion, settings.reducedMotion);
    await _prefs.setBool(_keyHighContrast, settings.highContrast);
  }

  Map<String, dynamic>? loadCachedWeather() {
    final raw = _prefs.getString(_keyCachedWeather);
    if (raw == null) return null;
    try {
      return jsonDecode(raw) as Map<String, dynamic>?;
    } catch (_) {
      return null;
    }
  }

  Future<void> saveCachedWeather(Map<String, dynamic> json) async {
    await _prefs.setString(_keyCachedWeather, jsonEncode(json));
  }

  Map<String, dynamic>? loadCachedAirQuality() {
    final raw = _prefs.getString(_keyCachedAirQuality);
    if (raw == null) return null;
    try {
      return jsonDecode(raw) as Map<String, dynamic>?;
    } catch (_) {
      return null;
    }
  }

  Future<void> saveCachedAirQuality(Map<String, dynamic> json) async {
    await _prefs.setString(_keyCachedAirQuality, jsonEncode(json));
  }

  Future<void> clearCache() async {
    await _prefs.remove(_keyCachedWeather);
    await _prefs.remove(_keyCachedAirQuality);
    await _prefs.remove(_keyRecents);
  }
}
