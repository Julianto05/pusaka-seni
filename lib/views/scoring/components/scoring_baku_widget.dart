import 'package:flutter/material.dart';
import '../../../models/scoring_models.dart';
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
    final int totalGerakan = jurusList.fold(0, (sum, j) => sum + j.totalGerakan);

    final String groupName = category == SeniCategory.beregu ? 'Seni Beregu' : activeJurus.weaponGroup;
    final String gerakanSuffix = activeJurus.totalGerakan > 0 ? ' • ${activeJurus.totalGerakan} Gerakan' : '';
    final String wrongSubtitle = 'Salah di Jurus ${activeJurus.jurusNumber} ($groupName$gerakanSuffix)';

    return Column(
      children: [
        // 1. Segmented Visual Progress Bar
        _buildSegmentedProgressBar(totalJurus),
        const SizedBox(height: 6),

        // 1b. Lock Banner if Juri Not Ready
        if (!isJuriReady)
          Container(
            margin: const EdgeInsets.only(bottom: 6),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: const Color(0xFF450A0A),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFDC2626)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.lock_rounded, color: Color(0xFFFCA5A5), size: 14),
                const SizedBox(width: 6),
                const Expanded(
                  child: Text(
                    'PENILAIAN DIKUNCI: Konfirmasi READY terlebih dahulu untuk mulai menilai',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFFCA5A5),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                InkWell(
                  onTap: onRequireReady,
                  borderRadius: BorderRadius.circular(6),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981),
                      borderRadius: BorderRadius.circular(6),
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
              // Left Button: WRONG & NEXT (Red Gradient)
              Expanded(
                child: _buildThumbButton(
                  isWrong: true,
                  title: 'Wrong & Next',
                  subtitle: wrongSubtitle,
                  badge: isJuriReady ? '-0.01' : '🔒 Belum Ready',
                  icon: Icons.close_rounded,
                  gradient: const LinearGradient(
                    colors: [Color(0xFFDC2626), Color(0xFFB91C1C), Color(0xFF991B1B)],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                  borderColor: const Color(0xFFF87171),
                  onTap: isJuriReady ? onWrongAction : (onRequireReady ?? onWrongAction),
                ),
              ),
              const SizedBox(width: 10),

              // Right Button: NEXT JURUS (Green Gradient)
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
                  icon: isLastJurus ? Icons.check_circle_rounded : Icons.arrow_forward_rounded,
                  gradient: const LinearGradient(
                    colors: [Color(0xFF059669), Color(0xFF047857), Color(0xFF065F46)],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                  borderColor: const Color(0xFF34D399),
                  onTap: isJuriReady ? onNextAction : (onRequireReady ?? onNextAction),
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
      // 12 green segments for Beregu
      return Row(
        children: List.generate(12, (index) {
          final isFilled = currentJurusIndex >= index;
          return Expanded(
            child: Container(
              height: 4,
              margin: const EdgeInsets.symmetric(horizontal: 1.5),
              decoration: BoxDecoration(
                color: isFilled ? const Color(0xFF10B981) : const Color(0xFF334155),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          );
        }),
      );
    }

    // Dynamic segment bars for Tunggal based on weapon groups in jurusList:
    // Tangan Kosong: amber, Golok: blue, Toya/tongkat: purple
    final List<Map<String, dynamic>> groupSegments = [];
    int startIdx = 0;
    while (startIdx < jurusList.length) {
      final currentGroup = jurusList[startIdx].weaponGroup;
      int endIdx = startIdx;
      while (endIdx < jurusList.length && jurusList[endIdx].weaponGroup == currentGroup) {
        endIdx++;
      }
      final int count = endIdx - startIdx;
      Color color;
      final lower = currentGroup.toLowerCase();
      if (lower.contains('tangan')) {
        color = const Color(0xFFF59E0B);
      } else if (lower.contains('golok')) {
        color = const Color(0xFF3B82F6);
      } else if (lower.contains('toya')) {
        color = const Color(0xFFA855F7);
      } else {
        color = const Color(0xFF10B981);
      }

      double progress;
      if (currentJurusIndex < startIdx) {
        progress = 0.0;
      } else if (currentJurusIndex >= endIdx) {
        progress = 1.0;
      } else {
        progress = ((currentJurusIndex - startIdx) / count.toDouble()).clamp(0.0, 1.0);
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
              height: 4.5,
              decoration: BoxDecoration(
                color: const Color(0xFF334155),
                borderRadius: BorderRadius.circular(3),
              ),
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: groupSegments[i]['progress'] as double,
                child: Container(
                  decoration: BoxDecoration(
                    color: groupSegments[i]['color'] as Color,
                    borderRadius: BorderRadius.circular(3),
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
      onTap: onTap, // NO VIBRATION
      borderRadius: BorderRadius.circular(24),
      splashColor: Colors.white.withValues(alpha: 0.15),
      highlightColor: Colors.white.withValues(alpha: 0.08),
      child: Container(
        decoration: BoxDecoration(
          gradient: gradient,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: borderColor.withValues(alpha: 0.8), width: 2),
          boxShadow: [
            BoxShadow(
              color: (isWrong ? Colors.red : Colors.green).withValues(alpha: 0.3),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
                      width: isCompact ? 32 : 44,
                      height: isCompact ? 32 : 44,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(icon, color: Colors.white, size: isCompact ? 20 : 26),
                    ),
                    SizedBox(height: isCompact ? 3 : 6),
                    Text(
                      title.toUpperCase(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: isCompact ? 14 : 18,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.6,
                        color: Colors.white,
                        shadows: const [
                          Shadow(
                            color: Colors.black38,
                            blurRadius: 4,
                            offset: Offset(0, 1),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: isCompact ? 1 : 2),
                    Text(
                      subtitle,
                      textAlign: TextAlign.center,
                      maxLines: isCompact ? 1 : 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: isCompact ? 9.5 : 11,
                        color: Colors.white.withValues(alpha: 0.9),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    SizedBox(height: isCompact ? 3 : 6),
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: isCompact ? 8 : 10,
                        vertical: isCompact ? 1.5 : 2.5,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.25),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Text(
                        badge,
                        style: TextStyle(
                          fontSize: isCompact ? 9.5 : 10.5,
                          fontWeight: FontWeight.bold,
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF334155)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Center: Kemantapan Status
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
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.military_tech_rounded,
                      color: Color(0xFF38BDF8),
                      size: 14,
                    ),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        scoreKemantapan == null
                            ? 'Kemantapan ($totalJurus Jurus)'
                            : '+${scoreKemantapan!.toStringAsFixed(2)}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: scoreKemantapan == null
                              ? const Color(0xFFF59E0B)
                              : const Color(0xFF38BDF8),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Reset Button
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
            icon: const Icon(Icons.refresh_rounded, size: 13, color: Color(0xFFEF4444)),
            label: const Text(
              'Reset',
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.bold,
                color: Color(0xFFEF4444),
              ),
            ),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Color(0xFF7F1D1D)),
              backgroundColor: const Color(0xFF450A0A).withValues(alpha: 0.3),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
              minimumSize: const Size(54, 28),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ],
      ),
    );
  }
}
