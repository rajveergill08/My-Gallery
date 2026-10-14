import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/media_model.dart';
import '../providers/gallery_provider.dart';

class MediaThumbnail extends StatefulWidget {
  const MediaThumbnail({
    super.key,
    required this.item,
    this.size = 360,
    this.fit = BoxFit.cover,
  });
  final MediaModel item;
  final int size;
  final BoxFit fit;

  @override
  State<MediaThumbnail> createState() => _MediaThumbnailState();
}

class _MediaThumbnailState extends State<MediaThumbnail> {
  late Future<Uint8List?> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.item.thumbnail(size: widget.size);
  }

  @override
  void didUpdateWidget(covariant MediaThumbnail oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.item.id != widget.item.id || oldWidget.size != widget.size) {
      _future = widget.item.thumbnail(size: widget.size);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Uint8List?>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return ColoredBox(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: const Center(
              child: SizedBox.square(
                dimension: 22,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
        }
        final bytes = snapshot.data;
        if (bytes == null || bytes.isEmpty || snapshot.hasError) {
          return ColoredBox(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: Icon(
              widget.item.kind == MediaKind.video
                  ? Icons.movie_outlined
                  : Icons.broken_image_outlined,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          );
        }
        return Image.memory(
          bytes,
          fit: widget.fit,
          gaplessPlayback: true,
          errorBuilder: (_, _, _) => ColoredBox(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: const Icon(Icons.broken_image_outlined),
          ),
        );
      },
    );
  }
}

class MediaTile extends StatelessWidget {
  const MediaTile({
    super.key,
    required this.item,
    required this.onTap,
    this.borderRadius = 9,
    this.selectionEnabled = true,
  });
  final MediaModel item;
  final VoidCallback onTap;
  final double borderRadius;
  final bool selectionEnabled;

  String _duration(Duration value) =>
      '${value.inMinutes}:${(value.inSeconds % 60).toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final selected = context.select<GalleryProvider, bool>(
      (provider) => provider.selected.contains(item.id),
    );
    final favourite = context.select<GalleryProvider, bool>(
      (provider) => provider.favourites.contains(item.id),
    );
    final selectionActive = context.select<GalleryProvider, bool>(
      (provider) => provider.selected.isNotEmpty,
    );
    final gallery = context.read<GalleryProvider>();
    return Semantics(
      label: item.title,
      selected: selected,
      button: true,
      child: GestureDetector(
        onTap: selectionEnabled && selectionActive
            ? () => gallery.toggleSelection(item)
            : onTap,
        onLongPress: selectionEnabled
            ? () => gallery.toggleSelection(item)
            : null,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(borderRadius),
          child: Stack(
            fit: StackFit.expand,
            children: [
              MediaThumbnail(item: item),
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Color(0x66000000)],
                  ),
                ),
              ),
              if (item.kind == MediaKind.video)
                Positioned(
                  left: 7,
                  bottom: 6,
                  child: Row(
                    children: [
                      const Icon(
                        Icons.play_circle_fill_rounded,
                        size: 17,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _duration(item.duration ?? Duration.zero),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              if (favourite)
                const Positioned(
                  right: 7,
                  bottom: 7,
                  child: Icon(
                    Icons.favorite_rounded,
                    size: 17,
                    color: Colors.white,
                  ),
                ),
              if (selectionEnabled && selectionActive)
                Positioned(
                  right: 6,
                  top: 6,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    width: 25,
                    height: 25,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: selected
                          ? Theme.of(context).colorScheme.primary
                          : Colors.black45,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: selected
                        ? const Icon(Icons.check, size: 16, color: Colors.white)
                        : null,
                  ),
                ),
              if (selected)
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: Theme.of(context).colorScheme.primary,
                      width: 4,
                    ),
                    borderRadius: BorderRadius.circular(borderRadius),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
