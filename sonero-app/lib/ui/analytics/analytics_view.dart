import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../providers/settings_provider.dart';
import '../../core/api_client.dart';
import '../theme.dart';
import '../auth/auth_dialog.dart';

class AnalyticsView extends StatefulWidget {
  const AnalyticsView({super.key});

  @override
  State<AnalyticsView> createState() => _AnalyticsViewState();
}

class _AnalyticsViewState extends State<AnalyticsView> with SingleTickerProviderStateMixin {
  String? _lastLoadedUserId;
  
  bool _isLoading = true;
  String _errorMessage = '';
  
  // Real stats gathered from backend
  double _totalHours = 0.0;
  int _completedCount = 0;
  int _musicCount = 0;
  List<dynamic> _history = [];
  
  // Smart features data
  Map<String, dynamic>? _bpmAnalysis;
  List<dynamic> _prioritizedTracks = [];
  Map<String, dynamic>? _currentMood;
  List<dynamic> _isoQueue = [];
  Map<String, dynamic>? _weeklyReport;
  
  // Focus Session Status
  bool _isFocusSessionActive = false;
  int? _activeSessionId;
  DateTime? _focusSessionStart;
  
  // Controllers
  final TextEditingController _apiKeyController = TextEditingController();
  bool _isSavingKey = false;
  bool _isGeneratingReport = false;
  bool _isEndingSession = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadData());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final userId = context.watch<SettingsProvider>().currentUserId;
    if (userId != _lastLoadedUserId) {
      _loadData();
    }
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
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
    final userId = settings.currentUserId;
    _lastLoadedUserId = userId;

    try {
      // 1. Fetch active focus session
      final activeSessionRes = await api.getActiveFocusSession(userId);
      _isFocusSessionActive = activeSessionRes['active'] ?? false;
      if (_isFocusSessionActive && activeSessionRes['session'] != null) {
        _activeSessionId = activeSessionRes['session']['id'];
        final startStr = activeSessionRes['session']['started_at'];
        if (startStr != null) {
          _focusSessionStart = DateTime.parse(startStr);
        }
      } else {
        _activeSessionId = null;
        _focusSessionStart = null;
      }

      // 2. Fetch playback history to compute real metrics
      final historyList = await api.getPlaybackHistory();
      _history = historyList;
      
      // Calculate stats
      double secondsWatched = 0.0;
      int completed = 0;
      int music = 0;
      for (var event in historyList) {
        secondsWatched += (event['duration_watched'] ?? 0.0) as double;
        if (event['completed'] == true) {
          completed++;
        }
        music++; // Assume each playback log is a track
      }
      
      _totalHours = secondsWatched / 3600.0;
      _completedCount = completed;
      _musicCount = music;

      // 3. Fetch optimal BPM range
      final bpmRes = await api.getOptimalBpm(userId);
      _bpmAnalysis = bpmRes['bpm_analysis'];
      _prioritizedTracks = bpmRes['prioritized_tracks'] ?? [];

      // 4. Fetch current mood
      _currentMood = await api.getCurrentMood(userId);

      // Clean default values or errors
      _errorMessage = '';
    } catch (e) {
      _errorMessage = 'Error al cargar datos del backend: $e';
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _toggleFocusSession() async {
    final settings = context.read<SettingsProvider>();
    final api = settings.api;
    final userId = settings.currentUserId;

    if (_isFocusSessionActive) {
      // End Focus Session
      if (_activeSessionId == null) return;
      setState(() {
        _isEndingSession = true;
      });

      try {
        final res = await api.endFocusSession(_activeSessionId!);
        final score = res['focus_score'] ?? 0.0;
        final totalSkips = res['total_skips'] ?? 0;
        
        setState(() {
          _isFocusSessionActive = false;
          _activeSessionId = null;
          _focusSessionStart = null;
        });

        // Show a beautiful score summary dialog
        if (mounted) {
          _showFocusScoreDialog(score as double, totalSkips as int);
        }
      } catch (e) {
        _showSnackBar('Error al finalizar sesión de enfoque: $e', isError: true);
      } finally {
        setState(() {
          _isEndingSession = false;
        });
        _loadData();
      }
    } else {
      // Start Focus Session
      try {
        final res = await api.startFocusSession(userId);
        setState(() {
          _isFocusSessionActive = true;
          _activeSessionId = res['session_id'];
          _focusSessionStart = DateTime.now();
        });
        _showSnackBar('¡Sesión de enfoque iniciada! Concéntrate en tus tareas.');
      } catch (e) {
        _showSnackBar('Error al iniciar sesión de enfoque: $e', isError: true);
      }
    }
  }

  void _showFocusScoreDialog(double score, int skips) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sesión de Enfoque Concluida', textAlign: TextAlign.center),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 16),
            Text(
              '${(score * 100).toStringAsFixed(1)}%',
              style: TextStyle(
                fontSize: 64, 
                fontWeight: FontWeight.bold, 
                color: Theme.of(context).colorScheme.primary
              ),
            ).animate().scale(duration: 600.ms, curve: Curves.elasticOut),
            const Text('Índice de Enfoque (Focus Score)', style: TextStyle(fontWeight: FontWeight.w500)),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildPopupStat('Saltos', '$skips', Icons.skip_next_outlined),
                _buildPopupStat('Calidad', score >= 0.7 ? 'Excelente' : score >= 0.4 ? 'Media' : 'Baja', Icons.verified_user_outlined),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              score >= 0.7 
                  ? '¡Excelente trabajo! Has logrado un estado de flujo óptimo.' 
                  : score >= 0.4 
                      ? 'Buen ritmo, pero intenta evitar saltar canciones instrumentales para mejorar tu enfoque.'
                      : 'Muchas interrupciones. Prueba a activar el filtro de BPM Barroco/Lo-Fi.',
              textAlign: TextAlign.center,
              style: TextStyle(color: context.colors.textSecondary, fontSize: 13),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Entendido'),
          )
        ],
      ),
    );
  }

  Widget _buildPopupStat(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: context.colors.textSecondary, size: 20),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        Text(label, style: TextStyle(color: context.colors.textSecondary, fontSize: 11)),
      ],
    );
  }

  Future<void> _saveGeminiKey() async {
    final key = _apiKeyController.text.trim();
    if (key.isEmpty) {
      _showSnackBar('Por favor ingresa una clave válida.', isError: true);
      return;
    }

    setState(() {
      _isSavingKey = true;
    });

    try {
      final settings = context.read<SettingsProvider>();
      await settings.api.saveGeminiKey(key);
      _apiKeyController.clear();
      _showSnackBar('Clave API de Gemini guardada correctamente en la base de datos.');
    } catch (e) {
      _showSnackBar('Error al guardar la clave API: $e', isError: true);
    } finally {
      setState(() {
        _isSavingKey = false;
      });
    }
  }

  Future<void> _generateWeeklyReport() async {
    setState(() {
      _isGeneratingReport = true;
    });

    try {
      final settings = context.read<SettingsProvider>();
      final reportRes = await settings.api.getWeeklyProductivityReport(settings.currentUserId);
      setState(() {
        _weeklyReport = reportRes;
      });
      _showSnackBar('¡Reporte semanal de productividad musical generado!');
    } catch (e) {
      _showSnackBar('Error al generar el reporte: $e', isError: true);
    } finally {
      setState(() {
        _isGeneratingReport = false;
      });
    }
  }

  Future<void> _generateIsoQueue() async {
    try {
      final settings = context.read<SettingsProvider>();
      final queueRes = await settings.api.getIsoPrincipleQueue(settings.currentUserId);
      setState(() {
        _isoQueue = queueRes['queue'] ?? [];
      });
      _showSnackBar('¡Cola de Ecualización Emocional (Iso-Principle) cargada!');
    } catch (e) {
      _showSnackBar('Error al generar la cola Iso: $e', isError: true);
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? context.colors.error : context.colors.success,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final isMobile = MediaQuery.of(context).size.width < 600;

    if (_isLoading) {
      return Scaffold(
        backgroundColor: context.colors.bg,
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    final double focusValence = _currentMood?['valence'] ?? 0.5;
    final double focusEnergy = _currentMood?['energy'] ?? 0.5;
    final String moodDescription = _currentMood?['description'] ?? 'Calma/Relajado';
    final String moodQuadrant = _currentMood?['quadrant'] ?? 'Baja Energía, Alta Valencia';
    
    // BPM analysis
    final String rangeName = _bpmAnalysis?['range_name'] ?? 'Barroco/Lo-Fi (60-90 BPM)';
    final List<dynamic> optimalRange = _bpmAnalysis?['optimal_range'] ?? [60, 90];
    final double? baroqueRate = _bpmAnalysis?['baroque_skip_rate'] != null ? (_bpmAnalysis!['baroque_skip_rate'] as num).toDouble() : null;
    final double? technoRate = _bpmAnalysis?['techno_skip_rate'] != null ? (_bpmAnalysis!['techno_skip_rate'] as num).toDouble() : null;

    return Scaffold(
      backgroundColor: context.colors.bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        titleSpacing: 24,
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Música Inteligente', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            Text('Analítica & Productividad', style: TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.w400)),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 20),
            child: IconButton(
              icon: const Icon(Icons.refresh_rounded, size: 20),
              tooltip: 'Recargar Datos',
              onPressed: _loadData,
              style: IconButton.styleFrom(
                shape: const CircleBorder(),
                backgroundColor: Colors.transparent,
                side: BorderSide.none,
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: isMobile ? 16.0 : 24.0, vertical: 12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSyncHeader(context, settings),
              const SizedBox(height: 24),
              if (_errorMessage.isNotEmpty)
                Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: context.colors.error.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: context.colors.error)
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline, color: context.colors.error),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _errorMessage, 
                          style: TextStyle(color: context.colors.textPrimary, fontWeight: FontWeight.bold)
                        ),
                      ),
                    ],
                  ),
                ),
                
              Text(
                'Tus Hábitos Semanales',
                style: TextStyle(fontSize: isMobile ? 18 : 22, fontWeight: FontWeight.bold, color: context.colors.textPrimary),
              ).animate().fadeIn(duration: 300.ms),
              const SizedBox(height: 16),
              
              // ── Stat Cards ─────────────────────────────────────────────────
              if (isMobile)
                Column(
                  children: [
                    _buildStatCardMobile(context, 'Horas de enfoque', '${_totalHours.toStringAsFixed(1)} h', Icons.timer, Theme.of(context).colorScheme.primary),
                    const SizedBox(height: 10),
                    _buildStatCardMobile(context, 'Completadas', '$_completedCount', Icons.check_circle_outline, context.colors.success),
                    const SizedBox(height: 10),
                    _buildStatCardMobile(context, 'Música Escuchada', '$_musicCount', Icons.music_note, Colors.orange),
                  ],
                ).animate().fade(duration: 400.ms).slideX(begin: 0.1, end: 0)
              else
                Row(
                  children: [
                    _buildStatCard(context, 'Horas de enfoque', '${_totalHours.toStringAsFixed(1)} h', Icons.timer, Theme.of(context).colorScheme.primary),
                    const SizedBox(width: 16),
                    _buildStatCard(context, 'Completadas', '$_completedCount', Icons.check_circle_outline, context.colors.success),
                    const SizedBox(width: 16),
                    _buildStatCard(context, 'Música Escuchada', '$_musicCount', Icons.music_note, Colors.orange),
                  ],
                ).animate().fade(duration: 400.ms).slideX(begin: 0.1, end: 0),
              
              const SizedBox(height: 32),
              
              if (isMobile)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildFocusSessionCard(),
                    const SizedBox(height: 16),
                    _buildMoodCircumplexCard(focusValence, focusEnergy, moodDescription, moodQuadrant),
                    const SizedBox(height: 16),
                    _buildBpmAnalysisCard(rangeName, optimalRange, baroqueRate, technoRate),
                    const SizedBox(height: 16),
                    _buildIsoPrincipleCard(),
                  ],
                )
              else
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 5,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildFocusSessionCard(),
                          const SizedBox(height: 24),
                          _buildBpmAnalysisCard(rangeName, optimalRange, baroqueRate, technoRate),
                        ],
                      ),
                    ),
                    const SizedBox(width: 24),
                    Expanded(
                      flex: 5,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildMoodCircumplexCard(focusValence, focusEnergy, moodDescription, moodQuadrant),
                          const SizedBox(height: 24),
                          _buildIsoPrincipleCard(),
                        ],
                      ),
                    ),
                  ],
                ),
              
              const SizedBox(height: 32),
              
              // Gemini Section: Weekly Report & Key Configuration
              Text(
                'Inteligencia Artificial (Gemini API)',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: context.colors.textPrimary),
              ),
              const SizedBox(height: 16),
              _buildGeminiSectionCard(),
              const SizedBox(height: 48),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatCard(BuildContext context, String title, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: context.colors.surfaceAlt,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: context.colors.border.withOpacity(0.5)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 10,
              offset: const Offset(0, 4)
            )
          ]
        ),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: color.withOpacity(0.1),
              radius: 24,
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    value,
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: context.colors.textPrimary),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    title,
                    style: TextStyle(fontSize: 12, color: context.colors.textSecondary),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCardMobile(BuildContext context, String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: context.colors.surfaceAlt,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.colors.border.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: color.withOpacity(0.1),
            radius: 20,
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(fontSize: 11, color: context.colors.textSecondary)),
                const SizedBox(height: 2),
                Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: context.colors.textPrimary)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFocusSessionCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Sesión de Enfoque',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                if (_isFocusSessionActive)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Theme.of(context).colorScheme.primary)
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 8, height: 8,
                          decoration: const BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Text(
                          'Activa',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              _isFocusSessionActive
                  ? 'El sistema está registrando tu telemetría de forma automática en segundo plano. Evita realizar saltos de canción.'
                  : 'El tracking es 100% automático al reproducir música. Puedes usar este botón si deseas iniciar un bloque de tiempo de forma manual.',
              style: TextStyle(color: context.colors.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 20),
            if (_isFocusSessionActive && _focusSessionStart != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 16.0),
                child: Text(
                  'Iniciada a las: ${_focusSessionStart!.toLocal().toString().substring(11, 16)} hs',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            SizedBox(
              width: double.infinity,
            child: _isEndingSession
                  ? const Center(child: CircularProgressIndicator())
                  : ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _isFocusSessionActive 
                            ? context.colors.error 
                            : Theme.of(context).colorScheme.primary
                      ),
                      icon: Icon(_isFocusSessionActive ? Icons.stop : Icons.play_arrow),
                      label: Text(_isFocusSessionActive ? 'Finalizar Sesión' : 'Iniciar Sesión'),
                      onPressed: _toggleFocusSession,
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBpmAnalysisCard(String rangeName, List<dynamic> range, double? baroqueRate, double? technoRate) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.bolt_rounded, size: 24, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 8),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Ritmo Ideal para Ti', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      Text('BPM que menos saltas', style: TextStyle(fontSize: 11, color: Colors.grey)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Theme.of(context).colorScheme.primary.withOpacity(0.15)),
              ),
              child: Row(
                children: [
                  Icon(Icons.speed, color: Theme.of(context).colorScheme.primary, size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          rangeName,
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Las canciones en este rango de BPM son las que más disfrutas sin saltarlas.',
                          style: TextStyle(color: context.colors.textSecondary, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 32),
            const Text('Comparación de saltos por género:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            _buildBpmRateRow('Barroco/Lo-Fi (60-90 BPM)', baroqueRate),
            const SizedBox(height: 8),
            _buildBpmRateRow('Techno/Deep House (120-140 BPM)', technoRate),
            
            if (_prioritizedTracks.isNotEmpty) ...[
              const Divider(height: 32),
              Text(
                'Canciones instrumentales recomendadas (${_prioritizedTracks.length})',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 120,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _prioritizedTracks.length,
                  itemBuilder: (ctx, idx) {
                    final t = _prioritizedTracks[idx];
                    return Container(
                      width: 150,
                      margin: const EdgeInsets.only(right: 12),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: context.colors.bg.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: context.colors.border.withOpacity(0.3))
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            t['title'] ?? 'Instrumental',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                          ),
                          Text(
                            t['artist'] ?? 'Desconocido',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: context.colors.textSecondary, fontSize: 10),
                          ),
                          const Spacer(),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('${t['bpm']?.toInt()} BPM', style: TextStyle(color: Theme.of(context).colorScheme.primary, fontSize: 10, fontWeight: FontWeight.bold)),
                              Icon(Icons.multitrack_audio, size: 14, color: context.colors.textSecondary),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ]
          ],
        ),
      ),
    );
  }

  Widget _buildBpmRateRow(String range, double? rate) {
    final hasData = rate != null;
    final pctStr = hasData ? '${(rate * 100).toStringAsFixed(1)}%' : 'Sin datos';
    
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(range, style: TextStyle(color: context.colors.textSecondary, fontSize: 13)),
        Row(
          children: [
            if (hasData)
              Container(
                width: 60,
                height: 8,
                margin: const EdgeInsets.only(right: 8),
                child: LinearProgressIndicator(
                  value: rate,
                  backgroundColor: context.colors.border,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    rate > 0.4 ? context.colors.error : context.colors.success
                  ),
                ),
              ),
            Text(
              pctStr, 
              style: TextStyle(
                fontWeight: FontWeight.bold, 
                fontSize: 13,
                color: !hasData 
                    ? context.colors.textSecondary 
                    : rate > 0.4 ? context.colors.error : context.colors.success
              )
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMoodCircumplexCard(double valence, double energy, String desc, String quad) {
    final accent = Theme.of(context).colorScheme.primary;
    final isFallback = desc.toLowerCase().contains('fallback');
    
    IconData moodIcon;
    String moodSimple;
    if (energy > 0.5 && valence > 0.5) {
      moodIcon = Icons.sentiment_very_satisfied_rounded; moodSimple = 'Alegre y Activo';
    } else if (energy > 0.5 && valence <= 0.5) {
      moodIcon = Icons.sentiment_dissatisfied_rounded; moodSimple = 'Tenso o Ansioso';
    } else if (energy <= 0.5 && valence > 0.5) {
      moodIcon = Icons.sentiment_satisfied_rounded; moodSimple = 'Calmado y Relajado';
    } else {
      moodIcon = Icons.sentiment_very_dissatisfied_rounded; moodSimple = 'Triste o Melancólico';
    }
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.psychology_rounded, size: 24, color: accent),
                const SizedBox(width: 8),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Tu Estado de Ánimo', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      Text('Basado en lo que escuchas', style: TextStyle(fontSize: 11, color: Colors.grey)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: accent.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: accent.withOpacity(0.15)),
              ),
              child: Row(
                children: [
                  Icon(moodIcon, size: 32, color: accent),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isFallback ? 'Sin datos suficientes' : moodSimple,
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: context.colors.textPrimary),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          isFallback ? 'Escucha música por 45 min para detectar tu estado' : 'Según tus últimos 45 min de escucha',
                          style: TextStyle(fontSize: 11, color: context.colors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Center(
              child: Container(
                width: 200, height: 200,
                decoration: BoxDecoration(
                  color: context.colors.bg.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: context.colors.border)
                ),
                child: Stack(
                  children: [
                    Positioned(top: 20, right: 16, child: Icon(Icons.sentiment_very_satisfied_rounded, size: 16, color: context.colors.textSecondary.withOpacity(0.2))),
                    Positioned(top: 20, left: 16, child: Icon(Icons.sentiment_dissatisfied_rounded, size: 16, color: context.colors.textSecondary.withOpacity(0.2))),
                    Positioned(bottom: 20, right: 16, child: Icon(Icons.sentiment_satisfied_rounded, size: 16, color: context.colors.textSecondary.withOpacity(0.2))),
                    Positioned(bottom: 20, left: 16, child: Icon(Icons.sentiment_very_dissatisfied_rounded, size: 16, color: context.colors.textSecondary.withOpacity(0.2))),
                    Center(child: Container(width: double.infinity, height: 1, color: context.colors.border.withOpacity(0.3))),
                    Center(child: Container(width: 1, height: double.infinity, color: context.colors.border.withOpacity(0.3))),
                    Positioned(top: 6, left: 0, right: 0, child: Text('ENERGÍA +', textAlign: TextAlign.center, style: TextStyle(fontSize: 7, color: context.colors.textSecondary.withOpacity(0.6), fontWeight: FontWeight.bold))),
                    Positioned(bottom: 6, left: 0, right: 0, child: Text('ENERGÍA −', textAlign: TextAlign.center, style: TextStyle(fontSize: 7, color: context.colors.textSecondary.withOpacity(0.6), fontWeight: FontWeight.bold))),
                    Positioned(
                      left: (valence * 200).clamp(10, 190) - 8,
                      bottom: (energy * 200).clamp(10, 190) - 8,
                      child: Container(
                        width: 16, height: 16,
                        decoration: BoxDecoration(
                          color: accent,
                          shape: BoxShape.circle,
                          boxShadow: [BoxShadow(color: accent.withOpacity(0.5), blurRadius: 8, spreadRadius: 1)]
                        ),
                      ).animate(onPlay: (controller) => controller.repeat(reverse: true))
                       .scale(begin: const Offset(1, 1), end: const Offset(1.2, 1.2), duration: 800.ms),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Center(child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.place_rounded, size: 12, color: context.colors.textSecondary),
              const SizedBox(width: 4),
              Text('Tu punto indica dónde estás emocionalmente', style: TextStyle(fontSize: 10, color: context.colors.textSecondary)),
            ])),
          ],
        ),
      ),
    );
  }

  Widget _buildIsoPrincipleCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Playlist Relajante',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Genera una cola que te lleva de tu estado actual a la calma',
                        style: TextStyle(fontSize: 11, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                  ),
                  icon: const Icon(Icons.auto_awesome, size: 16),
                  label: const Text('Generar', style: TextStyle(fontSize: 12)),
                  onPressed: _generateIsoQueue,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: context.colors.bg.withOpacity(0.4),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, size: 14, color: context.colors.textSecondary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '¿Cómo funciona? Selecciona 5 canciones de tu biblioteca que gradualmente bajan la energía, ayudándote a relajarte.',
                      style: TextStyle(color: context.colors.textSecondary, fontSize: 11, height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
            
            if (_isoQueue.isNotEmpty) ...[
              const Divider(height: 24),
              const Text('Secuencia de Transición Recomendada (5 Canciones):', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              Column(
                children: List.generate(_isoQueue.length, (idx) {
                  final item = _isoQueue[idx];
                  final track = item['track'];
                  final targetE = item['target_energy'];
                  final targetV = item['target_valence'];
                  
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: context.colors.bg.withOpacity(0.4),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: context.colors.border.withOpacity(0.3))
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                          radius: 12,
                          child: Text('${idx + 1}', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary)),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(track['title'] ?? 'Track', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                              Text(track['artist'] ?? 'Artista', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: context.colors.textSecondary, fontSize: 11)),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text('E: ${(track['energy'] as double).toStringAsFixed(2)} ➔ ${targetE.toStringAsFixed(2)}', style: const TextStyle(fontSize: 10, fontFamily: 'monospace')),
                            Text('V: ${(track['valence'] as double).toStringAsFixed(2)} ➔ ${targetV.toStringAsFixed(2)}', style: const TextStyle(fontSize: 10, fontFamily: 'monospace')),
                          ],
                        ),
                      ],
                    ),
                  );
                }),
              )
            ]
          ],
        ),
      ),
    );
  }

  Widget _buildGeminiSectionCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // API Key setup row
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Configurar Clave de Gemini',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 48,
                        child: TextField(
                          controller: _apiKeyController,
                          obscureText: true,
                          decoration: const InputDecoration(
                            hintText: 'Pega tu api_key de Google AI Studio...',
                            contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12)
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                SizedBox(
                  height: 48,
                  child: _isSavingKey 
                      ? const Center(child: CircularProgressIndicator())
                      : OutlinedButton(
                          onPressed: _saveGeminiKey,
                          child: const Text('Guardar en BD'),
                        ),
                ),
              ],
            ),
            const Divider(height: 40),
            
            // Weekly Report Section
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Reporte Semanal de Productividad Musical',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Analiza tu historial, skips y genera consejos psicológicos personalizados.',
                      style: TextStyle(color: context.colors.textSecondary, fontSize: 12),
                    ),
                  ],
                ),
                _isGeneratingReport 
                    ? const CircularProgressIndicator()
                    : ElevatedButton.icon(
                        icon: const Icon(Icons.insights),
                        label: const Text('Generar Reporte'),
                        onPressed: _generateWeeklyReport,
                      ),
              ],
            ),
            
            if (_weeklyReport != null) ...[
              const SizedBox(height: 20),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: context.colors.bg.withOpacity(0.6),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: context.colors.border)
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // A simple parser to show Markdown report beautifully in lists and headings
                    ..._renderMarkdownToWidgets(_weeklyReport!['report'] ?? ''),
                  ],
                ),
              ).animate().fadeIn(duration: 400.ms),
            ]
          ],
        ),
      ),
    );
  }

  List<Widget> _renderMarkdownToWidgets(String markdown) {
    final List<Widget> widgets = [];
    final lines = markdown.split('\n');
    final accent = Theme.of(context).colorScheme.primary;
    
    // Collect table rows for grouped rendering
    List<List<String>> tableBuffer = [];
    bool inTable = false;
    
    void flushTable() {
      if (tableBuffer.isEmpty) return;
      widgets.add(_buildStyledTable(tableBuffer));
      tableBuffer = [];
      inTable = false;
    }
    
    for (var line in lines) {
      final trimmed = line.trim();
      
      // Skip empty lines
      if (trimmed.isEmpty) {
        flushTable();
        widgets.add(const SizedBox(height: 6));
        continue;
      }
      
      // Skip horizontal rules
      if (trimmed == '---' || trimmed == '***' || trimmed == '___') {
        flushTable();
        widgets.add(Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Divider(color: context.colors.border.withOpacity(0.3), thickness: 1),
        ));
        continue;
      }
      
      // Table delimiter rows (|---|---|)
      if (trimmed.startsWith('|') && trimmed.contains('---')) {
        inTable = true;
        continue;
      }
      
      // Table rows
      if (trimmed.startsWith('|') && trimmed.endsWith('|')) {
        final cells = trimmed.split('|').map((c) => c.trim()).where((c) => c.isNotEmpty).toList();
        if (cells.isNotEmpty && !cells.any((c) => RegExp(r'^:?-+:?$').hasMatch(c))) {
          tableBuffer.add(cells);
          inTable = true;
          continue;
        }
        continue;
      }
      
      // If we were in a table and hit a non-table line, flush
      if (inTable) flushTable();
      
      // H1 Headers — main title with gradient accent bar
      if (trimmed.startsWith('# ') && !trimmed.startsWith('## ')) {
        final text = trimmed.substring(2).replaceAll('**', '');
        widgets.add(Container(
          margin: const EdgeInsets.only(top: 20, bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [accent.withOpacity(0.15), accent.withOpacity(0.05)],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: accent.withOpacity(0.2)),
          ),
          child: Row(
            children: [
              Container(
                width: 4,
                height: 28,
                decoration: BoxDecoration(
                  color: accent,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  text,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: context.colors.textPrimary,
                    letterSpacing: -0.3,
                  ),
                ),
              ),
            ],
          ),
        ));
      }
      // H2 Headers — section titles with icon
      else if (trimmed.startsWith('## ')) {
        final text = trimmed.substring(3).replaceAll('**', '');
        widgets.add(Container(
          margin: const EdgeInsets.only(top: 20, bottom: 10),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: context.colors.surfaceAlt,
            borderRadius: BorderRadius.circular(10),
            border: Border(
              left: BorderSide(color: accent, width: 3),
            ),
          ),
          child: Text(
            text,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: accent,
              letterSpacing: -0.2,
            ),
          ),
        ));
      }
      // H3 Headers
      else if (trimmed.startsWith('### ')) {
        final text = trimmed.substring(4).replaceAll('**', '');
        widgets.add(Padding(
          padding: const EdgeInsets.only(top: 14, bottom: 6),
          child: Text(
            text,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: context.colors.textPrimary.withOpacity(0.85),
            ),
          ),
        ));
      }
      // Bullet points with accent dot
      else if (trimmed.startsWith('* ') || trimmed.startsWith('- ')) {
        final text = trimmed.substring(2).replaceAll('**', '');
        widgets.add(Padding(
          padding: const EdgeInsets.only(left: 8, bottom: 6),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                margin: const EdgeInsets.only(top: 7),
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: accent,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  text,
                  style: TextStyle(
                    color: context.colors.textPrimary.withOpacity(0.9),
                    fontSize: 13,
                    height: 1.5,
                  ),
                ),
              ),
            ],
          ),
        ));
      }
      // Ordered list
      else if (RegExp(r'^\d+\.\s').hasMatch(trimmed)) {
        final match = RegExp(r'^(\d+)\.\s(.*)$').firstMatch(trimmed);
        if (match != null) {
          final num = match.group(1)!;
          final text = (match.group(2) ?? '').replaceAll('**', '');
          widgets.add(Padding(
            padding: const EdgeInsets.only(left: 8, bottom: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 22,
                  height: 22,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: accent.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    num,
                    style: TextStyle(
                      color: accent,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    text,
                    style: TextStyle(
                      color: context.colors.textPrimary.withOpacity(0.9),
                      fontSize: 13,
                      height: 1.5,
                    ),
                  ),
                ),
              ],
            ),
          ));
        }
      }
      // Normal paragraph
      else {
        final cleanText = trimmed.replaceAll('**', '');
        widgets.add(Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Text(
            cleanText,
            style: TextStyle(
              color: context.colors.textSecondary,
              fontSize: 13,
              height: 1.5,
            ),
          ),
        ));
      }
    }
    
    // Flush any remaining table
    flushTable();
    
    return widgets;
  }

  Widget _buildStyledTable(List<List<String>> rows) {
    if (rows.isEmpty) return const SizedBox.shrink();
    final accent = Theme.of(context).colorScheme.primary;
    
    final hasHeader = rows.length > 1;
    final headerRow = hasHeader ? rows.first : null;
    final dataRows = hasHeader ? rows.sublist(1) : rows;
    
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: context.colors.border.withOpacity(0.3)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          // Header row
          if (headerRow != null)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
              decoration: BoxDecoration(
                color: accent.withOpacity(0.1),
              ),
              child: Row(
                children: headerRow.asMap().entries.map((entry) {
                  final isFirst = entry.key == 0;
                  final isLast = entry.key == headerRow.length - 1;
                  return Expanded(
                    flex: isFirst ? 3 : 2,
                    child: Text(
                      entry.value.replaceAll('**', ''),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: accent,
                        letterSpacing: 0.5,
                      ),
                      textAlign: isLast ? TextAlign.end : TextAlign.start,
                    ),
                  );
                }).toList(),
              ),
            ),
          // Data rows
          ...dataRows.asMap().entries.map((rowEntry) {
            final isEven = rowEntry.key % 2 == 0;
            final cells = rowEntry.value;
            return Container(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 14),
              decoration: BoxDecoration(
                color: isEven ? Colors.transparent : context.colors.surfaceAlt.withOpacity(0.4),
              ),
              child: Row(
                children: cells.asMap().entries.map((entry) {
                  final isFirst = entry.key == 0;
                  final isLast = entry.key == cells.length - 1;
                  return Expanded(
                    flex: isFirst ? 3 : 2,
                    child: Text(
                      entry.value.replaceAll('**', ''),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: isFirst ? FontWeight.w600 : FontWeight.w400,
                        color: isFirst 
                            ? context.colors.textPrimary 
                            : context.colors.textSecondary,
                      ),
                      textAlign: isLast ? TextAlign.end : TextAlign.start,
                    ),
                  );
                }).toList(),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildSyncHeader(BuildContext context, SettingsProvider settings) {
    final colors = context.colors;
    final isLoggedIn = settings.isLoggedIn;
    
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isLoggedIn 
            ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.12)
            : colors.surfaceAlt.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isLoggedIn 
              ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.3)
              : colors.border.withValues(alpha: 0.5),
          width: 1.5,
        ),
      ),
      child: Row(
        children: [
          // Avatar/Icon
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: isLoggedIn 
                  ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.2)
                  : colors.border.withValues(alpha: 0.5),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isLoggedIn ? Icons.person_rounded : Icons.person_outline_rounded,
              color: isLoggedIn ? Theme.of(context).colorScheme.primary : colors.textSecondary,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          // Info Text
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isLoggedIn 
                      ? 'Sincronizado como: ${settings.currentUserName}' 
                      : 'Sesión Local (Invitado)',
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  isLoggedIn
                      ? 'Correo: ${settings.currentUserEmail} • ID de Google: ${settings.currentUserId.length > 15 ? "${settings.currentUserId.substring(0, 12)}..." : settings.currentUserId}'
                      : 'Tus datos se guardan solo en esta máquina. Inicia sesión para sincronizar.',
                  style: TextStyle(
                    color: colors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          // Action button
          if (isLoggedIn)
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: colors.error,
                side: BorderSide(color: colors.error.withValues(alpha: 0.5)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              icon: const Icon(Icons.logout_rounded, size: 16),
              label: const Text('Cerrar Sesión'),
              onPressed: () async {
                await settings.logout();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: const Text('Sesión cerrada correctamente. Volviendo a la cuenta local.'),
                    backgroundColor: colors.success,
                  ));
                }
              },
            )
          else
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              icon: const Icon(Icons.sync_rounded, size: 16),
              label: const Text('Sincronizar / Entrar'),
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (_) => const AuthDialog(),
                ).then((success) {
                  if (success == true) {
                    _loadData();
                  }
                });
              },
            ),
        ],
      ),
    );
  }
}

class _StatData {
  final String title;
  final String value;
  final IconData icon;
  const _StatData(this.title, this.value, this.icon);
}
