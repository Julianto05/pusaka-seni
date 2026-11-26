import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'services/app_link_helper.dart';
import 'services/gelanggang_sync_service.dart';
import 'services/pusaka_seni_api_service.dart';
import 'theme/app_theme.dart';
import 'views/dewan/dewan_panel_view.dart';
import 'views/monitoring/monitoring_scoreboard_view.dart';
import 'views/portal/gelanggang_verification_view.dart';
import 'views/portal/scoring_portal_view.dart';
import 'views/scoring/scoring_panel_view.dart';
import 'views/timekeeper/timekeeper_panel_view.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  AppThemeController.instance.applySystemUiOverlay();
  runApp(const PusakaSeniApp());
}

class PusakaSeniApp extends StatelessWidget {
  final Widget? home;
  final bool enableAnimation;
  final Uri? initialUri;

  const PusakaSeniApp({
    super.key,
    this.home,
    this.enableAnimation = true,
    this.initialUri,
  });

  static const String scoringUrl = 'https://beseni-temp.pusakarinjani.my.id';

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: AppThemeController.instance,
      builder: (context, themeMode, _) {
        return MaterialApp(
          title: 'Pusaka Seni Scoring IPSI',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light(),
          darkTheme: AppTheme.dark(),
          themeMode: themeMode,
          home:
              home ??
              ScoringHomeScreen(
                enableAnimation: enableAnimation,
                initialUri: initialUri,
              ),
        );
      },
    );
  }
}

enum ActiveScreen {
  portal,
  verification,
  dewan,
  juri,
  timekeeper,
  monitoring,
}

class ScoringHomeScreen extends StatefulWidget {
  final bool enableAnimation;
  final Uri? initialUri;

  const ScoringHomeScreen({
    super.key,
    this.enableAnimation = true,
    this.initialUri,
  });

  @override
  State<ScoringHomeScreen> createState() => _ScoringHomeScreenState();
}

class _ScoringHomeScreenState extends State<ScoringHomeScreen> {
  ActiveScreen _currentScreen = ActiveScreen.portal;
  ActiveScreen _targetRole = ActiveScreen.juri;
  String _targetRoleName = 'Juri Pertandingan';
  IconData _targetRoleIcon = Icons.balance_rounded;
  Color _targetRoleColor = const Color(0xFFF59E0B);
  String? _verifiedArenaCode;

  @override
  void initState() {
    super.initState();
    _applyInitialDeepLink();
  }

  void _applyInitialDeepLink() {
    final Uri? startupUri = widget.initialUri ?? (kIsWeb ? Uri.base : null);
    if (startupUri == null) return;

    final route = AppLinkHelper.parseStartupRoute(startupUri);
    if (!route.hasRole) return;

    final target = _screenFromRoleKey(route.role!);
    if (target == null) return;

    _applyRoleMeta(target);

    if (route.arenaCode != null && route.arenaCode!.isNotEmpty) {
      final sync = GelanggangSyncService.instance;
      if (route.juriNumber != null) {
        sync.setSelectedJuriNumber(route.juriNumber!);
      }
      final canonical = GelanggangSyncService.normalizeArenaCode(
        route.arenaCode!,
      );
      sync.verifyGelanggang(
        arenaCode: canonical,
        rawArenaCode: route.arenaCode!,
      );
      _verifiedArenaCode = canonical;
      _currentScreen = target;
      _hydrateDeepLinkedArena(route.arenaCode!, canonical);
    } else {
      _currentScreen = ActiveScreen.verification;
    }
  }

  Future<void> _hydrateDeepLinkedArena(
    String rawCode,
    String fallbackCanonical,
  ) async {
    final sync = GelanggangSyncService.instance;
    if (!sync.cloudSyncEnabled) return;
    try {
      final info = await PusakaSeniApiService().verifyGelanggangByCode(rawCode);
      if (info == null || !mounted) return;
      final arenaName =
          (rawCode == '12345678' || rawCode == '87654321')
              ? fallbackCanonical
              : info.arenaLabel;
      sync.verifyGelanggang(
        arenaCode: arenaName,
        rawArenaCode: info.rawArenaCode.isNotEmpty ? info.rawArenaCode : rawCode,
        gelanggangId: info.gelanggangId,
        gelanggangDocId: info.gelanggangDocId,
        eventId: info.eventId,
        eventDocId: info.eventDocId,
        eventTitle: info.eventTitle,
        eventCode: info.eventCode,
        jumlahJuri: info.jumlahJuri,
      );
      if (mounted && _verifiedArenaCode != arenaName) {
        setState(() => _verifiedArenaCode = arenaName);
      }
    } catch (_) {}
  }

  ActiveScreen? _screenFromRoleKey(String roleKey) {
    switch (roleKey) {
      case 'dewan':
        return ActiveScreen.dewan;
      case 'juri':
        return ActiveScreen.juri;
      case 'timekeeper':
        return ActiveScreen.timekeeper;
      case 'monitoring':
        return ActiveScreen.monitoring;
      default:
        return null;
    }
  }

  void _applyRoleMeta(ActiveScreen targetScreen) {
    _targetRole = targetScreen;
    switch (targetScreen) {
      case ActiveScreen.dewan:
        _targetRoleName = 'Dewan Pertandingan';
        _targetRoleIcon = Icons.shield_rounded;
        _targetRoleColor = const Color(0xFFDC2626);
        break;
      case ActiveScreen.juri:
        _targetRoleName = 'Juri Pertandingan';
        _targetRoleIcon = Icons.balance_rounded;
        _targetRoleColor = const Color(0xFFF59E0B);
        break;
      case ActiveScreen.timekeeper:
        _targetRoleName = 'Time Keeper';
        _targetRoleIcon = Icons.timer_rounded;
        _targetRoleColor = const Color(0xFF14B8A6);
        break;
      case ActiveScreen.monitoring:
        _targetRoleName = 'Monitoring Scoreboard';
        _targetRoleIcon = Icons.tv_rounded;
        _targetRoleColor = const Color(0xFF3B82F6);
        break;
      case ActiveScreen.portal:
      case ActiveScreen.verification:
        break;
    }
  }

  void _navigateToVerification({
    required ActiveScreen targetScreen,
    required String roleName,
    required IconData roleIcon,
    required Color accentColor,
  }) {
    setState(() {
      _targetRole = targetScreen;
      _targetRoleName = roleName;
      _targetRoleIcon = roleIcon;
      _targetRoleColor = accentColor;
      _currentScreen = ActiveScreen.verification;
    });
  }

  @override
  Widget build(BuildContext context) {
    switch (_currentScreen) {
      case ActiveScreen.portal:
        return ScoringPortalView(
          onSelectDewan: () => _navigateToVerification(
            targetScreen: ActiveScreen.dewan,
            roleName: 'Dewan Pertandingan',
            roleIcon: Icons.shield_rounded,
            accentColor: const Color(0xFFDC2626),
          ),
          onSelectJuri: () => _navigateToVerification(
            targetScreen: ActiveScreen.juri,
            roleName: 'Juri Pertandingan',
            roleIcon: Icons.balance_rounded,
            accentColor: const Color(0xFFF59E0B),
          ),
          onSelectTimekeeper: () => _navigateToVerification(
            targetScreen: ActiveScreen.timekeeper,
            roleName: 'Time Keeper',
            roleIcon: Icons.timer_rounded,
            accentColor: const Color(0xFF14B8A6),
          ),
          onSelectMonitoring: () => _navigateToVerification(
            targetScreen: ActiveScreen.monitoring,
            roleName: 'Monitoring Scoreboard',
            roleIcon: Icons.tv_rounded,
            accentColor: const Color(0xFF3B82F6),
          ),
        );
      case ActiveScreen.verification:
        return GelanggangVerificationView(
          roleName: _targetRoleName,
          roleIcon: _targetRoleIcon,
          accentColor: _targetRoleColor,
          enableAnimation: widget.enableAnimation,
          onVerified: (arenaCode) {
            setState(() {
              _verifiedArenaCode = arenaCode;
              _currentScreen = _targetRole;
            });
          },
          onBack: () => setState(() => _currentScreen = ActiveScreen.portal),
        );
      case ActiveScreen.dewan:
        return DewanPanelView(
          arenaCode: _verifiedArenaCode,
          onBackToPortal: () =>
              setState(() => _currentScreen = ActiveScreen.portal),
        );
      case ActiveScreen.juri:
        return ScoringPanelView(
          arenaCode: _verifiedArenaCode,
          onBackToPortal: () =>
              setState(() => _currentScreen = ActiveScreen.portal),
        );
      case ActiveScreen.timekeeper:
        return TimekeeperPanelView(
          arenaCode: _verifiedArenaCode,
          onBackToPortal: () =>
              setState(() => _currentScreen = ActiveScreen.portal),
        );
      case ActiveScreen.monitoring:
        return MonitoringScoreboardView(
          arenaCode: _verifiedArenaCode,
          onBackToPortal: () =>
              setState(() => _currentScreen = ActiveScreen.portal),
        );
    }
  }
}
