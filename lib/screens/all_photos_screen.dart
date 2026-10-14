import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';

import 'gallery_screen.dart';

class AllPhotosScreen extends StatelessWidget {
  const AllPhotosScreen({super.key});
  @override
  Widget build(BuildContext context) => const GalleryScreen(
    title: 'All Photos',
    type: RequestType.image,
    emptyTitle: 'No Photos Found',
    emptyMessage: 'Photos stored on your device will appear here.',
  );
}
