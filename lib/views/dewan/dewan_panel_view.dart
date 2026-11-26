import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/link.dart';
import '../../models/scoring_models.dart';
import '../../services/app_link_helper.dart';
import '../../services/gelanggang_sync_service.dart';
import '../../services/pusaka_seni_api_service.dart';
import '../../theme/app_theme.dart';
import '../scoring/components/modals/athlete_selector_dialog.dart';

class JuriScoreState {
  final int juriNumber;
  final double score;
  final bool isSubmitted;
  final String status; // 'not_ready', 'ready', 'scoring', 'submitted'
  final int? currentJurus;
  final int? totalJurus;
  final String? jurusLabel;

  const JuriScoreState({
    required this.juriNumber,
    required this.score,
    required this.isSubmitted,
    this.status = 'not_ready',
    this.currentJurus,
    this.totalJurus,
    this.jurusLabel,
  });
}

class DewanPanelView extends StatefulWidget {
  final VoidCallback onBackToPortal;
  final String? arenaCode;

  const DewanPanelView({
    super.key,
    required this.onBackToPortal,
    this.arenaCode,
  });

  @override
  State<DewanPanelView> createState() => _DewanPanelViewState();
}

class _DewanPanelViewState extends State<DewanPanelView> {
  late String _arenaCode;
  late AthleteModel _athlete;
  late SeniCategory _category;

  final List<JuriScoreState> _juriScores = [];
  final List<PenaltyDeduction> _penalties = [];
  bool _isFinalized = false;
  bool _isSubmitting = false;
  bool _isFullScreen = false;

  int _timeRemaining = 180;
  String _timerStatus = 'standby';
  String _timerModeTitle = 'Standar (03:00)';

  bool get _isOvertime => _timeRemaining < 0;

  Color _getTimerStatusColor() {
    if (_isOvertime) return AppColors.primary;
    switch (_timerStatus.toLowerCase()) {
      case 'running':
        return AppColors.emerald;
      case 'paused':
        return AppColors.amber;
      case 'stopped':
        return AppColors.primary;
      case 'standby':
      default:
        return AppColors.textMuted;
    }
  }

  String _getTimerStatusLabel() {
    if (_isOvertime) {
      if (_timerStatus.toLowerCase() == 'paused') return 'LEWAT (JEDA)';
      if (_timerStatus.toLowerCase() == 'stopped') return 'LEWAT (SELESAI)';
      return 'LEWAT WAKTU';
    }
    switch (_timerStatus.toLowerCase()) {
      case 'running':
        return 'BERJALAN';
      case 'paused':
        return 'JEDA';
      case 'stopped':
        return 'SELESAI';
      case 'standby':
      default:
        return 'STANDBY';
    }
  }

  IconData _getTimerStatusIcon({IconData standbyIcon = Icons.timer_rounded}) {
    switch (_timerStatus.toLowerCase()) {
      case 'running':
        return Icons.play_arrow_rounded;
      case 'paused':
        return Icons.pause_rounded;
      case 'stopped':
        return Icons.stop_rounded;
      default:
        return standbyIcon;
    }
  }

  String _formatRemainingTime() {
    final bool isNegative = _timeRemaining < 0;
    final int absSec = _timeRemaining.abs();
    final int m = absSec ~/ 60;
    final int s = absSec % 60;
    final formatted = '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    return isNegative ? '-$formatted' : formatted;
  }

  void _toggleFullScreen() {
    setState(() => _isFullScreen = !_isFullScreen);
    if (_isFullScreen) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    } else {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }
  }

  static const List<Map<String, dynamic>> availablePenaltiesBaku = [
    {'label': 'Waktu Lewat / Kurang', 'value': 0.50},
    {'label': 'Keluar Batas Gelanggang', 'value': 0.50},
    {'label': 'Senjata Jatuh / Patah', 'value': 0.50},
    {'label': 'Pelanggaran Pakaian', 'value': 0.50},
  ];

  static const List<Map<String, dynamic>> availablePenaltiesGanda = [
    {'label': 'Toleransi Waktu', 'value': 0.50},
    {'label': 'Penampilan Keluar Gelanggang', 'value': 0.50},
    {'label': 'Senjata Jatuh Tidak Sesuai Deskripsi', 'value': 0.50},
    {'label': 'Senjata Jatuh Di Luar Gelanggang', 'value': 0.50},
    {'label': 'Pakaian Tidak Sesuai Aturan', 'value': 0.50},
    {'label': 'Menahan Gerakan > 5 Detik', 'value': 0.50},
  ];

  @override
  void initState() {
    super.initState();
    final sync = GelanggangSyncService.instance;
    _arenaCode = widget.arenaCode ?? sync.activeArenaCode;
    final state = sync.getArenaState(_arenaCode);
    _athlete = state.athlete;
    _category = state.category;
    _refreshJuriScoresFromSync();
    sync.addListener(_handleGelanggangSync);
    sync.startRealtimeSync(arenaCode: _arenaCode);
    _loadInitialServerData();
  }

  @override
  void dispose() {
    GelanggangSyncService.instance.removeListener(_handleGelanggangSync);
    GelanggangSyncService.instance.stopRealtimeSync(arenaCode: _arenaCode);
    super.dispose();
  }

  void _handleGelanggangSync() {
    final sync = GelanggangSyncService.instance;
    if (sync.lastSyncArenaCode != null &&
        sync.lastSyncArenaCode != GelanggangSyncService.normalizeArenaCode(_arenaCode)) {
      return;
    }
    if (mounted) {
      setState(() => _refreshJuriScoresFromSync());
    }
  }

  void _refreshJuriScoresFromSync() {
    final sync = GelanggangSyncService.instance;
    final state = sync.getArenaState(_arenaCode);
    _athlete = state.athlete;
    _category = state.category;
    _isFinalized = state.isMatchFinalized;
    _penalties
      ..clear()
      ..addAll(state.penalties);
    _timeRemaining = state.timerRemainingSeconds;
    _timerStatus = state.timerStatus;
    _timerModeTitle = state.timerModeTitle;
    final map = state.juriScores;
    _juriScores.clear();
    for (int i = 1; i <= state.activeJuriCount; i++) {
      final val = map[i];
      if (val != null) {
        final isSub = val['submitted'] as bool? ?? false;
        final rawStatus = val['status']?.toString();
        final status = rawStatus ??
            (isSub ? 'submitted' : (val['isReady'] == true ? 'ready' : 'not_ready'));
        _juriScores.add(
          JuriScoreState(
            juriNumber: i,
            score: (val['score'] as num?)?.toDouble() ?? 9.90,
            isSubmitted: isSub,
            status: status,
            currentJurus: (val['currentJurus'] as num?)?.toInt(),
            totalJurus: (val['totalJurus'] as num?)?.toInt(),
            jurusLabel: val['jurusLabel']?.toString(),
          ),
        );
      }
    }
  }

  Future<void> _loadInitialServerData() async {
    final sync = GelanggangSyncService.instance;
    if (!sync.cloudSyncEnabled) return;
    final state = sync.getArenaState(_arenaCode);
    if (!state.isVerified) return;
    try {
      final pesertas = await PusakaSeniApiService().fetchPesertas(
        eventId: state.lockedEventId,
        eventDocId: state.lockedEventDocId,
        gelanggangDocId: state.lockedGelanggangDocId,
        rawArenaCode: state.lockedRawArenaCode,
        fallbackToSample: false,
      );
      if (mounted &&
          pesertas.isNotEmpty &&
          !state.isMatchFinalized &&
          state.athlete.documentId.startsWith('ath-00')) {
        final first = pesertas.first;
        final cat = SeniCategory.fromString(first.category);
        sync.dewanSelectMatch(
          athlete: first,
          category: cat,
          nomorPartai: first.partai,
          pool: first.pool,
          arenaCode: _arenaCode,
        );
      }
    } catch (_) {}
  }

  void _showRestartJuriDialog() {
    final sync = GelanggangSyncService.instance;
    final activeCount = sync.getActiveJuriCount(arenaCode: _arenaCode);
    final maxH = MediaQuery.sizeOf(context).height * 0.85;

    showDialog(
      context: context,
      builder: (ctx) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 12,
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: 420, maxHeight: maxH),
            child: Container(
              padding: const EdgeInsets.all(18),
              decoration: AppDecorations.card(
                radius: 22,
                borderColor: AppColors.amberBorder,
                borderWidth: 1.4,
              ),
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: AppColors.amberSoft,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.amberBorder),
                          ),
                          child: const Icon(
                            Icons.restart_alt_rounded,
                            color: AppColors.amber,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Restart Slot Juri',
                                style: TextStyle(
                                  fontSize: 15.5,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              Text(
                                '$_arenaCode • Buka kunci slot perangkat juri',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: AppDecorations.softTile(radius: 12),
                      child: Text(
                        'Gunakan fitur ini jika salah satu perangkat juri keluar/ganti HP dan tidak bisa memilih nomor jurinya kembali.',
                        style: TextStyle(
                          fontSize: 11.5,
                          color: AppColors.textSecondary,
                          height: 1.4,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'RESET 1 JURI TERTENTU',
                      style: TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.7,
                        color: AppColors.textMuted,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 7,
                      runSpacing: 7,
                      children: List.generate(activeCount, (idx) {
                        final jNum = idx + 1;
                        final isClaimed = sync.isJuriClaimed(
                          jNum,
                          arenaCode: _arenaCode,
                        );
                        return InkWell(
                          onTap: () {
                            sync.releaseJuriClaim(jNum, arenaCode: _arenaCode);
                            Navigator.of(ctx).pop();
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Slot Juri $jNum berhasil di-restart! Perangkat baru kini dapat masuk sebagai Juri $jNum.',
                                ),
                                backgroundColor: AppColors.emerald,
                                behavior: SnackBarBehavior.floating,
                                duration: const Duration(seconds: 3),
                              ),
                            );
                          },
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 7,
                            ),
                            decoration: BoxDecoration(
                              color: isClaimed
                                  ? AppColors.amberSoft
                                  : AppColors.surfaceSoft,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: isClaimed
                                    ? AppColors.amberBorder
                                    : AppColors.border,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  isClaimed
                                      ? Icons.lock_open_rounded
                                      : Icons.restart_alt_rounded,
                                  size: 13,
                                  color: isClaimed
                                      ? AppColors.amber
                                      : AppColors.textMuted,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'Juri $jNum',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w800,
                                    color: isClaimed
                                        ? AppColors.amberText
                                        : AppColors.textPrimary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: () {
                        sync.clearClaimedJudges(arenaCode: _arenaCode);
                        Navigator.of(ctx).pop();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Semua slot juri di $_arenaCode berhasil di-restart!',
                            ),
                            backgroundColor: AppColors.primary,
                            behavior: SnackBarBehavior.floating,
                            duration: const Duration(seconds: 3),
                          ),
                        );
                      },
                      icon: const Icon(Icons.refresh_rounded, size: 16),
                      label: const Text(
                        'Reset Semua Slot Juri',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 11),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextButton(
                      onPressed: () => Navigator.of(ctx).pop(),
                      child: Text(
                        'Tutup',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _openAthleteSelector() {
    showDialog(
      context: context,
      builder: (_) => AthleteSelectorDialog(
        arenaCode: _arenaCode,
        currentAthlete: _athlete,
        currentCategory: _category,
        onAthleteSelected: (newAthlete) {
          final newCat = SeniCategory.fromString(newAthlete.category);
          final sync = GelanggangSyncService.instance;
          setState(() {
            _athlete = newAthlete;
            _category = newCat;
            _penalties.clear();
            _isFinalized = sync.isAthleteCompleted(newAthlete, arenaCode: _arenaCode);
          });
          sync.dewanSelectMatch(
            athlete: newAthlete,
            category: newCat,
            nomorPartai: newAthlete.partai,
            pool: newAthlete.pool,
            arenaCode: _arenaCode,
          );
        },
        onCategoryChanged: (newCat) {
          setState(() => _category = newCat);
        },
      ),
    );
  }

  void _addPenalty(String label, double value) {
    if (_isFinalized) return;
    final item = PenaltyDeduction(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      label: label,
      deduction: value,
      timestamp: DateTime.now(),
    );
    setState(() => _penalties.add(item));
    GelanggangSyncService.instance.dewanAddPenalty(item, arenaCode: _arenaCode);
  }

  void _removePenalty(String id) {
    if (_isFinalized) return;
    final idx = _penalties.indexWhere((p) => p.id == id);
    if (idx != -1) {
      setState(() => _penalties.removeAt(idx));
      GelanggangSyncService.instance.dewanRemovePenalty(idx, arenaCode: _arenaCode);
    }
  }

  double _calculateAverageJuri() {
    if (_juriScores.isEmpty) return 0.0;
    final double sum = _juriScores.fold(0.0, (acc, j) => acc + j.score);
    return sum / _juriScores.length;
  }

  double _calculateTotalPenalties() {
    return _penalties.fold(0.0, (acc, p) => acc + p.deduction);
  }

  double _calculateOfficialFinalScore() {
    final double avg = _calculateAverageJuri();
    final double penalties = _calculateTotalPenalties();
    return (avg - penalties).clamp(0.0, 99.0);
  }

  void _showFinalizeConfirmation() {
    final double avg = _calculateAverageJuri();
    final double pen = _calculateTotalPenalties();
    final double finalScore = _calculateOfficialFinalScore();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(
          children: [
            Icon(Icons.verified_rounded, color: AppColors.primary),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Pengesahan Nilai Partai',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Sahkan hasil pertandingan untuk ${_athlete.name} (${_athlete.kontingen})?',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: AppDecorations.softTile(radius: 14),
                child: Column(
                  children: [
                    _buildSummaryRow('Rata-rata Skor Juri:', avg.toStringAsFixed(4)),
                    const SizedBox(height: 6),
                    _buildSummaryRow(
                      'Hukuman Dewan:',
                      '-${pen.toStringAsFixed(2)}',
                      color: AppColors.primary,
                    ),
                    Divider(color: AppColors.border, height: 16),
                    _buildSummaryRow(
                      'Nilai Akhir Resmi:',
                      finalScore.toStringAsFixed(4),
                      color: AppColors.emerald,
                      isBold: true,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('Batal', style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              setState(() => _isSubmitting = true);

              GelanggangSyncService.instance.dewanFinalizeMatch(
                finalScore,
                arenaCode: _arenaCode,
              );

              if (_athlete.documentId.isNotEmpty) {
                await PusakaSeniApiService().postScore(
                  athleteDocId: _athlete.documentId,
                  poolDocId: _athlete.poolDocId,
                  penilai: 'dewan',
                  nilai: finalScore,
                  keterangan: 'Pengesahan Nilai Dewan Pertandingan (Penalti: -$pen)',
                );
              }

              if (mounted) {
                setState(() {
                  _isFinalized = true;
                  _isSubmitting = false;
                });
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Nilai partai berhasil disahkan dan disinkronkan ke server!'),
                    backgroundColor: AppColors.emerald,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 0,
            ),
            child: const Text('Ya, Sahkan Nilai'),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(
    String label,
    String value, {
    Color? color,
    bool isBold = false,
  }) {
    final resolvedColor = color ?? AppColors.textPrimary;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: isBold ? 15 : 12.5,
            fontWeight: isBold ? FontWeight.w900 : FontWeight.w700,
            fontFamily: 'monospace',
            color: resolvedColor,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final double avg = _calculateAverageJuri();
    final double penaltiesTotal = _calculateTotalPenalties();
    final double officialScore = _calculateOfficialFinalScore();
    final penaltyList = _category.isBaku ? availablePenaltiesBaku : availablePenaltiesGanda;

    return ListenableBuilder(
      listenable: AppThemeController.instance,
      builder: (context, _) => Scaffold(
      backgroundColor: AppColors.background,
      body: Container(
        decoration: AppDecorations.pageBackground,
        child: SafeArea(
          top: !_isFullScreen,
          bottom: false,
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: _isFullScreen ? 8 : 12,
              vertical: _isFullScreen ? 6 : 10,
            ),
            child: Column(
              children: [
                _buildHeader(),
                SizedBox(height: _isFullScreen ? 6 : 10),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final isWide =
                          constraints.maxWidth >= 880 && constraints.maxHeight >= 480;

                      if (isWide) {
                        return Row(
                          children: [
                            Expanded(flex: 5, child: _buildJuriMonitoringCard(avg)),
                            const SizedBox(width: 12),
                            Expanded(
                              flex: 5,
                              child: _buildPenaltiesAndEndorsementCard(
                                penaltyList,
                                penaltiesTotal,
                                officialScore,
                              ),
                            ),
                          ],
                        );
                      }

                      return SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Column(
                          children: [
                            _buildJuriMonitoringCard(avg, isScrollable: false),
                            const SizedBox(height: 12),
                            _buildPenaltiesAndEndorsementCard(
                              penaltyList,
                              penaltiesTotal,
                              officialScore,
                              isScrollable: false,
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
    );
  }

  Widget _buildJuriMonitoringCard(double avg, {bool isScrollable = true}) {
    final sync = GelanggangSyncService.instance;
    final int currentCount = sync.getArenaState(_arenaCode).activeJuriCount;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: AppDecorations.card(radius: 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: isScrollable ? MainAxisSize.max : MainAxisSize.min,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final isVeryCompact = constraints.maxWidth < 450;
              final int readyCount =
                  _juriScores.where((j) => j.status != 'not_ready').length;
              final bool allReady =
                  _juriScores.isNotEmpty && readyCount == _juriScores.length;
              final timerColor = _getTimerStatusColor();
              return Wrap(
                spacing: 6,
                runSpacing: 5,
                crossAxisAlignment: WrapCrossAlignment.center,
                alignment: WrapAlignment.spaceBetween,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.remove_red_eye_rounded,
                        color: AppColors.sky,
                        size: 16,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        isVeryCompact ? 'Multi-Juri' : 'Monitoring Multi-Juri',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: allReady ? AppColors.emeraldSoft : AppColors.primarySoft,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: allReady ? AppColors.emeraldBorder : AppColors.primaryBorder,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: allReady ? AppColors.emerald : AppColors.primary,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '$readyCount/${_juriScores.length} Ready',
                          style: TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'monospace',
                            color: allReady ? AppColors.emeraldText : AppColors.primaryText,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: timerColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: timerColor.withValues(alpha: 0.35)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _getTimerStatusIcon(standbyIcon: Icons.timer_outlined),
                          size: 10,
                          color: timerColor,
                        ),
                        const SizedBox(width: 3),
                        Text(
                          isVeryCompact
                              ? _formatRemainingTime()
                              : '${_formatRemainingTime()} • ${_getTimerStatusLabel()}',
                          style: TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'monospace',
                            color: timerColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.skySoft,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.skyBorder),
                    ),
                    child: Text(
                      isVeryCompact
                          ? avg.toStringAsFixed(2)
                          : 'Rata-rata: ${avg.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'monospace',
                        color: AppColors.skyText,
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 10),

          // Active Judges Selector
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: AppDecorations.softTile(radius: 12),
            child: Row(
              children: [
                Icon(Icons.people_alt_rounded, size: 15, color: AppColors.textMuted),
                const SizedBox(width: 6),
                Text(
                  'Juri Bertugas:',
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    child: Row(
                      children: [3, 4, 5, 8, 10].map((count) {
                        final bool isSelected = currentCount == count;
                        return Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: InkWell(
                            onTap: () {
                              GelanggangSyncService.instance
                                  .setActiveJuriCount(count, arenaCode: _arenaCode);
                            },
                            borderRadius: BorderRadius.circular(8),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 150),
                              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                              decoration: BoxDecoration(
                                color: isSelected ? AppColors.primary : AppColors.surface,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: isSelected ? AppColors.primary : AppColors.border,
                                ),
                              ),
                              child: Text(
                                '$count Juri',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                                  color: isSelected ? Colors.white : AppColors.textSecondary,
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                IconButton(
                  onPressed: _showRestartJuriDialog,
                  tooltip: 'Restart Slot Juri',
                  icon: const Icon(
                    Icons.restart_alt_rounded,
                    size: 16,
                    color: AppColors.amber,
                  ),
                  constraints: const BoxConstraints(
                    minWidth: 28,
                    minHeight: 28,
                  ),
                  padding: EdgeInsets.zero,
                  style: IconButton.styleFrom(
                    backgroundColor: AppColors.amberSoft,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.compact,
                    side: BorderSide(color: AppColors.amberBorder),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          if (isScrollable)
            Expanded(child: _buildJuriGrid())
          else
            _buildJuriGrid(shrinkWrap: true),
        ],
      ),
    );
  }

  String _formatShortJurusLabel(String? raw) {
    if (raw == null || raw.isEmpty) return '';
    final lower = raw.toLowerCase();
    if (lower.contains('tuntas')) return 'Tuntas';
    if (lower.contains('tangan')) return 'T. Kosong';
    if (lower.contains('toya')) return 'Toya';
    if (lower.contains('golok')) return 'Golok';
    if (lower.contains('beregu')) return '';
    return raw;
  }

  Widget _buildJuriGrid({bool shrinkWrap = false}) {
    final int count = _juriScores.length;
    final int crossCount = count <= 3 ? count : 2;

    return GridView.builder(
      physics: shrinkWrap ? const NeverScrollableScrollPhysics() : const BouncingScrollPhysics(),
      shrinkWrap: shrinkWrap,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossCount,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        childAspectRatio: count <= 3 ? 1.32 : 1.60,
      ),
      itemCount: _juriScores.length,
      itemBuilder: (context, index) {
        final j = _juriScores[index];

        Color borderColor;
        Color badgeBg;
        Color badgeBorder;
        Color badgeText;
        String statusLabel;
        IconData statusIcon;

        switch (j.status) {
          case 'ready':
            borderColor = AppColors.emerald;
            badgeBg = AppColors.emeraldSoft;
            badgeBorder = AppColors.emeraldBorder;
            badgeText = AppColors.emeraldText;
            statusLabel = 'READY';
            statusIcon = Icons.check_circle_rounded;
            break;
          case 'scoring':
            borderColor = AppColors.amber;
            badgeBg = AppColors.amberSoft;
            badgeBorder = AppColors.amberBorder;
            badgeText = AppColors.amberText;
            statusLabel = 'MENILAI';
            statusIcon = Icons.edit_note_rounded;
            break;
          case 'submitted':
            borderColor = AppColors.sky;
            badgeBg = AppColors.skySoft;
            badgeBorder = AppColors.skyBorder;
            badgeText = AppColors.skyText;
            statusLabel = 'SELESAI';
            statusIcon = Icons.verified_rounded;
            break;
          case 'not_ready':
          default:
            borderColor = AppColors.primary;
            badgeBg = AppColors.primarySoft;
            badgeBorder = AppColors.primaryBorder;
            badgeText = AppColors.primaryText;
            statusLabel = 'BELUM READY';
            statusIcon = Icons.pending_rounded;
            break;
        }

        final bool hasJurusProgress = _category.isBaku &&
            j.currentJurus != null &&
            j.totalJurus != null &&
            j.totalJurus! > 0 &&
            (j.status == 'scoring' || j.status == 'submitted');
        final bool isJurusTuntas =
            j.status == 'submitted' || (j.jurusLabel?.toLowerCase() == 'tuntas');
        final String shortGroup = _formatShortJurusLabel(j.jurusLabel);
        final String jurusText = hasJurusProgress
            ? (isJurusTuntas
                ? 'Tuntas (${j.totalJurus}/${j.totalJurus})'
                : (shortGroup.isNotEmpty
                    ? 'Jurus ${j.currentJurus}/${j.totalJurus} • $shortGroup'
                    : 'Jurus ${j.currentJurus}/${j.totalJurus}'))
            : '';
        final double jurusProgress = hasJurusProgress
            ? (j.currentJurus! / j.totalJurus!).clamp(0.0, 1.0)
            : 0.0;
        final Color jurusAccent = isJurusTuntas ? AppColors.sky : AppColors.amber;

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.surfaceSoft,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: borderColor.withValues(alpha: 0.55),
              width: 1.3,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Expanded(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 7,
                                  height: 7,
                                  decoration: BoxDecoration(
                                    color: borderColor,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  'Juri ${j.juriNumber}',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 3),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                              decoration: BoxDecoration(
                                color: badgeBg,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: badgeBorder, width: 0.8),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(statusIcon, size: 8.5, color: badgeText),
                                  const SizedBox(width: 3),
                                  Text(
                                    statusLabel,
                                    style: TextStyle(
                                      fontSize: 8,
                                      fontWeight: FontWeight.w800,
                                      color: badgeText,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        j.score.toStringAsFixed(2),
                        style: TextStyle(
                          fontSize: 16.5,
                          fontWeight: FontWeight.w900,
                          fontFamily: 'monospace',
                          color: j.isSubmitted ? AppColors.sky : AppColors.primary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (hasJurusProgress) ...[
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  decoration: BoxDecoration(
                    color: isJurusTuntas ? AppColors.skySoft : AppColors.amberSoft,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isJurusTuntas ? AppColors.skyBorder : AppColors.amberBorder,
                      width: 0.8,
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Icon(
                            isJurusTuntas
                                ? Icons.flag_rounded
                                : Icons.directions_run_rounded,
                            size: 9.5,
                            color: jurusAccent,
                          ),
                          const SizedBox(width: 3),
                          Expanded(
                            child: Text(
                              jurusText,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 8.5,
                                fontWeight: FontWeight.w800,
                                fontFamily: 'monospace',
                                color: isJurusTuntas
                                    ? AppColors.skyText
                                    : AppColors.amberText,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2.5),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(3),
                        child: LinearProgressIndicator(
                          value: jurusProgress,
                          minHeight: 3,
                          backgroundColor: AppColors.surface,
                          valueColor: AlwaysStoppedAnimation<Color>(jurusAccent),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildPenaltiesAndEndorsementCard(
    List<Map<String, dynamic>> penaltyList,
    double penaltiesTotal,
    double officialScore, {
    bool isScrollable = true,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: AppDecorations.card(radius: 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: isScrollable ? MainAxisSize.max : MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.warning_amber_rounded, color: AppColors.primary, size: 17),
                    SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        'Hukuman Penalti Dewan',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.primarySoft,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.primaryBorder),
                ),
                child: Text(
                  'Total: -${penaltiesTotal.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'monospace',
                    color: AppColors.primaryText,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: penaltyList.map((p) {
              return Material(
                color: AppColors.surfaceSoft,
                borderRadius: BorderRadius.circular(10),
                child: InkWell(
                  onTap: () => _addPenalty(p['label'] as String, p['value'] as double),
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 160),
                          child: Text(
                            p['label'] as String,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 5),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                          decoration: BoxDecoration(
                            color: AppColors.primarySoft,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '-${(p['value'] as double).toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w800,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 10),

          Text(
            'RIWAYAT HUKUMAN:',
            style: TextStyle(
              fontSize: 9.5,
              fontWeight: FontWeight.w800,
              color: AppColors.textMuted,
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(height: 5),

          if (isScrollable)
            Expanded(child: _buildPenaltiesList())
          else
            _buildPenaltiesList(maxHeight: 120),

          const SizedBox(height: 10),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: (_isFinalized || _isSubmitting) ? null : _showFinalizeConfirmation,
              icon: Icon(
                _isFinalized ? Icons.verified_rounded : Icons.gavel_rounded,
                size: 16,
              ),
              label: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  _isFinalized
                      ? 'Partai Selesai & Disahkan (${officialScore.toStringAsFixed(4)})'
                      : _isSubmitting
                          ? 'Menyimpan ke Server...'
                          : 'Sahkan Nilai Partai (${officialScore.toStringAsFixed(4)})',
                  style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold),
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: _isFinalized ? AppColors.emerald : AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 11),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPenaltiesList({double? maxHeight}) {
    final listWidget = _penalties.isEmpty
        ? Center(
            child: Padding(
              padding: EdgeInsets.all(12),
              child: Text(
                'Belum ada hukuman dewan yang dicatat.',
                style: TextStyle(color: AppColors.textMuted, fontSize: 11),
              ),
            ),
          )
        : ListView.separated(
            shrinkWrap: maxHeight != null,
            physics: const BouncingScrollPhysics(),
            itemCount: _penalties.length,
            separatorBuilder: (_, _) => Divider(color: AppColors.border, height: 1),
            itemBuilder: (context, index) {
              final pen = _penalties[index];
              return Row(
                children: [
                  Expanded(
                    child: Text(
                      pen.label,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  Text(
                    '-${pen.deduction.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                      fontFamily: 'monospace',
                    ),
                  ),
                  IconButton(
                    onPressed: () => _removePenalty(pen.id),
                    icon: Icon(
                      Icons.delete_outline_rounded,
                      size: 15,
                      color: AppColors.textMuted,
                    ),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
                  ),
                ],
              );
            },
          );

    return Container(
      height: maxHeight,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: AppDecorations.softTile(radius: 12),
      child: listWidget,
    );
  }

  Widget _buildHeader() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isVeryNarrow = constraints.maxWidth < 450;
        final isCompact = constraints.maxWidth < 750;

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: AppDecorations.card(radius: 18),
          child: Row(
            children: [
              IconButton(
                onPressed: widget.onBackToPortal,
                tooltip: 'Kembali ke Portal',
                icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 13),
                constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
                padding: EdgeInsets.zero,
                style: IconButton.styleFrom(
                  backgroundColor: AppColors.surfaceMuted,
                  foregroundColor: AppColors.textPrimary,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  visualDensity: VisualDensity.compact,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
                ),
              ),
              const SizedBox(width: 6),

              if (!isVeryNarrow) ...[
                Container(
                  width: 28,
                  height: 28,
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: AppColors.amberSoft,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.amberBorder),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: Image.asset(
                      'assets/images/app_logo_small.png',
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) => const Icon(
                        Icons.shield_rounded,
                        color: AppColors.primary,
                        size: 15,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
              ],

              Expanded(
                child: InkWell(
                  onTap: _openAthleteSelector,
                  borderRadius: BorderRadius.circular(11),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.primarySoft.withValues(alpha: 0.65),
                      borderRadius: BorderRadius.circular(11),
                      border: Border.all(color: AppColors.primaryBorder),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.centerLeft,
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      'Dewan Pertandingan',
                                      maxLines: 1,
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w800,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                    const SizedBox(width: 5),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 5,
                                        vertical: 1.5,
                                      ),
                                      decoration: BoxDecoration(
                                        color: AppColors.primary,
                                        borderRadius: BorderRadius.circular(5),
                                      ),
                                      child: Text(
                                        _athlete.partai.toUpperCase(),
                                        style: const TextStyle(
                                          fontSize: 8.5,
                                          fontWeight: FontWeight.w900,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                    if (!isCompact) ...[
                                      const SizedBox(width: 5),
                                      Text(
                                        _arenaCode,
                                        style: const TextStyle(
                                          fontSize: 9,
                                          fontFamily: 'monospace',
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.primary,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              const SizedBox(height: 1),
                              Builder(
                                builder: (context) {
                                  final evTitle = GelanggangSyncService.instance
                                      .getArenaState(_arenaCode)
                                      .lockedEventTitle;
                                  final evPrefix =
                                      evTitle != null && evTitle.isNotEmpty
                                          ? '$evTitle • '
                                          : '';
                                  return Text(
                                    '$evPrefix${_athlete.name} (${_athlete.kontingen}) • ${_category.title}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: AppColors.textSecondary,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppColors.primaryBorder),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.published_with_changes_rounded,
                                size: 12,
                                color: AppColors.primary,
                              ),
                              if (!isCompact) ...[
                                const SizedBox(width: 4),
                                Text(
                                  'Ganti Partai',
                                  style: TextStyle(
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.primaryText,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),

              _buildLiveTimerBadge(isCompact: isCompact, isVeryNarrow: isVeryNarrow),
              const SizedBox(width: 6),

              if (!isCompact) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _isFinalized ? AppColors.emeraldSoft : AppColors.blueSoft,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: _isFinalized ? AppColors.emeraldBorder : AppColors.blueBorder,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _isFinalized ? Icons.check_circle_rounded : Icons.sync_rounded,
                        size: 11,
                        color: _isFinalized ? AppColors.emerald : AppColors.blue,
                      ),
                      const SizedBox(width: 3),
                      Text(
                        _isFinalized ? 'Disahkan' : 'Live',
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.bold,
                          color: _isFinalized ? AppColors.emeraldText : AppColors.blueText,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
              ],

              if (AppLinkHelper.supportsNewTab && !isCompact) ...[
                Builder(
                  builder: (context) {
                    final arenaParam =
                        GelanggangSyncService.instance
                            .getArenaState(_arenaCode)
                            .lockedRawArenaCode ??
                        _arenaCode;
                    final monUri = AppLinkHelper.buildRoleUri(
                      role: 'monitoring',
                      arenaCode: arenaParam,
                    );
                    return Link(
                      uri: monUri,
                      target: LinkTarget.blank,
                      builder: (context, _) => IconButton(
                        onPressed: () => AppLinkHelper.openRoleInNewTab(
                          role: 'monitoring',
                          arenaCode: arenaParam,
                        ),
                        tooltip: 'Buka Monitoring di Tab Baru',
                        icon: const Icon(
                          Icons.open_in_new_rounded,
                          size: 15,
                          color: AppColors.blue,
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 30,
                          minHeight: 30,
                        ),
                        padding: EdgeInsets.zero,
                        style: IconButton.styleFrom(
                          backgroundColor: AppColors.blueSoft,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          visualDensity: VisualDensity.compact,
                          side: BorderSide(color: AppColors.blueBorder),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(9),
                          ),
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(width: 5),
              ],

              const ThemeToggleButton(
                buttonSize: 30,
                iconSize: 15,
                borderRadius: 9,
              ),
              const SizedBox(width: 5),

              IconButton(
                onPressed: _toggleFullScreen,
                tooltip: _isFullScreen ? 'Keluar Layar Penuh' : 'Layar Penuh Dewan',
                icon: Icon(
                  _isFullScreen ? Icons.fullscreen_exit_rounded : Icons.fullscreen_rounded,
                  size: 16,
                  color: AppColors.textPrimary,
                ),
                constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
                padding: EdgeInsets.zero,
                style: IconButton.styleFrom(
                  backgroundColor: AppColors.surfaceMuted,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  visualDensity: VisualDensity.compact,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
                  side: BorderSide(
                    color: _isFullScreen ? AppColors.sky : AppColors.border,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLiveTimerBadge({required bool isCompact, required bool isVeryNarrow}) {
    final statusColor = _getTimerStatusColor();
    final statusLabel = _getTimerStatusLabel();
    final timeStr = _formatRemainingTime();

    return Container(
      constraints: BoxConstraints(maxWidth: isVeryNarrow ? 78 : (isCompact ? 115 : 185)),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerRight,
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: isVeryNarrow ? 5 : 8,
            vertical: 3.5,
          ),
          decoration: BoxDecoration(
            color: AppColors.surfaceSoft,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: (!_isOvertime && _timerStatus.toLowerCase() == 'standby')
                  ? AppColors.border
                  : statusColor,
              width: (_isOvertime || _timerStatus == 'running') ? 1.5 : 1.0,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(_getTimerStatusIcon(), size: 13, color: statusColor),
              const SizedBox(width: 4),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        timeStr,
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w900,
                          fontFamily: 'monospace',
                          color: _isOvertime ||
                                  (_timeRemaining <= 10 && _timerStatus == 'running')
                              ? AppColors.primary
                              : AppColors.textPrimary,
                        ),
                      ),
                      if (!isVeryNarrow) ...[
                        const SizedBox(width: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                          decoration: BoxDecoration(
                            color: statusColor.withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(5),
                          ),
                          child: Text(
                            statusLabel,
                            style: TextStyle(
                              fontSize: 8,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.4,
                              color: statusColor,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (!isCompact) ...[
                    const SizedBox(height: 1),
                    Text(
                      _timerModeTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 8.5,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
