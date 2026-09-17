import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:media_kit/media_kit.dart' hide Track;
import '../../providers/player_provider.dart';
import '../../providers/settings_provider.dart';
import '../../models/track.dart';
import '../theme.dart';
import '../widgets/track_cover_image.dart';

/// 3D Card Carousel view of the current queue.
class QueueCarouselView extends StatefulWidget {
  const QueueCarouselView({super.key});

  @override
  State<QueueCarouselView> createState() => _QueueCarouselViewState();
}

class _QueueCarouselViewState extends State<QueueCarouselView> {
  late PageController _pageController;
  double _currentPage = 0;

  @override
  void initState() {
    super.initState();
    // We'll initialize the page controller in didChangeDependencies
    // because we need the player context
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final player = context.read<PlayerProvider>();
    final queue = player.queue;
    final current = player.currentTrack;
    int initialIndex = 0;
    if (current != null && queue.isNotEmpty) {
      initialIndex = queue.indexWhere((t) => t.filename == current.filename);
      if (initialIndex < 0) initialIndex = 0;
    }
    _currentPage = initialIndex.toDouble();
    final isMobile = MediaQuery.of(context).size.width < 600;
    _pageController = PageController(
      viewportFraction: isMobile ? 0.65 : 0.3,
      initialPage: initialIndex,
    );
    _pageController.addListener(() {
      setState(() {
        _currentPage = _pageController.page ?? 0;
      });
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final player = context.watch<PlayerProvider>();
    final queue = player.queue;
    final current = player.currentTrack;
    final isMobile = MediaQuery.of(context).size.width < 600;

    if (queue.isEmpty) return const SizedBox.shrink();

    final currentIndex = current != null
        ? queue.indexWhere((t) => t.filename == current.filename)
        : 0;

    return Container(
      width: double.infinity,
      height: MediaQuery.of(context).size.height,
      clipBehavior: Clip.antiAlias,
      decoration: const BoxDecoration(),
      child: Stack(
        children: [
          // ── Background: blurred cover of current track ──
          if (current != null && current.coverUrl != null && getCoverImageProvider(current.coverUrl) != null)
            Positioned.fill(
              child: ClipRect(
                child: ImageFiltered(
                  imageFilter: ImageFilter.blur(sigmaX: 60, sigmaY: 60),
                  child: Transform.scale(
                    scale: 1.4,
                    child: Container(
                      decoration: BoxDecoration(
                        image: DecorationImage(
                          image: getCoverImageProvider(current.coverUrl)!,
                          fit: BoxFit.cover,
                          colorFilter: ColorFilter.mode(
                            Colors.black.withValues(alpha: 0.6),
                            BlendMode.darken,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            )
          else
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      context.colors.surfaceAlt.withValues(alpha: 0.9),
                      context.colors.bg,
                    ],
                  ),
                ),
              ),
            ),

          // ── Content ──
          SafeArea(
            child: Column(
              children: [
                // ── Top bar ──
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: Row(
                    children: [
                      Container(
                        width: 34, height: 34,
                        decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.75), shape: BoxShape.circle),
                        child: IconButton(
                          icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.black, size: 20),
                          onPressed: () => Navigator.of(context).pop(),
                          padding: EdgeInsets.zero,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        'Cola de Reproducción',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.8),
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '${(currentIndex >= 0 ? currentIndex + 1 : 1)} / ${queue.length}',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.5),
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // ── 3D Carousel ──
                Expanded(
                  flex: 5,
                  child: ScrollConfiguration(
                    behavior: ScrollConfiguration.of(context).copyWith(
                      dragDevices: {
                        PointerDeviceKind.touch,
                        PointerDeviceKind.mouse,
                        PointerDeviceKind.trackpad,
                      },
                    ),
                    child: PageView.builder(
                      controller: _pageController,
                      itemCount: queue.length,
                      itemBuilder: (context, index) {
                        return _buildCarouselCard(context, player, queue, index, isMobile);
                      },
                    ),
                  ),
                ),

                const SizedBox(height: 12),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _goToCurrentTrack(PlayerProvider player) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final queue = player.queue;
      final current = player.currentTrack;
      if (current == null) return;
      final idx = queue.indexWhere((t) => t.filename == current.filename);
      if (idx >= 0 && _pageController.hasClients) {
        _pageController.animateToPage(idx, duration: const Duration(milliseconds: 400), curve: Curves.easeInOut);
      }
    });
  }

  Widget _buildCarouselCard(BuildContext context, PlayerProvider player, List<Track> queue, int index, bool isMobile) {
    final track = queue[index];
    final hasCover = track.coverUrl != null && track.coverUrl!.isNotEmpty;
    final currentTrack = player.currentTrack;
    final isCurrentTrack = currentTrack != null && currentTrack.filename == track.filename;

    // Calculate position relative to center
    final double delta = _currentPage - index;
    final double absDelta = delta.abs();

    // Scale: center = 1.0, sides = 0.75
    final double scale = math.max(0.7, 1.0 - absDelta * 0.25);

    // Opacity: center = 1.0, far sides = 0.4
    final double opacity = math.max(0.4, 1.0 - absDelta * 0.3);

    // Vertical offset: sides shift down slightly
    final double verticalShift = absDelta * 20;

    // 3D rotation around Y axis
    final double rotationY = delta * -0.3; // radians

    return GestureDetector(
      onTap: () async {
        try {
          final settings = context.read<SettingsProvider>();
          await player.playTrack(queue[index], queue, settings);
        } catch (_) {}
        _pageController.animateToPage(index, duration: const Duration(milliseconds: 400), curve: Curves.easeInOut);
      },
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 200),
        opacity: opacity,
        child: Transform(
          alignment: Alignment.center,
          transform: Matrix4.identity()
            ..setEntry(3, 2, 0.001) // perspective
            ..rotateY(rotationY)
            ..scale(scale)
            ..translate(0.0, verticalShift, 0.0),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final side = math.min(constraints.maxWidth, constraints.maxHeight) * 0.95;
              return Center(
                child: SizedBox(
                  width: side,
                  height: side,
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      color: context.colors.surface,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: isCurrentTrack ? 0.5 : 0.3),
                          blurRadius: isCurrentTrack ? 30 : 15,
                          spreadRadius: isCurrentTrack ? 4 : 1,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        // Cover image
                        if (hasCover && getCoverImageProvider(track.coverUrl) != null)
                          Image(
                            image: getCoverImageProvider(track.coverUrl)!,
                            fit: BoxFit.cover,
                          )
                        else
                          Container(
                            color: context.colors.surfaceAlt,
                            child: Icon(Icons.music_note_rounded, color: context.colors.textSecondary, size: 60),
                          ),

                        // Bottom gradient overlay with track info
                        Positioned(
                          left: 0, right: 0, bottom: 0,
                          child: Container(
                            padding: const EdgeInsets.fromLTRB(16, 40, 16, 16),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [Colors.transparent, Colors.black.withValues(alpha: 0.8)],
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  track.title.isNotEmpty ? track.title : track.filename,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    decoration: TextDecoration.none,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  track.artist,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.7),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    decoration: TextDecoration.none,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        // Playing indicator
                        if (isCurrentTrack && player.isPlaying)
                          Positioned(
                            top: 12, right: 12,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.primary,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.equalizer_rounded, color: Colors.white, size: 14),
                                  const SizedBox(width: 4),
                                  const Text('Sonando', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w600, decoration: TextDecoration.none)),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
