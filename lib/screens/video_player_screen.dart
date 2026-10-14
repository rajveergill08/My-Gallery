import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';

import '../models/media_model.dart';
import '../providers/gallery_provider.dart';

class VideoPlayerScreen extends StatefulWidget {
  const VideoPlayerScreen({super.key, required this.item});

  final MediaModel item;

  @override
  State<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen>
    with WidgetsBindingObserver {
  VideoPlayerController? _controller;
  Timer? _controlsTimer;
  Duration? _scrubPosition;
  Object? _loadError;
  bool _isLoading = true;
  bool _controlsVisible = true;
  bool _isFullscreen = false;
  bool _fullscreenTransitionInProgress = false;
  double _volumeBeforeMute = 1;
  int _loadToken = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_initializeVideo());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.detached) {
      _controlsTimer?.cancel();
      final controller = _controller;
      if (controller != null && controller.value.isPlaying) {
        unawaited(controller.pause());
      }
      if (mounted && !_controlsVisible) {
        setState(() => _controlsVisible = true);
      }
    }
  }

  Future<void> _initializeVideo() async {
    final token = ++_loadToken;
    _controlsTimer?.cancel();

    final previousController = _controller;
    if (mounted) {
      setState(() {
        _controller = null;
        _isLoading = true;
        _loadError = null;
        _scrubPosition = null;
        _controlsVisible = true;
      });
    } else {
      _controller = null;
    }
    if (previousController != null) {
      await previousController.dispose();
    }

    VideoPlayerController? nextController;
    try {
      final file = await widget.item.file;
      if (file == null || !await file.exists()) {
        throw StateError('The video file is no longer available.');
      }

      nextController = VideoPlayerController.file(file);
      await nextController.initialize();

      if (!mounted || token != _loadToken) {
        await nextController.dispose();
        return;
      }

      _controller = nextController;
      setState(() => _isLoading = false);
    } catch (error) {
      await nextController?.dispose();
      if (!mounted || token != _loadToken) return;
      setState(() {
        _isLoading = false;
        _loadError = error;
      });
    }
  }

  Future<void> _togglePlayback() async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;

    if (controller.value.isPlaying) {
      await controller.pause();
      _controlsTimer?.cancel();
      if (mounted) setState(() => _controlsVisible = true);
      return;
    }

    final value = controller.value;
    if (value.duration > Duration.zero && value.position >= value.duration) {
      await controller.seekTo(Duration.zero);
    }
    await controller.play();
    _scheduleControlsHide();
  }

  void _toggleControls() {
    setState(() => _controlsVisible = !_controlsVisible);
    if (_controlsVisible) _scheduleControlsHide();
  }

  void _scheduleControlsHide() {
    _controlsTimer?.cancel();
    final controller = _controller;
    if (controller == null || !controller.value.isPlaying) return;
    _controlsTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => _controlsVisible = false);
    });
  }

  Future<void> _seekTo(double milliseconds) async {
    final controller = _controller;
    if (controller == null) return;
    final target = Duration(milliseconds: milliseconds.round());
    setState(() => _scrubPosition = null);
    await controller.seekTo(target);
    _scheduleControlsHide();
  }

  Future<void> _seekBy(Duration offset) async {
    final controller = _controller;
    if (controller == null) return;
    final duration = controller.value.duration;
    final requested = controller.value.position + offset;
    final target = requested < Duration.zero
        ? Duration.zero
        : requested > duration
        ? duration
        : requested;
    await controller.seekTo(target);
    _scheduleControlsHide();
  }

  Future<void> _toggleMute() async {
    final controller = _controller;
    if (controller == null) return;
    final currentVolume = controller.value.volume;
    if (currentVolume > 0) {
      _volumeBeforeMute = currentVolume;
      await controller.setVolume(0);
    } else {
      await controller.setVolume(
        _volumeBeforeMute <= 0 ? 1 : _volumeBeforeMute,
      );
    }
    _scheduleControlsHide();
  }

  Future<void> _setVolume(double volume) async {
    final controller = _controller;
    if (controller == null) return;
    if (volume > 0) _volumeBeforeMute = volume;
    await controller.setVolume(volume);
    _scheduleControlsHide();
  }

  Future<void> _setFullscreen(bool fullscreen) async {
    if (_isFullscreen == fullscreen || _fullscreenTransitionInProgress) return;
    _fullscreenTransitionInProgress = true;

    if (mounted) {
      setState(() {
        _isFullscreen = fullscreen;
        _controlsVisible = true;
      });
    } else {
      _isFullscreen = fullscreen;
    }

    try {
      if (fullscreen) {
        await SystemChrome.setPreferredOrientations(const [
          DeviceOrientation.landscapeLeft,
          DeviceOrientation.landscapeRight,
        ]);
        if (!mounted) {
          await _restoreSystemUi();
          return;
        }
        await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
        if (!mounted) {
          await _restoreSystemUi();
          return;
        }
      } else {
        await _restoreSystemUi();
      }

      _scheduleControlsHide();
    } on PlatformException {
      _isFullscreen = false;
      if (mounted) setState(() {});
      await _restoreSystemUi();
    } finally {
      _fullscreenTransitionInProgress = false;
    }
  }

  Future<void> _restoreSystemUi() async {
    await SystemChrome.setPreferredOrientations(const <DeviceOrientation>[]);
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  }

  void _handleBack() {
    if (_isFullscreen) {
      unawaited(_setFullscreen(false));
    } else {
      Navigator.of(context).maybePop();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _loadToken++;
    _controlsTimer?.cancel();
    final controller = _controller;
    _controller = null;
    if (controller != null) unawaited(controller.dispose());
    if (_isFullscreen) unawaited(_restoreSystemUi());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope<void>(
      canPop: !_isFullscreen,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _isFullscreen) unawaited(_setFullscreen(false));
      },
      child: Scaffold(backgroundColor: Colors.black, body: _buildBody()),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return _PlayerMessage(
        icon: const SizedBox.square(
          dimension: 34,
          child: CircularProgressIndicator(strokeWidth: 3),
        ),
        title: 'Preparing video',
        message: 'Loading this video from your device…',
        onBack: _handleBack,
      );
    }

    if (_loadError != null || _controller == null) {
      return _PlayerMessage(
        icon: const Icon(
          Icons.broken_image_outlined,
          color: Colors.white70,
          size: 52,
        ),
        title: 'Unable to play video',
        message: 'This video may have been moved, deleted, corrupted, or saved in an unsupported format.',
        onBack: _handleBack,
        onRetry: _initializeVideo,
      );
    }

    final controller = _controller!;
    return ValueListenableBuilder<VideoPlayerValue>(
      valueListenable: controller,
      builder: (context, value, _) {
        if (value.hasError) {
          return _PlayerMessage(
            icon: const Icon(
              Icons.error_outline_rounded,
              color: Colors.white70,
              size: 52,
            ),
            title: 'Playback error',
            message:
                value.errorDescription ?? 'This video could not be played.',
            onBack: _handleBack,
            onRetry: _initializeVideo,
          );
        }

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _toggleControls,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Center(
                child: AspectRatio(
                  aspectRatio: value.aspectRatio > 0
                      ? value.aspectRatio
                      : 16 / 9,
                  child: VideoPlayer(controller),
                ),
              ),
              if (value.isBuffering)
                const Center(
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 3,
                  ),
                ),
              _buildControls(controller, value),
            ],
          ),
        );
      },
    );
  }

  Widget _buildControls(
    VideoPlayerController controller,
    VideoPlayerValue value,
  ) {
    final favourite = context.select<GalleryProvider, bool>(
      (gallery) => gallery.isFavourite(widget.item),
    );
    final duration = value.duration;
    final shownPosition = _scrubPosition ?? value.position;
    final maximum = duration.inMilliseconds <= 0
        ? 1.0
        : duration.inMilliseconds.toDouble();
    final position = shownPosition.inMilliseconds
        .clamp(0, maximum.toInt())
        .toDouble();

    return IgnorePointer(
      ignoring: !_controlsVisible,
      child: AnimatedOpacity(
        opacity: _controlsVisible ? 1 : 0,
        duration: const Duration(milliseconds: 220),
        child: Stack(
          fit: StackFit.expand,
          children: [
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black54,
                    Colors.transparent,
                    Colors.transparent,
                    Colors.black87,
                  ],
                  stops: [0, 0.28, 0.56, 1],
                ),
              ),
            ),
            SafeArea(
              bottom: !_isFullscreen,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(6, 4, 14, 0),
                    child: Row(
                      children: [
                        IconButton(
                          tooltip: _isFullscreen ? 'Exit full screen' : 'Back',
                          onPressed: _handleBack,
                          icon: Icon(
                            _isFullscreen
                                ? Icons.fullscreen_exit_rounded
                                : Icons.arrow_back_rounded,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            widget.item.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: favourite
                              ? 'Remove from favourites'
                              : 'Add to favourites',
                          onPressed: () => context
                              .read<GalleryProvider>()
                              .toggleFavourite(widget.item),
                          color: favourite ? Colors.pinkAccent : Colors.white,
                          icon: Icon(
                            favourite
                                ? Icons.favorite_rounded
                                : Icons.favorite_border_rounded,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        tooltip: 'Rewind 10 seconds',
                        onPressed: () =>
                            unawaited(_seekBy(const Duration(seconds: -10))),
                        iconSize: 32,
                        color: Colors.white,
                        icon: const Icon(Icons.replay_10_rounded),
                      ),
                      const SizedBox(width: 20),
                      IconButton.filled(
                        tooltip: value.isPlaying ? 'Pause' : 'Play',
                        onPressed: _togglePlayback,
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.black,
                          minimumSize: const Size.square(64),
                        ),
                        iconSize: 36,
                        icon: Icon(
                          value.isPlaying
                              ? Icons.pause_rounded
                              : Icons.play_arrow_rounded,
                        ),
                      ),
                      const SizedBox(width: 20),
                      IconButton(
                        tooltip: 'Forward 10 seconds',
                        onPressed: () =>
                            unawaited(_seekBy(const Duration(seconds: 10))),
                        iconSize: 32,
                        color: Colors.white,
                        icon: const Icon(Icons.forward_10_rounded),
                      ),
                    ],
                  ),
                  const Spacer(),
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      _isFullscreen ? 26 : 14,
                      0,
                      _isFullscreen ? 26 : 14,
                      _isFullscreen ? 14 : 8,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            Text(
                              _formatDuration(shownPosition),
                              style: const TextStyle(
                                color: Colors.white,
                                fontFeatures: [FontFeature.tabularFigures()],
                              ),
                            ),
                            Expanded(
                              child: Slider(
                                value: position,
                                max: maximum,
                                onChangeStart: (_) {
                                  _controlsTimer?.cancel();
                                },
                                onChanged: duration <= Duration.zero
                                    ? null
                                    : (newPosition) {
                                        setState(() {
                                          _scrubPosition = Duration(
                                            milliseconds: newPosition.round(),
                                          );
                                        });
                                      },
                                onChangeEnd: duration <= Duration.zero
                                    ? null
                                    : (newPosition) =>
                                          unawaited(_seekTo(newPosition)),
                              ),
                            ),
                            Text(
                              _formatDuration(duration),
                              style: const TextStyle(
                                color: Colors.white,
                                fontFeatures: [FontFeature.tabularFigures()],
                              ),
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            IconButton(
                              tooltip: value.volume == 0 ? 'Unmute' : 'Mute',
                              onPressed: _toggleMute,
                              color: Colors.white,
                              icon: Icon(
                                value.volume == 0
                                    ? Icons.volume_off_rounded
                                    : value.volume < .5
                                    ? Icons.volume_down_rounded
                                    : Icons.volume_up_rounded,
                              ),
                            ),
                            SizedBox(
                              width: _isFullscreen ? 150 : 96,
                              child: Slider(
                                value: value.volume.clamp(0, 1),
                                onChanged: (volume) =>
                                    unawaited(_setVolume(volume)),
                              ),
                            ),
                            const Spacer(),
                            IconButton(
                              tooltip: _isFullscreen
                                  ? 'Exit full screen'
                                  : 'Full screen',
                              onPressed: () =>
                                  unawaited(_setFullscreen(!_isFullscreen)),
                              color: Colors.white,
                              icon: Icon(
                                _isFullscreen
                                    ? Icons.fullscreen_exit_rounded
                                    : Icons.fullscreen_rounded,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDuration(Duration duration) {
    final totalSeconds = duration.inSeconds.clamp(0, 359999);
    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    final seconds = totalSeconds % 60;
    if (hours > 0) {
      return '$hours:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }
}

class _PlayerMessage extends StatelessWidget {
  const _PlayerMessage({
    required this.icon,
    required this.title,
    required this.message,
    required this.onBack,
    this.onRetry,
  });

  final Widget icon;
  final String title;
  final String message;
  final VoidCallback onBack;
  final Future<void> Function()? onRetry;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Stack(
        children: [
          Positioned(
            top: 4,
            left: 4,
            child: IconButton(
              tooltip: 'Back',
              onPressed: onBack,
              color: Colors.white,
              icon: const Icon(Icons.arrow_back_rounded),
            ),
          ),
          Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  icon,
                  const SizedBox(height: 20),
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white70, height: 1.4),
                  ),
                  if (onRetry != null) ...[
                    const SizedBox(height: 24),
                    FilledButton.icon(
                      onPressed: () => unawaited(onRetry!()),
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('Try Again'),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
