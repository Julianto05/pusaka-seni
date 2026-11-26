import 'package:flutter/material.dart';
import '../../../models/scoring_models.dart';
import '../../../theme/app_theme.dart';
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
    0.01,
    0.02,
    0.03,
    0.04,
    0.05,
    0.06,
    0.07,
    0.08,
    0.09,
    0.10,
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: AppDecorations.card(
        radius: 22,
        borderColor: AppColors.border,
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
                  value:
                      '${totalMistakes}x (-${(totalMistakes * 0.01).toStringAsFixed(2)})',
                  color: AppColors.primary,
                  bgColor: AppColors.primarySoft,
                  borderColor: AppColors.primaryBorder,
                ),
                const SizedBox(width: 6),
                _buildStatPill(
                  label: 'Kebenaran',
                  value: scoreKebenaran.toStringAsFixed(2),
                  color: AppColors.skyText,
                  bgColor: AppColors.skySoft,
                  borderColor: AppColors.skyBorder,
                ),
                const SizedBox(width: 6),
                _buildStatPill(
                  label: 'Kemantapan',
                  value: scoreKemantapan == null
                      ? 'Belum'
                      : '+${scoreKemantapan!.toStringAsFixed(2)}',
                  color: scoreKemantapan == null
                      ? AppColors.textMuted
                      : AppColors.skyText,
                  bgColor: scoreKemantapan == null
                      ? AppColors.surface
                      : AppColors.skySoft,
                  borderColor: scoreKemantapan == null
                      ? AppColors.border
                      : AppColors.skyBorder,
                ),
                const SizedBox(width: 6),
                _buildStatPill(
                  label: 'Total Akhir',
                  value: totalFinalScore.toStringAsFixed(2),
                  color: AppColors.primary,
                  bgColor: AppColors.primarySoft,
                  borderColor: AppColors.primary,
                  isTotal: true,
                ),
              ];

              return Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 9,
                ),
                decoration: AppDecorations.softTile(
                  radius: 16,
                  color: AppColors.surfaceSoft,
                  borderColor: AppColors.border,
                ),
                child: isCompact
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: const BoxDecoration(
                                  color: AppColors.emerald,
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
                                      style: TextStyle(
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w800,
                                        color: AppColors.emeraldText,
                                      ),
                                    ),
                                    Text(
                                      athlete.name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: AppColors.textSecondary,
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
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: const BoxDecoration(
                                  color: AppColors.emerald,
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
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.emeraldText,
                                    ),
                                  ),
                                  Text(
                                    athlete.name,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: AppColors.textSecondary,
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
          const SizedBox(height: 10),

          // Kemantapan Picker Grid Section
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: AppDecorations.softTile(
                radius: 16,
                color: AppColors.surfaceSoft,
                borderColor: AppColors.border,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.military_tech_rounded,
                        color: AppColors.sky,
                        size: 17,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Pilih Nilai Kemantapan (0.01 - 0.10):',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      if (scoreKemantapan != null) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2.5,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.skySoft,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppColors.skyBorder),
                          ),
                          child: Text(
                            '+${scoreKemantapan!.toStringAsFixed(2)}',
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w800,
                              color: AppColors.skyText,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 8),

                  // 10 Buttons Adaptive Grid
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final isVeryWide = constraints.maxWidth >= 540;
                        final crossAxisCount = isVeryWide ? 10 : 5;
                        final double spacing = constraints.maxWidth < 360
                            ? 5
                            : 7;
                        final int rowCount = isVeryWide ? 1 : 2;
                        final double availableH = constraints.maxHeight;
                        final double cellW =
                            (constraints.maxWidth -
                                (crossAxisCount - 1) * spacing) /
                            crossAxisCount;
                        final double targetH =
                            ((availableH - (rowCount - 1) * spacing) / rowCount)
                                .clamp(26.0, 50.0);
                        final double aspectRatio = (cellW / targetH).clamp(
                          1.1,
                          3.2,
                        );

                        return GridView.builder(
                          physics: const BouncingScrollPhysics(),
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
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
                              borderRadius: BorderRadius.circular(10),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? AppColors.sky
                                      : AppColors.surface,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: isSelected
                                        ? AppColors.sky
                                        : AppColors.border,
                                    width: isSelected ? 1.5 : 1.0,
                                  ),
                                  boxShadow: isSelected
                                      ? [
                                          BoxShadow(
                                            color: AppColors.sky.withValues(
                                              alpha: 0.3,
                                            ),
                                            blurRadius: 8,
                                            offset: const Offset(0, 2),
                                          ),
                                        ]
                                      : null,
                                ),
                                child: Center(
                                  child: FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 4,
                                      ),
                                      child: Text(
                                        '+${val.toStringAsFixed(2)}',
                                        style: TextStyle(
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.w800,
                                          fontFamily: 'monospace',
                                          color: isSelected
                                              ? Colors.white
                                              : AppColors.textPrimary,
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

                  const SizedBox(height: 4),
                  Center(
                    child: Text(
                      'Ketuk tombol nilai kemantapan untuk konfirmasi dan simpan penilaian.',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 10,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),

          // Bottom Controls: Submit Final Score
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: onSubmitFinalScore,
              icon: const Icon(Icons.done_all_rounded, size: 17),
              label: const FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  'Selesai & Sinkronkan Nilai',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5),
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.emerald,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  vertical: 12,
                  horizontal: 14,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
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
    required Color bgColor,
    required Color borderColor,
    bool isTotal = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: borderColor, width: isTotal ? 1.3 : 1.0),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label.toUpperCase(),
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w800,
              color: isTotal ? color : AppColors.textMuted,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              fontFamily: 'monospace',
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
