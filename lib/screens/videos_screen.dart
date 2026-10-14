import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';

import 'gallery_screen.dart';

class VideosScreen extends StatelessWidget {
  const VideosScreen({super.key});
  @override
  Widget build(BuildContext context) => const GalleryScreen(
    title: 'Videos',
    type: RequestType.video,
    emptyTitle: 'No Videos Found',
    emptyMessage: 'Videos stored on your device will appear here.',
  );
}
