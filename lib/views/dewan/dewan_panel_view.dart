import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/scoring_models.dart';
import '../../services/gelanggang_sync_service.dart';
import '../../services/pusaka_seni_api_service.dart';
import '../scoring/components/modals/athlete_selector_dialog.dart';

class JuriScoreState {
  final int juriNumber;
  final double score;
  final bool isSubmitted;
  final String status; // 'not_ready', 'ready', 'scoring', 'submitted'

  const JuriScoreState({
    required this.juriNumber,
    required this.score,
    required this.isSubmitted,
    this.status = 'not_ready',
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

  // Multi-Juri Live Status (synced with GelanggangSyncService)
  final List<JuriScoreState> _juriScores = [];

  // Dewan Penalties Recorded
  final List<PenaltyDeduction> _penalties = [];
  bool _isFinalized = false;
  bool _isSubmitting = false;
  bool _isFullScreen = false;

  // Live Timer State (synced from Timekeeper)
  int _timeRemaining = 180;
  String _timerStatus = 'standby';
  String _timerModeTitle = 'Standar (03:00)';

  bool get _isOvertime => _timeRemaining < 0;

  Color _getTimerStatusColor() {
    if (_isOvertime) {
      return const Color(0xFFEF4444);
    }
    switch (_timerStatus.toLowerCase()) {
      case 'running':
        return const Color(0xFF10B981);
      case 'paused':
        return const Color(0xFFF59E0B);
      case 'stopped':
        return const Color(0xFFEF4444);
      case 'standby':
      default:
        return const Color(0xFF94A3B8);
    }
  }

  String _getTimerStatusLabel() {
    if (_isOvertime) {
      if (_timerStatus.toLowerCase() == 'paused') {
        return 'LEWAT (JEDA)';
      }
      if (_timerStatus.toLowerCase() == 'stopped') {
        return 'LEWAT (SELESAI)';
      }
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
      setState(() {
        _refreshJuriScoresFromSync();
      });
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
            (isSub
                ? 'submitted'
                : (val['isReady'] == true ? 'ready' : 'not_ready'));
        _juriScores.add(
          JuriScoreState(
            juriNumber: i,
            score: (val['score'] as num?)?.toDouble() ?? 9.90,
            isSubmitted: isSub,
            status: status,
          ),
        );
      }
    }
  }

  Future<void> _loadInitialServerData() async {
    try {
      final gelanggangs = await PusakaSeniApiService().fetchGelanggangs();
      if (mounted && gelanggangs.isNotEmpty) {
        final firstCode = gelanggangs.first['arena_code']?.toString();
        if (firstCode != null &&
            !GelanggangSyncService.instance.isGelanggangVerified &&
            widget.arenaCode == null) {
          GelanggangSyncService.instance.verifyGelanggang(arenaCode: firstCode);
        }
      }
    } catch (_) {}
  }

  void _openAthleteSelector() {
    showDialog(
      context: context,
      builder: (_) => AthleteSelectorDialog(
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
          // MASTER BROADCAST: Dewan selects match for this specific arena!
          sync.dewanSelectMatch(
            athlete: newAthlete,
            category: newCat,
            nomorPartai: newAthlete.partai,
            pool: newAthlete.pool,
            arenaCode: _arenaCode,
          );
        },
        onCategoryChanged: (newCat) {
          setState(() {
            _category = newCat;
          });
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
    setState(() {
      _penalties.add(item);
    });
    GelanggangSyncService.instance.dewanAddPenalty(item, arenaCode: _arenaCode);
  }

  void _removePenalty(String id) {
    if (_isFinalized) return;
    final idx = _penalties.indexWhere((p) => p.id == id);
    if (idx != -1) {
      setState(() {
        _penalties.removeAt(idx);
      });
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
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.verified_rounded, color: Color(0xFFDC2626)),
            SizedBox(width: 8),
            Text(
              'Pengesahan Nilai Partai',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
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
                style: const TextStyle(color: Color(0xFFCBD5E1), fontSize: 13),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F172A),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF334155)),
                ),
                child: Column(
                  children: [
                    _buildSummaryRow('Rata-rata Skor Juri:', avg.toStringAsFixed(4)),
                    const SizedBox(height: 6),
                    _buildSummaryRow(
                      'Hukuman Dewan:',
                      '-${pen.toStringAsFixed(2)}',
                      color: const Color(0xFFEF4444),
                    ),
                    const Divider(color: Color(0xFF334155), height: 16),
                    _buildSummaryRow(
                      'Nilai Akhir Resmi:',
                      finalScore.toStringAsFixed(4),
                      color: const Color(0xFF10B981),
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
            child: const Text('Batal', style: TextStyle(color: Colors.white70)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              setState(() {
                _isSubmitting = true;
              });

              // Broadcast to sync service for this arena
              GelanggangSyncService.instance.dewanFinalizeMatch(finalScore, arenaCode: _arenaCode);

              // Post to Strapi API
              if (_athlete.documentId.isNotEmpty) {
                await PusakaSeniApiService().postScore(
                  athleteDocId: _athlete.documentId,
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
                    backgroundColor: Color(0xFF10B981),
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
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
    Color color = Colors.white,
    bool isBold = false,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
        Text(
          value,
          style: TextStyle(
            fontSize: isBold ? 15 : 12.5,
            fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
            fontFamily: 'monospace',
            color: color,
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
    final penaltyList = _category.isBaku
        ? availablePenaltiesBaku
        : availablePenaltiesGanda;

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: SafeArea(
        top: !_isFullScreen,
        bottom: false,
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: _isFullScreen ? 6 : 10,
            vertical: _isFullScreen ? 4 : 8,
          ),
          child: Column(
            children: [
              // Top Header
              _buildHeader(),
              SizedBox(height: _isFullScreen ? 4 : 8),

              // Responsive Dashboard (Desktop/Landscape 2 cols vs Portrait vertical)
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final isWide = constraints.maxWidth >= 880 && constraints.maxHeight >= 480;

                    if (isWide) {
                      return Row(
                        children: [
                          // Left Column: Multi-Juri Monitoring
                          Expanded(
                            flex: 5,
                            child: _buildJuriMonitoringCard(avg),
                          ),
                          const SizedBox(width: 10),

                          // Right Column: Penalties & Endorsement
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
                    } else {
                      // Compact Screen (Mobile & Tablet Portrait): Vertical scrollable
                      return SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
                        child: Column(
                          children: [
                            _buildJuriMonitoringCard(avg, isScrollable: false),
                            const SizedBox(height: 10),
                            _buildPenaltiesAndEndorsementCard(
                              penaltyList,
                              penaltiesTotal,
                              officialScore,
                              isScrollable: false,
                            ),
                          ],
                        ),
                      );
                    }
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildJuriMonitoringCard(double avg, {bool isScrollable = true}) {
    final sync = GelanggangSyncService.instance;
    final int currentCount = sync.getArenaState(_arenaCode).activeJuriCount;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF334155)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: isScrollable ? MainAxisSize.max : MainAxisSize.min,
        children: [
          // Header Row with Title, Readiness, & Average
          LayoutBuilder(
            builder: (context, constraints) {
              final isVeryCompact = constraints.maxWidth < 450;
              final int readyCount =
                  _juriScores.where((j) => j.status != 'not_ready').length;
              final bool allReady =
                  _juriScores.isNotEmpty && readyCount == _juriScores.length;
              final timerColor = _getTimerStatusColor();
              return Wrap(
                spacing: 5,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                alignment: WrapAlignment.spaceBetween,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.remove_red_eye_rounded,
                        color: Color(0xFF38BDF8),
                        size: 15,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        isVeryCompact ? 'Multi-Juri' : 'Monitoring Multi-Juri',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                  // Readiness Summary Badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                    decoration: BoxDecoration(
                      color: allReady ? const Color(0xFF064E3B) : const Color(0xFF450A0A),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: allReady ? const Color(0xFF10B981) : const Color(0xFFDC2626),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 5,
                          height: 5,
                          decoration: BoxDecoration(
                            color: allReady ? const Color(0xFF10B981) : const Color(0xFFDC2626),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 3),
                        Text(
                          '$readyCount/${_juriScores.length} Ready',
                          style: TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'monospace',
                            color: allReady ? const Color(0xFF6EE7B7) : const Color(0xFFFCA5A5),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Live Timer Indicator (Synced with Timekeeper)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                    decoration: BoxDecoration(
                      color: timerColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: timerColor.withValues(alpha: 0.5)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _getTimerStatusIcon(standbyIcon: Icons.timer_outlined),
                          size: 9.5,
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
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F172A),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFF334155)),
                    ),
                    child: Text(
                      isVeryCompact ? avg.toStringAsFixed(2) : 'Rata-rata: ${avg.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'monospace',
                        color: Color(0xFF38BDF8),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 8),

          // Active Judges Selector (Controlled by Dewan: 3, 5, 8, 10 Juri)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
            decoration: BoxDecoration(
              color: const Color(0xFF0F172A),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFF334155)),
            ),
            child: Row(
              children: [
                const Icon(Icons.people_alt_rounded, size: 14, color: Color(0xFF94A3B8)),
                const SizedBox(width: 6),
                const Text(
                  'Juri Bertugas:',
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF94A3B8),
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
                          padding: const EdgeInsets.only(right: 5),
                          child: InkWell(
                            onTap: () {
                              GelanggangSyncService.instance.setActiveJuriCount(count, arenaCode: _arenaCode);
                            },
                            borderRadius: BorderRadius.circular(6),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? const Color(0xFFDC2626)
                                    : const Color(0xFF1E293B),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: isSelected
                                      ? const Color(0xFFEF4444)
                                      : const Color(0xFF475569),
                                  width: isSelected ? 1.4 : 1.0,
                                ),
                              ),
                              child: Text(
                                '$count Juri',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                                  color: isSelected ? Colors.white : const Color(0xFFCBD5E1),
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // Juri Grid
          if (isScrollable)
            Expanded(
              child: _buildJuriGrid(),
            )
          else
            _buildJuriGrid(shrinkWrap: true),
        ],
      ),
    );
  }

  Widget _buildJuriGrid({bool shrinkWrap = false}) {
    final int count = _juriScores.length;
    final int crossCount = count <= 3 ? count : 2;

    return GridView.builder(
      physics: shrinkWrap ? const NeverScrollableScrollPhysics() : const BouncingScrollPhysics(),
      shrinkWrap: shrinkWrap,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossCount,
        mainAxisSpacing: 6,
        crossAxisSpacing: 6,
        childAspectRatio: count <= 3 ? 1.45 : 1.80,
      ),
      itemCount: _juriScores.length,
      itemBuilder: (context, index) {
        final j = _juriScores[index];

        // 4 Status Colors:
        // 1. Merah = not_ready (Belum Ready)
        // 2. Hijau = ready (Telah Ready)
        // 3. Kuning = scoring (Sedang Melakukan Penilaian)
        // 4. Biru/Cyan = submitted (Sudah Melakukan Penilaian)
        Color borderColor;
        Color badgeBg;
        Color badgeBorder;
        Color badgeText;
        String statusLabel;
        IconData statusIcon;

        switch (j.status) {
          case 'ready':
            borderColor = const Color(0xFF10B981);
            badgeBg = const Color(0xFF064E3B);
            badgeBorder = const Color(0xFF10B981);
            badgeText = const Color(0xFF6EE7B7);
            statusLabel = 'READY';
            statusIcon = Icons.check_circle_rounded;
            break;
          case 'scoring':
            borderColor = const Color(0xFFF59E0B);
            badgeBg = const Color(0xFF451A03);
            badgeBorder = const Color(0xFFF59E0B);
            badgeText = const Color(0xFFFDE68A);
            statusLabel = 'MENILAI';
            statusIcon = Icons.edit_note_rounded;
            break;
          case 'submitted':
            borderColor = const Color(0xFF0284C7);
            badgeBg = const Color(0xFF0C4A6E);
            badgeBorder = const Color(0xFF0284C7);
            badgeText = const Color(0xFFBAE6FD);
            statusLabel = 'SELESAI';
            statusIcon = Icons.verified_rounded;
            break;
          case 'not_ready':
          default:
            borderColor = const Color(0xFFDC2626);
            badgeBg = const Color(0xFF450A0A);
            badgeBorder = const Color(0xFFDC2626);
            badgeText = const Color(0xFFFCA5A5);
            statusLabel = 'BELUM READY';
            statusIcon = Icons.pending_rounded;
            break;
        }

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFF0F172A),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: borderColor.withValues(alpha: 0.7),
              width: 1.2,
            ),
          ),
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
                          const SizedBox(width: 4),
                          Text(
                            'Juri ${j.juriNumber}',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                        decoration: BoxDecoration(
                          color: badgeBg,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: badgeBorder, width: 0.8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(statusIcon, size: 8, color: badgeText),
                            const SizedBox(width: 2.5),
                            Text(
                              statusLabel,
                              style: TextStyle(
                                fontSize: 8,
                                fontWeight: FontWeight.bold,
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
              const SizedBox(width: 4),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  j.score.toStringAsFixed(2),
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    fontFamily: 'monospace',
                    color: j.isSubmitted ? const Color(0xFF38BDF8) : const Color(0xFFEF4444),
                  ),
                ),
              ),
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
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF334155)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: isScrollable ? MainAxisSize.max : MainAxisSize.min,
        children: [
          Row(
            children: [
              const Expanded(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.warning_amber_rounded,
                      color: Color(0xFFEF4444),
                      size: 16,
                    ),
                    SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        'Hukuman Penalti Dewan',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF450A0A),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0xFF991B1B)),
                ),
                child: Text(
                  'Total: -${penaltiesTotal.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'monospace',
                    color: Color(0xFFFCA5A5),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Penalty Buttons
          Wrap(
            spacing: 5,
            runSpacing: 5,
            children: penaltyList.map((p) {
              return InkWell(
                onTap: () => _addPenalty(p['label'] as String, p['value'] as double),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F172A),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFF334155)),
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
                          style: const TextStyle(fontSize: 10, color: Color(0xFFCBD5E1)),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                        decoration: BoxDecoration(
                          color: const Color(0xFFDC2626).withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '-${(p['value'] as double).toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFEF4444),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 8),

          // Penalty History List
          const Text(
            'RIWAYAT HUKUMAN:',
            style: TextStyle(
              fontSize: 9.5,
              fontWeight: FontWeight.bold,
              color: Color(0xFF94A3B8),
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(height: 4),

          if (isScrollable)
            Expanded(
              child: _buildPenaltiesList(),
            )
          else
            _buildPenaltiesList(maxHeight: 120),

          const SizedBox(height: 8),

          // Final Endorsement Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: (_isFinalized || _isSubmitting)
                  ? null
                  : _showFinalizeConfirmation,
              icon: Icon(
                _isFinalized
                    ? Icons.verified_rounded
                    : Icons.gavel_rounded,
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
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: _isFinalized
                    ? const Color(0xFF059669)
                    : const Color(0xFFDC2626),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 9),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
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
              padding: const EdgeInsets.all(12),
              child: Text(
                'Belum ada hukuman dewan yang dicatat.',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 11),
              ),
            ),
          )
        : ListView.separated(
            shrinkWrap: maxHeight != null,
            physics: const BouncingScrollPhysics(),
            itemCount: _penalties.length,
            separatorBuilder: (_, _) => const Divider(color: Color(0xFF334155), height: 1),
            itemBuilder: (context, index) {
              final pen = _penalties[index];
              return Row(
                children: [
                  Expanded(
                    child: Text(
                      pen.label,
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFFCBD5E1),
                      ),
                    ),
                  ),
                  Text(
                    '-${pen.deduction.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFEF4444),
                      fontFamily: 'monospace',
                    ),
                  ),
                  IconButton(
                    onPressed: () => _removePenalty(pen.id),
                    icon: const Icon(
                      Icons.delete_outline_rounded,
                      size: 14,
                      color: Color(0xFF94A3B8),
                    ),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 24,
                      minHeight: 24,
                    ),
                  ),
                ],
              );
            },
          );

    return Container(
      height: maxHeight,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF334155)),
      ),
      child: listWidget,
    );
  }

  Widget _buildHeader() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isVeryNarrow = constraints.maxWidth < 450;
        final isCompact = constraints.maxWidth < 750;

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFF334155)),
          ),
          child: Row(
            children: [
              IconButton(
                onPressed: widget.onBackToPortal,
                tooltip: 'Kembali ke Portal',
                icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 13),
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                padding: EdgeInsets.zero,
                style: IconButton.styleFrom(
                  backgroundColor: const Color(0xFF0F172A),
                  foregroundColor: const Color(0xFFCBD5E1),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  visualDensity: VisualDensity.compact,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
              const SizedBox(width: 6),

              if (!isVeryNarrow) ...[
                Container(
                  width: 26,
                  height: 26,
                  padding: const EdgeInsets.all(1.5),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F172A),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFFD97706).withValues(alpha: 0.4)),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(5),
                    child: Image.asset(
                      'assets/images/app_logo_small.png',
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) => const Icon(
                        Icons.shield_rounded,
                        color: Color(0xFFEF4444),
                        size: 15,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
              ],

              // Master Controller: Athlete & Partai info
              Expanded(
                child: InkWell(
                  onTap: _openAthleteSelector,
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F172A).withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFDC2626).withValues(alpha: 0.4)),
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
                                    const Text(
                                      'Dewan Pertandingan',
                                      maxLines: 1,
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFDC2626),
                                        borderRadius: BorderRadius.circular(4),
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
                                      const SizedBox(width: 4),
                                      Text(
                                        _arenaCode,
                                        style: const TextStyle(
                                          fontSize: 8.5,
                                          fontFamily: 'monospace',
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFFEF4444),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              const SizedBox(height: 1),
                              Text(
                                '${_athlete.name} (${_athlete.kontingen}) • ${_category.title}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 10, color: Color(0xFFCBD5E1)),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFFDC2626).withValues(alpha: 0.25),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: const Color(0xFFDC2626)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.published_with_changes_rounded, size: 12, color: Color(0xFFEF4444)),
                              if (!isCompact) ...[
                                const SizedBox(width: 3),
                                const Text(
                                  'Ganti Partai',
                                  style: TextStyle(
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFFFCA5A5),
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
              const SizedBox(width: 4),

              // Live Timer Status Badge (Synced from Timekeeper)
              _buildLiveTimerBadge(isCompact: isCompact, isVeryNarrow: isVeryNarrow),
              const SizedBox(width: 4),

              // Status Badge
              if (!isCompact) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  decoration: BoxDecoration(
                    color: _isFinalized
                        ? const Color(0xFF065F46)
                        : const Color(0xFF1E3A8A),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _isFinalized ? Icons.check_circle_rounded : Icons.sync_rounded,
                        size: 11,
                        color: _isFinalized ? const Color(0xFF34D399) : const Color(0xFF93C5FD),
                      ),
                      const SizedBox(width: 3),
                      Text(
                        _isFinalized ? 'Disahkan' : 'Live',
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.bold,
                          color: _isFinalized ? const Color(0xFF34D399) : const Color(0xFF93C5FD),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 4),
              ],

              // Full Screen Toggle Button for Dewan
              IconButton(
                onPressed: _toggleFullScreen,
                tooltip: _isFullScreen ? 'Keluar Layar Penuh' : 'Layar Penuh Dewan',
                icon: Icon(
                  _isFullScreen ? Icons.fullscreen_exit_rounded : Icons.fullscreen_rounded,
                  size: 16,
                  color: Colors.white,
                ),
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                padding: EdgeInsets.zero,
                style: IconButton.styleFrom(
                  backgroundColor: const Color(0xFF0F172A),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  visualDensity: VisualDensity.compact,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  side: BorderSide(
                    color: _isFullScreen ? const Color(0xFF38BDF8) : const Color(0xFF334155),
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
      constraints: BoxConstraints(maxWidth: isVeryNarrow ? 78 : (isCompact ? 115 : 180)),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerRight,
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: isVeryNarrow ? 4 : 6,
            vertical: 2.5,
          ),
          decoration: BoxDecoration(
            color: const Color(0xFF0F172A),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: (!_isOvertime && _timerStatus.toLowerCase() == 'standby')
                  ? const Color(0xFF334155)
                  : statusColor,
              width: (_isOvertime || _timerStatus == 'running') ? 1.5 : 1.0,
            ),
            boxShadow: (_isOvertime || _timerStatus == 'running')
                ? [
                    BoxShadow(
                      color: statusColor.withValues(alpha: 0.25),
                      blurRadius: 6,
                      offset: const Offset(0, 1),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                _getTimerStatusIcon(),
                size: 13,
                color: statusColor,
              ),
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
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          fontFamily: 'monospace',
                          color: _isOvertime || (_timeRemaining <= 10 && _timerStatus == 'running')
                              ? const Color(0xFFEF4444)
                              : Colors.white,
                        ),
                      ),
                      if (!isVeryNarrow) ...[
                        const SizedBox(width: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                          decoration: BoxDecoration(
                            color: statusColor.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(3),
                          ),
                          child: Text(
                            statusLabel,
                            style: TextStyle(
                              fontSize: 8,
                              fontWeight: FontWeight.bold,
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
                      style: const TextStyle(
                        fontSize: 8,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF94A3B8),
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
