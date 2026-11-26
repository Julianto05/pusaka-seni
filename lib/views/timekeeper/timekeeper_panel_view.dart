import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/scoring_models.dart';
import '../../services/gelanggang_sync_service.dart';

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

  void _toggleFullScreen() {
    setState(() => _isFullScreen = !_isFullScreen);
    if (_isFullScreen) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    } else {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }
  }

  // Active athlete context synced with Dewan via GelanggangSyncService
  late AthleteModel _athlete;
  late SeniCategory _category;

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
            backgroundColor: const Color(0xFF10B981),
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

  void _startTimer() {
    GelanggangSyncService.instance.timekeeperStartTimer(arenaCode: _arenaCode);
  }

  void _pauseTimer() {
    GelanggangSyncService.instance.timekeeperPauseTimer(arenaCode: _arenaCode);
  }

  void _stopTimer() {
    GelanggangSyncService.instance.timekeeperStopTimer(arenaCode: _arenaCode);
  }

  void _resetTimer() {
    GelanggangSyncService.instance.timekeeperResetTimer(arenaCode: _arenaCode);
  }

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

              // Responsive Timer Dashboard
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final isWide = constraints.maxWidth >= 900 ||
                        (constraints.maxWidth >= 700 && constraints.maxWidth > constraints.maxHeight);

                    if (isWide) {
                      return Row(
                        children: [
                          // Left Column: Controls & Preset
                          Expanded(
                            flex: 4,
                            child: _buildPresetsAndAthleteCard(),
                          ),
                          const SizedBox(width: 10),

                          // Right Column: Countdown Big Display & Controls
                          Expanded(
                            flex: 6,
                            child: _buildCountdownAndActionsCard(elapsed, progress),
                          ),
                        ],
                      );
                    } else {
                      // Compact Screen (Mobile & Tablet Portrait): Vertical scrollable
                      return SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
                        child: Column(
                          children: [
                            _buildCountdownAndActionsCard(elapsed, progress, isCompact: true),
                            const SizedBox(height: 10),
                            _buildPresetsAndAthleteCard(isCompact: true),
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

  Widget _buildPresetsAndAthleteCard({bool isCompact = false}) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF334155)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: isCompact ? MainAxisSize.min : MainAxisSize.max,
        children: [
          const Row(
            children: [
              Icon(Icons.tune_rounded, color: Color(0xFF14B8A6), size: 16),
              SizedBox(width: 6),
              Flexible(
                child: Text(
                  'Kategori Durasi Waktu',
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
          const SizedBox(height: 8),

          // Presets
          ...TimeCategoryMode.values.map((mode) {
            final isSelected = _selectedMode == mode;
            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: InkWell(
                onTap: () => _switchMode(mode),
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? const Color(0xFF0F766E).withValues(alpha: 0.3)
                        : const Color(0xFF0F172A),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isSelected
                          ? const Color(0xFF14B8A6)
                          : const Color(0xFF334155),
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
                            fontSize: 11.5,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                            color: isSelected
                                ? const Color(0xFF99F6E4)
                                : const Color(0xFF94A3B8),
                          ),
                        ),
                      ),
                      if (isSelected) ...[
                        const SizedBox(width: 4),
                        const Icon(
                          Icons.check_circle_rounded,
                          color: Color(0xFF14B8A6),
                          size: 14,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            );
          }),

          if (!isCompact) const Spacer(),
          const SizedBox(height: 8),

          // Active Athlete Info Card (Synchronized from Dewan Pertandingan)
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF0F172A),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF334155)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Flexible(
                            child: Text(
                              'PESILAT TAMPIL SAAT INI',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF64748B),
                                letterSpacing: 0.6,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                            decoration: BoxDecoration(
                              color: const Color(0xFFDC2626),
                              borderRadius: BorderRadius.circular(3),
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
                      const SizedBox(height: 2),
                      Text(
                        _athlete.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        '${_athlete.kontingen} • ${_category.title}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 10.5,
                          color: Color(0xFF38BDF8),
                        ),
                      ),
                    ],
                  ),
                ),
                Tooltip(
                  message: 'Partai dikontrol oleh Dewan Pertandingan',
                  child: Container(
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E293B),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.4)),
                    ),
                    child: const Icon(Icons.lock_outline_rounded, color: Color(0xFF10B981), size: 14),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCountdownAndActionsCard(int elapsed, double progress, {bool isCompact = false}) {
    final bool isOvertime = _remainingSeconds < 0;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isOvertime ? const Color(0xFFEF4444) : const Color(0xFF334155),
          width: isOvertime ? 2.0 : 1.0,
        ),
        boxShadow: isOvertime
            ? [
                BoxShadow(
                  color: const Color(0xFFEF4444).withValues(alpha: 0.25),
                  blurRadius: 14,
                  offset: const Offset(0, 3),
                ),
              ]
            : null,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: isCompact ? MainAxisSize.min : MainAxisSize.max,
        children: [
          // Status Pill
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
            decoration: BoxDecoration(
              color: _getStatusColor().withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: _getStatusColor().withValues(alpha: 0.5),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.circle, size: 7, color: _getStatusColor()),
                const SizedBox(width: 5),
                Text(
                  _getStatusLabel().toUpperCase(),
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.8,
                    color: _getStatusColor(),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // Giant Remaining Countdown (FittedBox to prevent any overflow)
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              _formatTime(_remainingSeconds),
              style: TextStyle(
                fontSize: isCompact ? 54 : 64,
                fontWeight: FontWeight.w900,
                fontFamily: 'monospace',
                color: isOvertime
                    ? const Color(0xFFEF4444)
                    : (_remainingSeconds <= 10 && _status == TimerStatus.running
                        ? const Color(0xFFEF4444)
                        : Colors.white),
                shadows: [
                  Shadow(
                    color: isOvertime
                        ? const Color(0xFFEF4444).withValues(alpha: 0.6)
                        : Colors.black.withValues(alpha: 0.4),
                    blurRadius: 10,
                  ),
                ],
              ),
            ),
          ),
          if (isOvertime) ...[
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFFDC2626).withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: const Color(0xFFEF4444)),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.warning_amber_rounded, size: 12, color: Color(0xFFEF4444)),
                  SizedBox(width: 4),
                  Text(
                    'WAKTU MELEBIHI TARGET (LEWAT)',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFEF4444),
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Progress Bar
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 7,
              backgroundColor: const Color(0xFF0F172A),
              valueColor: AlwaysStoppedAnimation<Color>(
                isOvertime || _remainingSeconds <= 10
                    ? const Color(0xFFEF4444)
                    : const Color(0xFF14B8A6),
              ),
            ),
          ),
          const SizedBox(height: 8),

          // Elapsed time
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              'Waktu Berjalan: ${_formatTime(elapsed)} / Target: ${_formatTime(_selectedMode.durationSeconds)}',
              style: const TextStyle(
                fontSize: 11,
                color: Color(0xFF94A3B8),
                fontFamily: 'monospace',
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Action Buttons (NO VIBRATION)
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              // Start / Pause Toggle
              ElevatedButton.icon(
                onPressed: _status == TimerStatus.running
                    ? _pauseTimer
                    : _startTimer,
                icon: Icon(
                  _status == TimerStatus.running
                      ? Icons.pause_rounded
                      : Icons.play_arrow_rounded,
                  size: 18,
                ),
                label: Text(
                  _status == TimerStatus.running ? 'Jeda' : 'Mulai Timer',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _status == TimerStatus.running
                      ? const Color(0xFFF59E0B)
                      : const Color(0xFF10B981),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  elevation: 0,
                ),
              ),

              // Stop Button
              OutlinedButton.icon(
                onPressed: _status == TimerStatus.standby ? null : _stopTimer,
                icon: const Icon(Icons.stop_rounded, size: 16),
                label: const Text('Stop', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFEF4444),
                  side: const BorderSide(color: Color(0xFFDC2626)),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),

              // Reset Button
              OutlinedButton.icon(
                onPressed: _status == TimerStatus.running ? null : _resetTimer,
                icon: const Icon(Icons.refresh_rounded, size: 16),
                label: const Text('Reset', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF94A3B8),
                  side: const BorderSide(color: Color(0xFF475569)),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isVeryNarrow = constraints.maxWidth < 420;

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
                        Icons.timer_rounded,
                        color: Color(0xFF14B8A6),
                        size: 15,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
              ],

              // Synced Athlete & Partai Info (Managed by Dewan)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          const Flexible(
                            child: Text(
                              'Time Keeper',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          const SizedBox(width: 5),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
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
                                letterSpacing: 0.3,
                              ),
                            ),
                          ),
                          if (!isVeryNarrow) ...[
                            const SizedBox(width: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                              decoration: BoxDecoration(
                                color: const Color(0xFF0F172A),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.4)),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.lock_outline_rounded, size: 8, color: Color(0xFF10B981)),
                                  SizedBox(width: 2),
                                  Text(
                                    'Dewan Sync',
                                    style: TextStyle(fontSize: 8, color: Color(0xFF6EE7B7), fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${_athlete.name} (${_athlete.kontingen}) • ${_category.title}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8)),
                      ),
                    ],
                  ),
                ),
              ),
              if (!isVeryNarrow) ...[
                const SizedBox(width: 6),
                // Preset Badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F172A),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFF334155)),
                  ),
                  child: Text(
                    _formatTime(_selectedMode.durationSeconds),
                    style: const TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'monospace',
                      color: Color(0xFF14B8A6),
                    ),
                  ),
                ),
              ],
              const SizedBox(width: 6),

              // Full Screen Toggle Button for Timekeeper
              IconButton(
                onPressed: _toggleFullScreen,
                tooltip: _isFullScreen ? 'Keluar Layar Penuh' : 'Layar Penuh Time Keeper',
                icon: Icon(
                  _isFullScreen ? Icons.fullscreen_exit_rounded : Icons.fullscreen_rounded,
                  size: 16,
                  color: Colors.white,
                ),
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                padding: EdgeInsets.zero,
                style: IconButton.styleFrom(
                  backgroundColor: const Color(0xFF0F172A),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  side: BorderSide(
                    color: _isFullScreen ? const Color(0xFF14B8A6) : const Color(0xFF334155),
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
    if (_remainingSeconds < 0) {
      return const Color(0xFFEF4444);
    }
    switch (_status) {
      case TimerStatus.standby:
        return const Color(0xFF94A3B8);
      case TimerStatus.running:
        return const Color(0xFF10B981);
      case TimerStatus.paused:
        return const Color(0xFFF59E0B);
      case TimerStatus.stopped:
        return const Color(0xFFEF4444);
    }
  }

  String _getStatusLabel() {
    if (_remainingSeconds < 0) {
      if (_status == TimerStatus.paused) {
        return 'Lewat Waktu (Jeda)';
      }
      if (_status == TimerStatus.stopped) {
        return 'Lewat Waktu (Stop)';
      }
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
