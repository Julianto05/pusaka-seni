import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pusaka_seni_v2/main.dart';
import 'package:pusaka_seni_v2/models/scoring_models.dart';
import 'package:pusaka_seni_v2/services/gelanggang_sync_service.dart';
import 'package:pusaka_seni_v2/services/pusaka_seni_api_service.dart';
import 'package:pusaka_seni_v2/views/dewan/dewan_panel_view.dart';
import 'package:pusaka_seni_v2/views/monitoring/monitoring_scoreboard_view.dart';
import 'package:pusaka_seni_v2/views/portal/gelanggang_verification_view.dart';
import 'package:pusaka_seni_v2/views/portal/scoring_portal_view.dart';
import 'package:pusaka_seni_v2/views/scoring/components/modals/athlete_selector_dialog.dart';
import 'package:pusaka_seni_v2/views/scoring/components/modals/confirm_ganda_dialog.dart';
import 'package:pusaka_seni_v2/views/scoring/components/modals/confirm_kemantapan_dialog.dart';
import 'package:pusaka_seni_v2/views/scoring/components/modals/kemantapan_info_dialog.dart';
import 'package:pusaka_seni_v2/views/scoring/components/modals/reset_confirm_dialog.dart';
import 'package:pusaka_seni_v2/views/scoring/scoring_panel_view.dart';
import 'package:pusaka_seni_v2/views/timekeeper/timekeeper_panel_view.dart';

void main() {
  const Map<String, Size> targetDevices = {
    'Desktop (1920x1080)': Size(1920, 1080),
    'Tablet Portrait (800x1280)': Size(800, 1280),
    'Tablet Landscape (1280x800)': Size(1280, 800),
    'Mobile Portrait (360x780)': Size(360, 780),
    'Small Mobile (320x568)': Size(320, 568),
    'Mobile Landscape (780x360)': Size(780, 360),
    'Compact Landscape (640x320)': Size(640, 320),
  };

  group('Pusaka Seni Responsive Layout & Anti-Overflow Tests', () {
    for (final entry in targetDevices.entries) {
      final name = entry.key;
      final size = entry.value;

      testWidgets('ScoringPortalView renders without overflow on $name',
          (WidgetTester tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        await tester.pumpWidget(
          MaterialApp(
            home: ScoringPortalView(
              onSelectDewan: () {},
              onSelectJuri: () {},
              onSelectTimekeeper: () {},
              onSelectMonitoring: () {},
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(ScoringPortalView), findsOneWidget);
        expect(find.text('Dewan Pertandingan', skipOffstage: false), findsOneWidget);
        expect(find.text('Juri Pertandingan', skipOffstage: false), findsOneWidget);
        expect(find.text('Time Keeper', skipOffstage: false), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets('GelanggangVerificationView renders without overflow on $name',
          (WidgetTester tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        await tester.pumpWidget(
          MaterialApp(
            home: GelanggangVerificationView(
              roleName: 'Juri Pertandingan',
              roleIcon: Icons.balance_rounded,
              accentColor: const Color(0xFFF59E0B),
              enableAnimation: false,
              onVerified: (_) {},
              onBack: () {},
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(GelanggangVerificationView), findsOneWidget);
        expect(find.text('Kode Gelanggang (8 Digit)', skipOffstage: false), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets('ScoringPanelView (Juri Baku) renders without overflow on $name',
          (WidgetTester tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        await tester.pumpWidget(
          const MaterialApp(
            home: ScoringPanelView(),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(ScoringPanelView), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets('DewanPanelView renders without overflow on $name',
          (WidgetTester tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        await tester.pumpWidget(
          MaterialApp(
            home: DewanPanelView(onBackToPortal: () {}),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Dewan Pertandingan'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets('TimekeeperPanelView renders without overflow on $name',
          (WidgetTester tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        await tester.pumpWidget(
          MaterialApp(
            home: TimekeeperPanelView(onBackToPortal: () {}),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(TimekeeperPanelView), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets('MonitoringScoreboardView renders without overflow on $name',
          (WidgetTester tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        await tester.pumpWidget(
          MaterialApp(
            home: MonitoringScoreboardView(onBackToPortal: () {}),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(MonitoringScoreboardView), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('Full ScoringHomeScreen navigation with Gelanggang Verification flow',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      PusakaSeniApiService.testVerifierOverride = (code) async {
        if (code == '23456789') {
          return const GelanggangVerificationResult(
            status: GelanggangVerificationStatus.valid,
            info: VerifiedGelanggangInfo(
              gelanggangId: '717',
              gelanggangDocId: 'gel-1',
              rawArenaCode: '23456789',
              arenaLabel: 'GELANGGANG 1 (23456789)',
              eventId: '6',
              eventDocId: 'ev-6',
              eventTitle: 'ABATA CAMPIO',
              eventCode: 'ABT-87645',
              jumlahJuri: 4,
            ),
            message: 'Kode gelanggang terverifikasi.',
          );
        }
        return GelanggangVerificationResult(
          status: GelanggangVerificationStatus.notFound,
          message:
              'Kode gelanggang "$code" tidak ditemukan. Pastikan kode sudah dibuat oleh Admin Event.',
        );
      };
      addTearDown(() {
        PusakaSeniApiService.testVerifierOverride = null;
        GelanggangSyncService.instance.resetVerification();
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(const PusakaSeniApp(enableAnimation: false));
      await tester.pumpAndSettle();

      expect(find.byType(ScoringPortalView), findsOneWidget);

      // 1. Enter Juri -> Verification Screen
      await tester.tap(find.text('Masuk Juri'));
      await tester.pumpAndSettle();
      expect(find.byType(GelanggangVerificationView), findsOneWidget);

      // Verify Gelanggang by entering valid admin-created 8-digit code
      await tester.enterText(find.byType(TextField), '23456789');
      await tester.pumpAndSettle(const Duration(milliseconds: 500));
      expect(find.byType(ScoringPanelView), findsOneWidget);

      // Dismiss ready popup if present
      final readyBtn = find.text('SAYA SIAP MENILAI (READY)');
      if (readyBtn.evaluate().isNotEmpty) {
        await tester.tap(readyBtn);
        await tester.pumpAndSettle();
      }

      // Go back directly to portal (no Opsi Penilaian popup anymore)
      await tester.tap(find.byTooltip('Kembali ke Menu'));
      await tester.pumpAndSettle();
      expect(find.byType(ScoringPortalView), findsOneWidget);

      // 2. Enter Dewan -> Verification Screen
      await tester.tap(find.text('Masuk Dewan'));
      await tester.pumpAndSettle();
      expect(find.byType(GelanggangVerificationView), findsOneWidget);

      await tester.enterText(find.byType(TextField), '23456789');
      await tester.pumpAndSettle(const Duration(milliseconds: 500));
      expect(find.byType(DewanPanelView), findsOneWidget);

      await tester.tap(find.byTooltip('Kembali ke Portal'));
      await tester.pumpAndSettle();
      expect(find.byType(ScoringPortalView), findsOneWidget);

      // 3. Enter Timekeeper -> Verification Screen
      await tester.tap(find.text('Masuk Time Keeper'));
      await tester.pumpAndSettle();
      expect(find.byType(GelanggangVerificationView), findsOneWidget);

      await tester.enterText(find.byType(TextField), '23456789');
      await tester.pumpAndSettle(const Duration(milliseconds: 500));
      expect(find.byType(TimekeeperPanelView), findsOneWidget);

      await tester.tap(find.byTooltip('Kembali ke Portal'));
      await tester.pumpAndSettle();
      expect(find.byType(ScoringPortalView), findsOneWidget);

      // 4. Enter Monitoring -> Verification Screen
      await tester.tap(find.text('Masuk Monitoring'));
      await tester.pumpAndSettle();
      expect(find.byType(GelanggangVerificationView), findsOneWidget);

      await tester.enterText(find.byType(TextField), '23456789');
      await tester.pumpAndSettle(const Duration(milliseconds: 500));
      expect(find.byType(MonitoringScoreboardView), findsOneWidget);

      await tester.tap(find.byTooltip('Kembali ke Portal'));
      await tester.pumpAndSettle();
      expect(find.byType(ScoringPortalView), findsOneWidget);

      expect(tester.takeException(), isNull);
    });

    testWidgets('Modal dialogs render without overflow on Small Mobile (320x568)',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final athlete = AthleteModel.getSampleAthletes()[0];

      // Test ConfirmKemantapanDialog
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ConfirmKemantapanDialog(
              juriNumber: 1,
              athleteName: athlete.name,
              kemantapan: 0.05,
              kebenaran: 9.90,
              onConfirm: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(ConfirmKemantapanDialog), findsOneWidget);
      expect(tester.takeException(), isNull);

      // Test ConfirmGandaDialog
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ConfirmGandaDialog(
              juriNumber: 1,
              categoryTitle: 'Seni Ganda',
              athleteName: athlete.name,
              attackDefense: 0.88,
              firmnessHarmony: 0.87,
              soulfulness: 0.89,
              onConfirm: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(ConfirmGandaDialog), findsOneWidget);
      expect(tester.takeException(), isNull);

      // Test KemantapanInfoDialog
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: KemantapanInfoDialog(
              categoryName: 'Seni Tunggal',
              totalJurus: 14,
              currentKemantapan: 0.05,
              onSelectKemantapan: (_) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(KemantapanInfoDialog), findsOneWidget);
      expect(tester.takeException(), isNull);

      // Test ResetConfirmDialog
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ResetConfirmDialog(
              categoryTitle: 'Seni Tunggal',
              juriNumber: 1,
              isBaku: true,
              onReset: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(ResetConfirmDialog), findsOneWidget);
      expect(tester.takeException(), isNull);

      // Test AthleteSelectorDialog
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AthleteSelectorDialog(
              currentAthlete: athlete,
              currentCategory: SeniCategory.tunggal,
              onAthleteSelected: (_) {},
              onCategoryChanged: (_) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(AthleteSelectorDialog), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    test('Dewan selection syncs to GelanggangSyncService and all observers', () {
      final sync = GelanggangSyncService.instance;
      final athlete = AthleteModel.getSampleAthletes()[2]; // Ganda

      sync.dewanSelectMatch(
        athlete: athlete,
        category: SeniCategory.ganda,
        nomorPartai: 'PARTAI 05',
        pool: 'POOL B',
      );

      expect(sync.athlete.name, athlete.name);
      expect(sync.category, SeniCategory.ganda);
      expect(sync.nomorPartai, 'PARTAI 05');
      expect(sync.lastSyncAction, 'ATHLETE_SELECTED');
      expect(sync.isMatchFinalized, false);

      // Juri score submission
      sync.juriSubmitScore(juriNumber: 1, score: 9.95, kemantapan: 0.05);
      expect(sync.juriScores[1]!['score'], 9.95);
      expect(sync.juriScores[1]!['submitted'], true);

      // Timekeeper timer sync
      sync.timekeeperSyncTimer(remainingSeconds: 150, status: 'running');
      expect(sync.timerRemainingSeconds, 150);
      expect(sync.timerStatus, 'running');

      // Dewan penalties
      sync.dewanAddPenalty(
        PenaltyDeduction(id: '1', label: 'Waktu Kurang', deduction: 0.50, timestamp: DateTime.now()),
      );
      expect(sync.penalties.length, 1);
      expect(sync.calculateTotalPenalties(), 0.50);

      // Dewan finalize match
      sync.dewanFinalizeMatch(9.45);
      expect(sync.isMatchFinalized, true);
      expect(sync.officialFinalScore, 9.45);
    });
  });
}
