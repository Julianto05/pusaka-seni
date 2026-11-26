import 'package:flutter/material.dart';
import '../../../models/scoring_models.dart';
import '../../../theme/app_theme.dart';
import 'modals/kemantapan_info_dialog.dart';
import 'modals/reset_confirm_dialog.dart';
import 'scoring_baku_tuntas_widget.dart';

class ScoringBakuWidget extends StatelessWidget {
  final AthleteModel athlete;
  final int juriNumber;
  final SeniCategory category;
  final List<JurusModel> jurusList;
  final int currentJurusIndex; // 0-based
  final List<int> mistakesPerJurus;
  final double? scoreKemantapan;
  final bool isCompleted;
  final bool isJuriReady;
  final VoidCallback? onRequireReady;

  // Callbacks
  final VoidCallback onWrongAction;
  final VoidCallback onNextAction;
  final VoidCallback onResetAction;
  final ValueChanged<double> onSelectKemantapan;
  final VoidCallback onSubmitFinalScore;

  const ScoringBakuWidget({
    super.key,
    required this.athlete,
    required this.juriNumber,
    required this.category,
    required this.jurusList,
    required this.currentJurusIndex,
    required this.mistakesPerJurus,
    required this.scoreKemantapan,
    required this.isCompleted,
    this.isJuriReady = true,
    this.onRequireReady,
    required this.onWrongAction,
    required this.onNextAction,
    required this.onResetAction,
    required this.onSelectKemantapan,
    required this.onSubmitFinalScore,
  });

  @override
  Widget build(BuildContext context) {
    final int totalJurus = jurusList.length;
    final int totalMistakes = mistakesPerJurus.fold(0, (sum, m) => sum + m);
    final double kebenaran = (9.90 - (totalMistakes * 0.01)).clamp(0.0, 9.90);
    final double finalScore = kebenaran + (scoreKemantapan ?? 0.0);

    if (isCompleted) {
      return ScoringBakuTuntasWidget(
        athlete: athlete,
        juriNumber: juriNumber,
        totalJurus: totalJurus,
        totalMistakes: totalMistakes,
        scoreKebenaran: kebenaran,
        scoreKemantapan: scoreKemantapan,
        totalFinalScore: finalScore,
        onSelectKemantapan: onSelectKemantapan,
        onSubmitFinalScore: onSubmitFinalScore,
      );
    }

    final JurusModel activeJurus = currentJurusIndex < jurusList.length
        ? jurusList[currentJurusIndex]
        : jurusList.last;
    final bool isLastJurus = currentJurusIndex >= totalJurus - 1;
    final int totalGerakan = jurusList.fold(
      0,
      (sum, j) => sum + j.totalGerakan,
    );

    final String groupName = category == SeniCategory.beregu
        ? 'Seni Beregu'
        : activeJurus.weaponGroup;
    final String gerakanSuffix = activeJurus.totalGerakan > 0
        ? ' • ${activeJurus.totalGerakan} Gerakan'
        : '';
    final String wrongSubtitle =
        'Salah di Jurus ${activeJurus.jurusNumber} ($groupName$gerakanSuffix)';

    return Column(
      children: [
        // 1. Segmented Visual Progress Bar
        _buildSegmentedProgressBar(totalJurus),
        const SizedBox(height: 7),

        // 1b. Lock Banner if Juri Not Ready
        if (!isJuriReady)
          Container(
            margin: const EdgeInsets.only(bottom: 7),
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.primarySoft,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.primaryBorder),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.lock_rounded,
                  color: AppColors.primary,
                  size: 14,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'PENILAIAN DIKUNCI: Konfirmasi READY terlebih dahulu untuk mulai menilai',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primaryText,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                InkWell(
                  onTap: onRequireReady,
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.emerald,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'KLIK READY',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

        // 2. Main Two Thumb Buttons (Landscape Ergonomics)
        Expanded(
          child: Row(
            children: [
              // Left Button: WRONG & NEXT
              Expanded(
                child: _buildThumbButton(
                  isWrong: true,
                  title: 'Wrong & Next',
                  subtitle: wrongSubtitle,
                  badge: isJuriReady ? '-0.01' : '🔒 Belum Ready',
                  icon: Icons.close_rounded,
                  gradient: const LinearGradient(
                    colors: [
                      Color(0xFFEF4444),
                      Color(0xFFDC2626),
                      Color(0xFFB91C1C),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderColor: const Color(0xFFFCA5A5),
                  onTap: isJuriReady
                      ? onWrongAction
                      : (onRequireReady ?? onWrongAction),
                ),
              ),
              const SizedBox(width: 10),

              // Right Button: NEXT JURUS
              Expanded(
                child: _buildThumbButton(
                  isWrong: false,
                  title: 'Next',
                  subtitle: isLastJurus
                      ? (totalGerakan > 0
                            ? 'Selesaikan Semua $totalJurus Jurus ($totalGerakan Gerakan)'
                            : 'Selesaikan Semua $totalJurus Jurus')
                      : 'Lanjut ke Jurus Selanjutnya',
                  badge: isJuriReady
                      ? (isLastJurus ? 'Selesai' : 'Jurus Selanjutnya')
                      : '🔒 Belum Ready',
                  icon: isLastJurus
                      ? Icons.check_circle_rounded
                      : Icons.arrow_forward_rounded,
                  gradient: const LinearGradient(
                    colors: [
                      Color(0xFF10B981),
                      Color(0xFF059669),
                      Color(0xFF047857),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderColor: const Color(0xFF6EE7B7),
                  onTap: isJuriReady
                      ? onNextAction
                      : (onRequireReady ?? onNextAction),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),

        // 3. Bottom Utility Action Bar
        _buildBottomBar(context, totalJurus),
      ],
    );
  }

  Widget _buildSegmentedProgressBar(int totalJurus) {
    if (category == SeniCategory.beregu) {
      return Row(
        children: List.generate(12, (index) {
          final isFilled = currentJurusIndex >= index;
          return Expanded(
            child: Container(
              height: 5,
              margin: const EdgeInsets.symmetric(horizontal: 1.5),
              decoration: BoxDecoration(
                color: isFilled ? AppColors.emerald : AppColors.border,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          );
        }),
      );
    }

    final List<Map<String, dynamic>> groupSegments = [];
    int startIdx = 0;
    while (startIdx < jurusList.length) {
      final currentGroup = jurusList[startIdx].weaponGroup;
      int endIdx = startIdx;
      while (endIdx < jurusList.length &&
          jurusList[endIdx].weaponGroup == currentGroup) {
        endIdx++;
      }
      final int count = endIdx - startIdx;
      Color color;
      final lower = currentGroup.toLowerCase();
      if (lower.contains('tangan')) {
        color = AppColors.amber;
      } else if (lower.contains('golok')) {
        color = AppColors.blue;
      } else if (lower.contains('toya')) {
        color = AppColors.purple;
      } else {
        color = AppColors.emerald;
      }

      double progress;
      if (currentJurusIndex < startIdx) {
        progress = 0.0;
      } else if (currentJurusIndex >= endIdx) {
        progress = 1.0;
      } else {
        progress = ((currentJurusIndex - startIdx) / count.toDouble()).clamp(
          0.0,
          1.0,
        );
      }

      groupSegments.add({
        'group': currentGroup,
        'count': count,
        'color': color,
        'progress': progress,
      });

      startIdx = endIdx;
    }

    return Row(
      children: [
        for (int i = 0; i < groupSegments.length; i++) ...[
          if (i > 0) const SizedBox(width: 4),
          Expanded(
            flex: groupSegments[i]['count'] as int,
            child: Container(
              height: 5.5,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(4),
              ),
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: groupSegments[i]['progress'] as double,
                child: Container(
                  decoration: BoxDecoration(
                    color: groupSegments[i]['color'] as Color,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildThumbButton({
    required bool isWrong,
    required String title,
    required String subtitle,
    required String badge,
    required IconData icon,
    required LinearGradient gradient,
    required Color borderColor,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(26),
      splashColor: Colors.white.withValues(alpha: 0.18),
      highlightColor: Colors.white.withValues(alpha: 0.1),
      child: Container(
        decoration: BoxDecoration(
          gradient: gradient,
          borderRadius: BorderRadius.circular(26),
          border: Border.all(
            color: borderColor.withValues(alpha: 0.75),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: (isWrong ? AppColors.primary : AppColors.emerald)
                  .withValues(alpha: 0.24),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isCompact = constraints.maxHeight < 115;
            return FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.center,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minWidth: constraints.maxWidth,
                  maxWidth: constraints.maxWidth,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: isCompact ? 34 : 46,
                      height: isCompact ? 34 : 46,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        icon,
                        color: Colors.white,
                        size: isCompact ? 20 : 26,
                      ),
                    ),
                    SizedBox(height: isCompact ? 4 : 7),
                    Text(
                      title.toUpperCase(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: isCompact ? 14 : 18.5,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.6,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(height: isCompact ? 1 : 3),
                    Text(
                      subtitle,
                      textAlign: TextAlign.center,
                      maxLines: isCompact ? 1 : 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: isCompact ? 9.5 : 11.5,
                        color: Colors.white.withValues(alpha: 0.92),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    SizedBox(height: isCompact ? 4 : 7),
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: isCompact ? 9 : 11,
                        vertical: isCompact ? 2 : 3,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Text(
                        badge,
                        style: TextStyle(
                          fontSize: isCompact ? 9.5 : 10.5,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildBottomBar(BuildContext context, int totalJurus) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: AppDecorations.card(
        radius: 16,
        borderColor: AppColors.border,
        elevated: false,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: InkWell(
              onTap: () {
                if (!isJuriReady) {
                  onRequireReady?.call();
                  return;
                }
                showDialog(
                  context: context,
                  builder: (_) => KemantapanInfoDialog(
                    categoryName: category.title,
                    totalJurus: totalJurus,
                    currentKemantapan: scoreKemantapan,
                    onSelectKemantapan: onSelectKemantapan,
                  ),
                );
              },
              borderRadius: BorderRadius.circular(10),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.military_tech_rounded,
                      color: scoreKemantapan == null
                          ? AppColors.amber
                          : AppColors.sky,
                      size: 15,
                    ),
                    const SizedBox(width: 5),
                    Flexible(
                      child: Text(
                        scoreKemantapan == null
                            ? 'Kemantapan ($totalJurus Jurus)'
                            : '+${scoreKemantapan!.toStringAsFixed(2)}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                          color: scoreKemantapan == null
                              ? AppColors.amberText
                              : AppColors.skyText,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          OutlinedButton.icon(
            onPressed: () {
              if (!isJuriReady) {
                onRequireReady?.call();
                return;
              }
              showDialog(
                context: context,
                builder: (_) => ResetConfirmDialog(
                  categoryTitle: category.title,
                  juriNumber: juriNumber,
                  isBaku: true,
                  onReset: onResetAction,
                ),
              );
            },
            icon: const Icon(
              Icons.refresh_rounded,
              size: 13,
              color: AppColors.primary,
            ),
            label: Text(
              'Reset',
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w800,
                color: AppColors.primaryText,
              ),
            ),
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: AppColors.primaryBorder),
              backgroundColor: AppColors.primarySoft,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              minimumSize: const Size(56, 30),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
