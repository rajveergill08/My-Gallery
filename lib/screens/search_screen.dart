import 'dart:async';

import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:provider/provider.dart';

import '../models/album_model.dart';
import '../models/media_model.dart';
import '../providers/gallery_provider.dart';
import '../providers/settings_provider.dart';
import '../widgets/empty_state.dart';
import '../widgets/media_grid.dart';
import 'album_detail_screen.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});
  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final controller = TextEditingController();
  Timer? _debounce;
  String query = '';
  List<MediaModel> results = [];
  bool loading = false;
  String? error;
  int _generation = 0;

  @override
  void dispose() {
    _debounce?.cancel();
    controller.dispose();
    super.dispose();
  }

  void _changed(String value) {
    setState(() {
      query = value;
      error = null;
      if (value.trim().isEmpty) results = [];
    });
    _debounce?.cancel();
    if (value.trim().isEmpty) return;
    _debounce = Timer(const Duration(milliseconds: 450), () => _search(value));
  }

  Future<void> _search(String value) async {
    final generation = ++_generation;
    setState(() => loading = true);
    try {
      final gallery = context.read<GalleryProvider>();
      final settings = context.read<SettingsProvider>();
      final found = await gallery.mediaService.search(
        value,
        type: settings.showVideos ? RequestType.common : RequestType.image,
        includeHidden: settings.showHidden,
      );
      if (!mounted || generation != _generation) return;
      setState(() => results = found);
      await settings.addRecentSearch(value);
    } catch (exception) {
      if (mounted && generation == _generation) {
        setState(() => error = 'Search failed. $exception');
      }
    } finally {
      if (mounted && generation == _generation) setState(() => loading = false);
    }
  }

  List<AlbumModel> _albumResults(GalleryProvider gallery) {
    final normalized = query.trim().toLowerCase();
    if (normalized.isEmpty) return [];
    return gallery.albums
        .where((album) => album.name.toLowerCase().contains(normalized))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final gallery = context.watch<GalleryProvider>();
    final settings = context.watch<SettingsProvider>();
    final albumResults = _albumResults(gallery);
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Padding(
          padding: const EdgeInsets.only(right: 12),
          child: TextField(
            controller: controller,
            autofocus: true,
            textInputAction: TextInputAction.search,
            onChanged: _changed,
            onSubmitted: _search,
            decoration: InputDecoration(
              hintText: 'Search photos, videos, albums',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: query.isEmpty
                  ? null
                  : IconButton(
                      onPressed: () {
                        _generation++;
                        controller.clear();
                        _changed('');
                      },
                      icon: const Icon(Icons.close),
                    ),
            ),
          ),
        ),
      ),
      body: query.trim().isEmpty
          ? _recentSearches(settings)
          : loading
          ? const Center(child: CircularProgressIndicator())
          : error != null
          ? EmptyState(
              icon: Icons.error_outline,
              title: 'Search Unavailable',
              message: error!,
              actionLabel: 'Try Again',
              onAction: () => _search(query),
            )
          : results.isEmpty && albumResults.isEmpty
          ? const EmptyState(
              icon: Icons.search_off_rounded,
              title: 'No Results Found',
              message: 'Try another file name or album name.',
            )
          : _results(albumResults),
    );
  }

  Widget _recentSearches(SettingsProvider settings) {
    if (settings.recentSearches.isEmpty) {
      return const EmptyState(
        icon: Icons.manage_search_rounded,
        title: 'Search Your Gallery',
        message:
            'Search media file names and album names stored on this device.',
      );
    }
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Recent searches',
                style: Theme.of(context).textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
            ),
            TextButton(
              onPressed: settings.clearRecentSearches,
              child: const Text('Clear'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: settings.recentSearches
              .map(
                (value) => ActionChip(
                  label: Text(value),
                  avatar: const Icon(Icons.history, size: 18),
                  onPressed: () {
                    controller.text = value;
                    _changed(value);
                    _search(value);
                  },
                ),
              )
              .toList(),
        ),
      ],
    );
  }

  Widget _results(List<AlbumModel> albumResults) {
    return ListView(
      children: [
        if (albumResults.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
            child: Text(
              'Albums',
              style: Theme.of(context).textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
          ),
          ...albumResults.map(
            (album) => ListTile(
              leading: const CircleAvatar(
                child: Icon(Icons.photo_album_outlined),
              ),
              title: Text(album.name),
              subtitle: Text('${album.count} items'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => AlbumDetailScreen(album: album),
                ),
              ),
            ),
          ),
        ],
        if (results.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 4),
            child: Text(
              '${results.length} media results',
              style: Theme.of(context).textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
          ),
          MediaGrid(
            items: results,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            selectionEnabled: false,
          ),
        ],
      ],
    );
  }
}
