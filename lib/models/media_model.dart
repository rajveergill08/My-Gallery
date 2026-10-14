import 'dart:io';
import 'dart:typed_data';

import 'package:photo_manager/photo_manager.dart';

enum MediaKind { photo, video }

enum GallerySort { newest, oldest, modified, name }

extension GallerySortLabel on GallerySort {
  String get label => switch (this) {
    GallerySort.newest => 'Newest first',
    GallerySort.oldest => 'Oldest first',
    GallerySort.modified => 'Date modified',
    GallerySort.name => 'Name',
  };
}

class MediaModel {
  const MediaModel(this.asset);

  final AssetEntity asset;

  String get id => asset.id;
  String get title {
    final value = asset.title?.trim();
    if (value != null && value.isNotEmpty) return value;
    return kind == MediaKind.video ? 'Video' : 'Photo';
  }

  MediaKind get kind =>
      asset.type == AssetType.video ? MediaKind.video : MediaKind.photo;
  DateTime get date => asset.createDateTime;
  DateTime get modifiedDate => asset.modifiedDateTime;
  Duration? get duration =>
      kind == MediaKind.video ? Duration(seconds: asset.duration) : null;
  int get width => asset.orientatedWidth;
  int get height => asset.orientatedHeight;
  String? get mimeType => asset.mimeType;

  Future<Uint8List?> thumbnail({int size = 360}) =>
      asset.thumbnailDataWithSize(ThumbnailSize.square(size));
  Future<File?> get file => asset.file;
  Future<File?> get originFile => asset.originFile;
  Future<int> get fileSize => asset.fileSize;
  Future<LatLng?> get location async => asset.latLng ?? asset.latlngAsync();
}
