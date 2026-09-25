import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/settings_provider.dart';
import '../../providers/downloads_provider.dart';
import '../../core/api_client.dart';
import '../theme.dart';

class AnalyticsView extends StatefulWidget {
  const AnalyticsView({super.key});

  @override
  State<AnalyticsView> createState() => _AnalyticsViewState();
}

class _AnalyticsViewState extends State<AnalyticsView> with SingleTickerProviderStateMixin {
  bool _isLoading = true;
  String _errorMessage = '';

  // Stats from backend
  int _totalSongs = 0;
  int _totalVideos = 0;
  int _totalMedia = 0;
  int _thisWeek = 0;
  int _today = 0;
  List<dynamic> _topArtists = [];
  List<dynamic> _topGenres = [];
  List<dynamic> _recentDownloads = [];
  Map<String, dynamic> _formats = {};

  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadData());
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    final settings = context.read<SettingsProvider>();
    final ApiClient api = settings.api;

    try {
      // First sync the downloads folder with DB (clean junk + register new files)
      await api.syncDownloads();

      final stats = await api.getDownloadStats();
      _totalSongs = stats['total_songs'] ?? 0;
      _totalVideos = stats['total_videos'] ?? 0;
      _totalMedia = stats['total_media'] ?? 0;
      _thisWeek = stats['this_week'] ?? 0;
      _today = stats['today'] ?? 0;
      _topArtists = stats['top_artists'] ?? [];
      _topGenres = stats['top_genres'] ?? [];
      _recentDownloads = stats['recent_downloads'] ?? [];
      _formats = Map<String, dynamic>.from(stats['formats'] ?? {});
      _errorMessage = '';
    } catch (e) {
      _errorMessage = 'Error al cargar estadísticas: $e';
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;
    final accent = Theme.of(context).colorScheme.primary;

    return Scaffold(
      backgroundColor: context.colors.bg,
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: accent))
          : RefreshIndicator(
              onRefresh: _loadData,
              child: CustomScrollView(
                slivers: [
                  // ── Header ──────────────────────
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(
                        isMobile ? 16 : 32, isMobile ? 16 : 24,
                        isMobile ? 16 : 32, 0,
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.bar_chart_rounded, color: accent, size: isMobile ? 24 : 28),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Estadísticas',
                                  style: TextStyle(
                                    fontSize: isMobile ? 22 : 28,
                                    fontWeight: FontWeight.bold,
                                    color: context.colors.textPrimary,
                                  ),
                                ),
                                Text(
                                  'Tu biblioteca en números',
                                  style: TextStyle(
                                    fontSize: isMobile ? 12 : 13,
                                    color: context.colors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: Icon(Icons.refresh_rounded, color: context.colors.textSecondary),
                            onPressed: _loadData,
                            tooltip: 'Recargar',
                          ),
                        ],
                      ),
                    ),
                  ),

                  // ── Error ──────────────────────
                  if (_errorMessage.isNotEmpty)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: isMobile ? 16 : 32, vertical: 12),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: context.colors.error.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: context.colors.error.withOpacity(0.3)),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.error_outline, color: context.colors.error, size: 18),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  _errorMessage,
                                  style: TextStyle(color: context.colors.textPrimary, fontSize: 13),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                  // ── Stat Cards ──────────────────────
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: isMobile ? 16 : 32, vertical: 16),
                      child: isMobile
                          ? Column(
                              children: [
                                Row(children: [
                                  _buildStatCard('Canciones', '$_totalSongs', Icons.music_note_rounded, accent),
                                  const SizedBox(width: 10),
                                  _buildStatCard('Videos', '$_totalVideos', Icons.videocam_rounded, Colors.redAccent),
                                ]),
                                const SizedBox(height: 10),
                                Row(children: [
                                  _buildStatCard('Esta semana', '$_thisWeek', Icons.date_range_rounded, Colors.teal),
                                  const SizedBox(width: 10),
                                  _buildStatCard('Hoy', '$_today', Icons.today_rounded, Colors.orange),
                                ]),
                              ],
                            )
                          : Row(
                              children: [
                                _buildStatCard('Canciones', '$_totalSongs', Icons.music_note_rounded, accent),
                                const SizedBox(width: 14),
                                _buildStatCard('Videos', '$_totalVideos', Icons.videocam_rounded, Colors.redAccent),
                                const SizedBox(width: 14),
                                _buildStatCard('Esta semana', '$_thisWeek', Icons.date_range_rounded, Colors.teal),
                                const SizedBox(width: 14),
                                _buildStatCard('Hoy', '$_today', Icons.today_rounded, Colors.orange),
                              ],
                            ),
                    ),
                  ),

                  // ── Tabs ──────────────────────
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: isMobile ? 16 : 32),
                      child: Container(
                        decoration: BoxDecoration(
                          color: context.colors.surface,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: TabBar(
                          controller: _tabController,
                          onTap: (_) => setState(() {}),
                          indicatorColor: accent,
                          indicatorWeight: 2.5,
                          labelColor: accent,
                          unselectedLabelColor: context.colors.textSecondary.withOpacity(0.6),
                          labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                          unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w400, fontSize: 13),
                          tabs: const [
                            Tab(text: 'Recientes'),
                            Tab(text: 'Artistas'),
                            Tab(text: 'Descargas activas'),
                          ],
                        ),
                      ),
                    ),
                  ),

                  const SliverToBoxAdapter(child: SizedBox(height: 16)),

                  // ── Tab Content ──────────────────────
                  if (_tabController.index == 0)
                    _buildRecentDownloadsSliver(isMobile)
                  else if (_tabController.index == 1)
                    _buildTopArtistsSliver(isMobile)
                  else
                    _buildActiveDownloadsSliver(isMobile),
                ],
              ),
            ),
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: context.colors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: context.colors.border.withOpacity(0.15)),
        ),
        child: Row(
          children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: context.colors.textPrimary,
                    ),
                  ),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 11,
                      color: context.colors.textSecondary,
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

  // ── Recent Downloads Tab ──────────────────────
  Widget _buildRecentDownloadsSliver(bool isMobile) {
    if (_recentDownloads.isEmpty) {
      return SliverToBoxAdapter(
        child: _buildEmptyState(
          icon: Icons.download_done_rounded,
          title: 'Sin descargas aún',
          subtitle: 'Busca y descarga música para verla aquí',
        ),
      );
    }

    return SliverPadding(
      padding: EdgeInsets.symmetric(horizontal: isMobile ? 16 : 32),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final item = _recentDownloads[index];
            final title = item['title'] ?? 'Sin título';
            final artist = item['artist'] ?? 'Desconocido';
            final type = item['type'] ?? 'music';
            final format = item['format'] ?? '';
            final addedAt = item['added_at'] != null
                ? _formatDate(DateTime.parse(item['added_at']))
                : '';

            return Container(
              margin: const EdgeInsets.only(bottom: 6),
              decoration: BoxDecoration(
                color: context.colors.surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: context.colors.border.withOpacity(0.08)),
              ),
              child: ListTile(
                dense: true,
                leading: Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(
                    color: (type == 'video' ? Colors.redAccent : Theme.of(context).colorScheme.primary).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    type == 'video' ? Icons.videocam_rounded : Icons.music_note_rounded,
                    color: type == 'video' ? Colors.redAccent : Theme.of(context).colorScheme.primary,
                    size: 20,
                  ),
                ),
                title: Text(
                  title,
                  style: TextStyle(
                    color: context.colors.textPrimary,
                    fontWeight: FontWeight.w500,
                    fontSize: 13,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  artist,
                  style: TextStyle(
                    color: context.colors.textSecondary,
                    fontSize: 11,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: context.colors.border.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        format.toUpperCase(),
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                          color: context.colors.textSecondary,
                        ),
                      ),
                    ),
                    if (addedAt.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          addedAt,
                          style: TextStyle(
                            fontSize: 10,
                            color: context.colors.textSecondary.withOpacity(0.6),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
          childCount: _recentDownloads.length,
        ),
      ),
    );
  }

  // ── Top Artists Tab ──────────────────────
  Widget _buildTopArtistsSliver(bool isMobile) {
    if (_topArtists.isEmpty) {
      return SliverToBoxAdapter(
        child: _buildEmptyState(
          icon: Icons.person_rounded,
          title: 'Sin artistas aún',
          subtitle: 'Descarga música para ver tus artistas favoritos',
        ),
      );
    }

    final maxCount = _topArtists.isNotEmpty
        ? (_topArtists[0]['count'] as int)
        : 1;
    final accent = Theme.of(context).colorScheme.primary;

    return SliverPadding(
      padding: EdgeInsets.symmetric(horizontal: isMobile ? 16 : 32),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final item = _topArtists[index];
            final artist = item['artist'] ?? 'Desconocido';
            final count = item['count'] as int;
            final ratio = count / maxCount;

            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: context.colors.surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: context.colors.border.withOpacity(0.08)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 28, height: 28,
                        decoration: BoxDecoration(
                          color: accent.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            '${index + 1}',
                            style: TextStyle(
                              color: accent,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          artist,
                          style: TextStyle(
                            color: context.colors.textPrimary,
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        '$count ${count == 1 ? 'canción' : 'canciones'}',
                        style: TextStyle(
                          color: context.colors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: LinearProgressIndicator(
                      value: ratio,
                      minHeight: 4,
                      backgroundColor: context.colors.border.withOpacity(0.15),
                      valueColor: AlwaysStoppedAnimation<Color>(accent.withOpacity(0.7)),
                    ),
                  ),
                ],
              ),
            );
          },
          childCount: _topArtists.length,
        ),
      ),
    );
  }

  // ── Active Downloads Tab ──────────────────────
  Widget _buildActiveDownloadsSliver(bool isMobile) {
    final downloads = context.watch<DownloadsProvider>();

    if (downloads.jobs.isEmpty) {
      return SliverToBoxAdapter(
        child: _buildEmptyState(
          icon: Icons.download_done_rounded,
          title: 'Sin descargas activas',
          subtitle: 'Las descargas en progreso aparecerán aquí',
        ),
      );
    }

    return SliverPadding(
      padding: EdgeInsets.symmetric(horizontal: isMobile ? 16 : 32),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final job = downloads.jobs[index];
            final status = job['status'] ?? '';
            final isDone = status == 'done';
            final isError = status == 'error';
            final jobId = (job['job_id'] ?? job['id'] ?? '').toString();
            final step = job['step'] ?? '';
            final progress = (job['progress'] ?? 0) as num;

            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: context.colors.surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isError
                      ? context.colors.error.withOpacity(0.3)
                      : isDone
                          ? context.colors.success.withOpacity(0.3)
                          : context.colors.border.withOpacity(0.08),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    isDone
                        ? Icons.check_circle_rounded
                        : isError
                            ? Icons.error_rounded
                            : Icons.downloading_rounded,
                    color: isDone
                        ? context.colors.success
                        : isError
                            ? context.colors.error
                            : Theme.of(context).colorScheme.primary,
                    size: 22,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Descarga #${jobId.length > 8 ? jobId.substring(0, 8) : jobId}',
                          style: TextStyle(
                            color: context.colors.textPrimary,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          step.isNotEmpty ? step : status,
                          style: TextStyle(
                            color: isError ? context.colors.error : context.colors.textSecondary,
                            fontSize: 11,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (!isDone && !isError && progress > 0)
                          Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(3),
                              child: LinearProgressIndicator(
                                value: progress / 100,
                                minHeight: 3,
                                backgroundColor: context.colors.border.withOpacity(0.15),
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Theme.of(context).colorScheme.primary,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
          childCount: downloads.jobs.length,
        ),
      ),
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 60),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: context.colors.textSecondary.withOpacity(0.3)),
            const SizedBox(height: 16),
            Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: context.colors.textSecondary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 12,
                color: context.colors.textSecondary.withOpacity(0.6),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inMinutes < 1) return 'Ahora';
    if (diff.inMinutes < 60) return 'Hace ${diff.inMinutes}m';
    if (diff.inHours < 24) return 'Hace ${diff.inHours}h';
    if (diff.inDays < 7) return 'Hace ${diff.inDays}d';
    return '${date.day}/${date.month}/${date.year}';
  }
}
