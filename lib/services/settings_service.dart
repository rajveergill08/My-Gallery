import 'package:shared_preferences/shared_preferences.dart';

import '../models/media_model.dart';

class SettingsService {
  static const _onboardingKey = 'onboarding_complete';
  static const _themeKey = 'theme_mode';
  static const _gridKey = 'grid_size';
  static const _videosKey = 'show_videos';
  static const _hiddenKey = 'show_hidden';
  static const _sortKey = 'gallery_sort';
  static const _searchesKey = 'recent_searches';

  Future<SharedPreferences> get _prefs => SharedPreferences.getInstance();

  Future<bool> onboardingComplete() async =>
      (await _prefs).getBool(_onboardingKey) ?? false;
  Future<int> themeIndex() async => (await _prefs).getInt(_themeKey) ?? 0;
  Future<int> gridSize() async => (await _prefs).getInt(_gridKey) ?? 3;
  Future<bool> showVideos() async => (await _prefs).getBool(_videosKey) ?? true;
  Future<bool> showHidden() async =>
      (await _prefs).getBool(_hiddenKey) ?? false;
  Future<GallerySort> sortOrder() async {
    final index = (await _prefs).getInt(_sortKey) ?? GallerySort.newest.index;
    return GallerySort.values[index.clamp(0, GallerySort.values.length - 1)];
  }

  Future<List<String>> recentSearches() async =>
      (await _prefs).getStringList(_searchesKey) ?? const [];

  Future<void> setOnboardingComplete(bool value) async =>
      (await _prefs).setBool(_onboardingKey, value);
  Future<void> setThemeIndex(int value) async =>
      (await _prefs).setInt(_themeKey, value);
  Future<void> setGridSize(int value) async =>
      (await _prefs).setInt(_gridKey, value);
  Future<void> setShowVideos(bool value) async =>
      (await _prefs).setBool(_videosKey, value);
  Future<void> setShowHidden(bool value) async =>
      (await _prefs).setBool(_hiddenKey, value);
  Future<void> setSortOrder(GallerySort value) async =>
      (await _prefs).setInt(_sortKey, value.index);
  Future<void> setRecentSearches(List<String> values) async =>
      (await _prefs).setStringList(_searchesKey, values);
}
