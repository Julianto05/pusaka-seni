import 'package:flutter/material.dart';
import '../../../models/scoring_models.dart';

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
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Breakpoint for single row vs edge-to-edge two rows
        final isCompact = constraints.maxWidth < 920;

        return Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: const Color(0xFF334155),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.25),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          padding: EdgeInsets.symmetric(
            horizontal: 8,
            vertical: isCompact ? 5 : 4,
          ),
          child: isCompact
              ? _buildCompactTwoRowLayout()
              : _buildWideSingleRowLayout(),
        );
      },
    );
  }

  // Wide screen: Single streamlined row
  Widget _buildWideSingleRowLayout() {
    return Row(
      children: [
        // Navigation Back Button
        _buildBackButton(),
        const SizedBox(width: 5),

        // Arena Badge
        _buildArenaBadge(),
        const SizedBox(width: 5),

        // Locked Juri Badge (No Dropdown)
        _buildLockedJuriBadge(),
        const SizedBox(width: 5),

        // Juri Readiness Badge / Button
        _buildJuriReadinessPill(),
        const SizedBox(width: 5),

        // Category Badge
        _buildCategoryBadge(),
        const SizedBox(width: 6),

        // Synchronized Match/Partai Badge (Managed by Dewan)
        Expanded(
          child: _buildSyncedPartaiBadge(),
        ),
        const SizedBox(width: 6),

        // Jurus badge (Baku)
        if (category.isBaku && currentJurusNumber != null) ...[
          _buildJurusInfoBadge(),
          const SizedBox(width: 5),
        ],

        // Real-time Score Badge
        _buildScoreBadge(),
        const SizedBox(width: 5),

        // Fullscreen toggle
        _buildFullscreenButton(),
        const SizedBox(width: 5),

        // Sync indicator
        _buildSyncDot(),
      ],
    );
  }

  // Compact / Landscape Mobile: Two clean edge-to-edge rows spanning full width
  Widget _buildCompactTwoRowLayout() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Top Row: Controls (Left) ... Fullscreen & Sync (Right)
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
            _buildFullscreenButton(),
            const SizedBox(width: 5),
            _buildSyncDot(),
          ],
        ),
        const SizedBox(height: 5),

        // Bottom Row: Synchronized Partai & Athlete (Left) ... Jurus Info & Score (Right)
        LayoutBuilder(
          builder: (context, rowConstraints) {
            final isVeryNarrow = rowConstraints.maxWidth < 500;
            if (isVeryNarrow) {
              return SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                child: Row(
                  children: [
                    _buildSyncedPartaiBadge(isCompact: true),
                    const SizedBox(width: 6),
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
                Expanded(
                  child: _buildSyncedPartaiBadge(isCompact: false),
                ),
                const SizedBox(width: 6),
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
      bgColor = const Color(0xFFDC2626).withValues(alpha: 0.2);
      borderColor = const Color(0xFFEF4444);
      textColor = const Color(0xFFFCA5A5);
      icon = Icons.radio_button_checked;
      label = 'READY?';
    } else if (isReady) {
      bgColor = const Color(0xFF059669).withValues(alpha: 0.25);
      borderColor = const Color(0xFF10B981);
      textColor = const Color(0xFF6EE7B7);
      icon = Icons.check_circle_rounded;
      label = 'READY';
    } else if (isScoring) {
      bgColor = const Color(0xFFB45309).withValues(alpha: 0.25);
      borderColor = const Color(0xFFF59E0B);
      textColor = const Color(0xFFFDE68A);
      icon = Icons.edit_note_rounded;
      label = 'MENILAI';
    } else {
      bgColor = const Color(0xFF0369A1).withValues(alpha: 0.25);
      borderColor = const Color(0xFF38BDF8);
      textColor = const Color(0xFFBAE6FD);
      icon = Icons.verified_rounded;
      label = 'SELESAI';
    }

    return InkWell(
      onTap: onToggleReady,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: borderColor, width: 1.2),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 9, color: textColor),
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
        backgroundColor: const Color(0xFF0F172A),
        foregroundColor: const Color(0xFFCBD5E1),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  Widget _buildArenaBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFFDC2626).withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: const Color(0xFFDC2626).withValues(alpha: 0.4),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.asset(
            'assets/images/app_logo_small.png',
            width: 13,
            height: 13,
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
          ),
          const SizedBox(width: 4),
          Text(
            arenaCode,
            style: const TextStyle(
              fontSize: 10,
              fontFamily: 'monospace',
              fontWeight: FontWeight.bold,
              color: Color(0xFFEF4444),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLockedJuriBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3.5),
      decoration: BoxDecoration(
        color: const Color(0xFFDC2626),
        borderRadius: BorderRadius.circular(6),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFDC2626).withValues(alpha: 0.35),
            blurRadius: 4,
            offset: const Offset(0, 1),
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
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFF334155)),
      ),
      child: Text(
        category.title,
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: Color(0xFFE2E8F0),
        ),
      ),
    );
  }

  Widget _buildSyncedPartaiBadge({bool isCompact = false}) {
    return Container(
      constraints: isCompact ? const BoxConstraints(maxWidth: 220) : null,
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF334155)),
      ),
      child: Row(
        mainAxisSize: isCompact ? MainAxisSize.min : MainAxisSize.max,
        children: [
          // Partai Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
            decoration: BoxDecoration(
              color: const Color(0xFFDC2626),
              borderRadius: BorderRadius.circular(4),
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

          // Athlete Icon & Name
          const Icon(
            Icons.person_rounded,
            size: 13,
            color: Color(0xFF38BDF8),
          ),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              athlete.kontingen.isNotEmpty
                  ? '${athlete.name} (${athlete.kontingen})'
                  : athlete.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(width: 5),

          // Dewan Sync Lock Badge (No Dropdown)
          Tooltip(
            message: 'Partai ditentukan secara terpusat oleh Dewan Pertandingan',
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.5)),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.lock_outline_rounded, size: 9, color: Color(0xFF10B981)),
                  SizedBox(width: 2),
                  Text(
                    'Dewan',
                    style: TextStyle(
                      fontSize: 8.5,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF6EE7B7),
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
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF334155)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'J$currentJurusNumber/$totalJurusInGroup$gerakanStr',
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: Color(0xFFE2E8F0),
            ),
          ),
          const SizedBox(width: 3),
          const Text(
            '|',
            style: TextStyle(color: Color(0xFF475569), fontSize: 9),
          ),
          const SizedBox(width: 3),
          Text(
            'X: ${currentJurusMistakes ?? 0}',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: (currentJurusMistakes ?? 0) > 0
                  ? const Color(0xFFEF4444)
                  : const Color(0xFF94A3B8),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScoreBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFFDC2626).withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: const Color(0xFFDC2626).withValues(alpha: 0.4),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Skor: ',
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.bold,
              color: Color(0xFFFCA5A5),
            ),
          ),
          Text(
            currentScore.toStringAsFixed(2),
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w900,
              fontFamily: 'monospace',
              color: Color(0xFFEF4444),
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
      constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
      padding: EdgeInsets.zero,
      style: IconButton.styleFrom(
        backgroundColor: const Color(0xFF0F172A),
        foregroundColor: const Color(0xFFCBD5E1),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  Widget _buildSyncDot() {
    return Tooltip(
      message: 'Sinkron ke Dewan & Server',
      child: Container(
        width: 7,
        height: 7,
        decoration: BoxDecoration(
          color: const Color(0xFF10B981),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF10B981).withValues(alpha: 0.6),
              blurRadius: 4,
              spreadRadius: 1,
            ),
          ],
        ),
      ),
    );
  }
}
