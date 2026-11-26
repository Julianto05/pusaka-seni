import 'package:flutter/material.dart';
import '../../../models/scoring_models.dart';
import '../../../theme/app_theme.dart';
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
                margin: const EdgeInsets.only(bottom: 7),
                padding: const EdgeInsets.symmetric(
                  horizontal: 11,
                  vertical: 6,
                ),
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
                      onTap: widget.onRequireReady,
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

            // If compact screen, show a neat Tab Switcher for the 3 aspects
            if (!isWide) ...[_buildAspectTabBar(), const SizedBox(height: 6)],

            // Main aspect display
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
            const SizedBox(height: 7),

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
      decoration: AppDecorations.card(
        radius: 14,
        borderColor: AppColors.border,
        elevated: false,
      ),
      child: Row(
        children: [
          _buildTabItem(
            index: 0,
            label: '1. Serang Bela',
            value: widget.attackDefense,
            color: AppColors.emerald,
          ),
          const SizedBox(width: 4),
          _buildTabItem(
            index: 1,
            label: '2. Kemantapan',
            value: widget.firmnessHarmony,
            color: AppColors.sky,
          ),
          const SizedBox(width: 4),
          _buildTabItem(
            index: 2,
            label: '3. Penjiwaan',
            value: widget.soulfulness,
            color: AppColors.amber,
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
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
          decoration: BoxDecoration(
            color: isSelected
                ? color.withValues(alpha: 0.12)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? color : Colors.transparent,
              width: 1.2,
            ),
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
                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                  color: isSelected
                      ? AppColors.textPrimary
                      : AppColors.textSecondary,
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
                  fontWeight: FontWeight.w800,
                  color: value != null
                      ? (value > 0 ? AppColors.primary : AppColors.emerald)
                      : AppColors.textMuted,
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
      themeColor: AppColors.emerald,
      onSelect: widget.onSelectAttackDefense,
    );
  }

  Widget _buildFirmnessHarmonyCard() {
    return _buildAspectCard(
      stepNumber: '2',
      title: 'Kemantapan & Keselarasan',
      subtitle: 'Pengurangan Penalti (0.01 - 0.30)',
      value: widget.firmnessHarmony,
      themeColor: AppColors.sky,
      onSelect: widget.onSelectFirmnessHarmony,
    );
  }

  Widget _buildSoulfulnessCard() {
    return _buildAspectCard(
      stepNumber: '3',
      title: 'Penjiwaan & Karakter',
      subtitle: 'Pengurangan Penalti (0.01 - 0.30)',
      value: widget.soulfulness,
      themeColor: AppColors.amber,
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
      padding: const EdgeInsets.all(10),
      decoration: AppDecorations.card(
        radius: 18,
        borderColor: value != null
            ? themeColor.withValues(alpha: 0.45)
            : AppColors.border,
        borderWidth: value != null ? 1.4 : 1.0,
      ),
      child: Column(
        children: [
          // Card Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: themeColor.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: themeColor.withValues(alpha: 0.35),
                        ),
                      ),
                      child: Center(
                        child: Text(
                          stepNumber,
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w900,
                            color: themeColor,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 7),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          Text(
                            subtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 8.5,
                              color: AppColors.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              // Current Value Display
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: value != null
                      ? (value > 0
                            ? AppColors.primarySoft
                            : AppColors.emeraldSoft)
                      : AppColors.surfaceSoft,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: value != null
                        ? (value > 0
                              ? AppColors.primaryBorder
                              : AppColors.emeraldBorder)
                        : AppColors.border,
                  ),
                ),
                child: Text(
                  value != null
                      ? (value > 0 ? '-${value.toStringAsFixed(2)}' : '0.00')
                      : 'Belum',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    fontFamily: 'monospace',
                    color: value != null
                        ? (value > 0
                              ? AppColors.primary
                              : AppColors.emeraldText)
                        : AppColors.textMuted,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),

          // 0.00 Tanpa Penalti Button
          InkWell(
            onTap: () => onChanged(0.0),
            borderRadius: BorderRadius.circular(8),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 4.5),
              decoration: BoxDecoration(
                color: value == 0.0
                    ? AppColors.emeraldSoft
                    : AppColors.surfaceSoft,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: value == 0.0 ? AppColors.emerald : AppColors.border,
                  width: value == 0.0 ? 1.3 : 1.0,
                ),
              ),
              child: Center(
                child: Text(
                  '0.00 (Tanpa Penalti / Sempurna)',
                  style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: value == 0.0
                        ? FontWeight.w800
                        : FontWeight.w600,
                    color: value == 0.0
                        ? AppColors.emeraldText
                        : AppColors.textSecondary,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 5),

          // 30 Buttons Grid (5 cols x 6 rows)
          Expanded(
            child: GridView.builder(
              physics: const BouncingScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 5,
                mainAxisSpacing: 4,
                crossAxisSpacing: 4,
                childAspectRatio: 2.1,
              ),
              itemCount: ScoringGandaWidget.values30.length,
              itemBuilder: (context, index) {
                final v = ScoringGandaWidget.values30[index];
                final isSelected = value == v;

                return InkWell(
                  onTap: () => onChanged(v),
                  borderRadius: BorderRadius.circular(7),
                  child: Container(
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppColors.primary
                          : AppColors.surfaceSoft,
                      borderRadius: BorderRadius.circular(7),
                      border: Border.all(
                        color: isSelected
                            ? AppColors.primary
                            : AppColors.border,
                      ),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: AppColors.primary.withValues(alpha: 0.3),
                                blurRadius: 5,
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
                              ? FontWeight.w800
                              : FontWeight.w600,
                          fontFamily: 'monospace',
                          color: isSelected
                              ? Colors.white
                              : AppColors.textPrimary,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 5),

          // Quick Steppers
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: () => onStepChange(-0.01),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 5),
                    decoration: AppDecorations.softTile(
                      radius: 8,
                      color: AppColors.surfaceSoft,
                      borderColor: AppColors.border,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.remove,
                          size: 12,
                          color: AppColors.textSecondary,
                        ),
                        SizedBox(width: 2),
                        Text(
                          '0.01',
                          style: TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textSecondary,
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
                  onTap: () => onStepChange(0.01),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 5),
                    decoration: BoxDecoration(
                      color: AppColors.primarySoft,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.primaryBorder),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.add, size: 12, color: AppColors.primary),
                        SizedBox(width: 2),
                        Text(
                          '0.01',
                          style: TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w800,
                            color: AppColors.primaryText,
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
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
      decoration: AppDecorations.card(
        radius: 15,
        borderColor: AppColors.border,
        elevated: false,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: Row(
                children: [
                  Text(
                    'NILAI: ',
                    style: TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textMuted,
                    ),
                  ),
                  Text(
                    ScoringGandaWidget.baseScore.toStringAsFixed(2),
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800,
                      fontFamily: 'monospace',
                      color: AppColors.emerald,
                    ),
                  ),
                  const Text(
                    ' - ',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    widget.attackDefense != null
                        ? widget.attackDefense!.toStringAsFixed(2)
                        : '0.00',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800,
                      fontFamily: 'monospace',
                      color: (widget.attackDefense ?? 0.0) > 0
                          ? AppColors.primary
                          : AppColors.textMuted,
                    ),
                  ),
                  const Text(
                    ' - ',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    widget.firmnessHarmony != null
                        ? widget.firmnessHarmony!.toStringAsFixed(2)
                        : '0.00',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800,
                      fontFamily: 'monospace',
                      color: (widget.firmnessHarmony ?? 0.0) > 0
                          ? AppColors.primary
                          : AppColors.textMuted,
                    ),
                  ),
                  const Text(
                    ' - ',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    widget.soulfulness != null
                        ? widget.soulfulness!.toStringAsFixed(2)
                        : '0.00',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800,
                      fontFamily: 'monospace',
                      color: (widget.soulfulness ?? 0.0) > 0
                          ? AppColors.primary
                          : AppColors.textMuted,
                    ),
                  ),
                  Text(
                    ' = ',
                    style: TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    totalScore.toStringAsFixed(2),
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w900,
                      fontFamily: 'monospace',
                      color: AppColors.skyText,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
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
                  foregroundColor: AppColors.textSecondary,
                  side: BorderSide(color: AppColors.borderStrong),
                  backgroundColor: AppColors.surfaceSoft,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 4,
                  ),
                  minimumSize: const Size(50, 30),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(9),
                  ),
                ),
                child: const Text(
                  'Reset',
                  style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700),
                ),
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
                        backgroundColor: AppColors.primary,
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
                  style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: AppColors.borderStrong,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 11,
                    vertical: 4,
                  ),
                  minimumSize: const Size(84, 30),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(9),
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
