import 'package:flutter/material.dart';
import '../../../models/scoring_models.dart';
import '../../../theme/app_theme.dart';

class ScoringHeader extends StatelessWidget {
  final String arenaCode;
  final int juriNumber;
  final AthleteModel athlete;
  final SeniCategory category;
  final double currentScore;
  final bool isFullScreen;
  final VoidCallback onToggleFullScreen;
  final VoidCallback onBackToMenu;

  // Optional stats for Baku
  final int? currentJurusNumber;
  final int? totalJurusInGroup;
  final int? currentJurusMistakes;
  final int? currentJurusGerakan;
  final String juriStatus; // 'not_ready', 'ready', 'scoring', 'submitted'
  final VoidCallback? onToggleReady;

  // Live Timer synced from Time Keeper
  final int? timerRemainingSeconds;
  final String? timerStatus;

  const ScoringHeader({
    super.key,
    required this.arenaCode,
    required this.juriNumber,
    required this.athlete,
    required this.category,
    required this.currentScore,
    required this.isFullScreen,
    required this.onToggleFullScreen,
    required this.onBackToMenu,
    this.currentJurusNumber,
    this.totalJurusInGroup,
    this.currentJurusMistakes,
    this.currentJurusGerakan,
    this.juriStatus = 'ready',
    this.onToggleReady,
    this.timerRemainingSeconds,
    this.timerStatus,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 1340;

        return Container(
          width: double.infinity,
          decoration: AppDecorations.card(
            radius: 16,
            borderColor: AppColors.border,
          ),
          padding: EdgeInsets.symmetric(
            horizontal: 9,
            vertical: isCompact ? 6 : 5,
          ),
          child: isCompact
              ? _buildCompactTwoRowLayout()
              : _buildWideSingleRowLayout(),
        );
      },
    );
  }

  Widget _buildWideSingleRowLayout() {
    return Row(
      children: [
        _buildBackButton(),
        const SizedBox(width: 5),
        _buildArenaBadge(),
        const SizedBox(width: 5),
        _buildLockedJuriBadge(),
        const SizedBox(width: 5),
        _buildJuriReadinessPill(),
        const SizedBox(width: 5),
        _buildCategoryBadge(),
        const SizedBox(width: 6),
        Expanded(child: _buildSyncedPartaiBadge()),
        const SizedBox(width: 6),
        if (timerRemainingSeconds != null) ...[
          _buildLiveTimerBadge(),
          const SizedBox(width: 5),
        ],
        if (category.isBaku && currentJurusNumber != null) ...[
          _buildJurusInfoBadge(),
          const SizedBox(width: 5),
        ],
        _buildScoreBadge(),
        const SizedBox(width: 5),
        const ThemeToggleButton(
          buttonSize: 28,
          iconSize: 14,
          borderRadius: 9,
        ),
        const SizedBox(width: 5),
        _buildFullscreenButton(),
        const SizedBox(width: 5),
        _buildSyncDot(),
      ],
    );
  }

  Widget _buildCompactTwoRowLayout() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildBackButton(),
                    const SizedBox(width: 5),
                    _buildArenaBadge(),
                    const SizedBox(width: 5),
                    _buildLockedJuriBadge(),
                    const SizedBox(width: 5),
                    _buildJuriReadinessPill(),
                    const SizedBox(width: 5),
                    _buildCategoryBadge(),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 6),
            const ThemeToggleButton(
              buttonSize: 28,
              iconSize: 14,
              borderRadius: 9,
            ),
            const SizedBox(width: 5),
            _buildFullscreenButton(),
            const SizedBox(width: 5),
            _buildSyncDot(),
          ],
        ),
        const SizedBox(height: 5),
        LayoutBuilder(
          builder: (context, rowConstraints) {
            final isVeryNarrow = rowConstraints.maxWidth < 660;
            if (isVeryNarrow) {
              return SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                child: Row(
                  children: [
                    _buildSyncedPartaiBadge(isCompact: true),
                    const SizedBox(width: 6),
                    if (timerRemainingSeconds != null) ...[
                      _buildLiveTimerBadge(),
                      const SizedBox(width: 6),
                    ],
                    if (category.isBaku && currentJurusNumber != null) ...[
                      _buildJurusInfoBadge(),
                      const SizedBox(width: 6),
                    ],
                    _buildScoreBadge(),
                  ],
                ),
              );
            }

            return Row(
              children: [
                Expanded(child: _buildSyncedPartaiBadge(isCompact: false)),
                const SizedBox(width: 6),
                if (timerRemainingSeconds != null) ...[
                  _buildLiveTimerBadge(),
                  const SizedBox(width: 5),
                ],
                if (category.isBaku && currentJurusNumber != null) ...[
                  _buildJurusInfoBadge(),
                  const SizedBox(width: 5),
                ],
                _buildScoreBadge(),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _buildLiveTimerBadge() {
    final sec = timerRemainingSeconds ?? 180;
    final st = (timerStatus ?? 'standby').toLowerCase();
    final bool isOvertime = sec < 0;
    final int absSec = sec.abs();
    final int m = absSec ~/ 60;
    final int s = absSec % 60;
    final formatted =
        '${isOvertime ? '-' : ''}${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';

    Color accent;
    Color bg;
    Color border;
    IconData icon;
    if (isOvertime || (sec <= 10 && st == 'running')) {
      accent = AppColors.primary;
      bg = AppColors.primarySoft;
      border = AppColors.primaryBorder;
      icon = Icons.timer_rounded;
    } else if (st == 'running') {
      accent = AppColors.emerald;
      bg = AppColors.emeraldSoft;
      border = AppColors.emeraldBorder;
      icon = Icons.play_arrow_rounded;
    } else if (st == 'paused') {
      accent = AppColors.amber;
      bg = AppColors.amberSoft;
      border = AppColors.amberBorder;
      icon = Icons.pause_rounded;
    } else if (st == 'stopped') {
      accent = AppColors.primaryText;
      bg = AppColors.primarySoft;
      border = AppColors.primaryBorder;
      icon = Icons.stop_rounded;
    } else {
      accent = AppColors.tealText;
      bg = AppColors.tealSoft;
      border = AppColors.tealBorder;
      icon = Icons.timer_outlined;
    }

    return Tooltip(
      message: 'Waktu tersinkron langsung dari Time Keeper',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(9),
          border: Border.all(color: border, width: st == 'running' ? 1.3 : 1.0),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12, color: accent),
            const SizedBox(width: 3),
            Text(
              formatted,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w900,
                fontFamily: 'monospace',
                color: accent,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildJuriReadinessPill() {
    final bool isNotReady = juriStatus == 'not_ready';
    final bool isReady = juriStatus == 'ready';
    final bool isScoring = juriStatus == 'scoring';

    Color bgColor;
    Color borderColor;
    Color textColor;
    IconData icon;
    String label;

    if (isNotReady) {
      bgColor = AppColors.primarySoft;
      borderColor = AppColors.primaryBorder;
      textColor = AppColors.primaryText;
      icon = Icons.radio_button_checked;
      label = 'READY?';
    } else if (isReady) {
      bgColor = AppColors.emeraldSoft;
      borderColor = AppColors.emeraldBorder;
      textColor = AppColors.emeraldText;
      icon = Icons.check_circle_rounded;
      label = 'READY';
    } else if (isScoring) {
      bgColor = AppColors.amberSoft;
      borderColor = AppColors.amberBorder;
      textColor = AppColors.amberText;
      icon = Icons.edit_note_rounded;
      label = 'MENILAI';
    } else {
      bgColor = AppColors.skySoft;
      borderColor = AppColors.skyBorder;
      textColor = AppColors.skyText;
      icon = Icons.verified_rounded;
      label = 'SELESAI';
    }

    return InkWell(
      onTap: onToggleReady,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3.5),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: borderColor, width: 1.1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 10, color: textColor),
            const SizedBox(width: 3),
            Text(
              label,
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w900,
                color: textColor,
                letterSpacing: 0.4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBackButton() {
    return IconButton(
      onPressed: onBackToMenu,
      tooltip: 'Kembali ke Menu',
      icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 13),
      constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
      padding: EdgeInsets.zero,
      style: IconButton.styleFrom(
        backgroundColor: AppColors.surfaceSoft,
        foregroundColor: AppColors.textPrimary,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        visualDensity: VisualDensity.compact,
        side: BorderSide(color: AppColors.border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
      ),
    );
  }

  Widget _buildArenaBadge() {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 140),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3.5),
        decoration: BoxDecoration(
          color: AppColors.primarySoft,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.primaryBorder),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              'assets/images/app_logo_small.png',
              width: 13,
              height: 13,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) =>
                  const SizedBox.shrink(),
            ),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                arenaCode,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 10,
                  fontFamily: 'monospace',
                  fontWeight: FontWeight.w800,
                  color: AppColors.primaryText,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLockedJuriBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primary, AppColors.primaryDark],
        ),
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.25),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.shield_rounded, color: Colors.white, size: 11),
          const SizedBox(width: 3.5),
          Text(
            'JURI $juriNumber',
            style: const TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.5,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3.5),
      decoration: AppDecorations.softTile(
        radius: 8,
        color: AppColors.surfaceSoft,
        borderColor: AppColors.border,
      ),
      child: Text(
        category.title,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
        ),
      ),
    );
  }

  Widget _buildSyncedPartaiBadge({bool isCompact = false}) {
    return Container(
      constraints: isCompact ? const BoxConstraints(maxWidth: 220) : null,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
      decoration: AppDecorations.softTile(
        radius: 10,
        color: AppColors.surfaceSoft,
        borderColor: AppColors.border,
      ),
      child: Row(
        mainAxisSize: isCompact ? MainAxisSize.min : MainAxisSize.max,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 5.5, vertical: 1.5),
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(5),
            ),
            child: Text(
              athlete.partai.toUpperCase(),
              style: const TextStyle(
                fontSize: 9.5,
                fontWeight: FontWeight.w900,
                color: Colors.white,
                letterSpacing: 0.3,
              ),
            ),
          ),
          const SizedBox(width: 5),
          const Icon(Icons.person_rounded, size: 13, color: AppColors.sky),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              athlete.kontingen.isNotEmpty
                  ? '${athlete.name} (${athlete.kontingen})'
                  : athlete.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          const SizedBox(width: 5),
          Tooltip(
            message: 'Partai ditentukan secara terpusat oleh Dewan Pertandingan',
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
              decoration: BoxDecoration(
                color: AppColors.emeraldSoft,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: AppColors.emeraldBorder),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.lock_outline_rounded,
                    size: 9,
                    color: AppColors.emerald,
                  ),
                  SizedBox(width: 2),
                  Text(
                    'Dewan',
                    style: TextStyle(
                      fontSize: 8.5,
                      fontWeight: FontWeight.w800,
                      color: AppColors.emeraldText,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildJurusInfoBadge() {
    final gerakanStr = currentJurusGerakan != null && currentJurusGerakan! > 0
        ? ' (${currentJurusGerakan}grk)'
        : '';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: AppDecorations.softTile(
        radius: 9,
        color: AppColors.surfaceSoft,
        borderColor: AppColors.border,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'J$currentJurusNumber/$totalJurusInGroup$gerakanStr',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            '|',
            style: TextStyle(color: AppColors.borderStrong, fontSize: 9),
          ),
          const SizedBox(width: 4),
          Text(
            'X: ${currentJurusMistakes ?? 0}',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: (currentJurusMistakes ?? 0) > 0
                  ? AppColors.primary
                  : AppColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScoreBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
      decoration: BoxDecoration(
        color: AppColors.primarySoft,
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: AppColors.primaryBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Skor: ',
            style: TextStyle(
              fontSize: 9.5,
              fontWeight: FontWeight.w700,
              color: AppColors.primaryText,
            ),
          ),
          Text(
            currentScore.toStringAsFixed(2),
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w900,
              fontFamily: 'monospace',
              color: AppColors.primary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFullscreenButton() {
    return IconButton(
      onPressed: onToggleFullScreen,
      tooltip: isFullScreen ? 'Keluar Layar Penuh' : 'Layar Penuh',
      icon: Icon(
        isFullScreen ? Icons.fullscreen_exit_rounded : Icons.fullscreen_rounded,
        size: 15,
      ),
      constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
      padding: EdgeInsets.zero,
      style: IconButton.styleFrom(
        backgroundColor: AppColors.surfaceSoft,
        foregroundColor: AppColors.textSecondary,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        visualDensity: VisualDensity.compact,
        side: BorderSide(color: AppColors.border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
      ),
    );
  }

  Widget _buildSyncDot() {
    return Tooltip(
      message: 'Sinkron ke Dewan & Server',
      child: Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(
          color: AppColors.emerald,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: AppColors.emerald.withValues(alpha: 0.45),
              blurRadius: 5,
              spreadRadius: 1,
            ),
          ],
        ),
      ),
    );
  }
}
