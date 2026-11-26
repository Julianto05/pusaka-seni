import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/link.dart';
import '../../models/scoring_models.dart';
import '../../services/app_link_helper.dart';
import '../../services/gelanggang_sync_service.dart';
import '../../theme/app_theme.dart';

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

  String _eventTitle = 'PAPAN SKOR PUSAKA SENI IPSI';
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
    sync.startRealtimeSync(arenaCode: _arenaCode);
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
      setState(() => _syncFromGelanggangService());
    }
  }

  void _syncFromGelanggangService() {
    final sync = GelanggangSyncService.instance;
    final state = sync.getArenaState(_arenaCode);
    final lockedTitle = state.lockedEventTitle?.trim();
    _eventTitle = (lockedTitle != null && lockedTitle.isNotEmpty)
        ? lockedTitle.toUpperCase()
        : 'PAPAN SKOR PUSAKA SENI IPSI';
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

  String _formatCountdown() {
    final bool isNegative = _timeRemaining < 0;
    final int absSec = _timeRemaining.abs();
    final int m = absSec ~/ 60;
    final int s = absSec % 60;
    final formatted = '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    return isNegative ? '-$formatted' : formatted;
  }

  String _formatTimePerformance() {
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
        padding: EdgeInsets.symmetric(horizontal: compact ? 5 : 8, vertical: 2),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: 0.45)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(_getTimerStatusIcon(), size: compact ? 9 : 11, color: color),
            const SizedBox(width: 3),
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
              vertical: _isFullScreen ? 6 : 8,
            ),
            child: Column(
              children: [
                _buildTopBar(),
                SizedBox(height: _isFullScreen ? 5 : 8),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final isLandscape =
                          constraints.maxWidth >= 600 && constraints.maxHeight >= 280;
                      if (isLandscape) {
                        return _buildWideScoreboard(constraints);
                      }
                      return _buildCompactScoreboard();
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

  Widget _buildWideScoreboard(BoxConstraints constraints) {
    final bool isCompactHeight = constraints.maxHeight < 360;
    final double gap = isCompactHeight ? 6 : 10;

    return Column(
      children: [
        _buildAthleteSplitBar(compact: isCompactHeight),
        SizedBox(height: gap),
        _buildJuriCardsRow(isScrollable: false),
        SizedBox(height: gap),
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                flex: 9,
                child: _buildTotalScoreCard(compact: isCompactHeight),
              ),
              SizedBox(width: gap),
              Expanded(
                flex: 11,
                child: Column(
                  children: [
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
                          SizedBox(width: gap),
                          Expanded(
                            child: _buildMetricBox(
                              label: 'PENALTY',
                              value: _dewanPenalties.toStringAsFixed(2),
                            ),
                          ),
                          SizedBox(width: gap),
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
                    SizedBox(height: gap),
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

  Widget _buildCompactScoreboard() {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        children: [
          _buildAthleteSplitBar(compact: true),
          const SizedBox(height: 8),
          _buildJuriCardsRow(isScrollable: true),
          const SizedBox(height: 8),
          SizedBox(height: 122, child: _buildTotalScoreCard(compact: true)),
          const SizedBox(height: 8),
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
          const SizedBox(height: 8),
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

  Widget _buildMetricBox({
    required String label,
    required String value,
    bool isStdDev = false,
    bool compact = false,
    Widget? statusBadge,
    String? subtitle,
    bool isOvertime = false,
  }) {
    final Color headerBgColor = isOvertime ? AppColors.primary : AppColors.emeraldSoft;
    final Color headerTextColor = isOvertime ? Colors.white : AppColors.emeraldText;
    final Color boxBgColor = isOvertime ? AppColors.primarySoft : AppColors.surface;
    final Color borderColor = isOvertime ? AppColors.primary : AppColors.emeraldBorder;
    final Color valueColor = isOvertime ? AppColors.primaryText : AppColors.textPrimary;

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
                color: isOvertime ? AppColors.primary : AppColors.textMuted,
              ),
            ),
          ],
        ],
      ),
    );

    return Container(
      decoration: AppDecorations.card(
        radius: 16,
        color: boxBgColor,
        borderColor: borderColor,
        borderWidth: isOvertime ? 1.8 : 1.2,
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 6),
            color: headerBgColor,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.6,
                  color: headerTextColor,
                ),
              ),
            ),
          ),
          if (compact)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                child: valueContent,
              ),
            )
          else
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                  child: valueContent,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTotalScoreCard({bool compact = false}) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF2563EB), Color(0xFF1D4ED8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
            color: Color(0x282563EB),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 10),
            color: const Color(0xFFFEF08A),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                'TOTAL SCORE',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.2,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          ),
          Expanded(
            child: Center(
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: compact ? 6 : 12,
                  vertical: compact ? 2 : 6,
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

  Widget _buildAthleteSplitBar({bool compact = false}) {
    return Container(
      decoration: AppDecorations.card(radius: 16, borderColor: AppColors.blueBorder),
      clipBehavior: Clip.antiAlias,
      child: Row(
        children: [
          Expanded(
            flex: 5,
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: compact ? 10 : 16,
                vertical: compact ? 6 : 9,
              ),
              color: AppColors.blue,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  _athlete.kontingen.toUpperCase(),
                  style: TextStyle(
                    fontSize: compact ? 12 : 14,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.9,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            flex: 6,
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: compact ? 10 : 16,
                vertical: compact ? 6 : 9,
              ),
              color: AppColors.surface,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerRight,
                child: Text(
                  _athlete.name.toUpperCase(),
                  style: TextStyle(
                    fontSize: compact ? 12 : 14,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.9,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildJuriCardsRow({bool isScrollable = false}) {
    final sync = GelanggangSyncService.instance;

    final cards = _juriStatus.map((j) {
      final int num = j['juri'] as int;
      final double score = j['score'] as double;
      final bool isSubmitted = j['submitted'] == true;
      final bool isReady = sync.isJuriReady(num, arenaCode: _arenaCode);

      final bool isPositive = isSubmitted || isReady;
      final Color headerColor = isPositive ? AppColors.emerald : AppColors.primary;
      final Color bodyColor = isPositive ? AppColors.emeraldSoft : AppColors.primarySoft;
      final Color borderColor = isPositive ? AppColors.emeraldBorder : AppColors.primaryBorder;
      final Color scoreColor = isPositive ? AppColors.emeraldText : AppColors.primaryText;

      final cardWidget = Container(
        margin: const EdgeInsets.symmetric(horizontal: 3),
        decoration: BoxDecoration(
          color: bodyColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderColor, width: 1.3),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 3.5, horizontal: 4),
              color: headerColor,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white,
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
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 6),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  score.toStringAsFixed(2),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                    fontFamily: 'monospace',
                    color: scoreColor,
                  ),
                ),
              ),
            ),
          ],
        ),
      );

      if (isScrollable) {
        return SizedBox(width: 88, child: cardWidget);
      }
      return Expanded(child: cardWidget);
    }).toList();

    if (isScrollable) {
      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        child: Row(children: cards),
      );
    }
    return Row(children: cards);
  }

  Widget _buildTopBar() {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: 10,
        vertical: _isFullScreen ? 4 : 6,
      ),
      decoration: AppDecorations.card(radius: 16),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isVeryNarrow = constraints.maxWidth < 480;
          final isCompact = constraints.maxWidth < 680;
          final timerColor = _getTimerStatusColor();

          return Row(
            children: [
              IconButton(
                onPressed: widget.onBackToPortal,
                tooltip: 'Kembali ke Portal',
                icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 13),
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                padding: EdgeInsets.zero,
                style: IconButton.styleFrom(
                  backgroundColor: AppColors.surfaceMuted,
                  foregroundColor: AppColors.textPrimary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
              const SizedBox(width: 6),

              if (!isVeryNarrow) ...[
                Container(
                  width: 28,
                  height: 28,
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: AppColors.blueSoft,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.blueBorder),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: Image.asset(
                      'assets/images/app_logo_small.png',
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) => const Icon(
                        Icons.tv_rounded,
                        color: AppColors.blue,
                        size: 15,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
              ],

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        _eventTitle,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.8,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 1),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        '${_athlete.partai} - ${_category.title.toUpperCase()} • ${_athlete.pool.toUpperCase()}',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),

              Container(
                constraints: BoxConstraints(maxWidth: isVeryNarrow ? 95 : 145),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: timerColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: timerColor.withValues(alpha: 0.5),
                        width: _timerStatus == 'running' ? 1.4 : 1.0,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(_getTimerStatusIcon(), size: 11, color: timerColor),
                        const SizedBox(width: 3),
                        Text(
                          '${_formatCountdown()} • ${_getTimerStatusLabel()}',
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
                ),
              ),
              const SizedBox(width: 5),

              if (!isCompact) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3.5),
                  decoration: BoxDecoration(
                    color: AppColors.emeraldSoft,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.emeraldBorder),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.circle, size: 6, color: AppColors.emerald),
                      SizedBox(width: 4),
                      Text(
                        'LIVE',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'monospace',
                          color: AppColors.emeraldText,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 5),
              ],

              if (!isVeryNarrow) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3.5),
                  decoration: BoxDecoration(
                    color: AppColors.blueSoft,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.blueBorder),
                  ),
                  child: Text(
                    _arenaCode,
                    style: TextStyle(
                      fontSize: 9,
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.bold,
                      color: AppColors.blueText,
                    ),
                  ),
                ),
                const SizedBox(width: 5),
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
                        tooltip: 'Buka Scoreboard di Tab Baru',
                        icon: const Icon(
                          Icons.open_in_new_rounded,
                          size: 14,
                          color: AppColors.blue,
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 28,
                          minHeight: 28,
                        ),
                        padding: EdgeInsets.zero,
                        style: IconButton.styleFrom(
                          backgroundColor: AppColors.blueSoft,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          visualDensity: VisualDensity.compact,
                          side: BorderSide(color: AppColors.blueBorder),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(width: 5),
              ],

              const ThemeToggleButton(
                buttonSize: 28,
                iconSize: 15,
                borderRadius: 8,
              ),
              const SizedBox(width: 5),

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
                  backgroundColor: AppColors.surfaceMuted,
                  foregroundColor: AppColors.textPrimary,
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
