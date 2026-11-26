import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'views/dewan/dewan_panel_view.dart';
import 'views/monitoring/monitoring_scoreboard_view.dart';
import 'views/portal/gelanggang_verification_view.dart';
import 'views/portal/scoring_portal_view.dart';
import 'views/scoring/scoring_panel_view.dart';
import 'views/timekeeper/timekeeper_panel_view.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // Set system UI overlay styling for modern dark immersive UI
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Color(0xFF0F172A),
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );
  runApp(const PusakaSeniApp());
}

class PusakaSeniApp extends StatelessWidget {
  final Widget? home;
  final bool enableAnimation;

  const PusakaSeniApp({super.key, this.home, this.enableAnimation = true});

  static const String scoringUrl = 'https://app-seni.pusakarinjani.my.id/scoring';

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Pusaka Seni Scoring IPSI',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0F172A),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFDC2626),
          brightness: Brightness.dark,
        ),
      ),
      home: home ?? ScoringHomeScreen(enableAnimation: enableAnimation),
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

  const ScoringHomeScreen({super.key, this.enableAnimation = true});

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
          onBackToPortal: () => setState(() => _currentScreen = ActiveScreen.portal),
        );
      case ActiveScreen.juri:
        return ScoringPanelView(
          arenaCode: _verifiedArenaCode,
          onBackToPortal: () => setState(() => _currentScreen = ActiveScreen.portal),
        );
      case ActiveScreen.timekeeper:
        return TimekeeperPanelView(
          arenaCode: _verifiedArenaCode,
          onBackToPortal: () => setState(() => _currentScreen = ActiveScreen.portal),
        );
      case ActiveScreen.monitoring:
        return MonitoringScoreboardView(
          arenaCode: _verifiedArenaCode,
          onBackToPortal: () => setState(() => _currentScreen = ActiveScreen.portal),
        );
    }
  }
}
