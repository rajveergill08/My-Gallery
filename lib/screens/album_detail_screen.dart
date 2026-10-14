import 'package:flutter/material.dart';

import '../models/album_model.dart';
import 'gallery_screen.dart';

class AlbumDetailScreen extends StatelessWidget {
  const AlbumDetailScreen({super.key, required this.album});
  final AlbumModel album;
  @override
  Widget build(BuildContext context) => GalleryScreen(
    title: album.name,
    path: album.path,
    emptyTitle: 'Empty Album',
    emptyMessage: 'There are no accessible photos or videos in this album.',
  );
}
