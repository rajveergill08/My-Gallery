import 'dart:async';

import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:provider/provider.dart';

import '../providers/gallery_provider.dart';
import 'main_shell.dart';

class PermissionScreen extends StatefulWidget {
  const PermissionScreen({super.key});
  @override
  State<PermissionScreen> createState() => _PermissionScreenState();
}

class _PermissionScreenState extends State<PermissionScreen>
    with WidgetsBindingObserver {
  bool _requesting = false;
  bool _attempted = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _attempted =
        context.read<GalleryProvider>().permissionState ==
        PermissionState.denied;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(_checkAfterSettings());
  }

  Future<void> _checkAfterSettings() async {
    final gallery = context.read<GalleryProvider>();
    await gallery.checkPermission();
    if (gallery.hasAccess) await _enterGallery();
  }

  Future<void> _request() async {
    if (_requesting) return;
    final gallery = context.read<GalleryProvider>();
    setState(() {
      _requesting = true;
      _attempted = true;
    });
    await gallery.requestPermission();
    if (!mounted) return;
    setState(() => _requesting = false);
    if (gallery.hasAccess) await _enterGallery();
  }

  Future<void> _enterGallery() async {
    final gallery = context.read<GalleryProvider>();
    await gallery.initialize();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const MainShell()),
      (_) => false,
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final denied = _attempted && !context.watch<GalleryProvider>().hasAccess;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            children: [
              const Spacer(),
              Container(
                width: 172,
                height: 172,
                decoration: BoxDecoration(
                  color: scheme.primaryContainer,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  denied
                      ? Icons.no_photography_outlined
                      : Icons.perm_media_rounded,
                  size: 72,
                  color: scheme.primary,
                ),
              ),
              const SizedBox(height: 38),
              Text(
                denied ? 'Gallery Access Required' : 'Allow Gallery Access',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineMedium
                    ?.copyWith(fontWeight: FontWeight.w900, letterSpacing: -1),
              ),
              const SizedBox(height: 16),
              Text(
                denied
                    ? 'Please allow photo and video access to use MyGallery.'
                    : 'MyGallery needs access to your photos and videos so you can browse and organize your personal gallery.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: scheme.onSurfaceVariant,
                  height: 1.55,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: scheme.secondaryContainer.withValues(alpha: .55),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    Icon(Icons.lock_rounded, color: scheme.secondary),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Your media stays private and on this device.',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              if (_requesting)
                const CircularProgressIndicator()
              else if (denied)
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _request,
                        child: const Text('Try Again'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        onPressed: context
                            .read<GalleryProvider>()
                            .permissionService
                            .openSettings,
                        child: const Text('Open Settings'),
                      ),
                    ),
                  ],
                )
              else
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: FilledButton.icon(
                    onPressed: _request,
                    icon: const Icon(Icons.photo_library_outlined),
                    label: const Text('Allow Access'),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
