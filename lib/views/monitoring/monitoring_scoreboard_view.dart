import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/scoring_models.dart';
import '../../services/gelanggang_sync_service.dart';

class MonitoringScoreboardView extends StatefulWidget {
  final VoidCallback onBackToPortal;
  final String? arenaCode;

  const MonitoringScoreboardView({
    super.key,
    required this.onBackToPortal,
    this.arenaCode,
  });

  @override
  State<MonitoringScoreboardView> createState() => _MonitoringScoreboardViewState();
}

class _MonitoringScoreboardViewState extends State<MonitoringScoreboardView> {
  bool _isFullScreen = false;
  late String _arenaCode;
  late AthleteModel _athlete;
  late SeniCategory _category;

  int _timeRemaining = 180;
  int _targetDuration = 180;
  String _timerStatus = 'standby';
  String _timerModeTitle = 'Standar (03:00)';
  double _officialScore = 9.900;
  double _medianJuri = 9.900;
  double _standardDeviation = 0.0;
  double _dewanPenalties = 0.0;
  bool _isFinalized = false;

  final List<Map<String, dynamic>> _juriStatus = [];

  @override
  void initState() {
    super.initState();
    final sync = GelanggangSyncService.instance;
    _arenaCode = widget.arenaCode ?? sync.activeArenaCode;
    _syncFromGelanggangService();
    sync.addListener(_handleGelanggangSync);
  }

  @override
  void dispose() {
    GelanggangSyncService.instance.removeListener(_handleGelanggangSync);
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
        _syncFromGelanggangService();
      });
    }
  }

  void _syncFromGelanggangService() {
    final sync = GelanggangSyncService.instance;
    final state = sync.getArenaState(_arenaCode);
    _athlete = state.athlete;
    _category = state.category;
    _timeRemaining = state.timerRemainingSeconds;
    _targetDuration = state.targetDurationSeconds;
    _timerStatus = state.timerStatus;
    _timerModeTitle = state.timerModeTitle;
    _medianJuri = state.calculateJuriMedian();
    _standardDeviation = state.calculateStandardDeviation();
    _dewanPenalties = state.calculateTotalPenalties();
    _isFinalized = state.isMatchFinalized;
    _officialScore = _isFinalized
        ? state.officialFinalScore
        : (_medianJuri - _dewanPenalties).clamp(0.0, 99.0);

    _juriStatus.clear();
    for (int i = 1; i <= state.activeJuriCount; i++) {
      final data = state.juriScores[i];
      if (data != null) {
        _juriStatus.add({
          'juri': i,
          'score': (data['score'] as num?)?.toDouble() ?? 9.90,
          'submitted': data['submitted'] as bool? ?? false,
        });
      }
    }
  }

  void _toggleFullScreen() {
    setState(() => _isFullScreen = !_isFullScreen);
    if (_isFullScreen) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    } else {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }
  }

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

  String _formatCountdown() {
    final bool isNegative = _timeRemaining < 0;
    final int absSec = _timeRemaining.abs();
    final int m = absSec ~/ 60;
    final int s = absSec % 60;
    final formatted = '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    return isNegative ? '-$formatted' : formatted;
  }

  String _formatTimePerformance() {
    // If timer hasn't started yet, show 00 : 00
    if ((_timerStatus == 'standby' || _timerStatus == 'stopped') &&
        _timeRemaining == _targetDuration) {
      return '00 : 00';
    }
    final int elapsed = math.max(0, _targetDuration - _timeRemaining);
    final int m = elapsed ~/ 60;
    final int s = elapsed % 60;
    return '${m.toString().padLeft(2, '0')} : ${s.toString().padLeft(2, '0')}';
  }

  IconData _getTimerStatusIcon() {
    switch (_timerStatus.toLowerCase()) {
      case 'running':
        return Icons.play_arrow_rounded;
      case 'paused':
        return Icons.pause_rounded;
      case 'stopped':
        return Icons.stop_rounded;
      default:
        return Icons.timer_rounded;
    }
  }

  Widget _buildTimerStatusBadge({bool compact = false}) {
    final color = _getTimerStatusColor();
    final label = _getTimerStatusLabel();
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: compact ? 4 : 7, vertical: 1.5),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.7), width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _getTimerStatusIcon(),
              size: compact ? 8 : 11,
              color: color,
            ),
            const SizedBox(width: 2.5),
            Text(
              label,
              style: TextStyle(
                fontSize: compact ? 7.5 : 9.5,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.5,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF071228),
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
              // Unobtrusive Top Bar with controls & tournament info
              _buildTopBar(),
              SizedBox(height: _isFullScreen ? 4 : 6),

              // Responsive Audience Display Board
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final isLandscape = constraints.maxWidth >= 600 && constraints.maxHeight >= 280;

                    if (isLandscape) {
                      return _buildWideScoreboard(constraints);
                    } else {
                      return _buildCompactScoreboard();
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

  /// Wide TV / Landscape Layout (Original Photo Styling with Juri on Top & Total Score on Left)
  Widget _buildWideScoreboard(BoxConstraints constraints) {
    final bool isCompactHeight = constraints.maxHeight < 360;

    return Column(
      children: [
        // 1. Athlete Split Bar (Left: Kontingen [Blue], Right: Nama Atlet [Navy]) - NO ICONS
        _buildAthleteSplitBar(compact: isCompactHeight),
        SizedBox(height: isCompactHeight ? 5 : 8),

        // 2. Juri Cards Row DI ATAS (Above the Scoreboard Main Area)
        _buildJuriCardsRow(isScrollable: false),
        SizedBox(height: isCompactHeight ? 5 : 8),

        // 3. Scoreboard Main Area: Left (Total Score) vs Right (Median, Penalty, Time, StdDev)
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Left Column (flex 9): Total Score Card (diletakan di kirinya)
              Expanded(
                flex: 9,
                child: _buildTotalScoreCard(compact: isCompactHeight),
              ),
              SizedBox(width: isCompactHeight ? 5 : 8),

              // Right Column (flex 11): 3 top metrics + Standard Deviation below
              Expanded(
                flex: 11,
                child: Column(
                  children: [
                    // Top Row: Median, Penalty, Time Performance
                    Expanded(
                      flex: 5,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(
                            child: _buildMetricBox(
                              label: 'MEDIAN',
                              value: _medianJuri.toStringAsFixed(3),
                            ),
                          ),
                          SizedBox(width: isCompactHeight ? 5 : 8),
                          Expanded(
                            child: _buildMetricBox(
                              label: 'PENALTY',
                              value: _dewanPenalties.toStringAsFixed(2),
                            ),
                          ),
                          SizedBox(width: isCompactHeight ? 5 : 8),
                          Expanded(
                            child: _buildMetricBox(
                              label: 'TIME PERFORMANCE',
                              value: _formatTimePerformance(),
                              statusBadge: _buildTimerStatusBadge(),
                              subtitle: _timerModeTitle,
                              isOvertime: _isOvertime,
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: isCompactHeight ? 5 : 8),

                    // Bottom Row: Standard Deviation (wide box across all 3 columns)
                    Expanded(
                      flex: 5,
                      child: _buildMetricBox(
                        label: 'STANDARD DEVIATION',
                        value: _standardDeviation.toStringAsFixed(9),
                        isStdDev: true,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Compact Mobile Portrait / Small Screen Layout
  Widget _buildCompactScoreboard() {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Column(
        children: [
          // Athlete Split Bar
          _buildAthleteSplitBar(compact: true),
          const SizedBox(height: 8),

          // Juri Score Cards DI ATAS
          _buildJuriCardsRow(isScrollable: true),
          const SizedBox(height: 8),

          // Total Score Box
          SizedBox(
            height: 120,
            child: _buildTotalScoreCard(compact: true),
          ),
          const SizedBox(height: 8),

          // 3 Metric Cards Row
          Row(
            children: [
              Expanded(
                child: _buildMetricBox(
                  label: 'MEDIAN',
                  value: _medianJuri.toStringAsFixed(3),
                  compact: true,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _buildMetricBox(
                  label: 'PENALTY',
                  value: _dewanPenalties.toStringAsFixed(2),
                  compact: true,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _buildMetricBox(
                  label: 'TIME PERF',
                  value: _formatTimePerformance(),
                  compact: true,
                  statusBadge: _buildTimerStatusBadge(compact: true),
                  subtitle: _timerModeTitle,
                  isOvertime: _isOvertime,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),

          // Standard Deviation Card
          _buildMetricBox(
            label: 'STANDARD DEVIATION',
            value: _standardDeviation.toStringAsFixed(9),
            isStdDev: true,
            compact: true,
          ),
        ],
      ),
    );
  }

  /// Metric Box with Cyan/Green header pill (Warning Red on overtime) and dark blue body
  Widget _buildMetricBox({
    required String label,
    required String value,
    bool isStdDev = false,
    bool compact = false,
    Widget? statusBadge,
    String? subtitle,
    bool isOvertime = false,
  }) {
    final Color headerBgColor = isOvertime ? const Color(0xFFDC2626) : const Color(0xFF00DF89);
    final Color headerTextColor = isOvertime ? Colors.white : const Color(0xFF064E3B);
    final Color boxBgColor = isOvertime ? const Color(0xFF2A0A0A) : const Color(0xFF0B2146);
    final Color borderColor = isOvertime ? const Color(0xFFEF4444) : const Color(0xFF00DF89).withValues(alpha: 0.7);
    final Color valueColor = isOvertime ? const Color(0xFFFCA5A5) : Colors.white;

    final valueContent = FittedBox(
      fit: BoxFit.scaleDown,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (statusBadge != null) ...[
            statusBadge,
            const SizedBox(height: 3),
          ],
          Text(
            value,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: isStdDev ? (compact ? 20 : 30) : (compact ? 22 : 34),
              fontWeight: FontWeight.w900,
              fontFamily: 'monospace',
              letterSpacing: isStdDev ? 0.8 : 1.2,
              color: valueColor,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w600,
                color: isOvertime ? const Color(0xFFFCA5A5).withValues(alpha: 0.8) : const Color(0xFF94A3B8),
              ),
            ),
          ],
        ],
      ),
    );

    return Container(
      decoration: BoxDecoration(
        color: boxBgColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: borderColor,
          width: isOvertime ? 1.8 : 1.2,
        ),
        boxShadow: isOvertime
            ? [
                BoxShadow(
                  color: const Color(0xFFEF4444).withValues(alpha: 0.35),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header Bar (Red on overtime, Cyan-Green default)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 3.5, horizontal: 6),
            decoration: BoxDecoration(
              color: headerBgColor,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(6.8),
                topRight: Radius.circular(6.8),
              ),
            ),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.6,
                  color: headerTextColor,
                ),
              ),
            ),
          ),

          // Numeric Value Display
          if (compact)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 6,
                  vertical: 6,
                ),
                child: valueContent,
              ),
            )
          else
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 3,
                  ),
                  child: valueContent,
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// Large Total Score Card with cream header and massive score number (NO ICON, NO KETERANGAN)
  Widget _buildTotalScoreCard({bool compact = false}) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0A2B5C), // Rich deep blue from photo
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: const Color(0xFF38BDF8),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1D4ED8).withValues(alpha: 0.35),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Cream / Soft Gold Header Bar (NO ICON)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
            decoration: const BoxDecoration(
              color: Color(0xFFFEF08A), // Cream/yellow bar from photo
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(8.5),
                topRight: Radius.circular(8.5),
              ),
            ),
            child: const FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                'TOTAL SCORE',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.2,
                  color: Color(0xFF0F172A),
                ),
              ),
            ),
          ),

          // Massive Score Digits (NO extra formula text)
          Expanded(
            child: Center(
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: compact ? 6 : 10,
                  vertical: compact ? 2 : 4,
                ),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    _officialScore.toStringAsFixed(3),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: compact ? 56 : 88,
                      fontWeight: FontWeight.w900,
                      fontFamily: 'monospace',
                      color: Colors.white,
                      letterSpacing: 2.0,
                      shadows: const [
                        Shadow(
                          color: Color(0xFF38BDF8),
                          blurRadius: 18,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Split Athlete Bar (Left: Kontingen [Blue], Right: Nama Atlet [Navy]) - NO ICONS
  Widget _buildAthleteSplitBar({bool compact = false}) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF1E3A8A)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Row(
        children: [
          // Left: Kontingen (PAPUA BARAT in photo) - NO ICON
          Expanded(
            flex: 5,
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: compact ? 8 : 14,
                vertical: compact ? 5 : 8,
              ),
              color: const Color(0xFF1D4ED8), // Royal Blue
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  _athlete.kontingen.toUpperCase(),
                  style: TextStyle(
                    fontSize: compact ? 12 : 14,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.0,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),

          // Right: Athlete Name (SAITAMA in photo) - NO ICON
          Expanded(
            flex: 6,
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: compact ? 8 : 14,
                vertical: compact ? 5 : 8,
              ),
              color: const Color(0xFF0B192C), // Dark Navy
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerRight,
                child: Text(
                  _athlete.name.toUpperCase(),
                  style: TextStyle(
                    fontSize: compact ? 12 : 14,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.0,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Row of Individual Judge Score Cards DI ATAS
  /// Indikator warna untuk status Ready / Belum Ready TANPA keterangan teks
  Widget _buildJuriCardsRow({bool isScrollable = false}) {
    final sync = GelanggangSyncService.instance;

    final cards = _juriStatus.map((j) {
      final int num = j['juri'] as int;
      final double score = j['score'] as double;
      final bool isSubmitted = j['submitted'] == true;
      final bool isReady = sync.isJuriReady(num, arenaCode: _arenaCode);

      // Indikator status posisi Juri dengan WARNA tanpa keterangan teks:
      // Hijau jika Ready / Submitted, Merah jika Belum Ready
      final bool isPositive = isSubmitted || isReady;
      final Color headerColor = isPositive ? const Color(0xFF059669) : const Color(0xFFDC2626);
      final Color bodyColor = isPositive ? const Color(0xFF064E3B) : const Color(0xFF450A0A);
      final Color borderColor = isPositive ? const Color(0xFF10B981) : const Color(0xFFEF4444);

      final cardWidget = Container(
        margin: const EdgeInsets.symmetric(horizontal: 3),
        decoration: BoxDecoration(
          color: bodyColor,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: borderColor.withValues(alpha: 0.9),
            width: 1.2,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Juri Header Pill with Color Indicator (NO TEXT KETERANGAN)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 3, horizontal: 4),
              color: headerColor,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Dot indikator warna status juri
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isPositive ? const Color(0xFF6EE7B7) : const Color(0xFFFCA5A5),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'JURI $num',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Juri Score Display (NO TEXT KETERANGAN)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 5),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  score.toStringAsFixed(2),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                    fontFamily: 'monospace',
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      );

      if (isScrollable) {
        return SizedBox(width: 85, child: cardWidget);
      } else {
        return Expanded(child: cardWidget);
      }
    }).toList();

    if (isScrollable) {
      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        child: Row(children: cards),
      );
    } else {
      return Row(children: cards);
    }
  }

  /// Top Bar with tournament name, match details, back & fullscreen controls
  Widget _buildTopBar() {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: 8,
        vertical: _isFullScreen ? 3 : 5,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFF0B192C),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF1E3A8A)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isVeryNarrow = constraints.maxWidth < 480;
          final isCompact = constraints.maxWidth < 680;

          return Row(
            children: [
              // Back Button
              IconButton(
                onPressed: widget.onBackToPortal,
                tooltip: 'Kembali ke Portal',
                icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 13),
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                padding: EdgeInsets.zero,
                style: IconButton.styleFrom(
                  backgroundColor: const Color(0xFF0F172A),
                  foregroundColor: const Color(0xFFCBD5E1),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
              const SizedBox(width: 4),

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
                        Icons.tv_rounded,
                        color: Color(0xFF60A5FA),
                        size: 15,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 4),
              ],

              // Center: Tournament Title & Match Partai info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        'KEJUARAAN NASIONAL PENCAK SILAT AMPANA OPEN 2026',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.0,
                          color: Color(0xFFFACC15), // Gold/Yellow from photo
                        ),
                      ),
                    ),
                    const SizedBox(height: 1),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        '${_athlete.partai} - ${_category.title.toUpperCase()} • ${_athlete.pool.toUpperCase()}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.6,
                          color: Color(0xFFCBD5E1),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 4),

              // Time Keeper Synced Timer Badge in Top Bar
              Container(
                constraints: BoxConstraints(maxWidth: isVeryNarrow ? 95 : 140),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2.5),
                    decoration: BoxDecoration(
                      color: _getTimerStatusColor().withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: _getTimerStatusColor().withValues(alpha: 0.6),
                        width: _timerStatus == 'running' ? 1.4 : 1.0,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _getTimerStatusIcon(),
                          size: 11,
                          color: _getTimerStatusColor(),
                        ),
                        const SizedBox(width: 3),
                        Text(
                          '${_formatCountdown()} • ${_getTimerStatusLabel()}',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'monospace',
                            color: _getTimerStatusColor(),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 4),

              // Live Status Badge
              if (!isCompact) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F172A),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.5)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.circle, size: 6, color: Color(0xFF10B981)),
                      SizedBox(width: 4),
                      Text(
                        'LIVE',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'monospace',
                          color: Color(0xFF34D399),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 4),
              ],

              // Arena Code Badge
              if (!isVeryNarrow) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1D4ED8).withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFF3B82F6).withValues(alpha: 0.4)),
                  ),
                  child: Text(
                    _arenaCode,
                    style: const TextStyle(
                      fontSize: 9,
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF60A5FA),
                    ),
                  ),
                ),
                const SizedBox(width: 4),
              ],

              // Full Screen Toggle Button
              IconButton(
                onPressed: _toggleFullScreen,
                tooltip: _isFullScreen ? 'Keluar Layar Penuh' : 'Layar Penuh Display',
                icon: Icon(
                  _isFullScreen ? Icons.fullscreen_exit_rounded : Icons.fullscreen_rounded,
                  size: 16,
                ),
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                padding: EdgeInsets.zero,
                style: IconButton.styleFrom(
                  backgroundColor: const Color(0xFF0F172A),
                  foregroundColor: const Color(0xFFCBD5E1),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
