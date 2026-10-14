import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:photo_manager/photo_manager.dart';

import '../models/album_model.dart';
import '../models/media_model.dart';
import '../services/favorites_service.dart';
import '../services/media_service.dart';
import '../services/permission_service.dart';
import 'settings_provider.dart';

class GalleryProvider extends ChangeNotifier {
  GalleryProvider({
    required SettingsProvider settings,
    MediaService? mediaService,
    PermissionService? permissionService,
    FavoritesService? favoritesService,
  }) : _settings = settings,
       mediaService = mediaService ?? MediaService(),
       permissionService = permissionService ?? PermissionService(),
       _favoritesService = favoritesService ?? FavoritesService() {
    _lastShowVideos = settings.showVideos;
    _lastShowHidden = settings.showHidden;
    _lastSort = settings.sortOrder;
    _settings.addListener(_onSettingsChanged);
  }

  final SettingsProvider _settings;
  final FavoritesService _favoritesService;
  final MediaService mediaService;
  final PermissionService permissionService;

  PermissionState permissionState = PermissionState.notDetermined;
  List<MediaModel> media = [];
  List<AlbumModel> albums = [];
  AssetPathEntity? allPath;
  int allCount = 0;
  int photoCount = 0;
  int videoCount = 0;
  bool isLoading = false;
  bool isRefreshing = false;
  String? errorMessage;
  final Set<String> favourites = {};
  final Set<String> selected = {};

  bool _favouritesLoaded = false;
  bool _initialized = false;
  bool _changeNotificationsStarted = false;
  Timer? _changeDebounce;
  late bool _lastShowVideos;
  late bool _lastShowHidden;
  late GallerySort _lastSort;

  bool get hasAccess =>
      permissionState == PermissionState.authorized ||
      permissionState == PermissionState.limited;
  bool get isLimited => permissionState == PermissionState.limited;
  String get permissionLabel => switch (permissionState) {
    PermissionState.authorized => 'Full access',
    PermissionState.limited => 'Selected photos and videos',
    PermissionState.notDetermined => 'Not requested',
    PermissionState.restricted => 'Restricted',
    PermissionState.denied => 'Denied',
  };

  Future<PermissionState> checkPermission() async {
    try {
      permissionState = await permissionService.current();
    } catch (_) {
      permissionState = PermissionState.denied;
    }
    if (!hasAccess) _initialized = false;
    notifyListeners();
    return permissionState;
  }

  Future<PermissionState> requestPermission() async {
    try {
      permissionState = await permissionService.request();
    } catch (error) {
      permissionState = PermissionState.denied;
      errorMessage = 'Could not request gallery access: $error';
    }
    notifyListeners();
    if (hasAccess) await initialize();
    return permissionState;
  }

  Future<void> initialize({bool force = false}) async {
    if (!_favouritesLoaded) {
      favourites
        ..clear()
        ..addAll(await _favoritesService.load());
      _favouritesLoaded = true;
    }
    if (!hasAccess) {
      await checkPermission();
      if (!hasAccess) return;
    }
    if (_initialized && !force) return;
    if (isLoading && !force) return;
    await refresh(showFullLoader: media.isEmpty);
    _initialized = errorMessage == null;
    await _startChangeNotifications();
  }

  Future<void> refresh({bool showFullLoader = false}) async {
    if (!hasAccess) return;
    if (showFullLoader) {
      isLoading = true;
    } else {
      isRefreshing = true;
    }
    errorMessage = null;
    notifyListeners();
    try {
      final paths = await mediaService.getPaths(
        sort: _settings.sortOrder,
        includeHidden: _settings.showHidden,
      );
      allPath = paths.where((path) => path.isAll).firstOrNull;
      final requestType = _settings.showVideos
          ? RequestType.common
          : RequestType.image;
      final values = await Future.wait<dynamic>([
        mediaService.buildAlbums(
          paths.where((path) => !path.isAll).toList(),
          type: requestType,
          sort: _settings.sortOrder,
          includeHidden: _settings.showHidden,
        ),
        mediaService.loadPage(
          path: allPath,
          type: requestType,
          page: 0,
          sort: _settings.sortOrder,
          includeHidden: _settings.showHidden,
        ),
        mediaService.count(
          type: requestType,
          includeHidden: _settings.showHidden,
        ),
        mediaService.count(
          type: RequestType.image,
          includeHidden: _settings.showHidden,
        ),
        mediaService.count(
          type: RequestType.video,
          includeHidden: _settings.showHidden,
        ),
      ]);
      albums = values[0] as List<AlbumModel>;
      media = values[1] as List<MediaModel>;
      allCount = values[2] as int;
      photoCount = values[3] as int;
      videoCount = values[4] as int;
    } catch (error) {
      errorMessage = 'Unable to load your gallery. $error';
    } finally {
      isLoading = false;
      isRefreshing = false;
      notifyListeners();
    }
  }

  bool isFavourite(MediaModel item) => favourites.contains(item.id);
  bool isSelected(MediaModel item) => selected.contains(item.id);
  Future<void> toggleFavourite(MediaModel item) async {
    if (!favourites.add(item.id)) favourites.remove(item.id);
    notifyListeners();
    await _favoritesService.save(favourites);
  }

  void toggleSelection(MediaModel item) {
    if (!selected.add(item.id)) selected.remove(item.id);
    notifyListeners();
  }

  void clearSelection() {
    if (selected.isEmpty) return;
    selected.clear();
    notifyListeners();
  }

  void selectAll(Iterable<MediaModel> items) {
    selected.addAll(items.map((item) => item.id));
    notifyListeners();
  }

  List<MediaModel> selectedFrom(Iterable<MediaModel> items) =>
      items.where((item) => selected.contains(item.id)).toList();
  Future<void> favouriteSelected(Iterable<MediaModel> items) async {
    final ids = items
        .where((item) => selected.contains(item.id))
        .map((item) => item.id)
        .toSet();
    if (ids.isEmpty) return;
    if (ids.every(favourites.contains)) {
      favourites.removeAll(ids);
    } else {
      favourites.addAll(ids);
    }
    clearSelection();
    await _favoritesService.save(favourites);
  }

  Future<List<MediaModel>> favouriteMedia() async {
    final resolved = await mediaService.resolveIds(favourites);
    final validIds = resolved.map((item) => item.id).toSet();
    if (validIds.length != favourites.length) {
      favourites
        ..clear()
        ..addAll(validIds);
      await _favoritesService.save(favourites);
      notifyListeners();
    }
    return resolved;
  }

  Future<void> removeDeleted(Set<String> ids) async {
    if (ids.isEmpty) return;
    media.removeWhere((item) => ids.contains(item.id));
    favourites.removeAll(ids);
    selected.removeAll(ids);
    await _favoritesService.save(favourites);
    notifyListeners();
    unawaited(refresh());
  }

  Future<void> refreshPermissionAfterSettings() async {
    final before = hasAccess;
    await checkPermission();
    if (hasAccess) {
      await initialize(force: true);
    } else if (before) {
      _initialized = false;
      media = [];
      albums = [];
      notifyListeners();
    }
  }

  Future<void> _startChangeNotifications() async {
    if (_changeNotificationsStarted) return;
    PhotoManager.addChangeCallback(_onNativeChange);
    try {
      await PhotoManager.startChangeNotify();
      _changeNotificationsStarted = true;
    } catch (_) {
      PhotoManager.removeChangeCallback(_onNativeChange);
    }
  }

  void _onNativeChange(MethodCall _) {
    _changeDebounce?.cancel();
    _changeDebounce = Timer(const Duration(milliseconds: 700), refresh);
  }

  void _onSettingsChanged() {
    final changed =
        _lastShowVideos != _settings.showVideos ||
        _lastShowHidden != _settings.showHidden ||
        _lastSort != _settings.sortOrder;
    _lastShowVideos = _settings.showVideos;
    _lastShowHidden = _settings.showHidden;
    _lastSort = _settings.sortOrder;
    if (changed && hasAccess) unawaited(refresh(showFullLoader: true));
  }

  @override
  void dispose() {
    _settings.removeListener(_onSettingsChanged);
    _changeDebounce?.cancel();
    if (_changeNotificationsStarted) {
      PhotoManager.removeChangeCallback(_onNativeChange);
      unawaited(PhotoManager.stopChangeNotify());
    }
    super.dispose();
  }
}
