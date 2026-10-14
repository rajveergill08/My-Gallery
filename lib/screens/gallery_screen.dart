import 'dart:async';

import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:provider/provider.dart';

import '../models/media_model.dart';
import '../providers/gallery_provider.dart';
import '../providers/settings_provider.dart';
import '../services/media_service.dart';
import '../widgets/empty_state.dart';
import '../widgets/media_grid.dart';
import '../widgets/media_tile.dart';
import 'photo_viewer_screen.dart';
import 'search_screen.dart';
import 'video_player_screen.dart';

class GalleryScreen extends StatefulWidget {
  const GalleryScreen({
    super.key,
    required this.title,
    this.path,
    this.type = RequestType.common,
    this.initialItems,
    this.emptyTitle = 'Nothing Here Yet',
    this.emptyMessage = 'Your media will appear here.',
    this.groupByDate = false,
  });

  final String title;
  final AssetPathEntity? path;
  final RequestType type;
  final List<MediaModel>? initialItems;
  final String emptyTitle;
  final String emptyMessage;
  final bool groupByDate;

  @override
  State<GalleryScreen> createState() => _GalleryScreenState();
}

class _GalleryScreenState extends State<GalleryScreen> {
  final ScrollController _scrollController = ScrollController();
  final List<MediaModel> _items = [];
  late final GalleryProvider _gallery;
  var _page = 0;
  var _hasMore = true;
  var _loading = true;
  var _loadingMore = false;
  var _working = false;
  String? _error;
  late GallerySort _sort;

  bool get _isFixed => widget.initialItems != null;

  RequestType _effectiveType(SettingsProvider settings) {
    if (widget.type == RequestType.common && !settings.showVideos) {
      return RequestType.image;
    }
    return widget.type;
  }

  @override
  void initState() {
    super.initState();
    _gallery = context.read<GalleryProvider>();
    _sort = widget.groupByDate
        ? GallerySort.newest
        : context.read<SettingsProvider>().sortOrder;
    _scrollController.addListener(_onScroll);
    if (_isFixed) {
      _items.addAll(widget.initialItems!);
      _loading = false;
      _hasMore = false;
    } else {
      unawaited(_reload());
    }
  }

  @override
  void didUpdateWidget(covariant GalleryScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_isFixed && oldWidget.initialItems != widget.initialItems) {
      _items
        ..clear()
        ..addAll(widget.initialItems!);
    }
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    _gallery.clearSelection();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.extentAfter < 700) unawaited(_loadMore());
  }

  Future<void> _reload() async {
    setState(() {
      _page = 0;
      _hasMore = true;
      _loading = true;
      _error = null;
      _items.clear();
    });
    if (_sort == GallerySort.name) {
      await _loadAllForName();
    } else {
      await _loadMore(initial: true);
    }
  }

  Future<void> _loadAllForName() async {
    final settings = context.read<SettingsProvider>();
    final service = context.read<GalleryProvider>().mediaService;
    try {
      var page = 0;
      const size = 200;
      final all = <MediaModel>[];
      while (mounted) {
        final batch = await service.loadPage(
          path: widget.path,
          type: _effectiveType(settings),
          page: page,
          size: size,
          sort: _sort,
          includeHidden: settings.showHidden,
        );
        all.addAll(batch);
        if (batch.length < size) break;
        page++;
      }
      all.sort(
        (a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()),
      );
      if (!mounted) return;
      setState(() {
        _items.addAll(all);
        _hasMore = false;
      });
    } catch (error) {
      if (mounted) setState(() => _error = 'Could not load media. $error');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadMore({bool initial = false}) async {
    if (_isFixed || !_hasMore || _loadingMore) return;
    _loadingMore = true;
    if (!initial && mounted) setState(() {});
    final settings = context.read<SettingsProvider>();
    final service = context.read<GalleryProvider>().mediaService;
    try {
      final batch = await service.loadPage(
        path: widget.path,
        type: _effectiveType(settings),
        page: _page,
        sort: _sort,
        includeHidden: settings.showHidden,
      );
      if (!mounted) return;
      setState(() {
        final existing = _items.map((item) => item.id).toSet();
        _items.addAll(batch.where((item) => existing.add(item.id)));
        _hasMore = batch.length == MediaService.pageSize;
        _page++;
        _error = null;
      });
    } catch (error) {
      if (mounted) setState(() => _error = 'Could not load media. $error');
    } finally {
      _loadingMore = false;
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final gallery = context.watch<GalleryProvider>();
    final selecting = gallery.selected.isNotEmpty;
    return PopScope(
      canPop: !selecting,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && selecting) gallery.clearSelection();
      },
      child: Scaffold(
        appBar: AppBar(
          leading: selecting
              ? IconButton(
                  onPressed: gallery.clearSelection,
                  icon: const Icon(Icons.close),
                )
              : null,
          title: Text(
            selecting ? '${gallery.selected.length} selected' : widget.title,
          ),
          actions: selecting ? _selectionActions(gallery) : _normalActions(),
        ),
        body: Stack(
          children: [
            Positioned.fill(child: _body()),
            if (_working)
              const Positioned.fill(
                child: ColoredBox(
                  color: Color(0x66000000),
                  child: Center(child: CircularProgressIndicator()),
                ),
              ),
          ],
        ),
      ),
    );
  }

  List<Widget> _normalActions() => [
    IconButton(
      onPressed: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const SearchScreen()),
      ),
      icon: const Icon(Icons.search),
    ),
    if (!widget.groupByDate)
      PopupMenuButton<GallerySort>(
        initialValue: _sort,
        onSelected: (value) async {
          _sort = value;
          await context.read<SettingsProvider>().setSortOrder(value);
          if (!_isFixed) await _reload();
        },
        icon: const Icon(Icons.sort_rounded),
        itemBuilder: (_) => GallerySort.values
            .map(
              (value) =>
                  PopupMenuItem(value: value, child: Text(value.label)),
            )
            .toList(),
      ),
  ];

  List<Widget> _selectionActions(GalleryProvider gallery) => [
    IconButton(
      tooltip: 'Select loaded items',
      onPressed: () => gallery.selectAll(_items),
      icon: const Icon(Icons.select_all_rounded),
    ),
    IconButton(
      tooltip: 'Favourite',
      onPressed: () => gallery.favouriteSelected(_items),
      icon: const Icon(Icons.favorite_outline),
    ),
    IconButton(
      tooltip: 'Share',
      onPressed: _shareSelected,
      icon: const Icon(Icons.share_outlined),
    ),
    IconButton(
      tooltip: 'Delete',
      onPressed: _confirmDelete,
      icon: const Icon(Icons.delete_outline),
    ),
  ];

  Widget _body() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null && _items.isEmpty) {
      return EmptyState(
        icon: Icons.error_outline,
        title: 'Unable to Load Gallery',
        message: _error!,
        actionLabel: 'Try Again',
        onAction: _reload,
      );
    }
    if (_items.isEmpty) {
      return EmptyState(
        icon: Icons.photo_library_outlined,
        title: widget.emptyTitle,
        message: widget.emptyMessage,
      );
    }
    if (widget.groupByDate) return _groupedBody();
    return RefreshIndicator(
      onRefresh: _isFixed ? () async {} : _reload,
      child: MediaGrid(items: _items, controller: _scrollController),
    );
  }

  Widget _groupedBody() {
    final groups = <String, List<MediaModel>>{};
    for (final item in _items) {
      groups.putIfAbsent(_dateGroup(item.date), () => []).add(item);
    }
    return RefreshIndicator(
      onRefresh: _reload,
      child: CustomScrollView(
        controller: _scrollController,
        slivers: [
          for (final entry in groups.entries) ...[
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 22, 18, 10),
                child: Text(
                  entry.key,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverGrid.builder(
                itemCount: entry.value.length,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: context.read<SettingsProvider>().gridSize,
                  crossAxisSpacing: 4,
                  mainAxisSpacing: 4,
                ),
                itemBuilder: (_, index) {
                  final item = entry.value[index];
                  return MediaTile(item: item, onTap: () => _openItem(item));
                },
              ),
            ),
          ],
          if (_loadingMore)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              ),
            ),
          const SliverToBoxAdapter(child: SizedBox(height: 24)),
        ],
      ),
    );
  }

  String _dateGroup(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(date.year, date.month, date.day);
    final difference = today.difference(day).inDays;
    if (difference == 0) return 'Today';
    if (difference == 1) return 'Yesterday';
    if (difference < 7) return 'This Week';
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return '${months[date.month - 1]} ${date.year}';
  }

  void _openItem(MediaModel item) {
    if (item.kind == MediaKind.video) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => VideoPlayerScreen(item: item)),
      );
      return;
    }
    final photos = _items
        .where((entry) => entry.kind == MediaKind.photo)
        .toList();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PhotoViewerScreen(
          items: photos,
          initialIndex: photos.indexWhere((entry) => entry.id == item.id),
        ),
      ),
    );
  }

  Future<void> _shareSelected() async {
    final gallery = context.read<GalleryProvider>();
    final items = gallery.selectedFrom(_items);
    setState(() => _working = true);
    try {
      await gallery.mediaService.share(items);
      gallery.clearSelection();
    } catch (error) {
      if (mounted) _message('Could not share the selected media. $error');
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _confirmDelete() async {
    final gallery = context.read<GalleryProvider>();
    final selected = gallery.selectedFrom(_items);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        icon: const Icon(Icons.delete_outline_rounded),
        title: Text(
          selected.length == 1
              ? 'Delete this item?'
              : 'Delete ${selected.length} items?',
        ),
        content: const Text(
          "On supported Android versions, the selected media will be moved to the device's trash. Older Android versions may delete it permanently.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _working = true);
    try {
      final deleted = await gallery.mediaService.delete(selected);
      if (!mounted) return;
      setState(() => _items.removeWhere((item) => deleted.contains(item.id)));
      await gallery.removeDeleted(deleted);
      gallery.clearSelection();
      if (deleted.isEmpty) _message('Deletion was cancelled or not permitted.');
    } catch (error) {
      if (mounted) _message('Could not delete the selected media. $error');
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  void _message(String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
}
