import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pusaka_seni_v2/main.dart';
import 'package:pusaka_seni_v2/models/scoring_models.dart';
import 'package:pusaka_seni_v2/services/gelanggang_sync_service.dart';
import 'package:pusaka_seni_v2/theme/app_theme.dart';
import 'package:pusaka_seni_v2/views/dewan/dewan_panel_view.dart';
import 'package:pusaka_seni_v2/views/monitoring/monitoring_scoreboard_view.dart';
import 'package:pusaka_seni_v2/views/portal/gelanggang_verification_view.dart';
import 'package:pusaka_seni_v2/views/portal/scoring_portal_view.dart';
import 'package:pusaka_seni_v2/views/scoring/components/scoring_header.dart';
import 'package:pusaka_seni_v2/views/scoring/scoring_panel_view.dart';
import 'package:pusaka_seni_v2/views/timekeeper/timekeeper_panel_view.dart';

void main() {
  setUp(() {
    AppThemeController.instance.setThemeMode(ThemeMode.light);
    GelanggangSyncService.instance.setActiveJuriCount(8);
  });

  tearDown(() {
    AppThemeController.instance.setThemeMode(ThemeMode.light);
  });

  group('Theme Toggle & Fullscreen Scoring Tests', () {
    testWidgets('ThemeToggleButton switches app between Light and Dark theme', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(const PusakaSeniApp(enableAnimation: false));
      await tester.pumpAndSettle();

      // Starts in Light Mode
      expect(AppThemeController.instance.isDark, isFalse);
      expect(find.byIcon(Icons.dark_mode_rounded), findsOneWidget);
      expect(find.byTooltip('Ubah ke Tema Gelap'), findsOneWidget);

      // Tap toggle -> switches to Dark Mode
      await tester.tap(find.byType(ThemeToggleButton));
      await tester.pumpAndSettle();

      expect(AppThemeController.instance.isDark, isTrue);
      expect(find.byIcon(Icons.light_mode_rounded), findsOneWidget);
      expect(find.byTooltip('Ubah ke Tema Terang'), findsOneWidget);
      expect(AppColors.background, const Color(0xFF0F172A));
      expect(tester.takeException(), isNull);

      // Tap again -> switches back to Light Mode
      await tester.tap(find.byType(ThemeToggleButton));
      await tester.pumpAndSettle();

      expect(AppThemeController.instance.isDark, isFalse);
      expect(AppColors.background, const Color(0xFFF4F7FB));
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'All primary panels render cleanly in Dark Mode with ThemeToggleButton',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(1024, 700);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        AppThemeController.instance.setThemeMode(ThemeMode.dark);

        final views = <Widget>[
          ScoringPortalView(
            onSelectDewan: () {},
            onSelectJuri: () {},
            onSelectTimekeeper: () {},
            onSelectMonitoring: () {},
          ),
          GelanggangVerificationView(
            roleName: 'Juri Pertandingan',
            roleIcon: Icons.balance_rounded,
            accentColor: AppColors.amber,
            enableAnimation: false,
            onVerified: (_) {},
            onBack: () {},
          ),
          const ScoringPanelView(arenaCode: 'GELANGGANG A'),
          DewanPanelView(arenaCode: 'GELANGGANG A', onBackToPortal: () {}),
          TimekeeperPanelView(arenaCode: 'GELANGGANG A', onBackToPortal: () {}),
          MonitoringScoreboardView(
            arenaCode: 'GELANGGANG A',
            onBackToPortal: () {},
          ),
        ];

        for (final view in views) {
          await tester.pumpWidget(
            MaterialApp(
              theme: AppTheme.light(),
              darkTheme: AppTheme.dark(),
              themeMode: ThemeMode.dark,
              home: view,
            ),
          );
          await tester.pump(const Duration(milliseconds: 200));
          expect(find.byType(ThemeToggleButton), findsWidgets);
          expect(tester.takeException(), isNull);
        }
      },
    );

    testWidgets(
      'ScoringPanelView fullscreen toggles immersive mode while keeping ScoringHeader visible',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(1024, 600);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final sync = GelanggangSyncService.instance;
        sync.setSelectedJuriNumber(2);
        sync.dewanSelectMatch(
          athlete: const AthleteModel(
            id: '42',
            documentId: 'ath-42',
            name: 'Budi Santoso',
            kontingen: 'DKI Jakarta',
            category: 'Seni Tunggal',
            partai: 'Partai 7',
            pool: 'Pool A',
          ),
          category: SeniCategory.tunggal,
          nomorPartai: 'Partai 7',
          pool: 'Pool A',
          arenaCode: 'GELANGGANG A',
        );
        sync.juriSetReady(
          juriNumber: 2,
          isReady: true,
          arenaCode: 'GELANGGANG A',
        );

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.light(),
            home: const ScoringPanelView(arenaCode: 'GELANGGANG A'),
          ),
        );
        await tester.pumpAndSettle();

        // Initially NOT fullscreen
        expect(find.byType(ScoringHeader), findsOneWidget);
        expect(find.byTooltip('Layar Penuh'), findsOneWidget);
        expect(find.text('JURI 2'), findsOneWidget);

        // Tap fullscreen button
        await tester.tap(find.byTooltip('Layar Penuh'));
        await tester.pumpAndSettle();

        // Fullscreen active: ScoringHeader remains visible with Exit Fullscreen icon
        expect(find.byType(ScoringHeader), findsOneWidget);
        expect(find.byTooltip('Keluar Layar Penuh'), findsOneWidget);
        expect(find.text('JURI 2'), findsOneWidget);
        expect(find.text('PARTAI 7'), findsOneWidget);
        expect(find.textContaining('Budi Santoso'), findsOneWidget);
        expect(find.text('WRONG & NEXT'), findsOneWidget);
        expect(find.text('NEXT'), findsOneWidget);
        expect(tester.takeException(), isNull);

        // Exit fullscreen restores standard button state
        await tester.tap(find.byTooltip('Keluar Layar Penuh'));
        await tester.pumpAndSettle();

        expect(find.byType(ScoringHeader), findsOneWidget);
        expect(find.byTooltip('Layar Penuh'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  });
}
