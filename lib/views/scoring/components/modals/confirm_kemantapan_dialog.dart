import 'package:flutter/material.dart';

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
        constraints: BoxConstraints(maxWidth: 390, maxHeight: maxH),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: const Color(0xFF38BDF8).withValues(alpha: 0.35),
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
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: const Color(0xFF0284C7).withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: const Color(0xFF0284C7).withValues(alpha: 0.4),
                      ),
                    ),
                    child: const Icon(
                      Icons.military_tech_rounded,
                      color: Color(0xFF38BDF8),
                      size: 26,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Konfirmasi Kemantapan',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Juri $juriNumber • $athleteName',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF94A3B8),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Description
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F172A),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF334155)),
                ),
                child: RichText(
                  textAlign: TextAlign.center,
                  text: TextSpan(
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFFCBD5E1),
                    ),
                    children: [
                      const TextSpan(text: 'Tetapkan nilai kemantapan '),
                      TextSpan(
                        text: '+${kemantapan.toStringAsFixed(2)}',
                        style: const TextStyle(
                          color: Color(0xFF38BDF8),
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      const TextSpan(text: ' dan simpan ke penilaian?'),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // Data Table
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F172A),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFF334155)),
                ),
                child: Column(
                  children: [
                    _buildRow(
                      'Keterangan:',
                      'nilai kemantapan',
                      valueColor: Colors.white,
                    ),
                    const SizedBox(height: 6),
                    _buildRow(
                      'Penilai:',
                      'juri $juriNumber',
                      valueColor: const Color(0xFF94A3B8),
                    ),
                    const SizedBox(height: 6),
                    _buildRow(
                      'Nilai Kemantapan:',
                      '+${kemantapan.toStringAsFixed(2)}',
                      valueColor: const Color(0xFF38BDF8),
                      isBold: true,
                    ),
                    const Divider(color: Color(0xFF334155), height: 16),
                    _buildRow(
                      'Total Skor Akhir:',
                      totalSkor.toStringAsFixed(2),
                      valueColor: const Color(0xFFEF4444),
                      isBold: true,
                      fontSize: 16,
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
                      child: const Text(
                        'Batal',
                        style: TextStyle(fontWeight: FontWeight.w600),
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
                      label: const Text('Ya, Simpan'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0284C7),
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

  Widget _buildRow(
    String label,
    String value, {
    Color valueColor = Colors.white,
    bool isBold = false,
    double fontSize = 12.5,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 11.5,
              color: Color(0xFF94A3B8),
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
              color: valueColor,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              fontFamily: isBold ? 'monospace' : null,
            ),
          ),
        ),
      ],
    );
  }
}
