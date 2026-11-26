import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/pusaka_seni_api_service.dart';

class ScoringPortalView extends StatefulWidget {
  final VoidCallback onSelectDewan;
  final VoidCallback onSelectJuri;
  final VoidCallback onSelectTimekeeper;
  final VoidCallback onSelectMonitoring;

  const ScoringPortalView({
    super.key,
    required this.onSelectDewan,
    required this.onSelectJuri,
    required this.onSelectTimekeeper,
    required this.onSelectMonitoring,
  });

  @override
  State<ScoringPortalView> createState() => _ScoringPortalViewState();
}

class _ScoringPortalViewState extends State<ScoringPortalView> {
  bool _isFullScreen = false;
  bool _isLoadingData = true;

  // Live Server Data
  String _eventTitle = 'KEJUARAAN PENCAK SILAT';
  String _eventCode = 'ABT-87645';
  int _totalPeserta = 25;
  int _activeArenas = 2;

  @override
  void initState() {
    super.initState();
    _loadLiveTournamentData();
  }

  Future<void> _loadLiveTournamentData() async {
    setState(() => _isLoadingData = true);
    try {
      final event = await PusakaSeniApiService().fetchActiveEvent();
      final pesertas = await PusakaSeniApiService().fetchPesertas();
      final gelanggangs = await PusakaSeniApiService().fetchGelanggangs();

      if (mounted) {
        setState(() {
          if (event != null) {
            _eventTitle = event['event_title']?.toString() ?? 'KEJUARAAN PENCAK SILAT';
            _eventCode = event['event_code']?.toString() ?? 'LIVE';
          }
          _totalPeserta = pesertas.length;
          _activeArenas = gelanggangs.length;
          _isLoadingData = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingData = false);
    }
  }

  void _toggleFullScreen() {
    setState(() => _isFullScreen = !_isFullScreen);
    if (_isFullScreen) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    } else {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: SafeArea(
        top: !_isFullScreen,
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Column(
            children: [
              // 1. Top Header Bar
              _buildTopBar(),
              const SizedBox(height: 8),

              // 2. Live Tournament Status Bar (Data from API)
              _buildLiveStatusBar(),
              const SizedBox(height: 10),

              // 3. 4 Module Cards Grid / List (Fully Responsive)
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final isWide = constraints.maxWidth > 860;
                    final isMedium = constraints.maxWidth > 560;
                    final roleCards = _buildRoleCards();

                    if (!isMedium) {
                      // Small Mobile Screen: ListView ensures ZERO OVERFLOW
                      return ListView.separated(
                        physics: const BouncingScrollPhysics(),
                        itemCount: roleCards.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 10),
                        itemBuilder: (_, index) => roleCards[index],
                      );
                    }

                    // Tablet / Desktop Grid
                    return GridView.count(
                      crossAxisCount: isWide ? 4 : 2,
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                      childAspectRatio: isWide ? 0.70 : 0.92,
                      physics: const BouncingScrollPhysics(),
                      children: roleCards,
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

  List<Widget> _buildRoleCards() {
    return [
      _buildRoleCard(
        badgeText: 'Otoritas',
        badgeBg: const Color(0xFF450A0A),
        badgeBorder: const Color(0xFF991B1B),
        badgeTextColor: const Color(0xFFFCA5A5),
        icon: Icons.shield_rounded,
        iconGradient: const [Color(0xFFDC2626), Color(0xFF991B1B)],
        title: 'Dewan Pertandingan',
        subtitle: 'Ketua & Pengawas Partai',
        description:
            'Pusat kendali pengawasan skor multi-juri, hukuman penalti, dan pengesahan hasil akhir.',
        checkpoints: const [
          'Monitoring Skor Multi-Juri',
          'Input Hukuman Dewan',
          'Pengesahan & Penetapan Juara',
        ],
        accentColor: const Color(0xFFDC2626),
        actionLabel: 'Masuk Dewan',
        onTap: widget.onSelectDewan,
      ),
      _buildRoleCard(
        badgeText: 'Penilai',
        badgeBg: const Color(0xFF451A03),
        badgeBorder: const Color(0xFFB45309),
        badgeTextColor: const Color(0xFFFDE68A),
        icon: Icons.balance_rounded,
        iconGradient: const [Color(0xFFD97706), Color(0xFFB45309)],
        title: 'Juri Pertandingan',
        subtitle: 'Juri 1 s/d Juri 8',
        description:
            'Keypad sentuh juri untuk Tunggal, Ganda, Beregu, dan Solo Kreatif.',
        checkpoints: const [
          'Keypad Sentuh Juri 1 s/d 8',
          'Seni Baku 14 & 12 Jurus',
          '3 Aspek Penilaian Seni Ganda',
        ],
        accentColor: const Color(0xFFF59E0B),
        actionLabel: 'Masuk Juri',
        onTap: widget.onSelectJuri,
      ),
      _buildRoleCard(
        badgeText: 'Waktu',
        badgeBg: const Color(0xFF042F2E),
        badgeBorder: const Color(0xFF0F766E),
        badgeTextColor: const Color(0xFF99F6E4),
        icon: Icons.timer_rounded,
        iconGradient: const [Color(0xFF0D9488), Color(0xFF047857)],
        title: 'Time Keeper',
        subtitle: 'Pengendali Timer Global',
        description:
            'Pengatur waktu resmi 03:00, 01:20, dan 01:40 dengan sinkronisasi ke seluruh layar.',
        checkpoints: const [
          'Preset 03:00 / 01:20 / 01:40',
          'Countdown & Waktu Berjalan',
          'Peringatan 10 Detik Terakhir',
        ],
        accentColor: const Color(0xFF14B8A6),
        actionLabel: 'Masuk Time Keeper',
        onTap: widget.onSelectTimekeeper,
      ),
      _buildRoleCard(
        badgeText: 'Display',
        badgeBg: const Color(0xFF172554),
        badgeBorder: const Color(0xFF1D4ED8),
        badgeTextColor: const Color(0xFFBFDBFE),
        icon: Icons.tv_rounded,
        iconGradient: const [Color(0xFF2563EB), Color(0xFF1D4ED8)],
        title: 'Monitoring Scoreboard',
        subtitle: 'Display Penonton & Arena',
        description:
            'Papan skor visual layar lebar untuk penonton, official, dan atlet arena.',
        checkpoints: const [
          'Papan Skor Arena Layar Lebar',
          'Status Multi-Juri Real-Time',
          'Skor Resmi Akhir & Penalti',
        ],
        accentColor: const Color(0xFF3B82F6),
        actionLabel: 'Masuk Monitoring',
        onTap: widget.onSelectMonitoring,
      ),
    ];
  }

  Widget _buildLiveStatusBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF334155)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: const Color(0xFF10B981).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Icon(Icons.cloud_done_rounded, color: Color(0xFF10B981), size: 14),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: Row(
                children: [
                  Text(
                    '$_eventTitle ($_eventCode)',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F172A),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: const Color(0xFF334155)),
                    ),
                    child: Text(
                      '$_totalPeserta Peserta',
                      style: const TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF38BDF8),
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F172A),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: const Color(0xFF334155)),
                    ),
                    child: Text(
                      '$_activeArenas Gelanggang',
                      style: const TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF10B981),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          IconButton(
            onPressed: _loadLiveTournamentData,
            tooltip: 'Segarkan data dari server',
            icon: _isLoadingData
                ? const SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF38BDF8)),
                  )
                : const Icon(Icons.refresh_rounded, size: 14, color: Color(0xFF38BDF8)),
            constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
            padding: EdgeInsets.zero,
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF334155),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              color: const Color(0xFF0F172A),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFD97706).withValues(alpha: 0.5)),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFF59E0B).withValues(alpha: 0.25),
                  blurRadius: 6,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: Image.asset(
                'assets/images/app_logo_small.png',
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) => const Icon(
                  Icons.sports_martial_arts_rounded,
                  color: Color(0xFFF59E0B),
                  size: 20,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),

          // Portal Title
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'PUSAKA SENI SCORING IPSI',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.8,
                    color: Colors.white,
                  ),
                ),
                Text(
                  'Sistem Digital Penilaian Seni Pencak Silat Indonesia',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 9.5,
                    color: Color(0xFF94A3B8),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),

          // Fullscreen Toggle Button
          IconButton(
            onPressed: _toggleFullScreen,
            icon: Icon(
              _isFullScreen
                  ? Icons.fullscreen_exit_rounded
                  : Icons.fullscreen_rounded,
              size: 16,
              color: const Color(0xFFCBD5E1),
            ),
            tooltip: 'Layar Penuh',
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
            padding: EdgeInsets.zero,
            style: IconButton.styleFrom(
              backgroundColor: const Color(0xFF0F172A),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRoleCard({
    required String badgeText,
    required Color badgeBg,
    required Color badgeBorder,
    required Color badgeTextColor,
    required IconData icon,
    required List<Color> iconGradient,
    required String title,
    required String subtitle,
    required String description,
    required List<String> checkpoints,
    required Color accentColor,
    required String actionLabel,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0xFF334155),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header Card (Badge & Icon)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: iconGradient,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: Colors.white, size: 20),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: badgeBg,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: badgeBorder),
                ),
                child: Text(
                  badgeText.toUpperCase(),
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.6,
                    color: badgeTextColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Titles
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          Text(
            subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: accentColor,
            ),
          ),
          const SizedBox(height: 6),

          // Description
          Text(
            description,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 10.5,
              color: Color(0xFF94A3B8),
              height: 1.3,
            ),
          ),
          const SizedBox(height: 8),

          // Checkpoints
          ...checkpoints.map((cp) => Padding(
                padding: const EdgeInsets.only(bottom: 3),
                child: Row(
                  children: [
                    Icon(Icons.check_circle_rounded, size: 12, color: accentColor),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        cp,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 10,
                          color: Color(0xFFCBD5E1),
                        ),
                      ),
                    ),
                  ],
                ),
              )),
          const SizedBox(height: 10),

          // Action Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: onTap,
              icon: const Icon(Icons.arrow_forward_rounded, size: 14),
              label: Text(
                actionLabel,
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: accentColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                elevation: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
