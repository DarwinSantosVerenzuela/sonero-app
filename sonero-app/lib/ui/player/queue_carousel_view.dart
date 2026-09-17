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
  final Set<int> _flippedCards = {};

  @override
  void initState() {
    super.initState();
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
      viewportFraction: isMobile ? 0.75 : 0.35,
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

    return DefaultTextStyle(
      style: const TextStyle(decoration: TextDecoration.none, color: Colors.white),
      child: Container(
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
                      Material(
                        color: Colors.transparent,
                        child: Container(
                          width: 34, height: 34,
                          decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.75), shape: BoxShape.circle),
                          child: IconButton(
                            icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.black, size: 20),
                            onPressed: () => Navigator.of(context).pop(),
                            padding: EdgeInsets.zero,
                          ),
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
                          decoration: TextDecoration.none,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '${(currentIndex >= 0 ? currentIndex + 1 : 1)} / ${queue.length}',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.5),
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          decoration: TextDecoration.none,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // ── 3D Carousel ──
                Expanded(
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
    final isFlipped = _flippedCards.contains(index);

    // Calculate position relative to center
    final double delta = _currentPage - index;
    final double absDelta = delta.abs();

    // Scale: center = 1.0, sides = 0.78
    final double scale = math.max(0.75, 1.0 - absDelta * 0.22);

    // Opacity: center = 1.0, far sides = 0.5
    final double opacity = math.max(0.5, 1.0 - absDelta * 0.25);

    // Vertical offset
    final double verticalShift = absDelta * 15;

    // 3D rotation around Y axis
    final double rotationY = delta * -0.25;

    return GestureDetector(
      onTap: () {
        setState(() {
          if (_flippedCards.contains(index)) {
            _flippedCards.remove(index);
          } else {
            _flippedCards.add(index);
          }
        });
      },
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 200),
        opacity: opacity,
        child: Transform(
          alignment: Alignment.center,
          transform: Matrix4.identity()
            ..setEntry(3, 2, 0.001)
            ..rotateY(rotationY)
            ..scale(scale)
            ..translate(0.0, verticalShift, 0.0),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final side = math.min(constraints.maxWidth, constraints.maxHeight) * 0.92;
              return Center(
                child: SizedBox(
                  width: side,
                  height: side,
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: isFlipped ? math.pi : 0),
                    duration: const Duration(milliseconds: 500),
                    curve: Curves.easeInOutCubic,
                    builder: (context, angle, _) {
                      final showBack = angle > math.pi / 2;
                      return Transform(
                        alignment: Alignment.center,
                        transform: Matrix4.identity()
                          ..setEntry(3, 2, 0.001)
                          ..rotateY(angle),
                        child: showBack
                            ? Transform(
                                alignment: Alignment.center,
                                transform: Matrix4.identity()..rotateY(math.pi),
                                child: _buildBackFace(context, player, track, isCurrentTrack, side),
                              )
                            : _buildFrontFace(context, player, track, hasCover, isCurrentTrack),
                      );
                    },
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  // ── FRONT FACE: Cover Art ──
  Widget _buildFrontFace(BuildContext context, PlayerProvider player, Track track, bool hasCover, bool isCurrentTrack) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
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
              padding: const EdgeInsets.fromLTRB(16, 50, 16, 16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Colors.black.withValues(alpha: 0.85)],
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
                    style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700, decoration: TextDecoration.none),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    track.artist,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 13, fontWeight: FontWeight.w500, decoration: TextDecoration.none),
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
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.equalizer_rounded, color: Colors.white, size: 14),
                    SizedBox(width: 4),
                    Text('Sonando', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w600, decoration: TextDecoration.none)),
                  ],
                ),
              ),
            ),

          // Tap hint
          Positioned(
            top: 12, left: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.touch_app_rounded, color: Colors.white, size: 12),
                  SizedBox(width: 3),
                  Text('Toca', style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w500, decoration: TextDecoration.none)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── BACK FACE: Mini Player ──
  Widget _buildBackFace(BuildContext context, PlayerProvider player, Track track, bool isCurrentTrack, double side) {
    final accent = Theme.of(context).colorScheme.primary;
    final hasCover = track.coverUrl != null && track.coverUrl!.isNotEmpty;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 30,
            spreadRadius: 4,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Blurred background from cover
          if (hasCover && getCoverImageProvider(track.coverUrl) != null)
            ImageFiltered(
              imageFilter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
              child: Image(
                image: getCoverImageProvider(track.coverUrl)!,
                fit: BoxFit.cover,
              ),
            ),

          // Dark overlay
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              color: Colors.black.withValues(alpha: 0.65),
            ),
          ),

          // Player controls
          Material(
            color: Colors.transparent,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Small cover
                  Container(
                    width: side * 0.35,
                    height: side * 0.35,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withValues(alpha: 0.4), blurRadius: 15),
                      ],
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: hasCover && getCoverImageProvider(track.coverUrl) != null
                        ? Image(image: getCoverImageProvider(track.coverUrl)!, fit: BoxFit.cover)
                        : Container(color: context.colors.surfaceAlt, child: Icon(Icons.music_note, color: Colors.white54, size: 30)),
                  ),

                  const SizedBox(height: 16),

                  // Title & Artist
                  Text(
                    track.title.isNotEmpty ? track.title : track.filename,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700, decoration: TextDecoration.none),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    track.artist,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 13, decoration: TextDecoration.none),
                  ),

                  const SizedBox(height: 20),

                  // Progress bar (only if this track is playing)
                  if (isCurrentTrack) ...[
                    Builder(
                      builder: (context) {
                        final pos = player.position;
                        final dur = player.duration;
                        final progress = dur.inMilliseconds > 0 ? pos.inMilliseconds / dur.inMilliseconds : 0.0;
                        return Column(
                          children: [
                            SliderTheme(
                              data: SliderThemeData(
                                activeTrackColor: accent,
                                inactiveTrackColor: Colors.white.withValues(alpha: 0.2),
                                thumbColor: accent,
                                trackHeight: 3,
                                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
                                overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
                              ),
                              child: Slider(
                                value: progress.clamp(0.0, 1.0),
                                onChanged: (v) {
                                  final newPos = Duration(milliseconds: (v * dur.inMilliseconds).toInt());
                                  player.seek(newPos);
                                },
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 8),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(_formatDuration(pos), style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 11, decoration: TextDecoration.none)),
                                  Text(_formatDuration(dur), style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 11, decoration: TextDecoration.none)),
                                ],
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 12),
                  ],

                  // Controls
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      IconButton(
                        icon: Icon(Icons.shuffle_rounded, color: player.isShuffle ? accent : Colors.white.withValues(alpha: 0.6), size: 22),
                        onPressed: player.toggleShuffle,
                      ),
                      IconButton(
                        icon: const Icon(Icons.skip_previous_rounded, color: Colors.white, size: 30),
                        onPressed: () {
                          player.previous();
                          _goToCurrentTrack(player);
                        },
                      ),
                      GestureDetector(
                        onTap: () async {
                          if (!isCurrentTrack) {
                            try {
                              final settings = context.read<SettingsProvider>();
                              await player.playTrack(track, player.queue, settings);
                            } catch (_) {}
                          } else {
                            player.playPause();
                          }
                        },
                        child: Container(
                          width: 52, height: 52,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: accent,
                            boxShadow: [BoxShadow(color: accent.withValues(alpha: 0.4), blurRadius: 12, offset: const Offset(0, 4))],
                          ),
                          child: Icon(
                            isCurrentTrack && player.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                            color: Colors.white,
                            size: 28,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.skip_next_rounded, color: Colors.white, size: 30),
                        onPressed: () {
                          player.next();
                          _goToCurrentTrack(player);
                        },
                      ),
                      IconButton(
                        icon: Icon(
                          Icons.repeat_rounded,
                          color: player.repeatMode != PlaylistMode.none ? accent : Colors.white.withValues(alpha: 0.6),
                          size: 22,
                        ),
                        onPressed: player.toggleRepeat,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }
}
