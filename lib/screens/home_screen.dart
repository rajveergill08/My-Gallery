import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/media_model.dart';
import '../providers/gallery_provider.dart';
import '../widgets/album_card.dart';
import '../widgets/category_card.dart';
import '../widgets/empty_state.dart';
import '../widgets/media_tile.dart';
import 'album_detail_screen.dart';
import 'all_photos_screen.dart';
import 'favourites_screen.dart';
import 'photo_viewer_screen.dart';
import 'recents_screen.dart';
import 'search_screen.dart';
import 'video_player_screen.dart';
import 'videos_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, required this.onSettingsTap});
  final VoidCallback onSettingsTap;

  void _open(BuildContext context, Widget page) =>
      Navigator.push(context, MaterialPageRoute(builder: (_) => page));

  @override
  Widget build(BuildContext context) {
    final gallery = context.watch<GalleryProvider>();
    if (gallery.isLoading && gallery.media.isEmpty) {
      return const SafeArea(child: Center(child: CircularProgressIndicator()));
    }
    if (gallery.errorMessage != null && gallery.media.isEmpty) {
      return SafeArea(
        child: EmptyState(
          icon: Icons.error_outline,
          title: 'Unable to Load Gallery',
          message: gallery.errorMessage!,
          actionLabel: 'Try Again',
          onAction: () => gallery.refresh(showFullLoader: true),
        ),
      );
    }
    final recent = gallery.media.take(9).toList();
    return SafeArea(
      child: RefreshIndicator(
        onRefresh: gallery.refresh,
        child: CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 14, 12, 0),
              sliver: SliverToBoxAdapter(
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'MyGallery',
                            style: Theme.of(context).textTheme.headlineMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: -1,
                                ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            _greeting(),
                            style: TextStyle(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton.filledTonal(
                      onPressed: () => _open(context, const SearchScreen()),
                      icon: const Icon(Icons.search_rounded),
                    ),
                    const SizedBox(width: 6),
                    IconButton(
                      onPressed: onSettingsTap,
                      icon: const Icon(Icons.settings_outlined),
                    ),
                  ],
                ),
              ),
            ),
            if (gallery.isLimited)
              SliverToBoxAdapter(
                child: Container(
                  margin: const EdgeInsets.fromLTRB(16, 18, 16, 0),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.secondaryContainer,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.photo_library_outlined),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'Showing only the photos and videos you selected.',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                      TextButton(
                        onPressed: () async {
                          await gallery.permissionService
                              .manageLimitedSelection();
                          await gallery.refresh(showFullLoader: true);
                        },
                        child: const Text('Manage'),
                      ),
                    ],
                  ),
                ),
              ),
            const SliverToBoxAdapter(child: _SectionTitle('Quick Access')),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverGrid.count(
                crossAxisCount: MediaQuery.sizeOf(context).width > 650 ? 4 : 2,
                childAspectRatio: 1.22,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                children: [
                  CategoryCard(
                    icon: Icons.schedule_rounded,
                    title: 'Recents',
                    count: '${gallery.allCount} items',
                    color: const Color(0xFF5B55D6),
                    onTap: () => _open(context, const RecentsScreen()),
                  ),
                  CategoryCard(
                    icon: Icons.photo_library_rounded,
                    title: 'All Photos',
                    count: '${gallery.photoCount} items',
                    color: const Color(0xFF007A85),
                    onTap: () => _open(context, const AllPhotosScreen()),
                  ),
                  CategoryCard(
                    icon: Icons.play_circle_rounded,
                    title: 'Videos',
                    count: '${gallery.videoCount} items',
                    color: const Color(0xFFB3265E),
                    onTap: () => _open(context, const VideosScreen()),
                  ),
                  CategoryCard(
                    icon: Icons.favorite_rounded,
                    title: 'Favourites',
                    count: '${gallery.favourites.length} items',
                    color: const Color(0xFFE15C71),
                    onTap: () => _open(context, const FavouritesScreen()),
                  ),
                ],
              ),
            ),
            if (gallery.albums.isNotEmpty) ...[
              const SliverToBoxAdapter(child: _SectionTitle('Albums')),
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 186,
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    scrollDirection: Axis.horizontal,
                    itemCount: gallery.albums.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 8),
                    itemBuilder: (_, index) => AlbumCard(
                      compact: true,
                      album: gallery.albums[index],
                      onTap: () => _open(
                        context,
                        AlbumDetailScreen(album: gallery.albums[index]),
                      ),
                    ),
                  ),
                ),
              ),
            ],
            const SliverToBoxAdapter(child: _SectionTitle('Recent Memories')),
            if (recent.isEmpty)
              const SliverToBoxAdapter(
                child: SizedBox(
                  height: 230,
                  child: EmptyState(
                    icon: Icons.photo_library_outlined,
                    title: 'Your Gallery Is Empty',
                    message: 'Photos and videos stored on your device will appear here.',
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                sliver: SliverGrid.builder(
                  itemCount: recent.length,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 4,
                    mainAxisSpacing: 4,
                  ),
                  itemBuilder: (_, index) => MediaTile(
                    item: recent[index],
                    selectionEnabled: false,
                    onTap: () => _openMedia(context, recent[index], recent),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _openMedia(
    BuildContext context,
    MediaModel item,
    List<MediaModel> source,
  ) {
    if (item.kind == MediaKind.video) {
      _open(context, VideoPlayerScreen(item: item));
      return;
    }
    final photos = source
        .where((entry) => entry.kind == MediaKind.photo)
        .toList();
    _open(
      context,
      PhotoViewerScreen(
        items: photos,
        initialIndex: photos.indexWhere((entry) => entry.id == item.id),
      ),
    );
  }

  String _greeting() {
    final hour = DateTime.now().hour;
    return hour < 12
        ? 'Good morning'
        : hour < 17
        ? 'Good afternoon'
        : 'Good evening';
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title);
  final String title;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 28, 20, 12),
    child: Text(
      title,
      style: Theme.of(context).textTheme.titleLarge
          ?.copyWith(fontWeight: FontWeight.w900, letterSpacing: -.4),
    ),
  );
}
