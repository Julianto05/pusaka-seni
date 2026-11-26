import 'package:flutter/material.dart';
import '../../../../theme/app_theme.dart';

class ConfirmKemantapanDialog extends StatelessWidget {
  final int juriNumber;
  final String athleteName;
  final double kemantapan;
  final double kebenaran;
  final VoidCallback onConfirm;

  const ConfirmKemantapanDialog({
    super.key,
    required this.juriNumber,
    required this.athleteName,
    required this.kemantapan,
    required this.kebenaran,
    required this.onConfirm,
  });

  @override
  Widget build(BuildContext context) {
    final double totalSkor = kebenaran + kemantapan;
    final maxH = MediaQuery.sizeOf(context).height * 0.90;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 400, maxHeight: maxH),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: AppDecorations.card(
            radius: 24,
            borderColor: AppColors.skyBorder,
            borderWidth: 1.4,
          ),
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Icon Header
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: AppColors.skySoft,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.skyBorder),
                      ),
                      child: const Icon(
                        Icons.military_tech_rounded,
                        color: AppColors.sky,
                        size: 26,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Konfirmasi Kemantapan',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Juri $juriNumber • $athleteName',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Description
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 11,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.skySoft,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.skyBorder),
                  ),
                  child: RichText(
                    textAlign: TextAlign.center,
                    text: TextSpan(
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textPrimary,
                      ),
                      children: [
                        const TextSpan(text: 'Tetapkan nilai kemantapan '),
                        TextSpan(
                          text: '+${kemantapan.toStringAsFixed(2)}',
                          style: TextStyle(
                            color: AppColors.skyText,
                            fontWeight: FontWeight.w900,
                            fontSize: 15,
                          ),
                        ),
                        const TextSpan(text: ' dan simpan ke penilaian?'),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Data Table
                Container(
                  padding: const EdgeInsets.all(13),
                  decoration: AppDecorations.softTile(
                    radius: 16,
                    color: AppColors.surfaceSoft,
                    borderColor: AppColors.border,
                  ),
                  child: Column(
                    children: [
                      _buildRow(
                        'Keterangan:',
                        'nilai kemantapan',
                        valueColor: AppColors.textPrimary,
                      ),
                      const SizedBox(height: 6),
                      _buildRow(
                        'Penilai:',
                        'juri $juriNumber',
                        valueColor: AppColors.textSecondary,
                      ),
                      const SizedBox(height: 6),
                      _buildRow(
                        'Nilai Kemantapan:',
                        '+${kemantapan.toStringAsFixed(2)}',
                        valueColor: AppColors.sky,
                        isBold: true,
                      ),
                      Divider(color: AppColors.border, height: 16),
                      _buildRow(
                        'Total Skor Akhir:',
                        totalSkor.toStringAsFixed(2),
                        valueColor: AppColors.primary,
                        isBold: true,
                        fontSize: 16,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

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
                        child: const Text(
                          'Batal',
                          style: TextStyle(fontWeight: FontWeight.w700),
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
                        icon: const Icon(Icons.check_rounded, size: 18),
                        label: const Text(
                          'Ya, Simpan',
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.sky,
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

  Widget _buildRow(
    String label,
    String value, {
    Color? valueColor,
    bool isBold = false,
    double fontSize = 12.5,
  }) {
    final resolvedValueColor = valueColor ?? AppColors.textPrimary;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11.5,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w500,
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
              fontSize: fontSize,
              color: resolvedValueColor,
              fontWeight: isBold ? FontWeight.w800 : FontWeight.w600,
              fontFamily: isBold ? 'monospace' : null,
            ),
          ),
        ),
      ],
    );
  }
}
