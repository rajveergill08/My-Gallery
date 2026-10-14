import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/media_model.dart';
import '../providers/settings_provider.dart';
import '../screens/photo_viewer_screen.dart';
import '../screens/video_player_screen.dart';
import 'media_tile.dart';

class MediaGrid extends StatelessWidget {
  const MediaGrid({
    super.key,
    required this.items,
    this.padding = const EdgeInsets.all(16),
    this.shrinkWrap = false,
    this.physics,
    this.controller,
    this.selectionEnabled = true,
    this.onItemTap,
  });
  final List<MediaModel> items;
  final EdgeInsets padding;
  final bool shrinkWrap;
  final ScrollPhysics? physics;
  final ScrollController? controller;
  final bool selectionEnabled;
  final ValueChanged<MediaModel>? onItemTap;

  @override
  Widget build(BuildContext context) {
    final columns = context.watch<SettingsProvider>().gridSize;
    return GridView.builder(
      controller: controller,
      padding: padding,
      shrinkWrap: shrinkWrap,
      physics: physics,
      itemCount: items.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: columns,
        crossAxisSpacing: 4,
        mainAxisSpacing: 4,
      ),
      itemBuilder: (context, index) {
        final item = items[index];
        return MediaTile(
          item: item,
          selectionEnabled: selectionEnabled,
          onTap: () {
            if (onItemTap != null) {
              onItemTap!(item);
            } else {
              _open(context, item);
            }
          },
        );
      },
    );
  }

  void _open(BuildContext context, MediaModel item) {
    if (item.kind == MediaKind.video) {
      Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => VideoPlayerScreen(item: item)));
      return;
    }
    final photos = items
        .where((entry) => entry.kind == MediaKind.photo)
        .toList();
    final initialIndex = photos.indexWhere((entry) => entry.id == item.id);
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PhotoViewerScreen(
          items: photos,
          initialIndex: initialIndex < 0 ? 0 : initialIndex,
        ),
      ),
    );
  }
}
