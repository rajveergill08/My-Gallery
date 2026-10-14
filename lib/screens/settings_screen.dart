import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/media_model.dart';
import '../providers/gallery_provider.dart';
import '../providers/settings_provider.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final gallery = context.watch<GalleryProvider>();
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 30),
        children: [
          const _Header('APPEARANCE'),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.palette_outlined),
                  title: const Text('Theme'),
                  subtitle: Text(_themeName(settings.themeMode)),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _themes(context, settings),
                ),
                ListTile(
                  leading: const Icon(Icons.grid_view_rounded),
                  title: const Text('Grid size'),
                  subtitle: Text('${settings.gridSize} columns'),
                  trailing: SizedBox(
                    width: 135,
                    child: Slider(
                      value: settings.gridSize.toDouble(),
                      min: 2,
                      max: 5,
                      divisions: 3,
                      onChanged: (value) => settings.setGridSize(value.round()),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const _Header('GALLERY'),
          Card(
            child: Column(
              children: [
                SwitchListTile(
                  secondary: const Icon(Icons.movie_outlined),
                  title: const Text('Show videos'),
                  subtitle: const Text('Include videos in mixed galleries'),
                  value: settings.showVideos,
                  onChanged: settings.toggleVideos,
                ),
                ListTile(
                  leading: const Icon(Icons.swap_vert_rounded),
                  title: const Text('Default sort order'),
                  subtitle: Text(settings.sortOrder.label),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _sortOptions(context, settings),
                ),
                SwitchListTile(
                  secondary: const Icon(Icons.visibility_off_outlined),
                  title: const Text('Show hidden media'),
                  subtitle: const Text('Availability depends on the device'),
                  value: settings.showHidden,
                  onChanged: settings.toggleHidden,
                ),
              ],
            ),
          ),
          const _Header('PRIVACY'),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.verified_user_outlined),
                  title: const Text('Permission status'),
                  subtitle: Text(gallery.permissionLabel),
                  trailing: gallery.isLimited
                      ? TextButton(
                          onPressed: () async {
                            await gallery.permissionService
                                .manageLimitedSelection();
                            await gallery.refresh(showFullLoader: true);
                          },
                          child: const Text('Manage'),
                        )
                      : null,
                ),
                ListTile(
                  leading: const Icon(Icons.settings_applications_outlined),
                  title: const Text('Manage permissions'),
                  trailing: const Icon(Icons.open_in_new, size: 18),
                  onTap: gallery.permissionService.openSettings,
                ),
                ListTile(
                  leading: const Icon(Icons.lock_outline),
                  title: const Text('Privacy information'),
                  subtitle: const Text('Your media stays on your device.'),
                  onTap: () => _privacy(context),
                ),
              ],
            ),
          ),
          const _Header('ABOUT'),
          const Card(
            child: Column(
              children: [
                ListTile(
                  leading: Icon(Icons.photo_library_outlined),
                  title: Text('MyGallery'),
                  subtitle: Text('Version 1.0.0'),
                ),
                ListTile(
                  leading: Icon(Icons.info_outline),
                  title: Text('About MyGallery'),
                  subtitle: Text('A beautiful, private offline gallery.'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _themeName(ThemeMode mode) => mode == ThemeMode.light
      ? 'Light mode'
      : mode == ThemeMode.dark
      ? 'Dark mode'
      : 'System default';

  void _themes(BuildContext context, SettingsProvider settings) =>
      showModalBottomSheet(
        context: context,
        showDragHandle: true,
        builder: (_) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: ThemeMode.values
                .map(
                  (mode) => ListTile(
                    leading: Icon(
                      settings.themeMode == mode
                          ? Icons.radio_button_checked
                          : Icons.radio_button_off,
                    ),
                    title: Text(_themeName(mode)),
                    onTap: () {
                      settings.setTheme(mode);
                      Navigator.pop(context);
                    },
                  ),
                )
                .toList(),
          ),
        ),
      );

  void _sortOptions(BuildContext context, SettingsProvider settings) =>
      showModalBottomSheet(
        context: context,
        showDragHandle: true,
        builder: (_) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: GallerySort.values
                .map(
                  (sort) => ListTile(
                    leading: Icon(
                      settings.sortOrder == sort
                          ? Icons.radio_button_checked
                          : Icons.radio_button_off,
                    ),
                    title: Text(sort.label),
                    onTap: () {
                      settings.setSortOrder(sort);
                      Navigator.pop(context);
                    },
                  ),
                )
                .toList(),
          ),
        ),
      );

  void _privacy(BuildContext context) => showModalBottomSheet(
    context: context,
    showDragHandle: true,
    builder: (_) => const SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(24, 4, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Private by design',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
            ),
            SizedBox(height: 14),
            Text(
              'MyGallery reads only the photos and videos you allow. Media, favourites and settings remain on this device. The app has no account, cloud upload or gallery analytics.',
              style: TextStyle(height: 1.5),
            ),
          ],
        ),
      ),
    ),
  );
}

class _Header extends StatelessWidget {
  const _Header(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(12, 26, 12, 8),
    child: Text(
      text,
      style: TextStyle(
        color: Theme.of(context).colorScheme.primary,
        fontSize: 12,
        fontWeight: FontWeight.w900,
        letterSpacing: 1.1,
      ),
    ),
  );
}
