import 'package:flutter/material.dart';
import '../../../../models/scoring_models.dart';
import '../../../../services/gelanggang_sync_service.dart';
import '../../../../services/pusaka_seni_api_service.dart';
import '../../../../theme/app_theme.dart';

class AthleteSelectorDialog extends StatefulWidget {
  final AthleteModel currentAthlete;
  final SeniCategory currentCategory;
  final ValueChanged<AthleteModel> onAthleteSelected;
  final ValueChanged<SeniCategory> onCategoryChanged;
  final String? arenaCode;

  const AthleteSelectorDialog({
    super.key,
    required this.currentAthlete,
    required this.currentCategory,
    required this.onAthleteSelected,
    required this.onCategoryChanged,
    this.arenaCode,
  });

  @override
  State<AthleteSelectorDialog> createState() => _AthleteSelectorDialogState();
}

class _AthleteSelectorDialogState extends State<AthleteSelectorDialog> {
  List<AthleteModel> _athletes = [];
  bool _isLoading = true;
  String _searchQuery = '';
  SeniCategory? _selectedCategory;

  @override
  void initState() {
    super.initState();
    _selectedCategory = widget.currentCategory;
    _loadAthletes();
  }

  Future<void> _loadAthletes() async {
    setState(() => _isLoading = true);
    final sync = GelanggangSyncService.instance;
    final state = sync.getArenaState(widget.arenaCode ?? sync.activeArenaCode);
    final data = await PusakaSeniApiService().fetchPesertas(
      eventId: state.lockedEventId,
      eventDocId: state.lockedEventDocId,
      gelanggangDocId: state.lockedGelanggangDocId,
      rawArenaCode: state.lockedRawArenaCode,
    );
    if (mounted) {
      setState(() {
        _athletes = data;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final sync = GelanggangSyncService.instance;

    final filtered = _athletes.where((a) {
      final athCat = SeniCategory.fromString(a.category);
      final matchesCategory =
          _selectedCategory == null || athCat == _selectedCategory;
      final q = _searchQuery.toLowerCase().trim();
      final matchesSearch =
          q.isEmpty ||
          a.name.toLowerCase().contains(q) ||
          a.kontingen.toLowerCase().contains(q) ||
          a.partai.toLowerCase().contains(q);
      return matchesCategory && matchesSearch;
    }).toList();

    final maxH = MediaQuery.sizeOf(context).height * 0.90;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 540, maxHeight: maxH),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: AppDecorations.card(
            radius: 24,
            borderColor: AppColors.border,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(7),
                          decoration: BoxDecoration(
                            color: AppColors.primarySoft,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: AppColors.primaryBorder),
                          ),
                          child: const Icon(
                            Icons.gavel_rounded,
                            color: AppColors.primary,
                            size: 16,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            'Pilih Partai Pertandingan (Dewan)',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Row(
                    children: [
                      IconButton(
                        onPressed: _loadAthletes,
                        tooltip: 'Muat Ulang dari API',
                        icon: const Icon(
                          Icons.refresh_rounded,
                          color: AppColors.sky,
                          size: 18,
                        ),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(
                          minWidth: 30,
                          minHeight: 30,
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: Icon(
                          Icons.close_rounded,
                          color: AppColors.textMuted,
                          size: 20,
                        ),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(
                          minWidth: 30,
                          minHeight: 30,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (sync
                      .getArenaState(widget.arenaCode ?? sync.activeArenaCode)
                      .isVerified) ...[
                Builder(
                  builder: (context) {
                    final arenaState = sync.getArenaState(
                      widget.arenaCode ?? sync.activeArenaCode,
                    );
                    final evTitle = arenaState.lockedEventTitle;
                    final label = evTitle != null && evTitle.isNotEmpty
                        ? '$evTitle • ${arenaState.arenaCode}'
                        : arenaState.arenaCode;
                    return Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.emeraldSoft,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.emeraldBorder),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.lock_rounded,
                            size: 12,
                            color: AppColors.emerald,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'Terkunci: $label',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: AppColors.emeraldText,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],

              // Category Switcher Pills
              Text(
                'FILTER KATEGORI SENI',
                style: TextStyle(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                  color: AppColors.textMuted,
                ),
              ),
              const SizedBox(height: 6),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                child: Row(
                  children: [
                    _buildCategoryFilterChip(
                      label: 'Semua Kategori',
                      isSelected: _selectedCategory == null,
                      onTap: () {
                        setState(() => _selectedCategory = null);
                      },
                    ),
                    const SizedBox(width: 6),
                    ...SeniCategory.values.map((cat) {
                      final isSelected = _selectedCategory == cat;
                      return Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: _buildCategoryFilterChip(
                          label: cat.title,
                          isSelected: isSelected,
                          onTap: () {
                            setState(() => _selectedCategory = cat);
                            widget.onCategoryChanged(cat);
                          },
                        ),
                      );
                    }),
                  ],
                ),
              ),
              const SizedBox(height: 10),

              // Search Input
              Container(
                height: 38,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: AppDecorations.softTile(
                  radius: 12,
                  color: AppColors.surfaceSoft,
                  borderColor: AppColors.border,
                ),
                child: TextField(
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 12.5,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Cari nama atlet, kontingen, atau nomor partai...',
                    hintStyle: TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 11.5,
                    ),
                    prefixIcon: Icon(
                      Icons.search_rounded,
                      size: 16,
                      color: AppColors.textMuted,
                    ),
                    prefixIconConstraints: BoxConstraints(
                      minWidth: 26,
                      minHeight: 24,
                    ),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(vertical: 9),
                  ),
                  onChanged: (val) {
                    setState(() => _searchQuery = val);
                  },
                ),
              ),
              const SizedBox(height: 10),

              // Athletes List Header & Count
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      _selectedCategory == null
                          ? 'SEMUA PESERTA'
                          : 'PESERTA ${_selectedCategory!.title.toUpperCase()}',
                      style: TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.8,
                        color: AppColors.textMuted,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.skySoft,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.skyBorder),
                    ),
                    child: Text(
                      '${filtered.length} Peserta',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: AppColors.skyText,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),

              // Athletes List
              Expanded(
                child: _isLoading
                    ? const Center(
                        child: Padding(
                          padding: EdgeInsets.all(24),
                          child: CircularProgressIndicator(
                            color: AppColors.primary,
                            strokeWidth: 2.5,
                          ),
                        ),
                      )
                    : filtered.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Text(
                            _selectedCategory == null
                                ? 'Tidak ada peserta yang cocok.'
                                : 'Tidak ada peserta untuk kategori ${_selectedCategory!.title}.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      )
                    : ListView.separated(
                        shrinkWrap: true,
                        physics: const BouncingScrollPhysics(),
                        itemCount: filtered.length,
                        separatorBuilder: (context, index) =>
                            const SizedBox(height: 6),
                        itemBuilder: (context, index) {
                          final ath = filtered[index];
                          final isSelected =
                              widget.currentAthlete.documentId.isNotEmpty &&
                                  ath.documentId.isNotEmpty
                              ? widget.currentAthlete.documentId ==
                                    ath.documentId
                              : widget.currentAthlete.partai == ath.partai;

                          final bool isLiveNow = sync.isAthleteActive(ath);
                          final bool isCompleted = sync.isAthleteCompleted(ath);
                          final double? completedScore = sync.getAthleteScore(
                            ath,
                          );

                          return InkWell(
                            onTap: () {
                              final cat = SeniCategory.fromString(ath.category);
                              widget.onCategoryChanged(cat);
                              widget.onAthleteSelected(ath);
                              Navigator.of(context).pop();
                            },
                            borderRadius: BorderRadius.circular(14),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 9,
                              ),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? AppColors.primarySoft
                                    : (isLiveNow
                                          ? AppColors.tealSoft
                                          : AppColors.surfaceSoft),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: isSelected
                                      ? AppColors.primary
                                      : (isLiveNow
                                            ? AppColors.teal
                                            : (isCompleted
                                                  ? AppColors.emeraldBorder
                                                  : AppColors.border)),
                                  width: isSelected || isLiveNow ? 1.5 : 1.0,
                                ),
                              ),
                              child: Row(
                                children: [
                                  // Index Number Box
                                  Container(
                                    width: 28,
                                    height: 28,
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? AppColors.primary
                                          : (isLiveNow
                                                ? AppColors.teal
                                                : AppColors.surface),
                                      borderRadius: BorderRadius.circular(8),
                                      border: isSelected || isLiveNow
                                          ? null
                                          : Border.all(color: AppColors.border),
                                    ),
                                    child: Center(
                                      child: Text(
                                        '${index + 1}',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w800,
                                          color: isSelected || isLiveNow
                                              ? Colors.white
                                              : AppColors.textSecondary,
                                          fontSize: 11.5,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 9),

                                  // Athlete Details
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 6,
                                                    vertical: 2,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: AppColors.primary,
                                                borderRadius:
                                                    BorderRadius.circular(5),
                                              ),
                                              child: Text(
                                                ath.partai.toUpperCase(),
                                                style: const TextStyle(
                                                  fontSize: 8.5,
                                                  fontWeight: FontWeight.w900,
                                                  color: Colors.white,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 6),
                                            Expanded(
                                              child: Text(
                                                ath.name,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: TextStyle(
                                                  fontWeight: FontWeight.w800,
                                                  color: AppColors.textPrimary,
                                                  fontSize: 12.5,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          '${ath.kontingen} • ${ath.category.toUpperCase()} • ${ath.pool}',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            color: AppColors.textSecondary,
                                            fontSize: 10.5,
                                          ),
                                        ),
                                        const SizedBox(height: 5),
                                        _buildStatusBadge(
                                          isLiveNow: isLiveNow,
                                          isCompleted: isCompleted,
                                          completedScore: completedScore,
                                        ),
                                      ],
                                    ),
                                  ),

                                  if (isSelected) ...[
                                    const SizedBox(width: 6),
                                    const Icon(
                                      Icons.check_circle_rounded,
                                      color: AppColors.primary,
                                      size: 20,
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryFilterChip({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : AppColors.surfaceSoft,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.border,
            width: isSelected ? 1.4 : 1.0,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 10.5,
            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
            color: isSelected ? Colors.white : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBadge({
    required bool isLiveNow,
    required bool isCompleted,
    required double? completedScore,
  }) {
    if (isLiveNow) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: AppColors.primarySoft,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: AppColors.primaryBorder),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.circle, size: 6, color: AppColors.primary),
            SizedBox(width: 4),
            Text(
              'SEDANG TAMPIL',
              style: TextStyle(
                fontSize: 8.5,
                fontWeight: FontWeight.w900,
                color: AppColors.primaryText,
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
      );
    } else if (isCompleted) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: AppColors.emeraldSoft,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: AppColors.emeraldBorder),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.check_circle_rounded,
              size: 10,
              color: AppColors.emerald,
            ),
            const SizedBox(width: 4),
            Text(
              completedScore != null
                  ? 'SELESAI (${completedScore.toStringAsFixed(3)})'
                  : 'SELESAI TAMPIL',
              style: TextStyle(
                fontSize: 8.5,
                fontWeight: FontWeight.w900,
                color: AppColors.emeraldText,
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
      );
    } else {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: AppColors.surfaceMuted,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: AppColors.border),
        ),
        child: Text(
          'BELUM TAMPIL',
          style: TextStyle(
            fontSize: 8.5,
            fontWeight: FontWeight.w700,
            color: AppColors.textMuted,
            letterSpacing: 0.3,
          ),
        ),
      );
    }
  }
}
