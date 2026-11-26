import 'package:flutter/material.dart';
import '../../../models/scoring_models.dart';
import 'modals/confirm_kemantapan_dialog.dart';

class ScoringBakuTuntasWidget extends StatelessWidget {
  final AthleteModel athlete;
  final int juriNumber;
  final int totalJurus;
  final int totalMistakes;
  final double scoreKebenaran;
  final double? scoreKemantapan;
  final double totalFinalScore;
  final ValueChanged<double> onSelectKemantapan;
  final VoidCallback onSubmitFinalScore;

  const ScoringBakuTuntasWidget({
    super.key,
    required this.athlete,
    required this.juriNumber,
    required this.totalJurus,
    required this.totalMistakes,
    required this.scoreKebenaran,
    required this.scoreKemantapan,
    required this.totalFinalScore,
    required this.onSelectKemantapan,
    required this.onSubmitFinalScore,
  });

  static const List<double> kemantapanValues = [
    0.01, 0.02, 0.03, 0.04, 0.05,
    0.06, 0.07, 0.08, 0.09, 0.10,
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFF334155),
        ),
      ),
      child: Column(
        children: [
          // Header Summary Card
          LayoutBuilder(
            builder: (context, headerConstraints) {
              final isCompact = headerConstraints.maxWidth < 620;

              final statPills = [
                _buildStatPill(
                  label: 'Salah',
                  value: '${totalMistakes}x (-${(totalMistakes * 0.01).toStringAsFixed(2)})',
                  color: const Color(0xFFEF4444),
                ),
                const SizedBox(width: 6),
                _buildStatPill(
                  label: 'Kebenaran',
                  value: scoreKebenaran.toStringAsFixed(2),
                  color: const Color(0xFF38BDF8),
                ),
                const SizedBox(width: 6),
                _buildStatPill(
                  label: 'Kemantapan',
                  value: scoreKemantapan == null
                      ? 'Belum'
                      : '+${scoreKemantapan!.toStringAsFixed(2)}',
                  color: scoreKemantapan == null
                      ? const Color(0xFF94A3B8)
                      : const Color(0xFF38BDF8),
                ),
                const SizedBox(width: 6),
                _buildStatPill(
                  label: 'Total Akhir',
                  value: totalFinalScore.toStringAsFixed(2),
                  color: const Color(0xFFEF4444),
                  isTotal: true,
                ),
              ];

              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F172A),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFF334155)),
                ),
                child: isCompact
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(5),
                                decoration: const BoxDecoration(
                                  color: Color(0xFF10B981),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.check_circle_rounded,
                                  color: Colors.white,
                                  size: 14,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '$totalJurus Jurus Tuntas',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF10B981),
                                      ),
                                    ),
                                    Text(
                                      athlete.name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: Colors.white70,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            physics: const BouncingScrollPhysics(),
                            child: Row(children: statPills),
                          ),
                        ],
                      )
                    : Row(
                        children: [
                          // Icon & Title
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: const BoxDecoration(
                                  color: Color(0xFF10B981),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.check_circle_rounded,
                                  color: Colors.white,
                                  size: 16,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '$totalJurus Jurus Tuntas',
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF10B981),
                                    ),
                                  ),
                                  Text(
                                    athlete.name,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Colors.white70,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const Spacer(),
                          Row(children: statPills),
                        ],
                      ),
              );
            },
          ),
          const SizedBox(height: 8),

          // Kemantapan Picker Grid Section (Ultra-Responsive)
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF334155)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.military_tech_rounded,
                        color: Color(0xFF38BDF8),
                        size: 16,
                      ),
                      const SizedBox(width: 6),
                      const Expanded(
                        child: Text(
                          'Pilih Nilai Kemantapan (0.01 - 0.10):',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      if (scoreKemantapan != null) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0284C7).withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: const Color(0xFF0284C7).withValues(alpha: 0.5),
                            ),
                          ),
                          child: Text(
                            '+${scoreKemantapan!.toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF38BDF8),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 6),

                  // 10 Buttons Adaptive Grid
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final isVeryWide = constraints.maxWidth >= 540;
                        final crossAxisCount = isVeryWide ? 10 : 5;
                        final double spacing = constraints.maxWidth < 360 ? 4 : 6;
                        final int rowCount = isVeryWide ? 1 : 2;
                        final double availableH = constraints.maxHeight;
                        final double cellW = (constraints.maxWidth - (crossAxisCount - 1) * spacing) / crossAxisCount;
                        final double targetH = ((availableH - (rowCount - 1) * spacing) / rowCount).clamp(24.0, 48.0);
                        final double aspectRatio = (cellW / targetH).clamp(1.1, 3.2);

                        return GridView.builder(
                          physics: const BouncingScrollPhysics(),
                          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: crossAxisCount,
                            mainAxisSpacing: spacing,
                            crossAxisSpacing: spacing,
                            childAspectRatio: aspectRatio,
                          ),
                          itemCount: kemantapanValues.length,
                          itemBuilder: (context, index) {
                            final val = kemantapanValues[index];
                            final isSelected = scoreKemantapan == val;

                            return InkWell(
                              onTap: () {
                                showDialog(
                                  context: context,
                                  builder: (_) => ConfirmKemantapanDialog(
                                    juriNumber: juriNumber,
                                    athleteName: athlete.name,
                                    kemantapan: val,
                                    kebenaran: scoreKebenaran,
                                    onConfirm: () => onSelectKemantapan(val),
                                  ),
                                );
                              },
                              borderRadius: BorderRadius.circular(8),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? const Color(0xFF0284C7)
                                      : const Color(0xFF1E293B),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: isSelected
                                        ? const Color(0xFF38BDF8)
                                        : const Color(0xFF475569),
                                    width: isSelected ? 1.5 : 1.0,
                                  ),
                                  boxShadow: isSelected
                                      ? [
                                          BoxShadow(
                                            color: const Color(0xFF0284C7)
                                                .withValues(alpha: 0.4),
                                            blurRadius: 6,
                                          ),
                                        ]
                                      : null,
                                ),
                                child: Center(
                                  child: FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 4),
                                      child: Text(
                                        '+${val.toStringAsFixed(2)}',
                                        style: TextStyle(
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.bold,
                                          fontFamily: 'monospace',
                                          color: isSelected
                                              ? Colors.white
                                              : const Color(0xFFE2E8F0),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),

                  const SizedBox(height: 2),
                  const Center(
                    child: Text(
                      'Ketuk tombol nilai kemantapan untuk konfirmasi dan simpan penilaian.',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 9.5,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),

          // Bottom Controls: Submit Final Score (Full Width)
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: onSubmitFinalScore,
              icon: const Icon(Icons.done_all_rounded, size: 16),
              label: const FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  'Selesai & Sinkronkan Nilai',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF10B981),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                elevation: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatPill({
    required String label,
    required String value,
    required Color color,
    bool isTotal = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isTotal ? color.withValues(alpha: 0.5) : const Color(0xFF334155),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label.toUpperCase(),
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.bold,
              color: isTotal ? color : const Color(0xFF64748B),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              fontFamily: 'monospace',
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
