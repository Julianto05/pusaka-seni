import 'package:flutter/material.dart';
import '../../../../theme/app_theme.dart';

class KemantapanInfoDialog extends StatelessWidget {
  final String categoryName;
  final int totalJurus;
  final ValueChanged<double>? onSelectKemantapan;
  final double? currentKemantapan;

  const KemantapanInfoDialog({
    super.key,
    required this.categoryName,
    required this.totalJurus,
    this.onSelectKemantapan,
    this.currentKemantapan,
  });

  static const List<double> values = [
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
    final maxH = MediaQuery.sizeOf(context).height * 0.88;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 420, maxHeight: maxH),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: AppDecorations.card(
            radius: 24,
            borderColor: AppColors.amberBorder,
            borderWidth: 1.4,
          ),
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: AppColors.amberSoft,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.amberBorder),
                  ),
                  child: const Icon(
                    Icons.info_rounded,
                    color: AppColors.amber,
                    size: 28,
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  'Kemantapan di Akhir',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Aturan Penilaian $categoryName',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(13),
                  decoration: AppDecorations.softTile(
                    radius: 14,
                    color: AppColors.surfaceSoft,
                    borderColor: AppColors.border,
                  ),
                  child: RichText(
                    textAlign: TextAlign.center,
                    text: TextSpan(
                      style: TextStyle(
                        fontSize: 12.5,
                        color: AppColors.textSecondary,
                        height: 1.45,
                      ),
                      children: [
                        const TextSpan(text: 'Nilai kemantapan (rentang '),
                        TextSpan(
                          text: '0.01 s/d 0.10',
                          style: TextStyle(
                            color: AppColors.skyText,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const TextSpan(
                          text: ') baru ditentukan di akhir setelah semua ',
                        ),
                        TextSpan(
                          text: '$totalJurus jurus',
                          style: TextStyle(
                            color: AppColors.amberText,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const TextSpan(text: ' selesai dinilai.'),
                      ],
                    ),
                  ),
                ),
                if (onSelectKemantapan != null) ...[
                  const SizedBox(height: 14),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'PILIH NILAI LANGSUNG (OPSIONAL)',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.8,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: values.map((v) {
                      final isSel = currentKemantapan == v;
                      return InkWell(
                        onTap: () {
                          onSelectKemantapan!(v);
                          Navigator.of(context).pop();
                        },
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 11,
                            vertical: 7,
                          ),
                          decoration: BoxDecoration(
                            color: isSel
                                ? AppColors.sky
                                : AppColors.surfaceSoft,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: isSel ? AppColors.sky : AppColors.border,
                            ),
                          ),
                          child: Text(
                            '+${v.toStringAsFixed(2)}',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w800,
                              fontFamily: 'monospace',
                              color: isSel
                                  ? Colors.white
                                  : AppColors.textPrimary,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.amber,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      elevation: 0,
                    ),
                    child: const Text(
                      'Lanjutkan Penilaian Jurus',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
