import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/link.dart';
import '../../services/app_link_helper.dart';
import '../../services/gelanggang_sync_service.dart';
import '../../services/pusaka_seni_api_service.dart';
import '../../theme/app_theme.dart';

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
  bool _isLoadingData = false;
  int _arenaPesertaCount = 0;

  @override
  void initState() {
    super.initState();
    GelanggangSyncService.instance.addListener(_handleSyncUpdate);
    if (GelanggangSyncService.instance.isGelanggangVerified) {
      _loadVerifiedArenaData();
    }
  }

  @override
  void dispose() {
    GelanggangSyncService.instance.removeListener(_handleSyncUpdate);
    super.dispose();
  }

  void _handleSyncUpdate() {
    if (!mounted) return;
    setState(() {});
    if (GelanggangSyncService.instance.isGelanggangVerified &&
        GelanggangSyncService.instance.lastSyncAction == 'GELANGGANG_VERIFIED') {
      _loadVerifiedArenaData();
    }
  }

  Future<void> _loadVerifiedArenaData() async {
    final sync = GelanggangSyncService.instance;
    if (!sync.isGelanggangVerified) return;
    setState(() => _isLoadingData = true);
    try {
      final pesertas = await PusakaSeniApiService().fetchPesertas(
        eventId: sync.lockedEventId,
        eventDocId: sync.lockedEventDocId,
        gelanggangDocId: sync.lockedGelanggangDocId,
        rawArenaCode: sync.lockedRawArenaCode,
        fallbackToSample: false,
      );
      if (mounted) {
        setState(() {
          _arenaPesertaCount = pesertas.length;
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
    return ListenableBuilder(
      listenable: AppThemeController.instance,
      builder: (context, _) => Scaffold(
      backgroundColor: AppColors.background,
      body: Container(
        decoration: AppDecorations.pageBackground,
        child: SafeArea(
          top: !_isFullScreen,
          bottom: false,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1180),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                child: Column(
                  children: [
                    // 1. Clean Top Header Bar
                    _buildTopBar(),
                    const SizedBox(height: 10),

                    // 2. Live Tournament Status Bar (Synced from Backend)
                    _buildLiveStatusBar(),
                    const SizedBox(height: 12),

                    // 3. 4 Module Cards Grid / List (Soft & Responsive)
                    Expanded(
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final isWide = constraints.maxWidth > 860;
                          final isMedium = constraints.maxWidth > 560;
                          final roleCards = _buildRoleCards();

                          if (!isMedium) {
                            return ListView.separated(
                              physics: const BouncingScrollPhysics(),
                              padding: const EdgeInsets.only(bottom: 12),
                              itemCount: roleCards.length,
                              separatorBuilder: (_, _) => const SizedBox(height: 12),
                              itemBuilder: (_, index) => roleCards[index],
                            );
                          }

                          return GridView.count(
                            crossAxisCount: isWide ? 4 : 2,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                            childAspectRatio: isWide ? 0.72 : 0.96,
                            physics: const BouncingScrollPhysics(),
                            padding: const EdgeInsets.only(bottom: 12),
                            children: roleCards,
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    ),
    );
  }

  List<Widget> _buildRoleCards() {
    return [
      _buildRoleCard(
        roleKey: 'dewan',
        badgeText: 'Otoritas',
        badgeBg: AppColors.primarySoft,
        badgeBorder: AppColors.primaryBorder,
        badgeTextColor: AppColors.primaryText,
        icon: Icons.shield_rounded,
        iconGradient: const [Color(0xFFEF4444), Color(0xFFDC2626)],
        title: 'Dewan Pertandingan',
        subtitle: 'Ketua & Pengawas Partai',
        description:
            'Pusat kendali pengawasan skor multi-juri, hukuman penalti, dan pengesahan hasil akhir.',
        checkpoints: const [
          'Monitoring Skor Multi-Juri',
          'Input Hukuman Dewan',
          'Pengesahan & Penetapan Juara',
        ],
        accentColor: AppColors.primary,
        actionLabel: 'Masuk Dewan',
        onTap: widget.onSelectDewan,
      ),
      _buildRoleCard(
        roleKey: 'juri',
        badgeText: 'Penilai',
        badgeBg: AppColors.amberSoft,
        badgeBorder: AppColors.amberBorder,
        badgeTextColor: AppColors.amberText,
        icon: Icons.balance_rounded,
        iconGradient: const [Color(0xFFF59E0B), Color(0xFFD97706)],
        title: 'Juri Pertandingan',
        subtitle: 'Juri 1 s/d Juri 8',
        description:
            'Keypad sentuh juri untuk Tunggal, Ganda, Beregu, dan Solo Kreatif.',
        checkpoints: const [
          'Keypad Sentuh Juri 1 s/d 8',
          'Seni Baku 14 & 12 Jurus',
          '3 Aspek Penilaian Seni Ganda',
        ],
        accentColor: AppColors.amber,
        actionLabel: 'Masuk Juri',
        onTap: widget.onSelectJuri,
      ),
      _buildRoleCard(
        roleKey: 'timekeeper',
        badgeText: 'Waktu',
        badgeBg: AppColors.tealSoft,
        badgeBorder: AppColors.tealBorder,
        badgeTextColor: AppColors.tealText,
        icon: Icons.timer_rounded,
        iconGradient: const [Color(0xFF14B8A6), Color(0xFF0D9488)],
        title: 'Time Keeper',
        subtitle: 'Pengendali Timer Global',
        description:
            'Pengatur waktu resmi 03:00, 01:20, dan 01:40 dengan sinkronisasi ke seluruh layar.',
        checkpoints: const [
          'Preset 03:00 / 01:20 / 01:40',
          'Countdown & Waktu Berjalan',
          'Peringatan 10 Detik Terakhir',
        ],
        accentColor: AppColors.teal,
        actionLabel: 'Masuk Time Keeper',
        onTap: widget.onSelectTimekeeper,
      ),
      _buildRoleCard(
        roleKey: 'monitoring',
        badgeText: 'Display',
        badgeBg: AppColors.blueSoft,
        badgeBorder: AppColors.blueBorder,
        badgeTextColor: AppColors.blueText,
        icon: Icons.tv_rounded,
        iconGradient: const [Color(0xFF3B82F6), Color(0xFF2563EB)],
        title: 'Monitoring Scoreboard',
        subtitle: 'Display Penonton & Arena',
        description:
            'Papan skor visual layar lebar untuk penonton, official, dan atlet arena.',
        checkpoints: const [
          'Papan Skor Arena Layar Lebar',
          'Status Multi-Juri Real-Time',
          'Skor Resmi Akhir & Penalti',
        ],
        accentColor: AppColors.blue,
        actionLabel: 'Masuk Monitoring',
        onTap: widget.onSelectMonitoring,
      ),
    ];
  }

  Widget _buildLiveStatusBar() {
    final sync = GelanggangSyncService.instance;
    final bool isVerified = sync.isGelanggangVerified;
    final String? eventTitle = sync.lockedEventTitle;
    final String? eventCode = sync.lockedEventCode;

    if (!isVerified) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: AppDecorations.card(
          radius: 16,
          color: AppColors.surface,
          borderColor: AppColors.border,
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppColors.amberSoft,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.amberBorder),
              ),
              child: const Icon(
                Icons.lock_outline_rounded,
                color: AppColors.amber,
                size: 15,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Pilih peran dan verifikasi kode gelanggang untuk mengunci event & daftar atlet',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.amberSoft,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.amberBorder),
              ),
              child: Text(
                'Belum Verifikasi',
                style: TextStyle(
                  fontSize: 9.5,
                  fontWeight: FontWeight.bold,
                  color: AppColors.amberText,
                ),
              ),
            ),
          ],
        ),
      );
    }

    final String eventDisplay = eventTitle != null && eventTitle.isNotEmpty
        ? (eventCode != null && eventCode.isNotEmpty
            ? '$eventTitle ($eventCode)'
            : eventTitle)
        : 'Gelanggang Terverifikasi';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: AppDecorations.card(
        radius: 16,
        color: AppColors.surface,
        borderColor: AppColors.emeraldBorder,
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: AppColors.emeraldSoft,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.emeraldBorder),
            ),
            child: const Icon(
              Icons.verified_rounded,
              color: AppColors.emerald,
              size: 15,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: Row(
                children: [
                  Text(
                    eventDisplay,
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.emeraldSoft,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.emeraldBorder),
                    ),
                    child: Text(
                      sync.activeArenaCode,
                      style: TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.bold,
                        color: AppColors.emeraldText,
                      ),
                    ),
                  ),
                  if (_arenaPesertaCount > 0) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.skySoft,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppColors.skyBorder),
                      ),
                      child: Text(
                        '$_arenaPesertaCount Peserta',
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.bold,
                          color: AppColors.skyText,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(width: 6),
          IconButton(
            onPressed: _loadVerifiedArenaData,
            tooltip: 'Segarkan data gelanggang',
            icon: _isLoadingData
                ? const SizedBox(
                    width: 13,
                    height: 13,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.sky,
                    ),
                  )
                : const Icon(Icons.refresh_rounded, size: 16, color: AppColors.sky),
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
            padding: EdgeInsets.zero,
            style: IconButton.styleFrom(
              backgroundColor: AppColors.skySoft,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: AppDecorations.card(radius: 18),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: AppColors.amberSoft,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.amberBorder),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.asset(
                'assets/images/app_logo_small.png',
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) => const Icon(
                  Icons.sports_martial_arts_rounded,
                  color: AppColors.amber,
                  size: 20,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'PUSAKA SENI SCORING IPSI',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.6,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  'Sistem Digital Penilaian Seni Pencak Silat Indonesia',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          const ThemeToggleButton(
            buttonSize: 32,
            iconSize: 17,
            borderRadius: 10,
          ),
          const SizedBox(width: 6),
          IconButton(
            onPressed: _toggleFullScreen,
            icon: Icon(
              _isFullScreen
                  ? Icons.fullscreen_exit_rounded
                  : Icons.fullscreen_rounded,
              size: 18,
              color: AppColors.textSecondary,
            ),
            tooltip: 'Layar Penuh',
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            padding: EdgeInsets.zero,
            style: IconButton.styleFrom(
              backgroundColor: AppColors.surfaceMuted,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRoleCard({
    required String roleKey,
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
    final sync = GelanggangSyncService.instance;
    final String? verifiedArenaParam = sync.isGelanggangVerified
        ? (sync.lockedRawArenaCode ?? sync.activeArenaCode)
        : null;
    final Uri roleUri = AppLinkHelper.buildRoleUri(
      role: roleKey,
      arenaCode: verifiedArenaParam,
    );

    return Link(
      uri: roleUri,
      target: LinkTarget.self,
      builder: (context, followLink) {
        return Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(22),
            child: Container(
              decoration: AppDecorations.card(radius: 22),
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header Card (Icon & Soft Pill Badge)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: iconGradient,
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(13),
                          boxShadow: [
                            BoxShadow(
                              color: accentColor.withValues(alpha: 0.25),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Icon(icon, color: Colors.white, size: 21),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: badgeBg,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: badgeBorder),
                        ),
                        child: Text(
                          badgeText.toUpperCase(),
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.6,
                            color: badgeTextColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Titles
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 10.5,
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
                    style: TextStyle(
                      fontSize: 10.5,
                      color: AppColors.textSecondary,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Checkpoints
                  ...checkpoints.map(
                    (cp) => Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        children: [
                          Icon(
                            Icons.check_circle_rounded,
                            size: 13,
                            color: accentColor,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              cp,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 10.5,
                                color: AppColors.textSecondary,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Soft Pill Action Button + Open in New Tab (Chrome & Windows)
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: onTap,
                          icon: const Icon(
                            Icons.arrow_forward_rounded,
                            size: 15,
                          ),
                          label: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              actionLabel,
                              style: const TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: accentColor,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              vertical: 10,
                              horizontal: 8,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 0,
                          ),
                        ),
                      ),
                      if (AppLinkHelper.supportsNewTab) ...[
                        const SizedBox(width: 6),
                        Link(
                          uri: roleUri,
                          target: LinkTarget.blank,
                          builder: (context, openNewTabLink) => Tooltip(
                            message: 'Buka $title di Tab Baru',
                            child: IconButton(
                              onPressed: () {
                                AppLinkHelper.openRoleInNewTab(
                                  role: roleKey,
                                  arenaCode: verifiedArenaParam,
                                );
                              },
                              icon: Icon(
                                Icons.open_in_new_rounded,
                                size: 15,
                                color: accentColor,
                              ),
                              constraints: const BoxConstraints(
                                minWidth: 36,
                                minHeight: 36,
                              ),
                              padding: EdgeInsets.zero,
                              style: IconButton.styleFrom(
                                backgroundColor: badgeBg,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                visualDensity: VisualDensity.compact,
                                side: BorderSide(color: badgeBorder),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
