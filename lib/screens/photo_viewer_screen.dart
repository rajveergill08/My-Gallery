import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models/media_model.dart';
import '../providers/gallery_provider.dart';

class PhotoViewerScreen extends StatefulWidget {
  const PhotoViewerScreen({
    super.key,
    required this.items,
    required this.initialIndex,
  });

  final List<MediaModel> items;
  final int initialIndex;

  @override
  State<PhotoViewerScreen> createState() => _PhotoViewerScreenState();
}

class _PhotoViewerScreenState extends State<PhotoViewerScreen> {
  late final List<MediaModel> _items;
  late final PageController _pageController;
  late int _index;

  bool _controlsVisible = true;
  bool _currentPageZoomed = false;
  bool _sharing = false;
  bool _deleting = false;

  MediaModel? get _currentItem =>
      _items.isEmpty || _index >= _items.length ? null : _items[_index];

  @override
  void initState() {
    super.initState();
    _items = List<MediaModel>.of(widget.items);
    if (_items.isEmpty) {
      _index = 0;
    } else if (widget.initialIndex < 0) {
      _index = 0;
    } else if (widget.initialIndex >= _items.length) {
      _index = _items.length - 1;
    } else {
      _index = widget.initialIndex;
    }
    _pageController = PageController(initialPage: _index);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final item = _currentItem;
    if (item == null) {
      return const _UnavailableViewer();
    }

    final gallery = context.watch<GalleryProvider>();
    final isFavourite = gallery.isFavourite(item);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: Colors.black,
      ),
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          fit: StackFit.expand,
          children: [
            PageView.builder(
              controller: _pageController,
              physics: _currentPageZoomed
                  ? const NeverScrollableScrollPhysics()
                  : const PageScrollPhysics(),
              itemCount: _items.length,
              onPageChanged: (value) {
                setState(() {
                  _index = value;
                  _currentPageZoomed = false;
                });
              },
              itemBuilder: (context, itemIndex) => _ZoomableMediaPage(
                key: ValueKey(_items[itemIndex].id),
                item: _items[itemIndex],
                isCurrent: itemIndex == _index,
                onTap: () =>
                    setState(() => _controlsVisible = !_controlsVisible),
                onZoomChanged: (zoomed) {
                  if (itemIndex == _index &&
                      zoomed != _currentPageZoomed &&
                      mounted) {
                    setState(() => _currentPageZoomed = zoomed);
                  }
                },
              ),
            ),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: AnimatedSlide(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                offset: _controlsVisible ? Offset.zero : const Offset(0, -1),
                child: _TopBar(
                  item: item,
                  position: _index + 1,
                  total: _items.length,
                  isFavourite: isFavourite,
                  onBack: () => Navigator.maybePop(context),
                  onFavourite: () => _toggleFavourite(item),
                ),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: AnimatedSlide(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                offset: _controlsVisible ? Offset.zero : const Offset(0, 1),
                child: _BottomBar(
                  sharing: _sharing,
                  deleting: _deleting,
                  onShare: _sharing || _deleting ? null : () => _share(item),
                  onInfo: _deleting ? null : () => _showInfo(item),
                  onDelete: _sharing || _deleting
                      ? null
                      : () => _confirmDelete(item),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _toggleFavourite(MediaModel item) async {
    try {
      await context.read<GalleryProvider>().toggleFavourite(item);
    } catch (_) {
      _showMessage('Could not update this favourite. Please try again.');
    }
  }

  Future<void> _share(MediaModel item) async {
    setState(() => _sharing = true);
    try {
      await context.read<GalleryProvider>().mediaService.share([item]);
    } catch (_) {
      _showMessage(
        'Could not share this item. It may have been moved or deleted.',
      );
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  Future<void> _confirmDelete(MediaModel item) async {
    final mediaName = item.kind == MediaKind.video ? 'video' : 'photo';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(Icons.delete_outline_rounded),
        title: const Text('Delete this item?'),
        content: Text(
          'This $mediaName will be moved to the device\'s trash/recycle '
          'system if supported.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _deleting = true);
    var closeViewer = false;
    try {
      final gallery = context.read<GalleryProvider>();
      final deletedIds = await gallery.mediaService.delete([item]);
      if (!mounted) return;

      if (!deletedIds.contains(item.id)) {
        _showMessage('The item was not deleted.');
        return;
      }

      await gallery.removeDeleted(deletedIds);
      if (!mounted) return;

      final oldIndex = _index;
      _items.removeWhere((entry) => deletedIds.contains(entry.id));
      if (_items.isEmpty) {
        closeViewer = true;
      } else {
        setState(() {
          _index = oldIndex >= _items.length ? _items.length - 1 : oldIndex;
          _currentPageZoomed = false;
        });
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _pageController.hasClients) {
            _pageController.jumpToPage(_index);
          }
        });
        _showMessage('$mediaName deleted.');
      }
    } catch (_) {
      _showMessage(
        'Could not delete this $mediaName. It may have been moved, or access '
        'may have changed.',
      );
    } finally {
      if (mounted) setState(() => _deleting = false);
    }

    if (closeViewer && mounted) {
      final messenger = ScaffoldMessenger.of(context);
      Navigator.pop(context);
      messenger.showSnackBar(SnackBar(content: Text('$mediaName deleted.')));
    }
  }

  void _showInfo(MediaModel item) {
    final gallery = context.read<GalleryProvider>();
    final lazyDetails = _loadLazyDetails(item, gallery);
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) => _DetailsSheet(
        item: item,
        lazyDetails: lazyDetails,
        formatDate: _formatDate,
        formatDuration: _formatDuration,
      ),
    );
  }

  Future<_LazyDetails> _loadLazyDetails(
    MediaModel item,
    GalleryProvider gallery,
  ) async {
    String fileSize = 'Not available';
    String location = 'Not available';

    try {
      final bytes = await item.fileSize;
      fileSize = gallery.mediaService.formatBytes(bytes);
    } catch (_) {
      // The asset may have been deleted or access may have changed.
    }

    try {
      final coordinates = await item.location;
      if (coordinates != null &&
          (coordinates.latitude != 0 || coordinates.longitude != 0)) {
        location =
            '${coordinates.latitude.toStringAsFixed(5)}, '
            '${coordinates.longitude.toStringAsFixed(5)}';
      }
    } catch (_) {
      // Location is optional and can be unavailable without extra permission.
    }

    return _LazyDetails(fileSize: fileSize, location: location);
  }

  String _formatDate(DateTime value) {
    final local = value.toLocal();
    final day = local.day.toString().padLeft(2, '0');
    final month = local.month.toString().padLeft(2, '0');
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '${local.year}-$month-$day  $hour:$minute';
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return hours > 0
        ? '$hours:$minutes:$seconds'
        : '${duration.inMinutes}:$seconds';
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}

class _ZoomableMediaPage extends StatefulWidget {
  const _ZoomableMediaPage({
    super.key,
    required this.item,
    required this.isCurrent,
    required this.onTap,
    required this.onZoomChanged,
  });

  final MediaModel item;
  final bool isCurrent;
  final VoidCallback onTap;
  final ValueChanged<bool> onZoomChanged;

  @override
  State<_ZoomableMediaPage> createState() => _ZoomableMediaPageState();
}

class _ZoomableMediaPageState extends State<_ZoomableMediaPage>
    with SingleTickerProviderStateMixin {
  late Future<File?> _file;
  late Future<Uint8List?> _videoThumbnail;
  final TransformationController _transformationController =
      TransformationController();
  late final AnimationController _zoomAnimationController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 220),
  )..addListener(_applyZoomAnimation);

  Animation<Matrix4>? _zoomAnimation;
  TapDownDetails? _doubleTapDetails;
  bool _zoomed = false;

  @override
  void initState() {
    super.initState();
    _loadMedia();
    _transformationController.addListener(_handleTransformChanged);
  }

  @override
  void didUpdateWidget(covariant _ZoomableMediaPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.item.id != widget.item.id) {
      _loadMedia();
      _transformationController.value = Matrix4.identity();
    }
    if (!oldWidget.isCurrent && widget.isCurrent) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) widget.onZoomChanged(_zoomed);
      });
    }
  }

  void _loadMedia() {
    _file = _loadOriginalFile(widget.item);
    _videoThumbnail = widget.item.thumbnail(size: 1440);
  }

  Future<File?> _loadOriginalFile(MediaModel item) async {
    try {
      final original = await item.originFile;
      if (original != null && await original.exists()) return original;
    } catch (_) {
      // Fall back to the display file below.
    }
    try {
      final displayFile = await item.file;
      if (displayFile != null && await displayFile.exists()) return displayFile;
    } catch (_) {
      // The caller displays a recoverable unavailable state.
    }
    return null;
  }

  @override
  void dispose() {
    _transformationController
      ..removeListener(_handleTransformChanged)
      ..dispose();
    _zoomAnimationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.onTap,
      onDoubleTapDown: (details) => _doubleTapDetails = details,
      onDoubleTap: _handleDoubleTap,
      child: InteractiveViewer(
        transformationController: _transformationController,
        minScale: 1,
        maxScale: 5,
        panEnabled: _zoomed,
        scaleEnabled: true,
        clipBehavior: Clip.none,
        child: SizedBox.expand(
          child: widget.item.kind == MediaKind.video
              ? _buildVideoPreview()
              : _buildPhoto(),
        ),
      ),
    );
  }

  Widget _buildPhoto() => FutureBuilder<File?>(
    future: _file,
    builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done) {
        return const _ViewerLoading();
      }
      final file = snapshot.data;
      if (snapshot.hasError || file == null) {
        return _ViewerError(
          message: 'This photo is no longer available.',
          onRetry: _retry,
        );
      }
      return Image.file(
        file,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.high,
        gaplessPlayback: true,
        semanticLabel: widget.item.title,
        frameBuilder: (context, child, frame, loadedSynchronously) {
          if (loadedSynchronously || frame != null) return child;
          return const _ViewerLoading();
        },
        errorBuilder: (context, _, _) => _ViewerError(
          message: 'This photo could not be displayed.',
          onRetry: _retry,
        ),
      );
    },
  );

  Widget _buildVideoPreview() => FutureBuilder<Uint8List?>(
    future: _videoThumbnail,
    builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done) {
        return const _ViewerLoading();
      }
      final bytes = snapshot.data;
      if (snapshot.hasError || bytes == null) {
        return _ViewerError(
          message: 'This video is no longer available.',
          onRetry: _retry,
        );
      }
      return Stack(
        fit: StackFit.expand,
        children: [
          Image.memory(bytes, fit: BoxFit.contain, gaplessPlayback: true),
          const Center(
            child: Icon(
              Icons.play_circle_fill_rounded,
              color: Colors.white,
              size: 78,
              shadows: [Shadow(color: Colors.black54, blurRadius: 16)],
            ),
          ),
        ],
      );
    },
  );

  void _retry() {
    setState(_loadMedia);
  }

  void _handleDoubleTap() {
    final target = _zoomed
        ? Matrix4.identity()
        : _zoomAt(_doubleTapDetails?.localPosition ?? Offset.zero, 2.5);
    _zoomAnimation =
        Matrix4Tween(
          begin: Matrix4.copy(_transformationController.value),
          end: target,
        ).animate(
          CurvedAnimation(
            parent: _zoomAnimationController,
            curve: Curves.easeOutCubic,
          ),
        );
    _zoomAnimationController.forward(from: 0);
  }

  Matrix4 _zoomAt(Offset position, double scale) => Matrix4.identity()
    ..translateByDouble(
      -position.dx * (scale - 1),
      -position.dy * (scale - 1),
      0,
      1,
    )
    ..scaleByDouble(scale, scale, scale, 1);

  void _applyZoomAnimation() {
    final animation = _zoomAnimation;
    if (animation != null) {
      _transformationController.value = animation.value;
    }
  }

  void _handleTransformChanged() {
    final zoomed = _transformationController.value.getMaxScaleOnAxis() > 1.01;
    if (zoomed == _zoomed) return;
    if (mounted) setState(() => _zoomed = zoomed);
    if (widget.isCurrent) widget.onZoomChanged(zoomed);
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.item,
    required this.position,
    required this.total,
    required this.isFavourite,
    required this.onBack,
    required this.onFavourite,
  });

  final MediaModel item;
  final int position;
  final int total;
  final bool isFavourite;
  final VoidCallback onBack;
  final VoidCallback onFavourite;

  @override
  Widget build(BuildContext context) => Container(
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Colors.black87, Colors.black54],
      ),
    ),
    child: SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(6, 4, 8, 10),
        child: Row(
          children: [
            IconButton(
              tooltip: 'Back',
              onPressed: onBack,
              icon: const Icon(Icons.arrow_back_rounded),
              color: Colors.white,
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    item.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '$position of $total',
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: isFavourite
                  ? 'Remove from favourites'
                  : 'Add to favourites',
              onPressed: onFavourite,
              icon: AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                child: Icon(
                  isFavourite
                      ? Icons.favorite_rounded
                      : Icons.favorite_border_rounded,
                  key: ValueKey(isFavourite),
                  color: isFavourite ? Colors.redAccent : Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _BottomBar extends StatelessWidget {
  const _BottomBar({
    required this.sharing,
    required this.deleting,
    required this.onShare,
    required this.onInfo,
    required this.onDelete,
  });

  final bool sharing;
  final bool deleting;
  final VoidCallback? onShare;
  final VoidCallback? onInfo;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) => Container(
    color: Colors.black.withValues(alpha: .78),
    child: SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 10, 24, 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _ViewerAction(
              icon: Icons.share_outlined,
              label: 'Share',
              busy: sharing,
              onTap: onShare,
            ),
            _ViewerAction(
              icon: Icons.info_outline_rounded,
              label: 'Details',
              onTap: onInfo,
            ),
            _ViewerAction(
              icon: Icons.delete_outline_rounded,
              label: 'Delete',
              busy: deleting,
              onTap: onDelete,
            ),
          ],
        ),
      ),
    ),
  );
}

class _ViewerAction extends StatelessWidget {
  const _ViewerAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.busy = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool busy;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: label,
    child: InkResponse(
      onTap: onTap,
      radius: 34,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 24,
              height: 24,
              child: busy
                  ? const CircularProgressIndicator(
                      strokeWidth: 2.2,
                      color: Colors.white,
                    )
                  : Icon(
                      icon,
                      color: onTap == null ? Colors.white38 : Colors.white,
                    ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: onTap == null ? Colors.white38 : Colors.white,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _DetailsSheet extends StatelessWidget {
  const _DetailsSheet({
    required this.item,
    required this.lazyDetails,
    required this.formatDate,
    required this.formatDuration,
  });

  final MediaModel item;
  final Future<_LazyDetails> lazyDetails;
  final String Function(DateTime) formatDate;
  final String Function(Duration) formatDuration;

  @override
  Widget build(BuildContext context) {
    final kind = item.kind == MediaKind.video ? 'Video' : 'Photo';
    final resolution = item.width > 0 && item.height > 0
        ? '${item.width} × ${item.height}'
        : 'Not available';

    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          24,
          0,
          24,
          24 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    item.kind == MediaKind.video
                        ? Icons.movie_outlined
                        : Icons.image_outlined,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Details',
                        style: Theme.of(context).textTheme.titleLarge
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      Text(
                        item.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            _Detail(label: 'File name', value: item.title),
            _Detail(label: 'Date', value: formatDate(item.date)),
            _Detail(label: 'Modified', value: formatDate(item.modifiedDate)),
            _Detail(label: 'Resolution', value: resolution),
            _Detail(label: 'Media type', value: kind),
            if (item.mimeType != null)
              _Detail(label: 'Format', value: item.mimeType!),
            if (item.kind == MediaKind.video && item.duration != null)
              _Detail(label: 'Duration', value: formatDuration(item.duration!)),
            FutureBuilder<_LazyDetails>(
              future: lazyDetails,
              builder: (context, snapshot) {
                final waiting =
                    snapshot.connectionState != ConnectionState.done;
                return Column(
                  children: [
                    _Detail(
                      label: 'File size',
                      value: waiting
                          ? 'Loading…'
                          : snapshot.data?.fileSize ?? 'Not available',
                    ),
                    _Detail(
                      label: 'Location',
                      value: waiting
                          ? 'Loading…'
                          : snapshot.data?.location ?? 'Not available',
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _Detail extends StatelessWidget {
  const _Detail({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 104,
          child: Text(
            label,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        Expanded(
          child: SelectableText(
            value,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
      ],
    ),
  );
}

class _LazyDetails {
  const _LazyDetails({required this.fileSize, required this.location});

  final String fileSize;
  final String location;
}

class _ViewerLoading extends StatelessWidget {
  const _ViewerLoading();

  @override
  Widget build(BuildContext context) => const Center(
    child: SizedBox(
      width: 34,
      height: 34,
      child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
    ),
  );
}

class _ViewerError extends StatelessWidget {
  const _ViewerError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.broken_image_outlined,
            color: Colors.white54,
            size: 58,
          ),
          const SizedBox(height: 16),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white70),
          ),
          const SizedBox(height: 12),
          TextButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Try again'),
            style: TextButton.styleFrom(foregroundColor: Colors.white),
          ),
        ],
      ),
    ),
  );
}

class _UnavailableViewer extends StatelessWidget {
  const _UnavailableViewer();

  @override
  Widget build(BuildContext context) => AnnotatedRegion<SystemUiOverlayStyle>(
    value: SystemUiOverlayStyle.light,
    child: Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      body: const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.hide_image_outlined, color: Colors.white54, size: 58),
              SizedBox(height: 16),
              Text(
                'This item is no longer available.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white70),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
