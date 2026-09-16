import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:sonero_app/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/library_provider.dart';
import '../providers/listen_provider.dart';
import '../providers/player_provider.dart';
import '../providers/settings_provider.dart';
import '../models/track.dart';
import 'sidebar/sidebar_widget.dart';
import 'library/library_page.dart';
import 'home/home_view.dart';
import 'analytics/analytics_view.dart';
import 'listen/listen_overlay.dart';
import 'player/mini_player.dart';
import 'player/video_player_view.dart';
import 'player/lyrics_view.dart';
import 'theme.dart';
import 'video_download_dialog.dart';
import 'downloads/downloads_page.dart';
import 'search/search_view.dart';
import 'setup_modal.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path/path.dart' as p;
import 'wifi_transfer/wifi_transfer_page.dart';
import '../services/background_listen_service.dart';
import '../providers/downloads_provider.dart';
import 'settings/settings_page.dart' as settings_page;

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _currentViewIndex = 1;
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>>? _wifiFilesToSend;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchQueryChanged);
    HardwareKeyboard.instance.addHandler(_handleKey);
    WidgetsBinding.instance.addPostFrameCallback((_) => _init());
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchQueryChanged);
    _searchController.dispose();
    HardwareKeyboard.instance.removeHandler(_handleKey);
    super.dispose();
  }

  void _onSearchQueryChanged() {
    final query = _searchController.text;
    if (query.isNotEmpty && _currentViewIndex != 3) {
      setState(() {
        _currentViewIndex = 3;
      });
    }
  }

  bool _handleKey(KeyEvent event) {
    if (event is! KeyDownEvent) return false;

    final ctrl  = HardwareKeyboard.instance.isControlPressed;
    final shift = HardwareKeyboard.instance.isShiftPressed;
    final key   = event.logicalKey;
    final player = context.read<PlayerProvider>();
    final hasTrack = player.currentTrack != null;

    // ── Existing listen shortcuts (Ctrl+Shift+M/S/V) ──────────────────────
    if (ctrl && shift && key == LogicalKeyboardKey.keyM) {
      _triggerListen('mic');
      return true;
    }
    if (ctrl && shift && key == LogicalKeyboardKey.keyS) {
      _triggerListen('system');
      return true;
    }
    if (ctrl && shift && key == LogicalKeyboardKey.keyV) {
      showDialog(
        context: context,
        builder: (_) => const VideoDownloadDialog(),
      ).then((result) {
        if (result != null) {
          if (result is String) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Descarga completada con advertencias: $result'),
                backgroundColor: Colors.orange,
                duration: const Duration(seconds: 5),
              ),
            );
          } else if (result == true) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(AppLocalizations.of(context)!.downloadComplete)),
            );
          }
          final settings = context.read<SettingsProvider>();
          context.read<LibraryProvider>().loadTracks(settings.api);
        }
      });
      return true;
    }

    // ── Player shortcuts (only when a track is loaded) ────────────────────

    // Guard: don't fire single-key shortcuts while the user is typing in a field
    final bool typing = _isTyping();

    // Volume: Ctrl+↑ / Ctrl+↓  (avoids conflicts with sidebar list navigation)
    if (ctrl && !shift) {
      if (key == LogicalKeyboardKey.arrowUp && hasTrack) {
        player.setVolume((player.volume + 5).clamp(0, 100));
        return true;
      }
      if (key == LogicalKeyboardKey.arrowDown && hasTrack) {
        player.setVolume((player.volume - 5).clamp(0, 100));
        return true;
      }
    }

    if (!ctrl && !shift) {
      // ← / → : prev / next track (no conflict — sidebar navigates vertically)
      if (key == LogicalKeyboardKey.arrowLeft && hasTrack) {
        player.previous();
        return true;
      }
      if (key == LogicalKeyboardKey.arrowRight && hasTrack) {
        player.next();
        return true;
      }

      // Space: play/pause (only if not typing, to allow text-field spaces)
      if (key == LogicalKeyboardKey.space && hasTrack && !typing) {
        player.playPause();
        return true;
      }

      // Single-letter shortcuts — skip when typing in any text field
      if (!typing) {
        if (key == LogicalKeyboardKey.keyM && hasTrack) {
          player.toggleMute();
          return true;
        }
        if (key == LogicalKeyboardKey.keyS && hasTrack) {
          player.toggleShuffle();
          return true;
        }
        if (key == LogicalKeyboardKey.keyR && hasTrack) {
          player.toggleRepeat();
          return true;
        }
        if (key == LogicalKeyboardKey.keyX && hasTrack) {
          player.stop();
          return true;
        }
        if (key == LogicalKeyboardKey.keyF && player.isVideoMode) {
          player.toggleFullscreen();
          return true;
        }
        if (key == LogicalKeyboardKey.keyL && hasTrack && !player.isVideoMode) {
          final track = player.currentTrack!;
          showDialog(
            context: context,
            builder: (_) => LyricsView(
              title: track.title,
              artist: track.artist,
              filename: track.filename,
            ),
          );
          return true;
        }
      }

      if (key == LogicalKeyboardKey.escape) {
        if (player.isFullscreen) {
          player.setFullscreen(false);
          return true;
        }
        if (player.isVideoMode) {
          player.setVideoMode(false);
          return true;
        }
      }
    }

    return false;
  }

  /// Returns true when focus is inside an editable text widget, so single-key
  /// shortcuts don't interfere with typing in the search bar or other fields.
  ///
  /// We walk up the focus scope from the primary focus node and check whether
  /// any ancestor widget in the element tree is an [EditableText].  This covers
  /// cases where the focused node's own context points to a wrapper widget
  /// (e.g. TextField, SearchBar) whose child is the actual EditableText.
  bool _isTyping() {
    final focus = FocusManager.instance.primaryFocus;
    if (focus == null) return false;

    // Walk up the focus-node ancestors checking each context
    FocusNode? node = focus;
    while (node != null) {
      final ctx = node.context;
      if (ctx != null) {
        // Check if this element or any ancestor up to the nearest route is an
        // EditableText — visitAncestorElements stops when the callback returns false.
        bool found = false;
        ctx.visitAncestorElements((element) {
          if (element.widget is EditableText) {
            found = true;
            return false; // stop
          }
          return true; // keep walking
        });
        if (found) return true;
        // Also check the widget at this node itself
        if (ctx.widget is EditableText) return true;
      }
      // Move to the parent focus node
      node = node.parent;
      // Stop at the root scope to avoid infinite loops
      if (node == FocusManager.instance.rootScope) break;
    }
    return false;
  }

  void _triggerListen(String source) {
    final settings = context.read<SettingsProvider>();
    final listen   = context.read<ListenProvider>();
    if (listen.isListening) return;
    listen.startListening(
      api: settings.api,
      source: source,
      duration: settings.listenDuration,
      deviceIndex: settings.deviceIndex,
      onDone: () {
        context.read<LibraryProvider>().loadTracks(settings.api);
        context.read<LibraryProvider>().loadPlaylists(settings.api);
      },
    );
  }

  Future<void> _init() async {
    final settings = context.read<SettingsProvider>();
    final library  = context.read<LibraryProvider>();
    
    if (!settings.hasMusicFolder) {
      // Show setup modal. Since it is non-dismissible, we wait for it to close.
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const SetupModal(),
      );
    } else {
      // Already set up, but let's check/request permissions sequentially just in case
      if (!kIsWeb && Platform.isAndroid) {
        try {
          await [
            Permission.audio,
            Permission.videos,
            Permission.storage,
            Permission.manageExternalStorage,
            Permission.notification,
            Permission.microphone,
          ].request();
          await settings.refreshFolders();
        } catch (e) {
          debugPrint('Error requesting permissions in app_shell: $e');
        }
      }
    }
    
    await library.loadPlaylists(settings.api);
    await library.loadTracks(settings.api);

    if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
      try {
        await BackgroundListenService.start();
      } catch (e) {
        debugPrint('Error starting BackgroundListenService: $e');
      }
    }
  }

  List<Map<String, dynamic>> _prepareWifiUploadQueue(List<Track> selectedTracks, SettingsProvider settings) {
    final List<Map<String, dynamic>> queue = [];
    for (var track in selectedTracks) {
      final audioPath = p.join(settings.musicFolder, track.filename);
      
      final relativePath = track.filename;
      final hasFolder = relativePath.contains('/');
      final playlist = hasFolder ? p.dirname(relativePath) : null;
      final filename = p.basename(relativePath);

      String? coverFilename;
      if (track.coverUrl != null && track.coverUrl!.isNotEmpty && !track.coverUrl!.startsWith('http')) {
        final coverFile = File(track.coverUrl!);
        if (coverFile.existsSync()) {
          coverFilename = p.basename(track.coverUrl!);
          queue.add({
            'filePath': coverFile.path,
            'type': 'cover',
            'filename': coverFilename,
            'playlist': null,
            'title': '',
            'artist': '',
          });
        }
      }

      queue.add({
        'filePath': audioPath,
        'type': 'music',
        'filename': filename,
        'playlist': playlist,
        'title': track.title,
        'artist': track.artist,
        'album': track.album,
        'genre': track.genre,
        'year': track.year,
        'cover_url': coverFilename,
      });
    }
    return queue;
  }



  PopupMenuItem<int> _buildPopupMenuItem(int index, IconData icon, String title) {
    final isSelected = _currentViewIndex == index;
    return PopupMenuItem<int>(
      value: index,
      child: Row(
        children: [
          Icon(
            icon,
            color: isSelected ? Theme.of(context).colorScheme.primary : context.colors.textSecondary,
            size: 20,
          ),
          const SizedBox(width: 12),
          Text(
            title,
            style: TextStyle(
              color: isSelected ? context.colors.textPrimary : context.colors.textSecondary,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  void _openMobileSettings(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const SettingsPageRoute(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final player       = context.watch<PlayerProvider>();
    final isSidebarOpen = player.isSidebarVisible;
    final isVideoMode  = player.isVideoMode;
    final isMobile     = MediaQuery.of(context).size.width < 600;

    Widget currentView;
    switch (_currentViewIndex) {
      case 0:
        currentView = HomeView(onNavigate: (i) => setState(() => _currentViewIndex = i));
        break;
      case 1:
        currentView = LibraryPage(
          onWiFiShare: (selectedTracks) {
            final settings = context.read<SettingsProvider>();
            final queue = _prepareWifiUploadQueue(selectedTracks, settings);
            setState(() {
              _wifiFilesToSend = queue;
              _currentViewIndex = 5;
            });
          },
        );
        break;
      case 2:
        currentView = const AnalyticsView();
        break;
      case 3:
        currentView = SearchView(
          onNavigate: (i) => setState(() => _currentViewIndex = i),
          searchController: _searchController,
        );
        break;
      case 4:
        currentView = const DownloadsPage();
        break;
      case 5:
        currentView = WifiTransferPage(
          initialFilesToSend: _wifiFilesToSend,
          onClearFiles: () {
            setState(() {
              _wifiFilesToSend = null;
            });
          },
        );
        break;
      default:
        currentView = HomeView(onNavigate: (i) => setState(() => _currentViewIndex = i));
    }

    return Stack(
      children: [
        Scaffold(
          backgroundColor: context.colors.bg,
          body: Column(
            children: [
              Expanded(
                child: Row(
                  children: [
                    // Sidebar (always in flow, animates width)
                    if (!isMobile && !isVideoMode)
                      SidebarWidget(
                        currentIndex: _currentViewIndex,
                        isCollapsed: !isSidebarOpen,
                        onToggle: () => player.toggleSidebar(),
                        onNavigate: (index) =>
                            setState(() => _currentViewIndex = index),
                      ),

                    // Main content (takes remaining space)
                    Expanded(
                      child: Stack(
                        children: [
                          // Main view
                          Positioned.fill(
                            child: currentView,
                          ),

                          // Netflix-style Video Overlay (full width)
                          if (isVideoMode)
                            const Positioned.fill(
                              child: VideoOverlay(),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const MiniPlayer(),
              // Add padding at bottom for mobile pill bar
              if (isMobile) const SizedBox(height: 70),
            ],
          ),
        ),
        const ListenOverlay(),
        // ── Floating Pill Bottom Nav (Mobile only) ───────────────────
        if (isMobile)
          Positioned(
            left: 24,
            right: 24,
            bottom: MediaQuery.of(context).padding.bottom + 12,
            child: Container(
              height: 60,
              decoration: BoxDecoration(
                color: context.colors.surface.withOpacity(0.95),
                borderRadius: BorderRadius.circular(30),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.15),
                    blurRadius: 20,
                    offset: const Offset(0, 4),
                  ),
                ],
                border: Border.all(
                  color: context.colors.border.withOpacity(0.15),
                  width: 0.5,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _MobilePillNavItem(
                    icon: Icons.home_rounded,
                    label: 'Inicio',
                    isSelected: _currentViewIndex == 0,
                    onTap: () => setState(() => _currentViewIndex = 0),
                  ),
                  _MobilePillNavItem(
                    icon: Icons.library_music_rounded,
                    label: 'Biblioteca',
                    isSelected: _currentViewIndex == 1,
                    onTap: () => setState(() => _currentViewIndex = 1),
                  ),
                  _MobilePillNavItem(
                    icon: Icons.search_rounded,
                    label: 'Buscar',
                    isSelected: _currentViewIndex == 3,
                    onTap: () => setState(() => _currentViewIndex = 3),
                  ),
                  _MobilePillNavItem(
                    icon: Icons.download_rounded,
                    label: 'Descargas',
                    isSelected: _currentViewIndex == 4,
                    onTap: () => setState(() => _currentViewIndex = 4),
                    badgeCount: context.watch<DownloadsProvider>().activeJobsCount,
                  ),
                  _MobilePillNavItem(
                    icon: Icons.settings_rounded,
                    label: 'Ajustes',
                    isSelected: false,
                    onTap: () => _openMobileSettings(context),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class SettingsPageRoute extends StatelessWidget {
  const SettingsPageRoute({super.key});

  @override
  Widget build(BuildContext context) {
    return const settings_page.SettingsPage();
  }
}

class _MobilePillNavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final int badgeCount;

  const _MobilePillNavItem({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
    this.badgeCount = 0,
  });

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 52,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(
                  icon,
                  size: 22,
                  color: isSelected ? accent : context.colors.textSecondary.withOpacity(0.6),
                ),
                if (badgeCount > 0)
                  Positioned(
                    right: -6,
                    top: -4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                      decoration: BoxDecoration(
                        color: accent,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      constraints: const BoxConstraints(minWidth: 14, minHeight: 12),
                      child: Text(
                        '$badgeCount',
                        style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.w700),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                color: isSelected ? accent : context.colors.textSecondary.withOpacity(0.5),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
