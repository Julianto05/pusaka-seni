import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pusaka_seni_v2/models/scoring_models.dart';
import 'package:pusaka_seni_v2/services/gelanggang_sync_service.dart';
import 'package:pusaka_seni_v2/views/scoring/scoring_panel_view.dart';
import 'package:pusaka_seni_v2/views/timekeeper/timekeeper_panel_view.dart';

void main() {
  group('Timekeeper - Juri Mode Sync Tests', () {
    setUp(() {
      final sync = GelanggangSyncService.instance;
      sync.verifyGelanggang(arenaCode: 'GELANGGANG A');
      sync.setActiveJuriCount(8, arenaCode: 'GELANGGANG A');
      sync.timekeeperSwitchMode(
        durationSeconds: 180,
        modeTitle: 'Standar (03:00)',
        arenaCode: 'GELANGGANG A',
      );
    });

    test('TimeCategoryMode enum labels are Standar, Tangan Kosong, and Senjata', () {
      expect(TimeCategoryMode.standar.title, 'Standar (03:00)');
      expect(TimeCategoryMode.standar.durationSeconds, 180);

      expect(TimeCategoryMode.tanganKosong.title, 'Tangan Kosong (01:20)');
      expect(TimeCategoryMode.tanganKosong.durationSeconds, 80);

      expect(TimeCategoryMode.senjata.title, 'Senjata (01:40)');
      expect(TimeCategoryMode.senjata.durationSeconds, 100);
    });

    testWidgets('Timekeeper panel displays updated mode titles without Usia Dini',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        MaterialApp(
          home: TimekeeperPanelView(
            arenaCode: 'GELANGGANG A',
            onBackToPortal: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Standar (03:00)'), findsOneWidget);
      expect(find.text('Tangan Kosong (01:20)'), findsOneWidget);
      expect(find.text('Senjata (01:40)'), findsOneWidget);

      // Verify old "Usia Dini" text is NOT present
      expect(find.textContaining('Usia Dini'), findsNothing);
    });

    testWidgets('Juri panel initializes with Standar 14 jurus by default (up to toya)',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final sync = GelanggangSyncService.instance;
      sync.dewanSelectMatch(
        athlete: AthleteModel.getSampleAthletes()[0],
        category: SeniCategory.tunggal,
        arenaCode: 'GELANGGANG A',
      );
      sync.timekeeperSwitchMode(
        durationSeconds: 180,
        modeTitle: 'Standar (03:00)',
        arenaCode: 'GELANGGANG A',
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: ScoringPanelView(arenaCode: 'GELANGGANG A'),
        ),
      );
      await tester.pumpAndSettle();

      // Ready popup reflects Standar 14 jurus
      expect(find.textContaining('Standar 14 Jurus • Total 100 Gerakan'), findsOneWidget);

      // Dismiss ready popup
      if (find.text('SAYA SIAP MENILAI (READY)').evaluate().isNotEmpty) {
        await tester.tap(find.text('SAYA SIAP MENILAI (READY)'));
        await tester.pumpAndSettle();
      }

      // Standar has 14 jurus (up to Toya)
      expect(find.textContaining('14'), findsWidgets);
    });

    testWidgets('When Timekeeper selects Tangan Kosong, Juri evaluates only Tangan Kosong (7 jurus)',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final sync = GelanggangSyncService.instance;
      sync.dewanSelectMatch(
        athlete: AthleteModel.getSampleAthletes()[0],
        category: SeniCategory.tunggal,
        arenaCode: 'GELANGGANG A',
      );
      // Timekeeper switches mode to Tangan Kosong
      sync.timekeeperSwitchMode(
        durationSeconds: 80,
        modeTitle: 'Tangan Kosong (01:20)',
        arenaCode: 'GELANGGANG A',
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: ScoringPanelView(arenaCode: 'GELANGGANG A'),
        ),
      );
      await tester.pumpAndSettle();

      // Ready popup should reflect Tangan Kosong 7 jurus
      expect(find.textContaining('Tangan Kosong 7 Jurus • Total 50 Gerakan'), findsOneWidget);

      // Dismiss ready popup
      await tester.tap(find.text('SAYA SIAP MENILAI (READY)'));
      await tester.pumpAndSettle();

      // Progress through all 7 jurus
      for (int i = 0; i < 6; i++) {
        expect(find.text('NEXT'), findsOneWidget);
        await tester.tap(find.text('NEXT'));
        await tester.pumpAndSettle();
      }

      // At jurus 7 (last jurus), clicking Next should complete scoring
      expect(find.text('NEXT'), findsOneWidget);
      await tester.tap(find.text('NEXT'));
      await tester.pumpAndSettle();

      // Juri now reaches 7 Jurus Tuntas directly
      expect(find.text('7 Jurus Tuntas'), findsOneWidget);
      expect(find.textContaining('Pilih Nilai Kemantapan'), findsOneWidget);
      expect(find.text('Selesai & Sinkronkan Nilai'), findsOneWidget);
    });

    testWidgets('When Timekeeper selects Senjata, Juri starts evaluation from Senjata (Golok & Toya, 7 jurus)',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final sync = GelanggangSyncService.instance;
      sync.dewanSelectMatch(
        athlete: AthleteModel.getSampleAthletes()[0],
        category: SeniCategory.tunggal,
        arenaCode: 'GELANGGANG A',
      );
      // Timekeeper switches mode to Senjata
      sync.timekeeperSwitchMode(
        durationSeconds: 100,
        modeTitle: 'Senjata (01:40)',
        arenaCode: 'GELANGGANG A',
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: ScoringPanelView(arenaCode: 'GELANGGANG A'),
        ),
      );
      await tester.pumpAndSettle();

      // Ready popup reflects Senjata 7 jurus
      expect(find.textContaining('Senjata 7 Jurus • Total 50 Gerakan'), findsOneWidget);

      // Dismiss ready popup
      await tester.tap(find.text('SAYA SIAP MENILAI (READY)'));
      await tester.pumpAndSettle();

      // First jurus should start from Golok (not Tangan Kosong)
      expect(find.textContaining('Golok'), findsWidgets);
      expect(find.textContaining('Tangan kosong'), findsNothing);

      // Progress through 7 weapon jurus (3 Golok + 4 Toya)
      for (int i = 0; i < 6; i++) {
        await tester.tap(find.text('NEXT'));
        await tester.pumpAndSettle();
      }

      // At 7th jurus, clicking Next completes scoring
      await tester.tap(find.text('NEXT'));
      await tester.pumpAndSettle();

      // Reaches 7 Jurus Tuntas directly
      expect(find.text('7 Jurus Tuntas'), findsOneWidget);
      expect(find.textContaining('Pilih Nilai Kemantapan'), findsOneWidget);
      expect(find.text('Selesai & Sinkronkan Nilai'), findsOneWidget);
    });
  });
}
