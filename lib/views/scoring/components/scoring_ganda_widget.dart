import 'package:flutter/material.dart';
import '../../../models/scoring_models.dart';
import 'modals/confirm_ganda_dialog.dart';
import 'modals/reset_confirm_dialog.dart';

class ScoringGandaWidget extends StatefulWidget {
  final AthleteModel athlete;
  final int juriNumber;
  final SeniCategory category;
  final double? attackDefense;
  final double? firmnessHarmony;
  final double? soulfulness;
  final bool isJuriReady;
  final VoidCallback? onRequireReady;

  // Callbacks
  final ValueChanged<double> onSelectAttackDefense;
  final ValueChanged<double> onSelectFirmnessHarmony;
  final ValueChanged<double> onSelectSoulfulness;
  final VoidCallback onResetAction;
  final VoidCallback onSubmitScores;

  const ScoringGandaWidget({
    super.key,
    required this.athlete,
    required this.juriNumber,
    required this.category,
    required this.attackDefense,
    required this.firmnessHarmony,
    required this.soulfulness,
    this.isJuriReady = true,
    this.onRequireReady,
    required this.onSelectAttackDefense,
    required this.onSelectFirmnessHarmony,
    required this.onSelectSoulfulness,
    required this.onResetAction,
    required this.onSubmitScores,
  });

  static const double baseScore = 9.90;

  static final List<double> values30 = List.generate(
    30,
    (index) => double.parse(((index + 1) * 0.01).toStringAsFixed(2)),
  );

  @override
  State<ScoringGandaWidget> createState() => _ScoringGandaWidgetState();
}

class _ScoringGandaWidgetState extends State<ScoringGandaWidget> {
  int _activeAspectTab = 0; // For compact view (0: AD, 1: FH, 2: SF)

  @override
  Widget build(BuildContext context) {
    final double totalPenalty =
        (widget.attackDefense ?? 0.0) +
        (widget.firmnessHarmony ?? 0.0) +
        (widget.soulfulness ?? 0.0);
    final double totalScore = (ScoringGandaWidget.baseScore - totalPenalty)
        .clamp(0.0, ScoringGandaWidget.baseScore);
    final bool allFilled =
        widget.attackDefense != null &&
        widget.firmnessHarmony != null &&
        widget.soulfulness != null;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 720;

        return Column(
          children: [
            // Lock Banner if Juri Not Ready
            if (!widget.isJuriReady)
              Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF450A0A),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFDC2626)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.lock_rounded,
                      color: Color(0xFFEF4444),
                      size: 14,
                    ),
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
                      onTap: widget.onRequireReady,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
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

            // If compact screen, show a neat Tab Switcher for the 3 aspects
            if (!isWide) ...[_buildAspectTabBar(), const SizedBox(height: 6)],

            // Main aspect display: 3 columns if wide, active tab card if compact
            Expanded(
              child: isWide
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(child: _buildAttackDefenseCard()),
                        const SizedBox(width: 8),
                        Expanded(child: _buildFirmnessHarmonyCard()),
                        const SizedBox(width: 8),
                        Expanded(child: _buildSoulfulnessCard()),
                      ],
                    )
                  : _buildActiveCompactCard(),
            ),
            const SizedBox(height: 6),

            // Bottom bar
            _buildBottomBar(context, totalScore, allFilled),
          ],
        );
      },
    );
  }

  Widget _buildAspectTabBar() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF334155)),
      ),
      child: Row(
        children: [
          _buildTabItem(
            index: 0,
            label: '1. Serang Bela',
            value: widget.attackDefense,
            color: const Color(0xFF10B981),
          ),
          const SizedBox(width: 4),
          _buildTabItem(
            index: 1,
            label: '2. Kemantapan',
            value: widget.firmnessHarmony,
            color: const Color(0xFF38BDF8),
          ),
          const SizedBox(width: 4),
          _buildTabItem(
            index: 2,
            label: '3. Penjiwaan',
            value: widget.soulfulness,
            color: const Color(0xFFF59E0B),
          ),
        ],
      ),
    );
  }

  Widget _buildTabItem({
    required int index,
    required String label,
    required double? value,
    required Color color,
  }) {
    final isSelected = _activeAspectTab == index;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _activeAspectTab = index),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
          decoration: BoxDecoration(
            color: isSelected
                ? color.withValues(alpha: 0.2)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: isSelected ? color : Colors.transparent),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  color: isSelected ? Colors.white : const Color(0xFF94A3B8),
                ),
              ),
              const SizedBox(height: 1),
              Text(
                value != null
                    ? (value > 0 ? '-${value.toStringAsFixed(2)}' : '0.00')
                    : 'Belum',
                style: TextStyle(
                  fontSize: 10,
                  fontFamily: 'monospace',
                  fontWeight: FontWeight.bold,
                  color: value != null
                      ? (value > 0
                            ? const Color(0xFFEF4444)
                            : const Color(0xFF10B981))
                      : const Color(0xFF64748B),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActiveCompactCard() {
    switch (_activeAspectTab) {
      case 0:
        return _buildAttackDefenseCard();
      case 1:
        return _buildFirmnessHarmonyCard();
      case 2:
      default:
        return _buildSoulfulnessCard();
    }
  }

  Widget _buildAttackDefenseCard() {
    return _buildAspectCard(
      stepNumber: '1',
      title: 'Teknik Serang Bela',
      subtitle: 'Pengurangan Penalti (0.01 - 0.30)',
      value: widget.attackDefense,
      themeColor: const Color(0xFF10B981),
      onSelect: widget.onSelectAttackDefense,
    );
  }

  Widget _buildFirmnessHarmonyCard() {
    return _buildAspectCard(
      stepNumber: '2',
      title: 'Kemantapan & Keselarasan',
      subtitle: 'Pengurangan Penalti (0.01 - 0.30)',
      value: widget.firmnessHarmony,
      themeColor: const Color(0xFF38BDF8),
      onSelect: widget.onSelectFirmnessHarmony,
    );
  }

  Widget _buildSoulfulnessCard() {
    return _buildAspectCard(
      stepNumber: '3',
      title: 'Penjiwaan & Karakter',
      subtitle: 'Pengurangan Penalti (0.01 - 0.30)',
      value: widget.soulfulness,
      themeColor: const Color(0xFFF59E0B),
      onSelect: widget.onSelectSoulfulness,
    );
  }

  Widget _buildAspectCard({
    required String stepNumber,
    required String title,
    required String subtitle,
    required double? value,
    required Color themeColor,
    required ValueChanged<double> onSelect,
  }) {
    void onChanged(double v) {
      if (!widget.isJuriReady) {
        widget.onRequireReady?.call();
        return;
      }
      onSelect(v);
    }

    void onStepChange(double delta) {
      if (!widget.isJuriReady) {
        widget.onRequireReady?.call();
        return;
      }
      final next = ((value ?? 0.0) + delta).clamp(0.00, 0.30);
      onSelect(double.parse(next.toStringAsFixed(2)));
    }
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: value != null
              ? themeColor.withValues(alpha: 0.5)
              : const Color(0xFF334155),
          width: value != null ? 1.5 : 1.0,
        ),
      ),
      child: Column(
        children: [
          // Card Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      color: themeColor.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Center(
                      child: Text(
                        stepNumber,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: themeColor,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          fontSize: 8.5,
                          color: Color(0xFF94A3B8),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              // Current Value Display
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F172A),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: value != null
                        ? (value > 0
                              ? const Color(0xFFEF4444)
                              : const Color(0xFF10B981))
                        : const Color(0xFF334155),
                  ),
                ),
                child: Text(
                  value != null
                      ? (value > 0 ? '-${value.toStringAsFixed(2)}' : '0.00')
                      : 'Belum',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'monospace',
                    color: value != null
                        ? (value > 0
                              ? const Color(0xFFEF4444)
                              : const Color(0xFF10B981))
                        : const Color(0xFF64748B),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),

          // 0.00 Tanpa Penalti Button
          InkWell(
            onTap: () => onChanged(0.0),
            borderRadius: BorderRadius.circular(6),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 3.5),
              decoration: BoxDecoration(
                color: value == 0.0
                    ? const Color(0xFF10B981).withValues(alpha: 0.25)
                    : const Color(0xFF0F172A),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: value == 0.0
                      ? const Color(0xFF10B981)
                      : const Color(0xFF334155),
                ),
              ),
              child: Center(
                child: Text(
                  '0.00 (Tanpa Penalti / Sempurna)',
                  style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: value == 0.0
                        ? FontWeight.bold
                        : FontWeight.w600,
                    color: value == 0.0
                        ? const Color(0xFF34D399)
                        : const Color(0xFF94A3B8),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 4),

          // 30 Buttons Grid (5 cols x 6 rows)
          Expanded(
            child: GridView.builder(
              physics: const BouncingScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 5,
                mainAxisSpacing: 3.5,
                crossAxisSpacing: 3.5,
                childAspectRatio: 2.1,
              ),
              itemCount: ScoringGandaWidget.values30.length,
              itemBuilder: (context, index) {
                final v = ScoringGandaWidget.values30[index];
                final isSelected = value == v;

                return InkWell(
                  onTap: () => onChanged(v), // NO VIBRATION
                  borderRadius: BorderRadius.circular(6),
                  child: Container(
                    decoration: BoxDecoration(
                      color: isSelected
                          ? const Color(0xFFDC2626)
                          : const Color(0xFF0F172A),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: isSelected
                            ? const Color(0xFFEF4444)
                            : const Color(0xFF334155),
                      ),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: const Color(
                                  0xFFDC2626,
                                ).withValues(alpha: 0.35),
                                blurRadius: 4,
                              ),
                            ]
                          : null,
                    ),
                    child: Center(
                      child: Text(
                        '-${v.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: isSelected
                              ? FontWeight.bold
                              : FontWeight.w600,
                          fontFamily: 'monospace',
                          color: isSelected
                              ? Colors.white
                              : const Color(0xFFCBD5E1),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 4),

          // Quick Steppers
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: () => onStepChange(-0.01), // NO VIBRATION
                  borderRadius: BorderRadius.circular(6),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F172A),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFF334155)),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.remove, size: 12, color: Color(0xFFCBD5E1)),
                        SizedBox(width: 2),
                        Text(
                          '0.01',
                          style: TextStyle(
                            fontSize: 9.5,
                            color: Color(0xFFCBD5E1),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: InkWell(
                  onTap: () => onStepChange(0.01), // NO VIBRATION
                  borderRadius: BorderRadius.circular(6),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEF4444).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: const Color(0xFFEF4444).withValues(alpha: 0.4),
                      ),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.add, size: 12, color: Color(0xFFEF4444)),
                        SizedBox(width: 2),
                        Text(
                          '0.01',
                          style: TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFEF4444),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar(
    BuildContext context,
    double totalScore,
    bool allFilled,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF334155)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Left: Formula breakdown (scrollable or compact so it NEVER overflows)
          Flexible(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: Row(
                children: [
                  const Text(
                    'NILAI: ',
                    style: TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF94A3B8),
                    ),
                  ),
                  Text(
                    ScoringGandaWidget.baseScore.toStringAsFixed(2),
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'monospace',
                      color: Color(0xFF10B981),
                    ),
                  ),
                  const Text(
                    ' - ',
                    style: TextStyle(
                      color: Color(0xFFEF4444),
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    widget.attackDefense != null
                        ? widget.attackDefense!.toStringAsFixed(2)
                        : '0.00',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'monospace',
                      color: (widget.attackDefense ?? 0.0) > 0
                          ? const Color(0xFFFCA5A5)
                          : const Color(0xFF64748B),
                    ),
                  ),
                  const Text(
                    ' - ',
                    style: TextStyle(
                      color: Color(0xFFEF4444),
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    widget.firmnessHarmony != null
                        ? widget.firmnessHarmony!.toStringAsFixed(2)
                        : '0.00',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'monospace',
                      color: (widget.firmnessHarmony ?? 0.0) > 0
                          ? const Color(0xFFFCA5A5)
                          : const Color(0xFF64748B),
                    ),
                  ),
                  const Text(
                    ' - ',
                    style: TextStyle(
                      color: Color(0xFFEF4444),
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    widget.soulfulness != null
                        ? widget.soulfulness!.toStringAsFixed(2)
                        : '0.00',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'monospace',
                      color: (widget.soulfulness ?? 0.0) > 0
                          ? const Color(0xFFFCA5A5)
                          : const Color(0xFF64748B),
                    ),
                  ),
                  const Text(
                    ' = ',
                    style: TextStyle(
                      color: Color(0xFF94A3B8),
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    totalScore.toStringAsFixed(2),
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      fontFamily: 'monospace',
                      color: Color(0xFF38BDF8),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),

          // Right: Reset & Kirim Nilai
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              OutlinedButton(
                onPressed: () {
                  if (!widget.isJuriReady) {
                    widget.onRequireReady?.call();
                    return;
                  }
                  showDialog(
                    context: context,
                    builder: (_) => ResetConfirmDialog(
                      categoryTitle: widget.category.title,
                      juriNumber: widget.juriNumber,
                      isBaku: false,
                      onReset: widget.onResetAction,
                    ),
                  );
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF94A3B8),
                  side: const BorderSide(color: Color(0xFF334155)),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  minimumSize: const Size(48, 28),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
                child: const Text('Reset', style: TextStyle(fontSize: 10.5)),
              ),
              const SizedBox(width: 6),
              ElevatedButton.icon(
                onPressed: () {
                  if (!widget.isJuriReady) {
                    widget.onRequireReady?.call();
                    return;
                  }
                  if (!allFilled) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Lengkapi seluruh 3 aspek penilaian (Serang Bela, Kemantapan, Penjiwaan).',
                        ),
                        backgroundColor: Color(0xFFDC2626),
                      ),
                    );
                    return;
                  }

                  showDialog(
                    context: context,
                    builder: (_) => ConfirmGandaDialog(
                      juriNumber: widget.juriNumber,
                      categoryTitle: widget.category.title,
                      athleteName: widget.athlete.name,
                      attackDefense: widget.attackDefense ?? 0.0,
                      firmnessHarmony: widget.firmnessHarmony ?? 0.0,
                      soulfulness: widget.soulfulness ?? 0.0,
                      onConfirm: widget.onSubmitScores,
                    ),
                  );
                },
                icon: const Icon(Icons.send_rounded, size: 12),
                label: const Text(
                  'Kirim Nilai',
                  style: TextStyle(fontSize: 10.5),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFDC2626),
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: const Color(0xFF334155),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  minimumSize: const Size(80, 28),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
                  elevation: 0,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
