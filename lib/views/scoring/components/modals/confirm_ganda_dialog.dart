import 'package:flutter/material.dart';

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
        constraints: BoxConstraints(maxWidth: 390, maxHeight: maxH),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: const Color(0xFFDC2626).withValues(alpha: 0.35),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.5),
                blurRadius: 25,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Icon Header
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: const Color(0xFFDC2626).withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color(0xFFDC2626).withValues(alpha: 0.3),
                    ),
                  ),
                  child: const Icon(
                    Icons.emoji_events_rounded,
                    color: Color(0xFFEF4444),
                    size: 28,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Konfirmasi Nilai $categoryTitle',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                RichText(
                  textAlign: TextAlign.center,
                  text: TextSpan(
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF94A3B8),
                    ),
                    children: [
                      TextSpan(
                        text:
                            'Pastikan seluruh aspek penilaian Juri $juriNumber untuk pesilat ',
                      ),
                      TextSpan(
                        text: athleteName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
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
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F172A),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFF334155)),
                  ),
                  child: Column(
                    children: [
                      _buildAspectRow(
                        'Nilai Awal Penampilan',
                        '9.90',
                        color: const Color(0xFF38BDF8),
                      ),
                      const Divider(color: Color(0xFF334155), height: 16),
                      _buildAspectRow(
                        '1. Penalti Serang Bela',
                        '-${attackDefense.toStringAsFixed(2)}',
                        color: attackDefense > 0
                            ? const Color(0xFFEF4444)
                            : const Color(0xFF94A3B8),
                      ),
                      const SizedBox(height: 8),
                      _buildAspectRow(
                        '2. Penalti Kemantapan & Keselarasan',
                        '-${firmnessHarmony.toStringAsFixed(2)}',
                        color: firmnessHarmony > 0
                            ? const Color(0xFFEF4444)
                            : const Color(0xFF94A3B8),
                      ),
                      const SizedBox(height: 8),
                      _buildAspectRow(
                        '3. Penalti Penjiwaan & Karakter',
                        '-${soulfulness.toStringAsFixed(2)}',
                        color: soulfulness > 0
                            ? const Color(0xFFEF4444)
                            : const Color(0xFF94A3B8),
                      ),
                      const Divider(color: Color(0xFF334155), height: 16),
                      _buildAspectRow(
                        'Total Pengurangan (Penalti)',
                        '-${totalPenalty.toStringAsFixed(2)}',
                        color: totalPenalty > 0
                            ? const Color(0xFFF87171)
                            : const Color(0xFF94A3B8),
                      ),
                      const Divider(color: Color(0xFF334155), height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              'Total Nilai Akhir Juri $juriNumber:',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
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
                              color: Color(0xFF10B981),
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
                          foregroundColor: const Color(0xFF94A3B8),
                          side: const BorderSide(color: Color(0xFF475569)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            'Periksa Lagi',
                            style: TextStyle(fontWeight: FontWeight.w600),
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
                          child: Text('Kirim Nilai'),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFDC2626),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
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
              fontSize: 13,
              color: color,
              fontWeight: FontWeight.bold,
              fontFamily: 'monospace',
            ),
          ),
        ),
      ],
    );
  }
}
