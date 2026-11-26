import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/scoring_models.dart';
import '../../services/gelanggang_sync_service.dart';
import '../../theme/app_theme.dart';

enum TimeCategoryMode {
  standar('Standar (03:00)', 180),
  tanganKosong('Tangan Kosong (01:20)', 80),
  senjata('Senjata (01:40)', 100);

  final String title;
  final int durationSeconds;

  const TimeCategoryMode(this.title, this.durationSeconds);
}

enum TimerStatus { standby, running, paused, stopped }

class TimekeeperPanelView extends StatefulWidget {
  final VoidCallback onBackToPortal;
  final String? arenaCode;

  const TimekeeperPanelView({
    super.key,
    required this.onBackToPortal,
    this.arenaCode,
  });

  @override
  State<TimekeeperPanelView> createState() => _TimekeeperPanelViewState();
}

class _TimekeeperPanelViewState extends State<TimekeeperPanelView> {
  late String _arenaCode;
  TimeCategoryMode _selectedMode = TimeCategoryMode.standar;
  late int _remainingSeconds;
  TimerStatus _status = TimerStatus.standby;
  bool _isFullScreen = false;

  late AthleteModel _athlete;
  late SeniCategory _category;

  void _toggleFullScreen() {
    setState(() => _isFullScreen = !_isFullScreen);
    if (_isFullScreen) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    } else {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }
  }

  @override
  void initState() {
    super.initState();
    final sync = GelanggangSyncService.instance;
    _arenaCode = widget.arenaCode ?? sync.activeArenaCode;
    final state = sync.getArenaState(_arenaCode);
    _athlete = state.athlete;
    _category = state.category;
    _syncStateFromService();
    sync.addListener(_handleGelanggangSync);
    sync.startRealtimeSync(arenaCode: _arenaCode);
  }

  @override
  void dispose() {
    GelanggangSyncService.instance.removeListener(_handleGelanggangSync);
    GelanggangSyncService.instance.stopRealtimeSync(arenaCode: _arenaCode);
    super.dispose();
  }

  void _syncStateFromService() {
    final sync = GelanggangSyncService.instance;
    final state = sync.getArenaState(_arenaCode);
    _remainingSeconds = state.timerRemainingSeconds;
    _status = TimerStatus.values.firstWhere(
      (s) => s.name == state.timerStatus,
      orElse: () => TimerStatus.standby,
    );
    for (final mode in TimeCategoryMode.values) {
      if (mode.title == state.timerModeTitle ||
          mode.durationSeconds == state.targetDurationSeconds) {
        _selectedMode = mode;
        break;
      }
    }
  }

  void _handleGelanggangSync() {
    final sync = GelanggangSyncService.instance;
    if (sync.lastSyncArenaCode != null &&
        sync.lastSyncArenaCode != GelanggangSyncService.normalizeArenaCode(_arenaCode)) {
      return;
    }
    final state = sync.getArenaState(_arenaCode);
    if (mounted) {
      setState(() {
        _athlete = state.athlete;
        _category = state.category;
        _syncStateFromService();
      });
      if (sync.lastSyncAction == 'ATHLETE_SELECTED') {
        ScaffoldMessenger.of(context).removeCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Sinkronisasi Dewan: ${_athlete.name} (${_athlete.partai} - ${_category.title})',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
            ),
            backgroundColor: AppColors.emerald,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  void _switchMode(TimeCategoryMode mode) {
    if (_status == TimerStatus.running) return;
    GelanggangSyncService.instance.timekeeperSwitchMode(
      durationSeconds: mode.durationSeconds,
      modeTitle: mode.title,
      arenaCode: _arenaCode,
    );
  }

  void _startTimer() =>
      GelanggangSyncService.instance.timekeeperStartTimer(arenaCode: _arenaCode);
  void _pauseTimer() =>
      GelanggangSyncService.instance.timekeeperPauseTimer(arenaCode: _arenaCode);
  void _stopTimer() =>
      GelanggangSyncService.instance.timekeeperStopTimer(arenaCode: _arenaCode);
  void _resetTimer() =>
      GelanggangSyncService.instance.timekeeperResetTimer(arenaCode: _arenaCode);

  String _formatTime(int seconds) {
    final bool isNegative = seconds < 0;
    final int absSec = seconds.abs();
    final int m = absSec ~/ 60;
    final int s = absSec % 60;
    final formatted = '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    return isNegative ? '-$formatted' : formatted;
  }

  @override
  Widget build(BuildContext context) {
    final int elapsed = math.max(0, _selectedMode.durationSeconds - _remainingSeconds);
    final double progress = (_remainingSeconds / _selectedMode.durationSeconds).clamp(0.0, 1.0);

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
                      final isWide = constraints.maxWidth >= 900 ||
                          (constraints.maxWidth >= 700 &&
                              constraints.maxWidth > constraints.maxHeight);

                      if (isWide) {
                        return Row(
                          children: [
                            Expanded(flex: 4, child: _buildPresetsAndAthleteCard()),
                            const SizedBox(width: 12),
                            Expanded(
                              flex: 6,
                              child: _buildCountdownAndActionsCard(elapsed, progress),
                            ),
                          ],
                        );
                      }

                      return SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Column(
                          children: [
                            _buildCountdownAndActionsCard(elapsed, progress, isCompact: true),
                            const SizedBox(height: 12),
                            _buildPresetsAndAthleteCard(isCompact: true),
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

  Widget _buildPresetsAndAthleteCard({bool isCompact = false}) {
    Widget buildContent({bool useSpacer = false}) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: useSpacer ? MainAxisSize.max : MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(Icons.tune_rounded, color: AppColors.teal, size: 17),
              SizedBox(width: 6),
              Flexible(
                child: Text(
                  'Kategori Durasi Waktu',
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
          const SizedBox(height: 10),

          ...TimeCategoryMode.values.map((mode) {
            final isSelected = _selectedMode == mode;
            return Padding(
              padding: const EdgeInsets.only(bottom: 7),
              child: InkWell(
                onTap: () => _switchMode(mode),
                borderRadius: BorderRadius.circular(12),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 9,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppColors.tealSoft
                        : AppColors.surfaceSoft,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected ? AppColors.teal : AppColors.border,
                      width: isSelected ? 1.5 : 1.0,
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          mode.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: isSelected
                                ? FontWeight.w800
                                : FontWeight.w600,
                            color: isSelected
                                ? AppColors.tealText
                                : AppColors.textSecondary,
                          ),
                        ),
                      ),
                      if (isSelected) ...[
                        const SizedBox(width: 4),
                        const Icon(
                          Icons.check_circle_rounded,
                          color: AppColors.teal,
                          size: 16,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            );
          }),

          if (useSpacer) const Spacer(),
          const SizedBox(height: 8),

          Container(
            padding: const EdgeInsets.all(11),
            decoration: AppDecorations.softTile(radius: 14),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              'PESILAT TAMPIL SAAT INI',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                                color: AppColors.textMuted,
                                letterSpacing: 0.6,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
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
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        _athlete.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Text(
                        '${_athlete.kontingen} • ${_category.title}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                          color: AppColors.sky,
                        ),
                      ),
                    ],
                  ),
                ),
                Tooltip(
                  message: 'Partai dikontrol oleh Dewan Pertandingan',
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: AppColors.emeraldSoft,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.emeraldBorder),
                    ),
                    child: const Icon(
                      Icons.lock_outline_rounded,
                      color: AppColors.emerald,
                      size: 14,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: AppDecorations.card(radius: 22),
      child: isCompact
          ? buildContent(useSpacer: false)
          : LayoutBuilder(
              builder: (context, cardConstraints) {
                if (cardConstraints.maxHeight >= 310) {
                  return buildContent(useSpacer: true);
                }
                return SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: buildContent(useSpacer: false),
                );
              },
            ),
    );
  }

  Widget _buildCountdownAndActionsCard(
    int elapsed,
    double progress, {
    bool isCompact = false,
  }) {
    final bool isOvertime = _remainingSeconds < 0;
    final Color statusColor = _getStatusColor();

    Widget buildContent({required bool isShort}) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: statusColor.withValues(alpha: 0.4)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.circle, size: 7, color: statusColor),
                const SizedBox(width: 6),
                Text(
                  _getStatusLabel().toUpperCase(),
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                    color: statusColor,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: isShort ? 4 : 10),

          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              _formatTime(_remainingSeconds),
              style: TextStyle(
                fontSize: isShort ? 46 : (isCompact ? 56 : 68),
                fontWeight: FontWeight.w900,
                fontFamily: 'monospace',
                color:
                    isOvertime ||
                        (_remainingSeconds <= 10 &&
                            _status == TimerStatus.running)
                    ? AppColors.primary
                    : AppColors.textPrimary,
              ),
            ),
          ),
          if (isOvertime) ...[
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.primary),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.warning_amber_rounded,
                    size: 13,
                    color: AppColors.primary,
                  ),
                  SizedBox(width: 4),
                  Text(
                    'WAKTU MELEBIHI TARGET (LEWAT)',
                    style: TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primary,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
          ],
          SizedBox(height: isShort ? 5 : 8),

          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: AppColors.surfaceMuted,
              valueColor: AlwaysStoppedAnimation<Color>(
                isOvertime || _remainingSeconds <= 10
                    ? AppColors.primary
                    : AppColors.teal,
              ),
            ),
          ),
          SizedBox(height: isShort ? 5 : 8),

          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              'Waktu Berjalan: ${_formatTime(elapsed)} / Target: ${_formatTime(_selectedMode.durationSeconds)}',
              style: TextStyle(
                fontSize: 11.5,
                color: AppColors.textSecondary,
                fontFamily: 'monospace',
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          SizedBox(height: isShort ? 10 : 16),

          Wrap(
            alignment: WrapAlignment.center,
            spacing: 10,
            runSpacing: 8,
            children: [
              ElevatedButton.icon(
                onPressed: _status == TimerStatus.running
                    ? _pauseTimer
                    : _startTimer,
                icon: Icon(
                  _status == TimerStatus.running
                      ? Icons.pause_rounded
                      : Icons.play_arrow_rounded,
                  size: 19,
                ),
                label: Text(
                  _status == TimerStatus.running ? 'Jeda' : 'Mulai Timer',
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _status == TimerStatus.running
                      ? AppColors.amber
                      : AppColors.emerald,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(
                    horizontal: isShort ? 14 : 18,
                    vertical: isShort ? 8 : 10,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
              ),
              OutlinedButton.icon(
                onPressed: _status == TimerStatus.standby ? null : _stopTimer,
                icon: const Icon(Icons.stop_rounded, size: 17),
                label: const Text(
                  'Stop',
                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  backgroundColor: AppColors.primarySoft,
                  side: BorderSide(color: AppColors.primaryBorder),
                  padding: EdgeInsets.symmetric(
                    horizontal: isShort ? 12 : 14,
                    vertical: isShort ? 8 : 10,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              OutlinedButton.icon(
                onPressed: _status == TimerStatus.running ? null : _resetTimer,
                icon: const Icon(Icons.refresh_rounded, size: 17),
                label: const Text(
                  'Reset',
                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.textSecondary,
                  backgroundColor: AppColors.surfaceSoft,
                  side: BorderSide(color: AppColors.borderStrong),
                  padding: EdgeInsets.symmetric(
                    horizontal: isShort ? 12 : 14,
                    vertical: isShort ? 8 : 10,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
        ],
      );
    }

    return Container(
      padding: EdgeInsets.all(isCompact ? 14 : 16),
      decoration: AppDecorations.card(
        radius: 22,
        color: isOvertime ? AppColors.primarySoft : AppColors.surface,
        borderColor: isOvertime ? AppColors.primary : AppColors.border,
        borderWidth: isOvertime ? 2.0 : 1.0,
      ),
      child: isCompact
          ? buildContent(isShort: false)
          : LayoutBuilder(
              builder: (context, cardConstraints) {
                final isShort = cardConstraints.maxHeight < 270;
                return SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: cardConstraints.maxHeight,
                    ),
                    child: Center(child: buildContent(isShort: isShort)),
                  ),
                );
              },
            ),
    );
  }

  Widget _buildHeader() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isVeryNarrow = constraints.maxWidth < 420;

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
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
                ),
              ),
              const SizedBox(width: 8),

              if (!isVeryNarrow) ...[
                Container(
                  width: 28,
                  height: 28,
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: AppColors.tealSoft,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.tealBorder),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: Image.asset(
                      'assets/images/app_logo_small.png',
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) => const Icon(
                        Icons.timer_rounded,
                        color: AppColors.teal,
                        size: 15,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
              ],

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            'Time Keeper',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
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
                        if (!isVeryNarrow) ...[
                          const SizedBox(width: 5),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                            decoration: BoxDecoration(
                              color: AppColors.emeraldSoft,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: AppColors.emeraldBorder),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.lock_outline_rounded,
                                  size: 8.5,
                                  color: AppColors.emerald,
                                ),
                                SizedBox(width: 2),
                                Text(
                                  'Dewan Sync',
                                  style: TextStyle(
                                    fontSize: 8,
                                    color: AppColors.emeraldText,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 1),
                    Builder(
                      builder: (context) {
                        final evTitle = GelanggangSyncService.instance
                            .getArenaState(_arenaCode)
                            .lockedEventTitle;
                        final evPrefix = evTitle != null && evTitle.isNotEmpty
                            ? '$evTitle • '
                            : '';
                        return Text(
                          '$evPrefix${_athlete.name} (${_athlete.kontingen}) • ${_category.title}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 10,
                            color: AppColors.textSecondary,
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
              if (!isVeryNarrow) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.skySoft,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.skyBorder),
                  ),
                  child: Text(
                    '${GelanggangSyncService.instance.getActiveJuriCount(arenaCode: _arenaCode)} Juri',
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                      color: AppColors.skyText,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.tealSoft,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.tealBorder),
                  ),
                  child: Text(
                    _formatTime(_selectedMode.durationSeconds),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      fontFamily: 'monospace',
                      color: AppColors.tealText,
                    ),
                  ),
                ),
              ],
              const SizedBox(width: 6),
              const ThemeToggleButton(
                buttonSize: 30,
                iconSize: 15,
                borderRadius: 9,
              ),
              const SizedBox(width: 5),

              IconButton(
                onPressed: _toggleFullScreen,
                tooltip: _isFullScreen ? 'Keluar Layar Penuh' : 'Layar Penuh Time Keeper',
                icon: Icon(
                  _isFullScreen ? Icons.fullscreen_exit_rounded : Icons.fullscreen_rounded,
                  size: 16,
                  color: AppColors.textPrimary,
                ),
                constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
                padding: EdgeInsets.zero,
                style: IconButton.styleFrom(
                  backgroundColor: AppColors.surfaceMuted,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
                  side: BorderSide(
                    color: _isFullScreen ? AppColors.teal : AppColors.border,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Color _getStatusColor() {
    if (_remainingSeconds < 0) return AppColors.primary;
    switch (_status) {
      case TimerStatus.standby:
        return AppColors.textMuted;
      case TimerStatus.running:
        return AppColors.emerald;
      case TimerStatus.paused:
        return AppColors.amber;
      case TimerStatus.stopped:
        return AppColors.primary;
    }
  }

  String _getStatusLabel() {
    if (_remainingSeconds < 0) {
      if (_status == TimerStatus.paused) return 'Lewat Waktu (Jeda)';
      if (_status == TimerStatus.stopped) return 'Lewat Waktu (Stop)';
      return 'Lewat Waktu';
    }
    switch (_status) {
      case TimerStatus.standby:
        return 'Siap (Standby)';
      case TimerStatus.running:
        return 'Berjalan (Live)';
      case TimerStatus.paused:
        return 'Jeda (Paused)';
      case TimerStatus.stopped:
        return 'Waktu Berhenti';
    }
  }
}
