import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/track.dart';
import '../../models/playlist.dart';
import '../../providers/library_provider.dart';
import '../../providers/settings_provider.dart';
import '../../providers/player_provider.dart';
import '../../core/csv_service.dart';
import '../../services/lyrics_service.dart';
import '../theme.dart';
import '../widgets/track_cover_image.dart';
import 'metadata_dialog.dart';

class LibraryPage extends StatefulWidget {
  final Function(List<Track>)? onWiFiShare;
  const LibraryPage({super.key, this.onWiFiShare});

  @override
  State<LibraryPage> createState() => _LibraryPageState();
}

class _LibraryPageState extends State<LibraryPage>
    with SingleTickerProviderStateMixin {
  bool _isListView = false;
  late TabController _tabController;
  bool _isMultiSelectMode = false;
  final Set<String> _selectedTrackFilenames = {};

  static const _videoExts = {'.mp4', '.mkv', '.avi', '.mov', '.webm'};

  bool _isVideoTrack(Track t) {
    final name = t.filename.toLowerCase();
    return _videoExts.any((e) => name.endsWith(e));
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _toggleMultiSelectMode() {
    setState(() {
      _isMultiSelectMode = !_isMultiSelectMode;
      _selectedTrackFilenames.clear();
    });
  }

  void _toggleTrackSelection(Track track) {
    setState(() {
      if (_selectedTrackFilenames.contains(track.filename)) {
        _selectedTrackFilenames.remove(track.filename);
        if (_selectedTrackFilenames.isEmpty) {
          _isMultiSelectMode = false;
        }
      } else {
        _selectedTrackFilenames.add(track.filename);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final library  = context.watch<LibraryProvider>();
    final settings = context.read<SettingsProvider>();
    final selected = library.selected;

    final allTracks   = library.tracks;
    final audioTracks = allTracks.where((t) => !_isVideoTrack(t)).toList();
    final videoTracks = allTracks.where(_isVideoTrack).toList();

    final List<Track> currentTracks = switch (_tabController.index) {
      1 => audioTracks,
      2 => videoTracks,
      _ => allTracks,
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Header ──────────────────────────────────────────────────────────
        _PageHeader(
          playlist:    selected,
          tracks:      currentTracks,
          allTracks:   allTracks,
          settings:    settings,
          isListView:  _isListView,
          tabIndex:    _tabController.index,
          onToggleView: () => setState(() => _isListView = !_isListView),
          isMultiSelectMode: _isMultiSelectMode,
          onToggleMultiSelect: _toggleMultiSelectMode,
        ),

        // ── Tabs ─────────────────────────────────────────────────────────────
        Builder(builder: (context) {
          final isMobile = MediaQuery.of(context).size.width < 600;
          return TabBar(
            controller: _tabController,
            isScrollable: false,
            indicatorColor: Theme.of(context).colorScheme.primary,
            labelColor: Theme.of(context).colorScheme.primary,
            unselectedLabelColor: context.colors.textSecondary,
            labelStyle: TextStyle(fontWeight: FontWeight.w600, fontSize: isMobile ? 11 : 13),
            labelPadding: isMobile ? const EdgeInsets.symmetric(horizontal: 6) : null,
            tabs: [
              Tab(
                height: isMobile ? 36 : null,
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.library_music_rounded, size: isMobile ? 14 : 16),
                  const SizedBox(width: 4),
                  Text('Todo (${allTracks.length})'),
                ]),
              ),
              Tab(
                height: isMobile ? 36 : null,
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.audiotrack_rounded, size: isMobile ? 14 : 16),
                  const SizedBox(width: 4),
                  Text('Audio (${audioTracks.length})'),
                ]),
              ),
              Tab(
                height: isMobile ? 36 : null,
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.videocam_rounded, size: isMobile ? 14 : 16),
                  const SizedBox(width: 4),
                  Text('Video (${videoTracks.length})'),
                ]),
              ),
            ],
          );
        }),

        Divider(height: 1, color: context.colors.border),

        // ── Content ─────────────────────────────────────────────────────────
        Expanded(
          child: library.loading
              ? Center(child: CircularProgressIndicator(
                  color: Theme.of(context).colorScheme.primary))
              : currentTracks.isEmpty
                  ? _EmptyState(
                      playlist: selected,
                      tabIndex: _tabController.index,
                    )
                  : TabBarView(
                      controller: _tabController,
                      children: [
                        _buildContent(allTracks,   allTracks),
                        _buildContent(audioTracks, audioTracks),
                        _buildContent(videoTracks, videoTracks),
                      ],
                    ),
        ),
        if (_isMultiSelectMode)
          _buildSelectionActionBar(context, library, settings, currentTracks),
      ],
    );
  }

  Widget _buildContent(List<Track> tracks, List<Track> queue) {
    if (tracks.isEmpty) {
      return _EmptyState(
        playlist: context.read<LibraryProvider>().selected,
        tabIndex: _tabController.index,
      );
    }
    return _isListView
        ? _TrackList(
            tracks: tracks,
            queue: queue,
            isMultiSelectMode: _isMultiSelectMode,
            selectedTrackFilenames: _selectedTrackFilenames,
            onTrackToggled: _toggleTrackSelection,
            onTrackLongPressed: (track) {
              if (!_isMultiSelectMode) {
                setState(() {
                  _isMultiSelectMode = true;
                  _selectedTrackFilenames.add(track.filename);
                });
              }
            },
          )
        : _TrackGrid(
            tracks: tracks,
            queue: queue,
            isMultiSelectMode: _isMultiSelectMode,
            selectedTrackFilenames: _selectedTrackFilenames,
            onTrackToggled: _toggleTrackSelection,
            onTrackLongPressed: (track) {
              if (!_isMultiSelectMode) {
                setState(() {
                  _isMultiSelectMode = true;
                  _selectedTrackFilenames.add(track.filename);
                });
              }
            },
          );
  }

  Widget _buildSelectionActionBar(
    BuildContext context,
    LibraryProvider library,
    SettingsProvider settings,
    List<Track> currentTracks,
  ) {
    final selectedTracks = currentTracks.where((t) => _selectedTrackFilenames.contains(t.filename)).toList();
    
    return SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.fromLTRB(12, 8, 12, 12),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: context.colors.surfaceAlt,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: context.colors.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.close),
              iconSize: 20,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              onPressed: () {
                setState(() {
                  _isMultiSelectMode = false;
                  _selectedTrackFilenames.clear();
                });
              },
            ),
            const SizedBox(width: 6),
            Text(
              '${selectedTracks.length} seleccionados',
              style: TextStyle(
                color: context.colors.textPrimary,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Align(
                alignment: Alignment.centerRight,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.playlist_add),
                        iconSize: 20,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                        color: Theme.of(context).colorScheme.primary,
                        tooltip: 'Añadir a playlist',
                        onPressed: selectedTracks.isEmpty ? null : () => _onBatchAdd(context, library, settings, selectedTracks),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.drive_file_move_rounded),
                        iconSize: 20,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                        color: Colors.cyan,
                        tooltip: 'Mover a playlist',
                        onPressed: selectedTracks.isEmpty ? null : () => _onBatchMove(context, library, settings, selectedTracks),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.auto_awesome_rounded),
                        iconSize: 20,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                        color: Colors.orange,
                        tooltip: 'Autocompletar metadatos (API)',
                        onPressed: selectedTracks.isEmpty ? null : () => _onBatchAutocomplete(context, library, settings, selectedTracks),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.delete_rounded),
                        iconSize: 20,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                        color: context.colors.error,
                        tooltip: 'Eliminar archivos',
                        onPressed: selectedTracks.isEmpty ? null : () => _onBatchDelete(context, library, settings, selectedTracks),
                      ),
                      if (widget.onWiFiShare != null) ...[
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(Icons.wifi_rounded),
                          iconSize: 20,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                          color: Colors.lightGreen,
                          tooltip: 'Compartir vía WiFi',
                          onPressed: selectedTracks.isEmpty ? null : () => widget.onWiFiShare!(selectedTracks),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _onBatchAdd(
    BuildContext context,
    LibraryProvider library,
    SettingsProvider settings,
    List<Track> tracks,
  ) async {
    final Playlist? pl = await _showPlaylistPicker(context, library, title: 'Añadir selección a...');
    if (pl != null && context.mounted) {
      await library.addTracksToPlaylist(settings.api, tracks, pl.name);
      setState(() {
        _isMultiSelectMode = false;
        _selectedTrackFilenames.clear();
      });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Añadidas ${tracks.length} canciones a "${pl.name}"'),
        backgroundColor: context.colors.success,
      ));
    }
  }

  Future<void> _onBatchMove(
    BuildContext context,
    LibraryProvider library,
    SettingsProvider settings,
    List<Track> tracks,
  ) async {
    final Playlist? pl = await _showPlaylistPicker(context, library, title: 'Mover selección a...');
    if (pl != null && context.mounted) {
      await library.moveTracks(settings.api, tracks, pl.name);
      setState(() {
        _isMultiSelectMode = false;
        _selectedTrackFilenames.clear();
      });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Movidas ${tracks.length} canciones a "${pl.name}"'),
        backgroundColor: context.colors.success,
      ));
    }
  }

  Future<void> _onBatchAutocomplete(
    BuildContext context,
    LibraryProvider library,
    SettingsProvider settings,
    List<Track> tracks,
  ) async {
    try {
      final filenames = tracks.map((t) => t.filename).toList();
      final jobId = await settings.api.autoFillMetadata(filenames);
      if (context.mounted) {
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => _AutofillProgressDialog(jobId: jobId, settings: settings),
        );
        setState(() {
          _isMultiSelectMode = false;
          _selectedTrackFilenames.clear();
        });
        context.read<LibraryProvider>().loadTracks(settings.api);
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error: $e'),
          backgroundColor: context.colors.error,
        ));
      }
    }
  }

  Future<void> _onBatchDelete(
    BuildContext context,
    LibraryProvider library,
    SettingsProvider settings,
    List<Track> tracks,
  ) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: context.colors.surfaceAlt,
        title: const Text('Eliminar canciones'),
        content: Text('¿Seguro que quieres eliminar estas ${tracks.length} canciones del disco físicamente? Esta acción no se puede deshacer.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Eliminar', style: TextStyle(color: context.colors.error)),
          ),
        ],
      ),
    );

    if (confirm == true && context.mounted) {
      await library.deleteTracks(settings.api, tracks);
      setState(() {
        _isMultiSelectMode = false;
        _selectedTrackFilenames.clear();
      });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Eliminadas ${tracks.length} canciones'),
        backgroundColor: context.colors.success,
      ));
    }
  }

  Future<Playlist?> _showPlaylistPicker(BuildContext context, LibraryProvider library, {required String title}) async {
    return await showModalBottomSheet<Playlist>(
      context: context,
      backgroundColor: context.colors.bg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        final customPlaylists = library.playlists.where((p) => !p.isLibrary).toList();
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 10),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: context.colors.textSecondary.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                title,
                style: TextStyle(
                  color: context.colors.textPrimary,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const Divider(),
              if (customPlaylists.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text('No hay listas de reproducción creadas.', style: TextStyle(color: context.colors.textSecondary)),
                )
              else
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: customPlaylists.length,
                    itemBuilder: (context, index) {
                      final pl = customPlaylists[index];
                      return ListTile(
                        leading: const Icon(Icons.playlist_play_rounded),
                        title: Text(pl.name, style: TextStyle(color: context.colors.textPrimary)),
                        onTap: () => Navigator.pop(ctx, pl),
                      );
                    },
                  ),
                ),
              const SizedBox(height: 10),
            ],
          ),
        );
      },
    );
  }
}

// ── Header ────────────────────────────────────────────────────────────────────

class _PageHeader extends StatelessWidget {
  final Playlist playlist;
  final List<Track> tracks;     // current tab's tracks (for count)
  final List<Track> allTracks; // all tracks (for autofill/export)
  final SettingsProvider settings;
  final bool isListView;
  final int tabIndex;
  final VoidCallback onToggleView;
  final bool isMultiSelectMode;
  final VoidCallback onToggleMultiSelect;

  const _PageHeader({
    required this.playlist,
    required this.tracks,
    required this.allTracks,
    required this.settings,
    required this.isListView,
    required this.tabIndex,
    required this.onToggleView,
    required this.isMultiSelectMode,
    required this.onToggleMultiSelect,
  });

  @override
  Widget build(BuildContext context) {
    final label = switch (tabIndex) {
      1 => '${tracks.length} pista${tracks.length == 1 ? '' : 's'} de audio',
      2 => '${tracks.length} video${tracks.length == 1 ? '' : 's'}',
      _ => '${tracks.length} canción${tracks.length == 1 ? '' : 'es'}',
    };
    
    final isMobile = MediaQuery.of(context).size.width < 600;

    final headerText = Container(
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 10 : 14,
        vertical: isMobile ? 6 : 10,
      ),
      decoration: BoxDecoration(
        color: context.colors.surfaceAlt,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () => _showPlaylistSelectorBottomSheet(context),
            borderRadius: BorderRadius.circular(8),
            hoverColor: Colors.transparent,
            splashColor: Colors.transparent,
            highlightColor: Colors.transparent,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(
                    playlist.name,
                    style: TextStyle(
                      fontSize: isMobile ? 16 : 22,
                      fontWeight: FontWeight.w700,
                      color: context.colors.textPrimary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  Icons.add_rounded,
                  color: context.colors.textPrimary,
                  size: isMobile ? 18 : 24,
                ),
              ],
            ),
          ),
          const SizedBox(height: 1),
          Text(
            label,
            style: TextStyle(
              color: context.colors.textSecondary,
              fontSize: isMobile ? 11 : 13,
            ),
          ),
        ],
      ),
    );

    // Desktop: full toolbar.  Mobile: three-dot menu.
    final Widget actionsWidget;

    if (isMobile) {
      actionsWidget = PopupMenuButton<String>(
        icon: Icon(Icons.more_vert_rounded, color: context.colors.textSecondary, size: 22),
        color: context.colors.surfaceAlt,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        onSelected: (value) {
          switch (value) {
            case 'multi_select':
              onToggleMultiSelect();
              break;
            case 'toggle_view':
              onToggleView();
              break;
            case 'refresh':
              context.read<LibraryProvider>().loadTracks(settings.api);
              break;
            // Sort options
            case 'sort_dateAdded':
              context.read<LibraryProvider>().setSortOption(SortOption.dateAdded);
              break;
            case 'sort_titleAsc':
              context.read<LibraryProvider>().setSortOption(SortOption.titleAsc);
              break;
            case 'sort_titleDesc':
              context.read<LibraryProvider>().setSortOption(SortOption.titleDesc);
              break;
            case 'sort_artistAsc':
              context.read<LibraryProvider>().setSortOption(SortOption.artistAsc);
              break;
            case 'sort_artistDesc':
              context.read<LibraryProvider>().setSortOption(SortOption.artistDesc);
              break;
          }
        },
        itemBuilder: (ctx) => [
          PopupMenuItem(
            value: 'multi_select',
            child: Row(
              children: [
                Icon(
                  isMultiSelectMode ? Icons.check_circle_rounded : Icons.check_circle_outline_rounded,
                  size: 18,
                  color: isMultiSelectMode ? Theme.of(context).colorScheme.primary : context.colors.textSecondary,
                ),
                const SizedBox(width: 10),
                Text(isMultiSelectMode ? 'Cancelar selección' : 'Seleccionar'),
              ],
            ),
          ),
          const PopupMenuDivider(),
          PopupMenuItem(
            enabled: false,
            height: 32,
            child: Text('Ordenar por', style: TextStyle(
              fontSize: 12, fontWeight: FontWeight.w600,
              color: context.colors.textSecondary,
            )),
          ),
          const PopupMenuItem(value: 'sort_dateAdded', child: Text('  Más recientes')),
          const PopupMenuItem(value: 'sort_titleAsc', child: Text('  Título (A-Z)')),
          const PopupMenuItem(value: 'sort_titleDesc', child: Text('  Título (Z-A)')),
          const PopupMenuItem(value: 'sort_artistAsc', child: Text('  Artista (A-Z)')),
          const PopupMenuItem(value: 'sort_artistDesc', child: Text('  Artista (Z-A)')),
          const PopupMenuDivider(),
          PopupMenuItem(
            value: 'toggle_view',
            child: Row(
              children: [
                Icon(isListView ? Icons.grid_view_rounded : Icons.list_rounded, size: 18, color: context.colors.textSecondary),
                const SizedBox(width: 10),
                Text(isListView ? 'Vista cuadrícula' : 'Vista lista'),
              ],
            ),
          ),
          PopupMenuItem(
            value: 'refresh',
            child: Row(
              children: [
                Icon(Icons.refresh_rounded, size: 18, color: context.colors.textSecondary),
                const SizedBox(width: 10),
                const Text('Actualizar'),
              ],
            ),
          ),
        ],
      );
    } else {
      actionsWidget = Wrap(
        spacing: 8,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          // AutoFill Button (uses allTracks, not filtered)
          if (allTracks.isNotEmpty)
            _AutoFillButton(tracks: allTracks, settings: settings),
          // Export CSV button (only for playlists, not library root)
          if (!playlist.isLibrary && allTracks.isNotEmpty)
            _ExportButton(playlist: playlist, tracks: allTracks, settings: settings),
          // Grouped icon toolbar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            decoration: BoxDecoration(
              color: context.colors.surfaceAlt,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Multi-select Toggle Button
                IconButton(
                  icon: Icon(isMultiSelectMode ? Icons.check_circle_rounded : Icons.check_circle_outline_rounded, size: 19),
                  color: isMultiSelectMode ? Theme.of(context).colorScheme.primary : context.colors.textSecondary,
                  tooltip: 'Seleccionar por lotes',
                  onPressed: onToggleMultiSelect,
                  style: IconButton.styleFrom(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    backgroundColor: Colors.transparent,
                    side: BorderSide.none,
                  ),
                ),
                Container(width: 1, height: 20, color: context.colors.border.withOpacity(0.3)),
                // Sort button
                PopupMenuButton<SortOption>(
                  icon: Icon(Icons.sort_rounded, size: 19, color: context.colors.textSecondary),
                  color: context.colors.surfaceAlt,
                  tooltip: 'Ordenar',
                  initialValue: context.read<LibraryProvider>().sortOption,
                  onSelected: (option) {
                    context.read<LibraryProvider>().setSortOption(option);
                  },
                  itemBuilder: (ctx) => [
                    const PopupMenuItem(
                      value: SortOption.dateAdded,
                      child: Text('Más recientes'),
                    ),
                    const PopupMenuItem(
                      value: SortOption.titleAsc,
                      child: Text('Título (A-Z)'),
                    ),
                    const PopupMenuItem(
                      value: SortOption.titleDesc,
                      child: Text('Título (Z-A)'),
                    ),
                    const PopupMenuItem(
                      value: SortOption.artistAsc,
                      child: Text('Artista (A-Z)'),
                    ),
                    const PopupMenuItem(
                      value: SortOption.artistDesc,
                      child: Text('Artista (Z-A)'),
                    ),
                  ],
                ),
                Container(width: 1, height: 20, color: context.colors.border.withOpacity(0.3)),
                // View Toggle Button
                IconButton(
                  icon: Icon(isListView ? Icons.grid_view_rounded : Icons.list_rounded, size: 19),
                  color: context.colors.textSecondary,
                  tooltip: isListView ? 'Vista de Cuadrícula' : 'Vista de Lista',
                  onPressed: onToggleView,
                  style: IconButton.styleFrom(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    backgroundColor: Colors.transparent,
                    side: BorderSide.none,
                  ),
                ),
                Container(width: 1, height: 20, color: context.colors.border.withOpacity(0.3)),
                // Refresh button
                IconButton(
                  icon: const Icon(Icons.refresh_rounded, size: 19),
                  color: context.colors.textSecondary,
                  tooltip: 'Actualizar',
                  onPressed: () {
                    context.read<LibraryProvider>().loadTracks(settings.api);
                  },
                  style: IconButton.styleFrom(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    backgroundColor: Colors.transparent,
                    side: BorderSide.none,
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }

    return Padding(
      padding: EdgeInsets.fromLTRB(isMobile ? 16 : 24, isMobile ? 12 : 20, isMobile ? 12 : 24, isMobile ? 8 : 12),
      child: Row(
        children: [
          Expanded(child: headerText),
          if (isMobile)
            actionsWidget
          else ...[
            const Spacer(),
            actionsWidget,
          ],
        ],
      ),
    );
  }
}

class _AutoFillButton extends StatefulWidget {
  final List<Track> tracks;
  final SettingsProvider settings;

  const _AutoFillButton({
    required this.tracks,
    required this.settings,
  });

  @override
  State<_AutoFillButton> createState() => _AutoFillButtonState();
}

class _AutoFillButtonState extends State<_AutoFillButton> {
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      icon: _isLoading 
          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
          : const Icon(Icons.auto_fix_high, size: 16),
      label: Text('Autocompletar Metadatos', style: const TextStyle(fontSize: 13)),
      style: OutlinedButton.styleFrom(
        foregroundColor: Theme.of(context).colorScheme.primary,
        side: BorderSide(color: Theme.of(context).colorScheme.primary.withOpacity(0.5)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      ),
      onPressed: _isLoading ? null : () async {
        setState(() => _isLoading = true);
        try {
          final filenames = widget.tracks.map((t) => t.filename).toList();
          final jobId = await widget.settings.api.autoFillMetadata(filenames);
          
          if (context.mounted) {
            await showDialog(
              context: context,
              barrierDismissible: false,
              builder: (ctx) => _AutofillProgressDialog(jobId: jobId, settings: widget.settings),
            );
            context.read<LibraryProvider>().loadTracks(widget.settings.api);
          }
        } catch (e) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text('Error: $e'),
              backgroundColor: context.colors.error,
            ));
          }
        } finally {
          if (mounted) setState(() => _isLoading = false);
        }
      },
    );
  }
}

class _ExportButton extends StatelessWidget {
  final Playlist playlist;
  final List<Track> tracks;
  final SettingsProvider settings;

  const _ExportButton({
    required this.playlist,
    required this.tracks,
    required this.settings,
  });

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      icon: Icon(Icons.download_outlined, size: 16),
      label: Text('Exportar CSV', style: TextStyle(fontSize: 13)),
      style: OutlinedButton.styleFrom(
        foregroundColor: Theme.of(context).colorScheme.secondary,
        side: BorderSide(color: Theme.of(context).colorScheme.secondary),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      ),
      onPressed: () async {
        try {
          final path = await CsvService.exportPlaylistCsv(
            playlistName: playlist.name,
            tracks: tracks,
            outputDir: settings.musicFolder,
          );
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('CSV guardado: $path'),
                backgroundColor: context.colors.success,
              ),
            );
          }
        } catch (e) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Error: $e'),
                backgroundColor: context.colors.error,
              ),
            );
          }
        }
      },
    );
  }
}

// ── Track list ────────────────────────────────────────────────────────────────

class _TrackList extends StatelessWidget {
  final List<Track> tracks;
  final List<Track> queue;
  final bool isMultiSelectMode;
  final Set<String> selectedTrackFilenames;
  final void Function(Track) onTrackToggled;
  final void Function(Track) onTrackLongPressed;
  
  const _TrackList({
    required this.tracks,
    required this.queue,
    required this.isMultiSelectMode,
    required this.selectedTrackFilenames,
    required this.onTrackToggled,
    required this.onTrackLongPressed,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: tracks.length,
      itemBuilder: (_, i) => _TrackListRow(
        track: tracks[i],
        queue: queue,
        isMultiSelectMode: isMultiSelectMode,
        isSelected: selectedTrackFilenames.contains(tracks[i].filename),
        onToggled: () => onTrackToggled(tracks[i]),
        onLongPressed: () => onTrackLongPressed(tracks[i]),
      ),
    );
  }
}

class _TrackListRow extends StatefulWidget {
  final Track track;
  final List<Track> queue;
  final bool isMultiSelectMode;
  final bool isSelected;
  final VoidCallback onToggled;
  final VoidCallback onLongPressed;
  
  const _TrackListRow({
    required this.track,
    required this.queue,
    required this.isMultiSelectMode,
    required this.isSelected,
    required this.onToggled,
    required this.onLongPressed,
  });

  @override
  State<_TrackListRow> createState() => _TrackListRowState();
}

class _TrackListRowState extends State<_TrackListRow> {
  bool _hovered = false;

  List<PopupMenuEntry<String>> _buildMenuItems(BuildContext context, Track track) {
    final library = context.read<LibraryProvider>();
    final settings = context.read<SettingsProvider>();
    final playlists = library.playlists
        .where((p) => !p.isLibrary && p.name != track.playlist)
        .toList();

    return [
      const PopupMenuItem(value: '__edit__', child: Text('Editar metadatos')),
      const PopupMenuItem(value: '__auto__', child: Text('Autocompletar metadatos (API)')),
      PopupMenuItem(
        value: '__lyrics__',
        child: Row(
          children: [
            const Expanded(child: Text('Descargar letra')),
            if (LyricsService.hasLocal(settings.musicFolder, track.filename))
              Icon(Icons.offline_pin_rounded, size: 16, color: Colors.green.shade400),
          ],
        ),
      ),
      PopupMenuItem(
        value: '__delete__',
        child: Text('Eliminar archivo', style: TextStyle(color: context.colors.error)),
      ),
      const PopupMenuDivider(),
      PopupMenuItem(enabled: false,
        child: Text('Mover a...',
            style: TextStyle(
                color: context.colors.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w600)),
      ),
      if (track.playlist.isNotEmpty)
        const PopupMenuItem(value: '__root__', child: Text('Biblioteca (raíz)')),
      ...playlists.map(
        (pl) => PopupMenuItem(value: pl.name, child: Text(pl.name)),
      ),
      const PopupMenuDivider(),
      const PopupMenuItem(
        value: '__new_playlist__',
        child: Row(
          children: [
            Icon(Icons.playlist_add_rounded, size: 18),
            SizedBox(width: 8),
            Text('Crear lista de reproducción'),
          ],
        ),
      ),
      const PopupMenuItem(
        value: '__new_album__',
        child: Row(
          children: [
            Icon(Icons.album_rounded, size: 18),
            SizedBox(width: 8),
            Text('Crear álbum'),
          ],
        ),
      ),
    ];
  }

  void _handleMenuAction(BuildContext context, Track track, String action) {
    final renderBox = context.findRenderObject() as RenderBox;
    final position = renderBox.localToGlobal(Offset(renderBox.size.width, renderBox.size.height / 2));
    // Delegate to existing handler
    _handleTrackAction(context, track, action);
  }

  Future<void> _handleTrackAction(BuildContext context, Track track, String action) async {
    final library = context.read<LibraryProvider>();
    final settings = context.read<SettingsProvider>();

    if (action == '__edit__') {
      final changed = await showDialog<bool>(
        context: context,
        builder: (_) => MetadataDialog(track: track),
      );
      if (changed == true && context.mounted) {
        context.read<LibraryProvider>().loadTracks(settings.api);
      }
      return;
    }

    if (action == '__auto__') {
      try {
        final jobId = await settings.api.autoFillMetadata([track.filename]);
        if (context.mounted) {
          await showDialog(
            context: context,
            barrierDismissible: false,
            builder: (ctx) => _AutofillProgressDialog(jobId: jobId, settings: settings),
          );
          context.read<LibraryProvider>().loadTracks(settings.api);
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Error: $e'),
            backgroundColor: context.colors.error,
          ));
        }
      }
      return;
    }

    if (action == '__lyrics__') {
      try {
        final result = await settings.api.saveLyrics(
          filename: track.filename,
          title: track.title.isNotEmpty ? track.title : track.filename,
          artist: track.artist,
        );
        if (context.mounted) {
          if (result['saved'] == true) {
            final musicFolder = settings.musicFolder;
            if (musicFolder.isNotEmpty) {
              final syncedContent = result['synced'] as String?;
              final plainContent = result['plain'] as String?;
              if (syncedContent != null && syncedContent.trim().isNotEmpty) {
                await LyricsService.saveLrc(musicFolder, track.filename, syncedContent);
              } else if (plainContent != null && plainContent.trim().isNotEmpty) {
                await LyricsService.saveTxt(musicFolder, track.filename, plainContent);
              }
            }
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text('Letra guardada (${result['type'] == 'synced' ? 'sincronizada' : 'texto plano'})'),
                backgroundColor: context.colors.success,
                duration: const Duration(seconds: 3),
              ));
            }
          } else {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(result['error'] ?? 'No se pudo descargar la letra.'),
              backgroundColor: context.colors.error,
            ));
          }
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Error: $e'),
            backgroundColor: context.colors.error,
          ));
        }
      }
      return;
    }

    if (action == '__delete__') {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Eliminar canción'),
          content: Text('¿Seguro que quieres eliminar "${track.title.isNotEmpty ? track.title : track.filename}"?'),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancelar')),
            TextButton(onPressed: () => Navigator.of(context).pop(true),
              child: Text('Eliminar', style: TextStyle(color: context.colors.error))),
          ],
        ),
      );
      if (confirm == true) {
        try {
          await library.deleteTrack(settings.api, track);
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: const Text('Archivo eliminado'),
              backgroundColor: context.colors.success,
            ));
          }
        } catch (e) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: context.colors.error));
          }
        }
      }
      return;
    }

    if (action == '__new_playlist__') {
      final name = await showDialog<String>(
        context: context,
        builder: (_) => _NameInputDialog(title: 'Nueva lista de reproducción', hint: 'Nombre de la lista'),
      );
      if (name != null && name.trim().isNotEmpty && context.mounted) {
        try {
          await library.createPlaylist(settings.api, name.trim());
          await library.moveTrack(settings.api, track, name.trim());
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text('Lista "$name" creada'),
              backgroundColor: context.colors.success,
            ));
          }
        } catch (e) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: context.colors.error));
          }
        }
      }
      return;
    }

    if (action == '__new_album__') {
      final name = await showDialog<String>(
        context: context,
        builder: (_) => _NameInputDialog(title: 'Nuevo álbum', hint: 'Nombre del álbum'),
      );
      if (name != null && name.trim().isNotEmpty && context.mounted) {
        try {
          await library.createPlaylist(settings.api, name.trim());
          await library.moveTrack(settings.api, track, name.trim());
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text('Álbum "$name" creado'),
              backgroundColor: context.colors.success,
            ));
          }
        } catch (e) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: context.colors.error));
          }
        }
      }
      return;
    }

    // Move to playlist
    final toPlaylist = action == '__root__' ? null : action;
    await library.moveTrack(settings.api, track, toPlaylist);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Movida a ${toPlaylist ?? 'Biblioteca'}'),
        backgroundColor: context.colors.success,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final track = widget.track;
    final isMobile = MediaQuery.of(context).size.width < 600;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: () async {
          if (widget.isMultiSelectMode) {
            widget.onToggled();
            return;
          }
          try {
            final settings = context.read<SettingsProvider>();
            await context.read<PlayerProvider>().playTrack(
                  widget.track, widget.queue, settings);
          } catch (e) {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text(e.toString().replaceAll('Exception: ', '')),
                backgroundColor: context.colors.error,
                duration: const Duration(seconds: 4),
              ));
            }
          }
        },
        onLongPress: widget.onLongPressed,
        onSecondaryTapUp: (d) {
          if (!widget.isMultiSelectMode) {
            _showTrackContextMenu(context, track, d.globalPosition);
          }
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: widget.isSelected
                ? Theme.of(context).colorScheme.primary.withOpacity(0.12)
                : (_hovered ? context.colors.surfaceAlt : context.colors.surface),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: widget.isSelected
                  ? Theme.of(context).colorScheme.primary
                  : (_hovered ? Theme.of(context).colorScheme.primary.withOpacity(0.3) : context.colors.border),
            ),
          ),
          child: Row(
            children: [
              if (widget.isMultiSelectMode) ...[
                Checkbox(
                  value: widget.isSelected,
                  onChanged: (_) => widget.onToggled(),
                  activeColor: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
              ],
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: SizedBox(
                  width: 48,
                  height: 48,
                  child: TrackCoverImage(
                    coverUrl: track.coverUrl,
                    width: 48,
                    height: 48,
                    fit: BoxFit.cover,
                    errorWidget: _CoverPlaceholderSmall(isVideo: _isVideo(track)),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              // Title & Artist
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      track.title.isNotEmpty ? track.title : track.filename,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: context.colors.textPrimary,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    if (track.artist.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        track.artist,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: context.colors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (!isMobile) ...[
                // Album
                Expanded(
                  flex: 2,
                  child: Text(
                    track.album,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: context.colors.textSecondary, fontSize: 13),
                  ),
                ),
                // Year
                SizedBox(
                  width: 60,
                  child: Text(
                    track.year,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: context.colors.textSecondary, fontSize: 13),
                  ),
                ),
              ],
              // Divider line
              if (!widget.isMultiSelectMode)
                Container(
                  width: 1,
                  height: 28,
                  margin: const EdgeInsets.symmetric(horizontal: 8),
                  color: context.colors.border.withOpacity(0.4),
                ),
              // Options Menu Button
              if (!widget.isMultiSelectMode)
                SizedBox(
                  width: 36,
                  height: 36,
                  child: PopupMenuButton<String>(
                    padding: EdgeInsets.zero,
                    icon: Icon(Icons.more_horiz, size: 20, color: context.colors.textSecondary),
                    color: context.colors.surfaceAlt,
                    onSelected: (action) => _handleMenuAction(context, track, action),
                    itemBuilder: (_) => _buildMenuItems(context, track),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CoverPlaceholderSmall extends StatelessWidget {
  final bool isVideo;
  const _CoverPlaceholderSmall({this.isVideo = false});

  @override
  Widget build(BuildContext context) => Container(
        color: context.colors.surfaceAlt,
        child: Center(
          child: Icon(
            isVideo ? Icons.videocam_rounded : Icons.music_note_rounded,
            color: context.colors.textSecondary,
            size: 20,
          ),
        ),
      );
}

// ── Track context menu ────────────────────────────────────────────────────────
void _showTrackContextMenu(BuildContext context, Track track, Offset position) async {
  final library = context.read<LibraryProvider>();
  final settings = context.read<SettingsProvider>();
  final playlists = library.playlists
      .where((p) => !p.isLibrary && p.name != track.playlist)
      .toList();

  final action = await showMenu<String>(
    context: context,
    color: context.colors.surfaceAlt,
    position: RelativeRect.fromLTRB(
        position.dx, position.dy, position.dx, position.dy),
    items: [
      const PopupMenuItem(
        value: '__edit__',
        child: Text('Editar metadatos'),
      ),
      const PopupMenuItem(
        value: '__auto__',
        child: Text('Autocompletar metadatos (API)'),
      ),
      // Lyrics: show checkmark if already saved locally
      PopupMenuItem(
        value: '__lyrics__',
        child: Row(
          children: [
            const Expanded(child: Text('Descargar letra')),
            if (LyricsService.hasLocal(settings.musicFolder, track.filename))
              Icon(Icons.offline_pin_rounded,
                  size: 16, color: Colors.green.shade400),
          ],
        ),
      ),
      PopupMenuItem(
        value: '__delete__',
        child: Text('Eliminar archivo', style: TextStyle(color: context.colors.error)),
      ),
      const PopupMenuDivider(),
      // ── Organizar ──
      PopupMenuItem(enabled: false,
        child: Text('Mover a...',
            style: TextStyle(
                color: context.colors.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w600)),
      ),
      // Move to library root
      if (track.playlist.isNotEmpty)
        const PopupMenuItem(
            value: '__root__', child: Text('Biblioteca (raíz)')),
      // Move to each playlist
      ...playlists.map(
        (pl) => PopupMenuItem(value: pl.name, child: Text(pl.name)),
      ),
      const PopupMenuDivider(),
      const PopupMenuItem(
        value: '__new_playlist__',
        child: Row(
          children: [
            Icon(Icons.playlist_add_rounded, size: 18),
            SizedBox(width: 8),
            Text('Crear lista de reproducción'),
          ],
        ),
      ),
      const PopupMenuItem(
        value: '__new_album__',
        child: Row(
          children: [
            Icon(Icons.album_rounded, size: 18),
            SizedBox(width: 8),
            Text('Crear álbum'),
          ],
        ),
      ),
    ],
  );

  if (action != null) {
    if (action == '__edit__') {
      final changed = await showDialog<bool>(
        context: context,
        builder: (_) => MetadataDialog(track: track),
      );
      if (changed == true && context.mounted) {
        context.read<LibraryProvider>().loadTracks(settings.api);
      }
      return;
    }

    if (action == '__auto__') {
      try {
        final jobId = await settings.api.autoFillMetadata([track.filename]);
        if (context.mounted) {
          await showDialog(
            context: context,
            barrierDismissible: false,
            builder: (ctx) => _AutofillProgressDialog(jobId: jobId, settings: settings),
          );
          context.read<LibraryProvider>().loadTracks(settings.api);
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Error: $e'),
            backgroundColor: context.colors.error,
          ));
        }
      }
      return;
    }

    if (action == '__lyrics__') {
      try {
        final result = await settings.api.saveLyrics(
          filename: track.filename,
          title:    track.title.isNotEmpty ? track.title : track.filename,
          artist:   track.artist,
        );
        if (context.mounted) {
          if (result['saved'] == true) {
            // Also persist locally in lyrics/ folder
            final musicFolder = settings.musicFolder;
            if (musicFolder.isNotEmpty) {
              final syncedContent = result['synced'] as String?;
              final plainContent  = result['plain']  as String?;
              if (syncedContent != null && syncedContent.trim().isNotEmpty) {
                await LyricsService.saveLrc(
                    musicFolder, track.filename, syncedContent);
              } else if (plainContent != null && plainContent.trim().isNotEmpty) {
                await LyricsService.saveTxt(
                    musicFolder, track.filename, plainContent);
              }
            }
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Row(children: [
                  const Icon(Icons.offline_pin_rounded,
                      color: Colors.white, size: 18),
                  const SizedBox(width: 8),
                  Text('Letra guardada offline '
                      '(${result['type'] == 'synced' ? 'sincronizada' : 'texto plano'})'),
                ]),
                backgroundColor: context.colors.success,
                duration: const Duration(seconds: 3),
              ));
            }
          } else {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(
                  result['error'] ?? 'No se pudo descargar la letra.'),
              backgroundColor: context.colors.error,
              duration: const Duration(seconds: 4),
            ));
          }
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Error: $e'),
            backgroundColor: context.colors.error,
          ));
        }
      }
      return;
    }

    if (action == '__delete__') {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Eliminar canción'),
          content: Text('¿Seguro que quieres eliminar "${track.title.isNotEmpty ? track.title : track.filename}" del disco?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text('Eliminar', style: TextStyle(color: context.colors.error)),
            ),
          ],
        ),
      );

      if (confirm == true) {
        try {
          await library.deleteTrack(settings.api, track);
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: const Text('Archivo eliminado'),
              backgroundColor: context.colors.success,
              duration: const Duration(seconds: 2),
            ));
          }
        } catch (e) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text('Error: $e'),
              backgroundColor: context.colors.error,
            ));
          }
        }
      }
      return;
    }

    if (action == '__new_playlist__') {
      final name = await showDialog<String>(
        context: context,
        builder: (_) => _NameInputDialog(
          title: 'Nueva lista de reproducción',
          hint: 'Nombre de la lista',
        ),
      );
      if (name != null && name.trim().isNotEmpty && context.mounted) {
        try {
          await library.createPlaylist(settings.api, name.trim());
          await library.moveTrack(settings.api, track, name.trim());
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text('Lista "$name" creada y canción movida'),
              backgroundColor: context.colors.success,
              duration: const Duration(seconds: 2),
            ));
          }
        } catch (e) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text('Error: $e'),
              backgroundColor: context.colors.error,
            ));
          }
        }
      }
      return;
    }

    if (action == '__new_album__') {
      final name = await showDialog<String>(
        context: context,
        builder: (_) => _NameInputDialog(
          title: 'Nuevo álbum',
          hint: 'Nombre del álbum',
        ),
      );
      if (name != null && name.trim().isNotEmpty && context.mounted) {
        try {
          await library.createPlaylist(settings.api, name.trim());
          await library.moveTrack(settings.api, track, name.trim());
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text('Álbum "$name" creado y canción movida'),
              backgroundColor: context.colors.success,
              duration: const Duration(seconds: 2),
            ));
          }
        } catch (e) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text('Error: $e'),
              backgroundColor: context.colors.error,
            ));
          }
        }
      }
      return;
    }

    final toPlaylist = action == '__root__' ? null : action;
    await library.moveTrack(settings.api, track, toPlaylist);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
            'Movida a ${toPlaylist ?? 'Biblioteca'}'),
        backgroundColor: context.colors.success,
        duration: const Duration(seconds: 2),
      ));
    }
  }
}

// ── Name Input Dialog ─────────────────────────────────────────────────────────
class _NameInputDialog extends StatefulWidget {
  final String title;
  final String hint;
  const _NameInputDialog({required this.title, required this.hint});

  @override
  State<_NameInputDialog> createState() => _NameInputDialogState();
}

class _NameInputDialogState extends State<_NameInputDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.title),
    content: TextField(
      controller: _controller,
      autofocus: true,
      decoration: InputDecoration(
        hintText: widget.hint,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      ),
      onSubmitted: (_) => Navigator.of(context).pop(_controller.text),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('Cancelar'),
      ),
      TextButton(
        onPressed: () => Navigator.of(context).pop(_controller.text),
        child: const Text('Crear'),
      ),
    ],
  );
}

// ── Helper: detect video by extension ────────────────────────────────────────
bool _isVideo(Track t) {
  const exts = {'.mp4', '.mkv', '.avi', '.mov', '.webm'};
  final name = t.filename.toLowerCase();
  return exts.any((e) => name.endsWith(e));
}

// ── Track grid ────────────────────────────────────────────────────────────────

class _TrackGrid extends StatelessWidget {
  final List<Track> tracks;
  final List<Track> queue;
  final bool isMultiSelectMode;
  final Set<String> selectedTrackFilenames;
  final void Function(Track) onTrackToggled;
  final void Function(Track) onTrackLongPressed;
  
  const _TrackGrid({
    required this.tracks,
    required this.queue,
    required this.isMultiSelectMode,
    required this.selectedTrackFilenames,
    required this.onTrackToggled,
    required this.onTrackLongPressed,
  });

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.all(20),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 220,
        mainAxisSpacing: 16,
        crossAxisSpacing: 16,
        childAspectRatio: 0.78,
      ),
      itemCount: tracks.length,
      itemBuilder: (_, i) => _TrackCard(
        track: tracks[i],
        queue: queue,
        isMultiSelectMode: isMultiSelectMode,
        isSelected: selectedTrackFilenames.contains(tracks[i].filename),
        onToggled: () => onTrackToggled(tracks[i]),
        onLongPressed: () => onTrackLongPressed(tracks[i]),
      ),
    );
  }
}

// ── Track card ────────────────────────────────────────────────────────────────

class _TrackCard extends StatefulWidget {
  final Track track;
  final List<Track> queue;
  final bool isMultiSelectMode;
  final bool isSelected;
  final VoidCallback onToggled;
  final VoidCallback onLongPressed;
  
  const _TrackCard({
    required this.track,
    required this.queue,
    required this.isMultiSelectMode,
    required this.isSelected,
    required this.onToggled,
    required this.onLongPressed,
  });

  @override
  State<_TrackCard> createState() => _TrackCardState();
}

class _TrackCardState extends State<_TrackCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final track = widget.track;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: () async {
          if (widget.isMultiSelectMode) {
            widget.onToggled();
            return;
          }
          try {
            final settings = context.read<SettingsProvider>();
            await context.read<PlayerProvider>().playTrack(
                  widget.track, widget.queue, settings);
          } catch (e) {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text(e.toString().replaceAll('Exception: ', '')),
                backgroundColor: context.colors.error,
                duration: const Duration(seconds: 4),
              ));
            }
          }
        },
        onLongPress: widget.onLongPressed,
        onSecondaryTapUp: (d) {
          if (!widget.isMultiSelectMode) {
            _showTrackContextMenu(context, track, d.globalPosition);
          }
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          decoration: BoxDecoration(
            color: widget.isSelected
                ? Theme.of(context).colorScheme.primary.withOpacity(0.12)
                : (_hovered ? context.colors.surfaceAlt : context.colors.surface),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: widget.isSelected
                  ? Theme.of(context).colorScheme.primary
                  : (_hovered ? Theme.of(context).colorScheme.primary.withOpacity(0.5) : context.colors.border),
            ),
            boxShadow: _hovered
                ? [
                    BoxShadow(
                      color: Theme.of(context).colorScheme.primary.withOpacity(0.08),
                      blurRadius: 8,
                      spreadRadius: 0,
                    )
                  ]
                : [],
          ),
          child: Stack(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Cover / placeholder
                  Expanded(
                    child: ClipRRect(
                      borderRadius:
                          const BorderRadius.vertical(top: Radius.circular(12)),
                      child: TrackCoverImage(
                        coverUrl: track.coverUrl,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        errorWidget: _CoverPlaceholder(isVideo: _isVideo(widget.track)),
                      ),
                    ),
                  ),
                  // Info
                  Padding(
                    padding: const EdgeInsets.all(10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          track.title.isNotEmpty ? track.title : track.filename,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: context.colors.textPrimary,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                        if (track.artist.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            track.artist,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: context.colors.textSecondary,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
              if (widget.isMultiSelectMode)
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.5),
                      shape: BoxShape.circle,
                    ),
                    child: Checkbox(
                      value: widget.isSelected,
                      onChanged: (_) => widget.onToggled(),
                      activeColor: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CoverPlaceholder extends StatelessWidget {
  final bool isVideo;
  const _CoverPlaceholder({this.isVideo = false});

  @override
  Widget build(BuildContext context) => Container(
        color: context.colors.surfaceAlt,
        child: Center(
          child: Icon(
            isVideo ? Icons.videocam_rounded : Icons.music_note_rounded,
            color: context.colors.textSecondary,
            size: 36,
          ),
        ),
      );
}

class _EmptyState extends StatelessWidget {
  final Playlist playlist;
  final int tabIndex;
  const _EmptyState({required this.playlist, this.tabIndex = 0});

  @override
  Widget build(BuildContext context) {
    final String message = switch (tabIndex) {
      1 => playlist.isLibrary
          ? 'No hay pistas de audio'
          : 'Sin audio en ${playlist.name}',
      2 => playlist.isLibrary
          ? 'No hay videos en la biblioteca'
          : 'Sin videos en ${playlist.name}',
      _ => playlist.isLibrary
          ? 'Tu biblioteca está vacía'
          : '${playlist.name} está vacía',
    };
    final IconData icon = switch (tabIndex) {
      2 => Icons.videocam_off_rounded,
      _ => Icons.library_music_outlined,
    };

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: context.colors.textSecondary, size: 52),
          const SizedBox(height: 16),
          Text(
            message,
            style: TextStyle(color: context.colors.textSecondary, fontSize: 16),
          ),
          const SizedBox(height: 8),
          Text(
            'Presiona el atajo de teclado para reconocer una canción',
            style: TextStyle(color: context.colors.textSecondary, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

class _AutofillProgressDialog extends StatefulWidget {
  final String jobId;
  final SettingsProvider settings;
  const _AutofillProgressDialog({required this.jobId, required this.settings});

  @override
  State<_AutofillProgressDialog> createState() => _AutofillProgressDialogState();
}

class _AutofillProgressDialogState extends State<_AutofillProgressDialog> {
  double _progress = 0.0;
  String _step = 'Iniciando escaneo...';
  String? _errorMessage;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startPolling();
  }

  void _startPolling() {
    _timer = Timer.periodic(const Duration(milliseconds: 500), (timer) async {
      try {
        final status = await widget.settings.api.getAutofillJobStatus(widget.jobId);
        if (!mounted) {
          timer.cancel();
          return;
        }
        
        final total = status['total'] as int? ?? 1;
        final completed = status['completed'] as int? ?? 0;
        final failed = status['failed'] as int? ?? 0;
        
        setState(() {
          _progress = total > 0 ? (completed + failed) / total : 0;
          _step = status['current'] ?? '';
        });

        if (status['status'] == 'done' || status['status'] == 'failed') {
          timer.cancel();
          if (mounted) {
            Navigator.of(context).pop(true);
          }
        }
      } catch (e) {
        timer.cancel();
        if (mounted) {
          setState(() {
            _errorMessage = e.toString();
          });
        }
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Escaneando Metadatos'),
      content: SizedBox(
        width: 300,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_errorMessage != null)
              Text(_errorMessage!, style: const TextStyle(color: Colors.red))
            else ...[
              LinearProgressIndicator(value: _progress > 0 ? _progress : null),
              const SizedBox(height: 16),
              Text(_step, textAlign: TextAlign.center, style: const TextStyle(fontSize: 13)),
            ],
          ],
        ),
      ),
      actions: [
        if (_errorMessage != null || _progress >= 1.0)
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cerrar')),
      ],
    );
  }
}

void _showPlaylistSelectorBottomSheet(BuildContext context) {
  final library = context.read<LibraryProvider>();
  final settings = context.read<SettingsProvider>();
  
  showModalBottomSheet(
    context: context,
    backgroundColor: context.colors.bg,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) {
      return Consumer<LibraryProvider>(
        builder: (context, lib, child) {
          return SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 10),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: context.colors.textSecondary.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Listas de reproducción',
                        style: TextStyle(
                          color: context.colors.textPrimary,
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                      TextButton.icon(
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text('Nueva', style: TextStyle(fontSize: 13)),
                        onPressed: () {
                          Navigator.pop(ctx);
                          _createPlaylistDialog(context, lib, settings);
                        },
                      ),
                    ],
                  ),
                ),
                const Divider(),
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: lib.playlists.length,
                    itemBuilder: (context, index) {
                      final pl = lib.playlists[index];
                      final isSelected = lib.selected.name == pl.name;
                      
                      return ListTile(
                        leading: Icon(
                          pl.isLibrary ? Icons.library_music_rounded : Icons.playlist_play_rounded,
                          color: isSelected ? Theme.of(context).colorScheme.primary : context.colors.textSecondary,
                        ),
                        title: Text(
                          pl.name,
                          style: TextStyle(
                            color: isSelected ? context.colors.textPrimary : context.colors.textSecondary,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                        trailing: pl.isLibrary
                            ? null
                            : PopupMenuButton<String>(
                                icon: Icon(Icons.more_vert, color: context.colors.textSecondary),
                                color: context.colors.surfaceAlt,
                                onSelected: (val) {
                                  if (val == 'rename') {
                                    _renamePlaylistDialog(context, lib, settings, pl);
                                  } else if (val == 'delete') {
                                    _confirmDeletePlaylist(context, lib, settings, pl);
                                  }
                                },
                                itemBuilder: (context) => [
                                  const PopupMenuItem(
                                    value: 'rename',
                                    child: Text('Renombrar'),
                                  ),
                                  const PopupMenuItem(
                                    value: 'delete',
                                    child: Text('Eliminar', style: TextStyle(color: Colors.red)),
                                  ),
                                ],
                              ),
                        onTap: () {
                          lib.selectPlaylist(settings.api, pl);
                          Navigator.pop(ctx);
                        },
                      );
                    },
                  ),
                ),
                const SizedBox(height: 10),
              ],
            ),
          );
        },
      );
    },
  );
}

Future<void> _createPlaylistDialog(
  BuildContext context,
  LibraryProvider library,
  SettingsProvider settings,
) async {
  final ctrl = TextEditingController();
  final name = await showDialog<String>(
    context: context,
    builder: (_) => AlertDialog(
      backgroundColor: context.colors.surfaceAlt,
      title: const Text('Nueva lista de reproducción'),
      content: TextField(
        controller: ctrl,
        autofocus: true,
        decoration: const InputDecoration(hintText: 'Nombre de la lista'),
        onSubmitted: (v) => Navigator.pop(context, v),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, ctrl.text),
          child: const Text('Crear'),
        ),
      ],
    ),
  );
  if (name != null && name.trim().isNotEmpty) {
    await library.createPlaylist(settings.api, name.trim());
  }
}

Future<void> _renamePlaylistDialog(
  BuildContext context,
  LibraryProvider library,
  SettingsProvider settings,
  Playlist pl,
) async {
  final ctrl = TextEditingController(text: pl.name);
  final name = await showDialog<String>(
    context: context,
    builder: (_) => AlertDialog(
      backgroundColor: context.colors.surfaceAlt,
      title: const Text('Renombrar lista'),
      content: TextField(
        controller: ctrl,
        autofocus: true,
        onSubmitted: (v) => Navigator.pop(context, v),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, ctrl.text),
          child: const Text('Guardar'),
        ),
      ],
    ),
  );
  if (name != null && name.trim().isNotEmpty && name.trim() != pl.name) {
    await library.renamePlaylist(settings.api, pl.name, name.trim());
  }
}

Future<void> _confirmDeletePlaylist(
  BuildContext context,
  LibraryProvider library,
  SettingsProvider settings,
  Playlist pl,
) async {
  final confirm = await showDialog<bool>(
    context: context,
    builder: (_) => AlertDialog(
      backgroundColor: context.colors.surfaceAlt,
      title: const Text('Eliminar lista de reproducción'),
      content: Text('¿Seguro que quieres eliminar la lista "${pl.name}"?\n(Las canciones no se eliminarán del disco)'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancelar'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Eliminar', style: TextStyle(color: Colors.red)),
        ),
      ],
    ),
  );
  if (confirm == true) {
    await library.deletePlaylist(settings.api, pl.name);
  }
}




