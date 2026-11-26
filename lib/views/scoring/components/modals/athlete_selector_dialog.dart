import 'package:flutter/material.dart';
import '../../../../models/scoring_models.dart';
import '../../../../services/gelanggang_sync_service.dart';
import '../../../../services/pusaka_seni_api_service.dart';

class AthleteSelectorDialog extends StatefulWidget {
  final AthleteModel currentAthlete;
  final SeniCategory currentCategory;
  final ValueChanged<AthleteModel> onAthleteSelected;
  final ValueChanged<SeniCategory> onCategoryChanged;

  const AthleteSelectorDialog({
    super.key,
    required this.currentAthlete,
    required this.currentCategory,
    required this.onAthleteSelected,
    required this.onCategoryChanged,
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
    final data = await PusakaSeniApiService().fetchPesertas();
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

    // Filter by selected category (instant filter) and search query
    final filtered = _athletes.where((a) {
      final athCat = SeniCategory.fromString(a.category);
      final matchesCategory = _selectedCategory == null || athCat == _selectedCategory;
      final q = _searchQuery.toLowerCase().trim();
      final matchesSearch = q.isEmpty ||
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
        constraints: BoxConstraints(maxWidth: 520, maxHeight: maxH),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.15),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.5),
                blurRadius: 25,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Expanded(
                    child: Row(
                      children: [
                        Icon(Icons.gavel_rounded, color: Color(0xFFDC2626), size: 18),
                        SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            'Pilih Partai Pertandingan (Dewan)',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
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
                        icon: const Icon(Icons.refresh_rounded, color: Color(0xFF38BDF8), size: 18),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close_rounded, color: Colors.white54, size: 20),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Category Switcher Pills with instant filter
              const Text(
                'FILTER KATEGORI SENI',
                style: TextStyle(
                  fontSize: 9.5,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.8,
                  color: Color(0xFF94A3B8),
                ),
              ),
              const SizedBox(height: 5),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                child: Row(
                  children: [
                    // All categories option
                    _buildCategoryFilterChip(
                      label: 'Semua Kategori',
                      isSelected: _selectedCategory == null,
                      onTap: () {
                        setState(() => _selectedCategory = null);
                      },
                    ),
                    const SizedBox(width: 6),
                    // Specific categories
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
                height: 36,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F172A),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFF334155)),
                ),
                child: TextField(
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                  decoration: const InputDecoration(
                    hintText: 'Cari nama atlet, kontingen, atau nomor partai...',
                    hintStyle: TextStyle(color: Color(0xFF64748B), fontSize: 11),
                    prefixIcon: Icon(Icons.search_rounded, size: 15, color: Color(0xFF94A3B8)),
                    prefixIconConstraints: BoxConstraints(minWidth: 24, minHeight: 24),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(vertical: 9),
                  ),
                  onChanged: (val) {
                    setState(() => _searchQuery = val);
                  },
                ),
              ),
              const SizedBox(height: 8),

              // Athletes List Header & Count
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      _selectedCategory == null
                          ? 'SEMUA PESERTA'
                          : 'PESERTA ${_selectedCategory!.title.toUpperCase()}',
                      style: const TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.8,
                        color: Color(0xFF94A3B8),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${filtered.length} Peserta',
                    style: const TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF38BDF8),
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
                            color: Color(0xFFDC2626),
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
                                style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                              ),
                            ),
                          )
                        : ListView.separated(
                            shrinkWrap: true,
                            physics: const BouncingScrollPhysics(),
                            itemCount: filtered.length,
                            separatorBuilder: (context, index) => const SizedBox(height: 6),
                            itemBuilder: (context, index) {
                              final ath = filtered[index];
                              final isSelected = widget.currentAthlete.documentId.isNotEmpty &&
                                      ath.documentId.isNotEmpty
                                  ? widget.currentAthlete.documentId == ath.documentId
                                  : widget.currentAthlete.partai == ath.partai;

                              final bool isLiveNow = sync.isAthleteActive(ath);
                              final bool isCompleted = sync.isAthleteCompleted(ath);
                              final double? completedScore = sync.getAthleteScore(ath);

                              return InkWell(
                                onTap: () {
                                  final cat = SeniCategory.fromString(ath.category);
                                  widget.onCategoryChanged(cat);
                                  widget.onAthleteSelected(ath);
                                  Navigator.of(context).pop();
                                },
                                borderRadius: BorderRadius.circular(12),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? const Color(0xFFDC2626).withValues(alpha: 0.15)
                                        : (isLiveNow
                                            ? const Color(0xFF0F766E).withValues(alpha: 0.15)
                                            : const Color(0xFF0F172A)),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: isSelected
                                          ? const Color(0xFFDC2626)
                                          : (isLiveNow
                                              ? const Color(0xFF14B8A6)
                                              : (isCompleted
                                                  ? const Color(0xFF059669).withValues(alpha: 0.4)
                                                  : const Color(0xFF334155))),
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
                                              ? const Color(0xFFDC2626)
                                              : (isLiveNow
                                                  ? const Color(0xFF0F766E)
                                                  : const Color(0xFF1E293B)),
                                          borderRadius: BorderRadius.circular(7),
                                        ),
                                        child: Center(
                                          child: Text(
                                            '${index + 1}',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: Colors.white,
                                              fontSize: 11.5,
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),

                                      // Athlete Details
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                // Partai Tag
                                                Container(
                                                  padding: const EdgeInsets.symmetric(
                                                      horizontal: 5, vertical: 1.5),
                                                  decoration: BoxDecoration(
                                                    color: const Color(0xFFDC2626),
                                                    borderRadius: BorderRadius.circular(4),
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
                                                // Name
                                                Expanded(
                                                  child: Text(
                                                    ath.name,
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                    style: const TextStyle(
                                                      fontWeight: FontWeight.bold,
                                                      color: Colors.white,
                                                      fontSize: 12,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 2),
                                            // Kontingen & Category Subtitle
                                            Text(
                                              '${ath.kontingen} • ${ath.category.toUpperCase()} • ${ath.pool}',
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                color: Color(0xFF94A3B8),
                                                fontSize: 10,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            // Performance Status Badge (Sedang Tampil / Selesai Tampil / Belum Tampil)
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
                                          color: Color(0xFFEF4444),
                                          size: 18,
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
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFDC2626) : const Color(0xFF0F172A),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? const Color(0xFFEF4444) : const Color(0xFF334155),
            width: isSelected ? 1.4 : 1.0,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 10.5,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected ? Colors.white : const Color(0xFFCBD5E1),
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
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
        decoration: BoxDecoration(
          color: const Color(0xFFDC2626).withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(5),
          border: Border.all(color: const Color(0xFFEF4444)),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.circle, size: 6, color: Color(0xFFEF4444)),
            SizedBox(width: 3),
            Text(
              'SEDANG TAMPIL',
              style: TextStyle(
                fontSize: 8.5,
                fontWeight: FontWeight.w900,
                color: Color(0xFFFCA5A5),
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
      );
    } else if (isCompleted) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
        decoration: BoxDecoration(
          color: const Color(0xFF065F46).withValues(alpha: 0.35),
          borderRadius: BorderRadius.circular(5),
          border: Border.all(color: const Color(0xFF10B981)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle_rounded, size: 9, color: Color(0xFF34D399)),
            const SizedBox(width: 3),
            Text(
              completedScore != null
                  ? 'SELESAI (${completedScore.toStringAsFixed(3)})'
                  : 'SELESAI TAMPIL',
              style: const TextStyle(
                fontSize: 8.5,
                fontWeight: FontWeight.w900,
                color: Color(0xFF6EE7B7),
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
      );
    } else {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
        decoration: BoxDecoration(
          color: const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(5),
          border: Border.all(color: const Color(0xFF475569)),
        ),
        child: const Text(
          'BELUM TAMPIL',
          style: TextStyle(
            fontSize: 8,
            fontWeight: FontWeight.bold,
            color: Color(0xFF94A3B8),
            letterSpacing: 0.3,
          ),
        ),
      );
    }
  }
}
