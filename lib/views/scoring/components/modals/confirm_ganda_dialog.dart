import 'package:flutter/material.dart';
import '../../../../theme/app_theme.dart';

class ConfirmGandaDialog extends StatelessWidget {
  final int juriNumber;
  final String categoryTitle;
  final String athleteName;
  final double attackDefense;
  final double firmnessHarmony;
  final double soulfulness;
  final VoidCallback onConfirm;

  const ConfirmGandaDialog({
    super.key,
    required this.juriNumber,
    required this.categoryTitle,
    required this.athleteName,
    required this.attackDefense,
    required this.firmnessHarmony,
    required this.soulfulness,
    required this.onConfirm,
  });

  @override
  Widget build(BuildContext context) {
    final double totalPenalty = attackDefense + firmnessHarmony + soulfulness;
    final double totalScore = (9.90 - totalPenalty).clamp(0.0, 9.90);
    final maxH = MediaQuery.sizeOf(context).height * 0.88;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 400, maxHeight: maxH),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: AppDecorations.card(
            radius: 24,
            borderColor: AppColors.primaryBorder,
            borderWidth: 1.4,
          ),
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Icon Header
                Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    color: AppColors.primarySoft,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.primaryBorder),
                  ),
                  child: const Icon(
                    Icons.emoji_events_rounded,
                    color: AppColors.primary,
                    size: 28,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Konfirmasi Nilai $categoryTitle',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                RichText(
                  textAlign: TextAlign.center,
                  text: TextSpan(
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                    children: [
                      TextSpan(
                        text:
                            'Pastikan seluruh aspek penilaian Juri $juriNumber untuk pesilat ',
                      ),
                      TextSpan(
                        text: athleteName,
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const TextSpan(text: ' sudah sesuai.'),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Breakdown Box
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: AppDecorations.softTile(
                    radius: 16,
                    color: AppColors.surfaceSoft,
                    borderColor: AppColors.border,
                  ),
                  child: Column(
                    children: [
                      _buildAspectRow(
                        'Nilai Awal Penampilan',
                        '9.90',
                        color: AppColors.skyText,
                      ),
                      Divider(color: AppColors.border, height: 16),
                      _buildAspectRow(
                        '1. Penalti Serang Bela',
                        '-${attackDefense.toStringAsFixed(2)}',
                        color: attackDefense > 0
                            ? AppColors.primary
                            : AppColors.textSecondary,
                      ),
                      const SizedBox(height: 8),
                      _buildAspectRow(
                        '2. Penalti Kemantapan & Keselarasan',
                        '-${firmnessHarmony.toStringAsFixed(2)}',
                        color: firmnessHarmony > 0
                            ? AppColors.primary
                            : AppColors.textSecondary,
                      ),
                      const SizedBox(height: 8),
                      _buildAspectRow(
                        '3. Penalti Penjiwaan & Karakter',
                        '-${soulfulness.toStringAsFixed(2)}',
                        color: soulfulness > 0
                            ? AppColors.primary
                            : AppColors.textSecondary,
                      ),
                      Divider(color: AppColors.border, height: 16),
                      _buildAspectRow(
                        'Total Pengurangan (Penalti)',
                        '-${totalPenalty.toStringAsFixed(2)}',
                        color: totalPenalty > 0
                            ? AppColors.primaryText
                            : AppColors.textSecondary,
                      ),
                      Divider(color: AppColors.border, height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              'Total Nilai Akhir Juri $juriNumber:',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: AppColors.textPrimary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            totalScore.toStringAsFixed(2),
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              color: AppColors.emerald,
                              fontFamily: 'monospace',
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),

                // Buttons
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.textSecondary,
                          side: BorderSide(color: AppColors.borderStrong),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: const FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            'Periksa Lagi',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.of(context).pop();
                          onConfirm();
                        },
                        icon: const Icon(Icons.check_circle_rounded, size: 16),
                        label: const FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            'Kirim Nilai',
                            style: TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          elevation: 0,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAspectRow(String label, String value, {required Color color}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: color,
              fontWeight: FontWeight.w600,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.end,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 13,
              color: color,
              fontWeight: FontWeight.w800,
              fontFamily: 'monospace',
            ),
          ),
        ),
      ],
    );
  }
}
