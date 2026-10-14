import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/media_model.dart';
import '../providers/gallery_provider.dart';
import 'gallery_screen.dart';

class FavouritesScreen extends StatefulWidget {
  const FavouritesScreen({super.key});
  @override
  State<FavouritesScreen> createState() => _FavouritesScreenState();
}

class _FavouritesScreenState extends State<FavouritesScreen> {
  Future<List<MediaModel>>? _future;
  int _lastCount = -1;

  @override
  Widget build(BuildContext context) {
    final count = context.select<GalleryProvider, int>(
      (p) => p.favourites.length,
    );
    if (_future == null || count != _lastCount) {
      _lastCount = count;
      _future = context.read<GalleryProvider>().favouriteMedia();
    }
    return FutureBuilder<List<MediaModel>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(
            appBar: AppBar(title: const Text('Favourites')),
            body: const Center(child: CircularProgressIndicator()),
          );
        }
        return GalleryScreen(
          title: 'Favourites',
          initialItems: snapshot.data ?? const [],
          emptyTitle: 'No Favourites Yet',
          emptyMessage:
              'Tap the heart icon on your favourite memories to see them here.',
        );
      },
    );
  }
}
