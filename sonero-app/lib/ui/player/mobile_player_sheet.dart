import 'dart:ui';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:media_kit/media_kit.dart' hide Track;
import '../../providers/player_provider.dart';
import '../../providers/settings_provider.dart';
import '../theme.dart';
import '../widgets/track_cover_image.dart';
import 'lyrics_view.dart';
import 'equalizer_view.dart';
import 'queue_carousel_view.dart';

class MobileExpandedPlayer extends StatefulWidget {
  const MobileExpandedPlayer({super.key});

  @override
  State<MobileExpandedPlayer> createState() => _MobileExpandedPlayerState();
}

class _MobileExpandedPlayerState extends State<MobileExpandedPlayer> with SingleTickerProviderStateMixin {
  late final AnimationController _marqueeController;
  bool _showLyrics = false;

  @override
  void initState() {
    super.initState();
    _marqueeController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _marqueeController.repeat();
    });
  }

  @override
  void dispose() {
    _marqueeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final player = context.watch<PlayerProvider>();
    final track = player.currentTrack;
    if (track == null) return const SizedBox.shrink();

    final hasCover = track.coverUrl != null && track.coverUrl!.isNotEmpty;
    final primaryColor = Theme.of(context).colorScheme.primary;
    final isMobile = MediaQuery.of(context).size.width < 600;

    return Scaffold(
      backgroundColor: context.colors.bg,
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(color: context.colors.bg),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
          // ── Background artwork blur ──
          if (hasCover && getCoverImageProvider(track.coverUrl) != null) ...[
            Positioned.fill(
              child: ClipRect(
                clipBehavior: Clip.hardEdge,
                child: ImageFiltered(
                  imageFilter: ImageFilter.blur(sigmaX: 80, sigmaY: 80),
                  child: Transform.scale(
                    scale: 1.5,
                    child: Container(
                      decoration: BoxDecoration(
                        image: DecorationImage(
                          image: getCoverImageProvider(track.coverUrl)!,
                          fit: BoxFit.cover,
                          colorFilter: ColorFilter.mode(Colors.black.withValues(alpha: 0.35), BlendMode.darken),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            // Glass overlay for depth
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.black.withValues(alpha: 0.15),
                      Colors.black.withValues(alpha: 0.3),
                      Colors.black.withValues(alpha: 0.15),
                    ],
                    stops: const [0.0, 0.5, 1.0],
                  ),
                ),
              ),
            ),
          ] else
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [context.colors.surfaceAlt, context.colors.bg],
                  ),
                ),
              ),
            ),

          // ── Player Content ──
          SafeArea(
            child: isMobile
                ? _buildMobileLayout(context, player, track, hasCover, primaryColor)
                : _buildDesktopLayout(context, player, track, hasCover, primaryColor),
           ),
         ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Desktop Layout: Cover left, controls right — fullscreen
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildDesktopLayout(BuildContext context, PlayerProvider player, dynamic track, bool hasCover, Color primaryColor) {
    return Column(
      children: [
        // ── Top bar ──
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
          child: Row(
            children: [
              _buildCircleButton(Icons.keyboard_arrow_down_rounded, () => Navigator.of(context).pop()),
              const Spacer(),
              Text('Reproduciendo', style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontWeight: FontWeight.w600, fontSize: 13, letterSpacing: 1.0)),
              const Spacer(),
              _buildCircleButton(Icons.more_horiz_rounded, () => _showMoreOptions(context, player, track)),
            ],
          ),
        ),
        // ── Main content ──
        Expanded(
          child: Row(
            children: [
              // ── LEFT: Cover + Controls ──
              Expanded(
                flex: 2,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(40, 0, 20, 24),
                  child: Column(
                    children: [
                      const Spacer(),
                      // Cover art
                      Hero(
                        tag: 'mobile_player_cover',
                        child: Container(
                          width: 320,
                          height: 320,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(20),
                            color: context.colors.surface,
                            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.5), blurRadius: 30, spreadRadius: 4, offset: const Offset(0, 12))],
                            image: hasCover && getCoverImageProvider(track.coverUrl) != null
                                ? DecorationImage(image: getCoverImageProvider(track.coverUrl)!, fit: BoxFit.cover)
                                : null,
                          ),
                          child: !hasCover || getCoverImageProvider(track.coverUrl) == null
                              ? Icon(Icons.music_note_rounded, color: context.colors.textSecondary, size: 80)
                              : null,
                        ),
                      ),
                      const SizedBox(height: 24),
                      // Title + Artist
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Column(
                          children: [
                            _buildTitleMarquee(track, 24),
                            const SizedBox(height: 6),
                            _buildArtist(track, 15),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      // Seek bar
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: _buildSeekBar(context, player, primaryColor),
                      ),
                      const SizedBox(height: 12),
                      // Playback controls
                      _buildPlaybackControls(context, player, primaryColor),
                      const SizedBox(height: 16),
                      // Volume + Utilities
                      _buildVolumeAndUtils(context, player, isMobile: false),
                      const Spacer(),
                    ],
                  ),
                ),
              ),

              // ── RIGHT: Queue list or Lyrics ──
              Expanded(
                flex: 3,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: _showLyrics
                      ? _buildDesktopLyricsPanel(context, player, track, primaryColor)
                      : _buildDesktopQueuePanel(context, player, track, primaryColor),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDesktopQueuePanel(BuildContext context, PlayerProvider player, dynamic track, Color primaryColor) {
    final queue = player.queue;
    final currentIndex = queue.indexWhere((t) => t.filename == track.filename);

    return Padding(
      key: const ValueKey('queue_panel'),
      padding: const EdgeInsets.fromLTRB(20, 0, 32, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Icon(Icons.queue_music_rounded, color: Colors.white.withValues(alpha: 0.7), size: 22),
              const SizedBox(width: 10),
              Text(
                'Cola de Reproducción',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const Spacer(),
              Text(
                '${currentIndex + 1} / ${queue.length}',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 13),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Queue list
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: ListView.builder(
                itemCount: queue.length,
                padding: const EdgeInsets.symmetric(vertical: 4),
                itemBuilder: (context, index) {
                  final qTrack = queue[index];
                  final isPlaying = index == currentIndex;
                  final hasCoverQ = qTrack.coverUrl != null && qTrack.coverUrl!.isNotEmpty;

                  return Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(10),
                      onTap: () {
                        if (!isPlaying) {
                          final settings = context.read<SettingsProvider>();
                          player.playTrack(qTrack, queue, settings);
                        }
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        margin: const EdgeInsets.only(bottom: 4),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          color: isPlaying
                              ? primaryColor.withValues(alpha: 0.15)
                              : Colors.white.withValues(alpha: 0.04),
                          border: isPlaying
                              ? Border.all(color: primaryColor.withValues(alpha: 0.4), width: 1)
                              : null,
                        ),
                        child: Row(
                          children: [
                            // Index or playing indicator
                            SizedBox(
                              width: 28,
                              child: isPlaying
                                  ? Icon(Icons.equalizer_rounded, color: primaryColor, size: 20)
                                  : Text(
                                      '${index + 1}',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 13, fontWeight: FontWeight.w500),
                                    ),
                            ),
                            const SizedBox(width: 12),
                            // Cover
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: SizedBox(
                                width: 44,
                                height: 44,
                                child: hasCoverQ && getCoverImageProvider(qTrack.coverUrl) != null
                                    ? Image(image: getCoverImageProvider(qTrack.coverUrl)!, fit: BoxFit.cover)
                                    : Container(
                                        color: context.colors.surfaceAlt,
                                        child: Icon(Icons.music_note_rounded, color: context.colors.textSecondary, size: 18),
                                      ),
                              ),
                            ),
                            const SizedBox(width: 14),
                            // Title + Artist
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    qTrack.title.isNotEmpty ? qTrack.title : qTrack.filename,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: isPlaying ? Colors.white : Colors.white.withValues(alpha: 0.8),
                                      fontSize: 14,
                                      fontWeight: isPlaying ? FontWeight.w700 : FontWeight.w500,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    qTrack.artist.isNotEmpty ? qTrack.artist : 'Desconocido',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: isPlaying ? Colors.white.withValues(alpha: 0.7) : Colors.white.withValues(alpha: 0.45),
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            // Duration placeholder
                            if (isPlaying)
                              Text(
                                'Sonando',
                                style: TextStyle(color: primaryColor, fontSize: 11, fontWeight: FontWeight.w600),
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
        ],
      ),
    );
  }

  Widget _buildDesktopLyricsPanel(BuildContext context, PlayerProvider player, dynamic track, Color primaryColor) {
    return Padding(
      key: const ValueKey('lyrics'),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: Column(
        children: [
          // Header with back button
          Row(
            children: [
              IconButton(
                icon: Icon(Icons.arrow_back_rounded, color: Colors.white.withValues(alpha: 0.8), size: 22),
                onPressed: () => setState(() => _showLyrics = false),
              ),
              const SizedBox(width: 8),
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.lyrics_rounded, color: Colors.white, size: 18),
              ),
              const SizedBox(width: 8),
              Text('Letra', style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 18, fontWeight: FontWeight.w700)),
              const Spacer(),
              Text(
                '${track.title.isNotEmpty ? track.title : track.filename}',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Inline LyricsView
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: LyricsView(
                title: track.title ?? '',
                artist: track.artist ?? '',
                filename: track.filename,
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Mobile Layout: Original vertical column
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildMobileLayout(BuildContext context, PlayerProvider player, dynamic track, bool hasCover, Color primaryColor) {
    final screenHeight = MediaQuery.of(context).size.height;
    final coverSize = (screenHeight * 0.32).clamp(160.0, 300.0);

    return Column(
      children: [
        const SizedBox(height: 12),
        Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(10))),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildCircleButton(Icons.keyboard_arrow_down_rounded, () => Navigator.of(context).pop()),
              Text('Reproduciendo', style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontWeight: FontWeight.w600, fontSize: 13, letterSpacing: 1.0)),
              _buildCircleButton(Icons.more_horiz_rounded, () => _showMoreOptions(context, player, track)),
            ],
          ),
        ),

        Expanded(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Column(
              children: [
                const SizedBox(height: 16),
                // Cover Art
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 8),
                  child: Center(
                    child: Hero(
                      tag: 'mobile_player_cover',
                      child: Container(
                        width: coverSize,
                        height: coverSize,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          color: context.colors.surface,
                          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.4), blurRadius: 20, spreadRadius: 2, offset: const Offset(0, 10))],
                          image: hasCover && getCoverImageProvider(track.coverUrl) != null
                              ? DecorationImage(image: getCoverImageProvider(track.coverUrl)!, fit: BoxFit.cover)
                              : null,
                        ),
                        child: !hasCover || getCoverImageProvider(track.coverUrl) == null
                            ? Icon(Icons.music_note_rounded, color: context.colors.textSecondary, size: 80)
                            : null,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // Title & Artist
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      _buildTitleMarquee(track, 22),
                      const SizedBox(height: 6),
                      _buildArtist(track, 16),
                    ],
                  ),
                ),

                const SizedBox(height: 24),
                Padding(padding: const EdgeInsets.symmetric(horizontal: 24), child: _buildSeekBar(context, player, primaryColor)),
                const SizedBox(height: 16),
                Padding(padding: const EdgeInsets.symmetric(horizontal: 24), child: _buildPlaybackControls(context, player, primaryColor)),
                const SizedBox(height: 24),
                Padding(padding: const EdgeInsets.symmetric(horizontal: 20), child: _buildVolumeAndUtils(context, player, isMobile: true)),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Shared Widgets
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildCircleButton(IconData icon, VoidCallback onPressed) {
    return Container(
      width: 34, height: 34,
      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.75), shape: BoxShape.circle),
      child: IconButton(icon: Icon(icon, color: Colors.black, size: 20), onPressed: onPressed, padding: EdgeInsets.zero),
    );
  }

  Widget _buildTitleMarquee(dynamic track, double fontSize) {
    final title = track.title.isNotEmpty ? track.title : track.filename;
    return SizedBox(
      height: fontSize + 10,
      child: _MarqueeBanner(
        text: title,
        fontSize: fontSize,
        controller: _marqueeController,
      ),
    );
  }

  Widget _buildArtist(dynamic track, double fontSize) {
    return Text(
      track.artist,
      textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis,
      style: TextStyle(
        color: Colors.white.withValues(alpha: 0.85), fontSize: fontSize, fontWeight: FontWeight.w500, decoration: TextDecoration.none,
        shadows: [Shadow(color: Colors.black.withValues(alpha: 0.7), blurRadius: 4)],
      ),
    );
  }

  Widget _buildSeekBar(BuildContext context, PlayerProvider player, Color primaryColor) {
    return Column(
      children: [
        SliderTheme(
          data: SliderThemeData(
            trackHeight: 4,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
            activeTrackColor: primaryColor,
            inactiveTrackColor: context.colors.border.withValues(alpha: 0.4),
            thumbColor: context.colors.textPrimary,
          ),
          child: Slider(
            value: player.position.inMilliseconds.toDouble().clamp(0.0, player.duration.inMilliseconds > 0 ? player.duration.inMilliseconds.toDouble() : 100.0),
            max: player.duration.inMilliseconds > 0 ? player.duration.inMilliseconds.toDouble() : 100.0,
            onChanged: (val) => player.seek(Duration(milliseconds: val.toInt())),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(_formatDuration(player.position), style: TextStyle(color: context.colors.textSecondary, fontSize: 12, fontWeight: FontWeight.w500)),
              Text(_formatDuration(player.duration), style: TextStyle(color: context.colors.textSecondary, fontSize: 12, fontWeight: FontWeight.w500)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPlaybackControls(BuildContext context, PlayerProvider player, Color primaryColor) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        IconButton(icon: Icon(Icons.shuffle_rounded, color: player.isShuffle ? primaryColor : context.colors.textSecondary, size: 24), onPressed: player.toggleShuffle),
        IconButton(icon: Icon(Icons.skip_previous_rounded, color: context.colors.textPrimary, size: 36), onPressed: player.previous),
        GestureDetector(
          onTap: player.playPause,
          child: Container(
            width: 72, height: 72,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(colors: [primaryColor, primaryColor.withValues(alpha: 0.8)], begin: Alignment.topLeft, end: Alignment.bottomRight),
              boxShadow: [BoxShadow(color: primaryColor.withValues(alpha: 0.4), blurRadius: 12, spreadRadius: 1, offset: const Offset(0, 4))],
            ),
            child: Icon(player.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded, color: Colors.white, size: 36),
          ),
        ),
        IconButton(icon: Icon(Icons.skip_next_rounded, color: context.colors.textPrimary, size: 36), onPressed: player.next),
        IconButton(icon: Icon(player.repeatMode == PlaylistMode.single ? Icons.repeat_one_rounded : Icons.repeat_rounded, color: player.repeatMode != PlaylistMode.none ? primaryColor : context.colors.textSecondary, size: 24), onPressed: player.toggleRepeat),
      ],
    );
  }

  Widget _buildVolumeAndUtils(BuildContext context, PlayerProvider player, {bool isMobile = true}) {
    final iconSize = isMobile ? 18.0 : 24.0;
    final labelSize = isMobile ? 12.0 : 14.0;
    final btnColor = Colors.white.withValues(alpha: 0.85);

    return ClipRRect(
      borderRadius: BorderRadius.circular(isMobile ? 16 : 20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: EdgeInsets.fromLTRB(isMobile ? 12 : 20, isMobile ? 8 : 14, isMobile ? 12 : 20, isMobile ? 4 : 10),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(isMobile ? 16 : 20),
            border: Border.all(color: Colors.white.withValues(alpha: 0.2), width: 0.5),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Icon(player.volume > 0 ? Icons.volume_up_rounded : Icons.volume_mute_rounded, color: Colors.white70, size: isMobile ? 18 : 22),
                  Expanded(
                    child: SliderTheme(
                      data: SliderThemeData(
                        trackHeight: isMobile ? 3 : 5,
                        thumbShape: RoundSliderThumbShape(enabledThumbRadius: isMobile ? 4 : 7),
                        activeTrackColor: Colors.white,
                        inactiveTrackColor: Colors.white24,
                        thumbColor: Colors.white,
                      ),
                      child: Slider(value: player.volume.toDouble().clamp(0.0, 100.0), max: 100, onChanged: (val) => player.setVolume(val)),
                    ),
                  ),
                ],
              ),
              SizedBox(height: isMobile ? 0 : 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  TextButton.icon(
                    onPressed: () {
                      Navigator.of(context).pop();
                      showGeneralDialog(
                        context: context,
                        barrierDismissible: true,
                        barrierLabel: 'Cover Flow',
                        barrierColor: Colors.black87,
                        transitionDuration: const Duration(milliseconds: 300),
                        pageBuilder: (_, __, ___) => const QueueCarouselView(),
                        transitionBuilder: (_, anim, __, child) {
                          return FadeTransition(opacity: anim, child: child);
                        },
                      );
                    },
                    icon: Icon(Icons.view_carousel_rounded, color: btnColor, size: iconSize),
                    label: Text('Cover Flow', style: TextStyle(color: btnColor, fontSize: labelSize, fontWeight: FontWeight.w500)),
                  ),
                  TextButton.icon(
                    onPressed: () {
                      if (isMobile) {
                        Navigator.of(context).pop();
                        _showLyricsDialog(context, player.currentTrack!.title, player.currentTrack!.artist, player.currentTrack!.filename);
                      } else {
                        setState(() => _showLyrics = !_showLyrics);
                      }
                    },
                    icon: Icon(Icons.lyrics_outlined, color: btnColor, size: iconSize),
                    label: Text('Letras', style: TextStyle(color: btnColor, fontSize: labelSize, fontWeight: FontWeight.w500)),
                  ),
                  if (player.isVideo)
                    TextButton.icon(
                      onPressed: () { Navigator.of(context).pop(); player.setVideoMode(true); },
                      icon: Icon(Icons.fullscreen_rounded, color: btnColor, size: iconSize),
                      label: Text('Video', style: TextStyle(color: btnColor, fontSize: labelSize, fontWeight: FontWeight.w500)),
                    ),
                  TextButton.icon(
                    onPressed: () { Navigator.of(context).pop(); showEqualizerDialog(context); },
                    icon: Icon(Icons.equalizer_rounded, color: btnColor, size: iconSize),
                    label: Text('Ecualizador', style: TextStyle(color: btnColor, fontSize: labelSize, fontWeight: FontWeight.w500)),
                  ),
                  TextButton.icon(
                    onPressed: () { Navigator.of(context).pop(); player.stop(); },
                    icon: Icon(Icons.stop_rounded, color: Colors.red.shade300, size: iconSize),
                    label: Text('Detener', style: TextStyle(color: Colors.red.shade300, fontSize: labelSize, fontWeight: FontWeight.w500)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDuration(Duration d) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(d.inMinutes.remainder(60))}:${two(d.inSeconds.remainder(60))}';
  }

  void _showLyricsDialog(BuildContext context, String title, String artist, String? filename) {
    showDialog(context: context, builder: (_) => LyricsView(title: title, artist: artist, filename: filename));
  }

  void _showMoreOptions(BuildContext context, PlayerProvider player, dynamic track) {
    showModalBottomSheet(
      context: context,
      backgroundColor: context.colors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.only(topLeft: Radius.circular(20), topRight: Radius.circular(20))),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(Icons.playlist_add_rounded, color: context.colors.textPrimary),
                title: Text('Añadir a playlist', style: TextStyle(color: context.colors.textPrimary)),
                onTap: () => Navigator.of(context).pop(),
              ),
              ListTile(
                leading: const Icon(Icons.share_rounded, color: Colors.blueAccent),
                title: Text('Compartir', style: TextStyle(color: context.colors.textPrimary)),
                onTap: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Infinite scrolling text banner widget
class _MarqueeBanner extends StatefulWidget {
  final String text;
  final double fontSize;
  final AnimationController controller;

  const _MarqueeBanner({
    required this.text,
    required this.fontSize,
    required this.controller,
  });

  @override
  State<_MarqueeBanner> createState() => _MarqueeBannerState();
}

class _MarqueeBannerState extends State<_MarqueeBanner> {
  double _textWidth = 0;
  final String _spacer = '       •       ';

  @override
  void initState() {
    super.initState();
    _measureText();
  }

  @override
  void didUpdateWidget(covariant _MarqueeBanner oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text || oldWidget.fontSize != widget.fontSize) {
      _measureText();
    }
  }

  void _measureText() {
    final textPainter = TextPainter(
      text: TextSpan(
        text: '${widget.text}$_spacer',
        style: TextStyle(fontSize: widget.fontSize, fontWeight: FontWeight.w700, letterSpacing: -0.5),
      ),
      maxLines: 1,
      textDirection: TextDirection.ltr,
    )..layout();
    setState(() {
      _textWidth = textPainter.width;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_textWidth <= 0) return const SizedBox.shrink();

    final style = TextStyle(
      color: Colors.white,
      fontSize: widget.fontSize,
      fontWeight: FontWeight.w700,
      letterSpacing: -0.5,
      decoration: TextDecoration.none,
      shadows: [
        Shadow(color: Colors.black.withValues(alpha: 0.8), blurRadius: 6),
        Shadow(color: Colors.black.withValues(alpha: 0.4), blurRadius: 12),
      ],
    );

    return ClipRect(
      child: AnimatedBuilder(
        animation: widget.controller,
        builder: (context, child) {
          final offset = widget.controller.value * _textWidth;
          return Transform.translate(
            offset: Offset(-offset, 0),
            child: child,
          );
        },
        child: OverflowBox(
          maxWidth: double.infinity,
          alignment: Alignment.centerLeft,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('${widget.text}$_spacer', style: style),
              Text('${widget.text}$_spacer', style: style),
              Text('${widget.text}$_spacer', style: style),
            ],
          ),
        ),
      ),
    );
  }
}
