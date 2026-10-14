import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:share_plus/share_plus.dart';

import '../models/album_model.dart';
import '../models/media_model.dart';

class MediaService {
  static const int pageSize = 80;

  FilterOptionGroup filterFor(GallerySort sort, {bool includeHidden = false}) {
    final order = switch (sort) {
      GallerySort.oldest => const OrderOption(
        type: OrderOptionType.createDate,
        asc: true,
      ),
      GallerySort.modified => const OrderOption(
        type: OrderOptionType.updateDate,
        asc: false,
      ),
      _ => const OrderOption(type: OrderOptionType.createDate, asc: false),
    };
    return FilterOptionGroup(
      imageOption: const FilterOption(needTitle: true),
      videoOption: const FilterOption(needTitle: true),
      includeHiddenAssets: includeHidden,
      orders: [order],
    );
  }

  Future<List<AssetPathEntity>> getPaths({
    required GallerySort sort,
    required bool includeHidden,
  }) => PhotoManager.getAssetPathList(
    hasAll: true,
    type: RequestType.common,
    filterOption: filterFor(sort, includeHidden: includeHidden),
  );

  Future<List<AlbumModel>> buildAlbums(
    List<AssetPathEntity> paths, {
    RequestType type = RequestType.common,
    GallerySort sort = GallerySort.newest,
    bool includeHidden = false,
  }) async {
    final filter = filterFor(sort, includeHidden: includeHidden);
    final albums = await Future.wait(
      paths.map((path) async {
        try {
          final scopedPath = type == RequestType.common
              ? path
              : await AssetPathEntity.fromId(
                  path.id,
                  albumType: path.albumType,
                  type: type,
                  filterOption: filter,
                );
          final results = await Future.wait<dynamic>([
            scopedPath.assetCountAsync,
            scopedPath.getAssetListPaged(page: 0, size: 1, type: type),
          ]);
          final assets = results[1] as List<AssetEntity>;
          return AlbumModel(
            path: path,
            count: results[0] as int,
            cover: assets.isEmpty ? null : MediaModel(assets.first),
          );
        } catch (_) {
          return AlbumModel(path: path, count: 0);
        }
      }),
    );
    return albums.where((album) => album.count > 0).toList();
  }

  Future<List<MediaModel>> loadPage({
    AssetPathEntity? path,
    RequestType type = RequestType.common,
    required int page,
    int size = pageSize,
    required GallerySort sort,
    required bool includeHidden,
  }) async {
    final filter = filterFor(sort, includeHidden: includeHidden);
    List<AssetEntity> entities;
    if (path == null || path.isAll) {
      entities = await PhotoManager.getAssetListPaged(
        page: page,
        pageCount: size,
        type: type,
        filterOption: filter,
      );
    } else {
      final refreshed = await AssetPathEntity.fromId(
        path.id,
        albumType: path.albumType,
        type: type,
        filterOption: filter,
      );
      entities = await refreshed.getAssetListPaged(
        page: page,
        size: size,
        type: type,
      );
    }
    final result = entities.map(MediaModel.new).toList();
    if (sort == GallerySort.name) {
      result.sort(
        (a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()),
      );
    }
    return result;
  }

  Future<int> count({required RequestType type, required bool includeHidden}) =>
      PhotoManager.getAssetCount(
        type: type,
        filterOption: filterFor(
          GallerySort.newest,
          includeHidden: includeHidden,
        ),
      );

  Future<List<MediaModel>> resolveIds(Iterable<String> ids) async {
    final values = await Future.wait(ids.map(AssetEntity.fromId));
    return values.whereType<AssetEntity>().map(MediaModel.new).toList()
      ..sort((a, b) => b.date.compareTo(a.date));
  }

  Future<List<MediaModel>> search(
    String query, {
    RequestType type = RequestType.common,
    int maxResults = 120,
    int scanLimit = 4000,
    bool includeHidden = false,
  }) async {
    final normalized = query.trim().toLowerCase();
    if (normalized.isEmpty) return [];
    final matches = <MediaModel>[];
    const batchSize = 200;
    final pages = (scanLimit / batchSize).ceil();
    for (var page = 0; page < pages && matches.length < maxResults; page++) {
      final batch = await loadPage(
        type: type,
        page: page,
        size: batchSize,
        sort: GallerySort.newest,
        includeHidden: includeHidden,
      );
      if (batch.isEmpty) break;
      matches.addAll(
        batch.where((item) => item.title.toLowerCase().contains(normalized)),
      );
      if (batch.length < batchSize) break;
    }
    return matches.take(maxResults).toList();
  }

  Future<void> share(
    Iterable<MediaModel> media, {
    Rect? sharePositionOrigin,
  }) async {
    final files = <XFile>[];
    for (final item in media) {
      final file = await item.file;
      if (file != null) {
        files.add(XFile(file.path, mimeType: item.mimeType));
      }
    }
    if (files.isEmpty) throw StateError('No shareable files were available.');
    await SharePlus.instance.share(
      ShareParams(files: files, sharePositionOrigin: sharePositionOrigin),
    );
  }

  Future<Set<String>> delete(Iterable<MediaModel> media) async {
    final items = media.toList();
    final ids = items.map((item) => item.id).toList();
    if (ids.isEmpty) return {};
    List<String> deleted;
    if (Platform.isAndroid) {
      final version = int.tryParse(await PhotoManager.systemVersion()) ?? 0;
      deleted = version >= 30
          ? await PhotoManager.editor.android.moveToTrash(
              items.map((item) => item.asset).toList(),
            )
          : await PhotoManager.editor.deleteWithIds(ids);
    } else {
      deleted = await PhotoManager.editor.deleteWithIds(ids);
    }
    return deleted.toSet();
  }

  String formatBytes(int bytes) {
    if (bytes <= 0) return '0 B';
    const units = ['B', 'KB', 'MB', 'GB'];
    final index = math.min((math.log(bytes) / math.log(1024)).floor(), 3);
    final value = bytes / math.pow(1024, index);
    return '${value.toStringAsFixed(index == 0 ? 0 : 1)} ${units[index]}';
  }
}
