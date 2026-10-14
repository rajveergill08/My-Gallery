import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/gallery_provider.dart';
import '../widgets/album_card.dart';
import '../widgets/empty_state.dart';
import 'album_detail_screen.dart';

class AlbumsScreen extends StatelessWidget {
  const AlbumsScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final gallery = context.watch<GalleryProvider>();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Albums'),
        actions: [
          IconButton(
            tooltip: 'Refresh albums',
            onPressed: gallery.refresh,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: gallery.isLoading
          ? const Center(child: CircularProgressIndicator())
          : gallery.albums.isEmpty
          ? const EmptyState(
              icon: Icons.photo_album_outlined,
              title: 'No Albums Found',
              message: 'Accessible device albums will appear here.',
            )
          : RefreshIndicator(
              onRefresh: gallery.refresh,
              child: GridView.builder(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                itemCount: gallery.albums.length,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: MediaQuery.sizeOf(context).width > 650
                      ? 3
                      : 2,
                  childAspectRatio: .86,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                ),
                itemBuilder: (_, index) => AlbumCard(
                  album: gallery.albums[index],
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          AlbumDetailScreen(album: gallery.albums[index]),
                    ),
                  ),
                ),
              ),
            ),
    );
  }
}
