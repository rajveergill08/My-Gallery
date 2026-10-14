import 'package:flutter/material.dart';

import 'gallery_screen.dart';

class RecentsScreen extends StatelessWidget {
  const RecentsScreen({super.key});
  @override
  Widget build(BuildContext context) => const GalleryScreen(
    title: 'Recents',
    groupByDate: true,
    emptyTitle: 'No Recent Memories',
    emptyMessage: 'Recently created photos and videos will appear here.',
  );
}
