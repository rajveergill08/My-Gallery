import 'package:photo_manager/photo_manager.dart';

import 'media_model.dart';

class AlbumModel {
  const AlbumModel({required this.path, required this.count, this.cover});

  final AssetPathEntity path;
  final int count;
  final MediaModel? cover;

  String get id => path.id;
  String get name => path.name;
  bool get isAll => path.isAll;
}
