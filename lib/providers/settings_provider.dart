import 'package:flutter/material.dart';

import '../models/media_model.dart';
import '../services/settings_service.dart';

class SettingsProvider extends ChangeNotifier {
  SettingsProvider({SettingsService? service})
    : _service = service ?? SettingsService();
  final SettingsService _service;

  ThemeMode themeMode = ThemeMode.system;
  int gridSize = 3;
  bool showVideos = true;
  bool showHidden = false;
  bool onboardingComplete = false;
  GallerySort sortOrder = GallerySort.newest;
  List<String> recentSearches = [];

  Future<void> load() async {
    final values = await Future.wait<dynamic>([
      _service.onboardingComplete(),
      _service.themeIndex(),
      _service.gridSize(),
      _service.showVideos(),
      _service.showHidden(),
      _service.sortOrder(),
      _service.recentSearches(),
    ]);
    onboardingComplete = values[0] as bool;
    final themeIndex = values[1] as int;
    themeMode =
        ThemeMode.values[themeIndex.clamp(0, ThemeMode.values.length - 1)];
    gridSize = (values[2] as int).clamp(2, 5);
    showVideos = values[3] as bool;
    showHidden = values[4] as bool;
    sortOrder = values[5] as GallerySort;
    recentSearches = values[6] as List<String>;
  }

  Future<void> finishOnboarding() async {
    onboardingComplete = true;
    notifyListeners();
    await _service.setOnboardingComplete(true);
  }

  Future<void> setTheme(ThemeMode value) async {
    themeMode = value;
    notifyListeners();
    await _service.setThemeIndex(value.index);
  }

  Future<void> setGridSize(int value) async {
    gridSize = value.clamp(2, 5);
    notifyListeners();
    await _service.setGridSize(gridSize);
  }

  Future<void> toggleVideos(bool value) async {
    showVideos = value;
    notifyListeners();
    await _service.setShowVideos(value);
  }

  Future<void> toggleHidden(bool value) async {
    showHidden = value;
    notifyListeners();
    await _service.setShowHidden(value);
  }

  Future<void> setSortOrder(GallerySort value) async {
    sortOrder = value;
    notifyListeners();
    await _service.setSortOrder(value);
  }

  Future<void> addRecentSearch(String value) async {
    final normalized = value.trim();
    if (normalized.isEmpty) return;
    recentSearches = [
      normalized,
      ...recentSearches.where(
        (item) => item.toLowerCase() != normalized.toLowerCase(),
      ),
    ].take(6).toList();
    notifyListeners();
    await _service.setRecentSearches(recentSearches);
  }

  Future<void> clearRecentSearches() async {
    recentSearches = [];
    notifyListeners();
    await _service.setRecentSearches(const []);
  }
}
