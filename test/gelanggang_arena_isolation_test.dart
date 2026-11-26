import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pusaka_seni_v2/models/scoring_models.dart';
import 'package:pusaka_seni_v2/services/gelanggang_sync_service.dart';
import 'package:pusaka_seni_v2/views/monitoring/monitoring_scoreboard_view.dart';

void main() {
  group('Gelanggang Arena Isolation & Multi-Arena Independence Tests', () {
    late GelanggangSyncService sync;

    setUp(() {
      sync = GelanggangSyncService.instance;
      sync.verifyGelanggang(arenaCode: 'GELANGGANG A');
      sync.setActiveJuriCount(8, arenaCode: 'GELANGGANG A');
      sync.setActiveJuriCount(8, arenaCode: 'GELANGGANG B');
    });

    test('Arena codes are canonicalized properly (12345678, ARENA-A -> GELANGGANG A; 87654321, ARENA-B -> GELANGGANG B)', () {
      expect(GelanggangSyncService.normalizeArenaCode('12345678'), 'GELANGGANG A');
      expect(GelanggangSyncService.normalizeArenaCode('ARENA-A'), 'GELANGGANG A');
      expect(GelanggangSyncService.normalizeArenaCode('GELANGGANG A'), 'GELANGGANG A');
      expect(GelanggangSyncService.normalizeArenaCode('arena-a'), 'GELANGGANG A');

      expect(GelanggangSyncService.normalizeArenaCode('87654321'), 'GELANGGANG B');
      expect(GelanggangSyncService.normalizeArenaCode('ARENA-B'), 'GELANGGANG B');
      expect(GelanggangSyncService.normalizeArenaCode('GELANGGANG B'), 'GELANGGANG B');
      expect(GelanggangSyncService.normalizeArenaCode('arena-b'), 'GELANGGANG B');
    });

    test('Gelanggang A and Gelanggang B have separate, isolated states for athlete and match', () {
      final samples = AthleteModel.getSampleAthletes();
      final athleteA = samples[0];
      final athleteB = samples.length > 1 ? samples[1] : samples[0];

      // Dewan sets match in Gelanggang A
      sync.dewanSelectMatch(
        athlete: athleteA,
        category: SeniCategory.tunggal,
        nomorPartai: 'PARTAI 01',
        pool: 'POOL A',
        arenaCode: 'GELANGGANG A',
      );

      // Dewan sets match in Gelanggang B
      sync.dewanSelectMatch(
        athlete: athleteB,
        category: SeniCategory.ganda,
        nomorPartai: 'PARTAI 02',
        pool: 'POOL B',
        arenaCode: 'GELANGGANG B',
      );

      final stateA = sync.getArenaState('GELANGGANG A');
      final stateB = sync.getArenaState('GELANGGANG B');

      // Verify Gelanggang A
      expect(stateA.athlete.name, athleteA.name);
      expect(stateA.category, SeniCategory.tunggal);
      expect(stateA.nomorPartai, 'PARTAI 01');
      expect(stateA.pool, 'POOL A');

      // Verify Gelanggang B
      expect(stateB.athlete.name, athleteB.name);
      expect(stateB.category, SeniCategory.ganda);
      expect(stateB.nomorPartai, 'PARTAI 02');
      expect(stateB.pool, 'POOL B');

      // Modifying Gelanggang A must NOT affect Gelanggang B
      final athleteA2 = samples.length > 2 ? samples[2] : samples[0];
      sync.dewanSelectMatch(
        athlete: athleteA2,
        category: SeniCategory.beregu,
        nomorPartai: 'PARTAI 05',
        pool: 'POOL FINAL',
        arenaCode: 'GELANGGANG A',
      );

      expect(sync.getArenaState('GELANGGANG A').athlete.name, athleteA2.name);
      expect(sync.getArenaState('GELANGGANG A').category, SeniCategory.beregu);
      // Gelanggang B remains completely untouched
      expect(sync.getArenaState('GELANGGANG B').athlete.name, athleteB.name);
      expect(sync.getArenaState('GELANGGANG B').category, SeniCategory.ganda);
    });

    test('Judge score submission in Gelanggang A does NOT sync or leak to Gelanggang B', () {
      final stateA = sync.getArenaState('GELANGGANG A');
      final stateB = sync.getArenaState('GELANGGANG B');

      // Juri 1 in Gelanggang A submits score 9.85
      sync.juriSubmitScore(
        juriNumber: 1,
        score: 9.85,
        arenaCode: 'GELANGGANG A',
      );

      // Check Gelanggang A
      expect(stateA.juriScores[1]?['submitted'], isTrue);
      expect(stateA.juriScores[1]?['score'], 9.85);

      // Check Gelanggang B: Juri 1 must NOT be submitted and must NOT have score 9.85
      expect(stateB.juriScores[1]?['submitted'], isFalse);
      expect(stateB.juriScores[1]?['score'], 9.90);

      // Juri 2 in Gelanggang B submits score 9.78
      sync.juriSubmitScore(
        juriNumber: 2,
        score: 9.78,
        arenaCode: 'GELANGGANG B',
      );

      // Check Gelanggang B
      expect(stateB.juriScores[2]?['submitted'], isTrue);
      expect(stateB.juriScores[2]?['score'], 9.78);

      // Gelanggang A Juri 2 remains unsubmitted
      expect(stateA.juriScores[2]?['submitted'], isFalse);
    });

    test('Dewan penalties in Gelanggang A do NOT deduct from Gelanggang B score', () {
      final penaltyA = PenaltyDeduction(
        id: 'p1',
        label: 'Keluar Batas Gelanggang',
        deduction: 0.50,
        timestamp: DateTime.now(),
      );

      sync.dewanAddPenalty(penaltyA, arenaCode: 'GELANGGANG A');

      expect(sync.getArenaState('GELANGGANG A').penalties.length, 1);
      expect(sync.getArenaState('GELANGGANG A').calculateTotalPenalties(), 0.50);

      // Gelanggang B must have 0 penalties
      expect(sync.getArenaState('GELANGGANG B').penalties.length, 0);
      expect(sync.getArenaState('GELANGGANG B').calculateTotalPenalties(), 0.0);
    });

    test('Timekeeper timer in Gelanggang A runs independently without affecting Gelanggang B', () {
      // Start timer in Gelanggang A
      sync.timekeeperStartTimer(arenaCode: 'GELANGGANG A');
      sync.timekeeperSyncTimer(
        remainingSeconds: 120,
        status: 'running',
        arenaCode: 'GELANGGANG A',
      );

      final stateA = sync.getArenaState('GELANGGANG A');
      final stateB = sync.getArenaState('GELANGGANG B');

      expect(stateA.timerStatus, 'running');
      expect(stateA.timerRemainingSeconds, 120);

      // Gelanggang B timer must remain in standby with default 180 seconds
      expect(stateB.timerStatus, 'standby');
      expect(stateB.timerRemainingSeconds, 180);

      sync.timekeeperStopTimer(arenaCode: 'GELANGGANG A');
    });

    testWidgets('UI panel isolation: MonitoringScoreboardView for Gelanggang B ignores Gelanggang A events',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1000, 600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final samples = AthleteModel.getSampleAthletes();
      final athleteA = samples[0];
      final athleteB = samples.length > 1 ? samples[1] : samples[0];

      sync.dewanSelectMatch(
        athlete: athleteA,
        category: SeniCategory.tunggal,
        arenaCode: 'GELANGGANG A',
      );
      sync.dewanSelectMatch(
        athlete: athleteB,
        category: SeniCategory.ganda,
        arenaCode: 'GELANGGANG B',
      );

      // Mount Monitoring Scoreboard for GELANGGANG B
      await tester.pumpWidget(
        MaterialApp(
          home: MonitoringScoreboardView(
            arenaCode: 'GELANGGANG B',
            onBackToPortal: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Must display Gelanggang B info
      expect(find.text('GELANGGANG B'), findsOneWidget);
      expect(find.text(athleteB.name.toUpperCase()), findsWidgets);

      // Now, simulate Dewan update in Gelanggang A
      final newAthleteA = AthleteModel(
        id: 'new_a',
        documentId: 'doc_new_a',
        name: 'ATLET ARENA A BARU',
        kontingen: 'JAWA TIMUR',
        category: 'Tunggal',
        pool: 'POOL A',
        partai: 'PARTAI 99',
      );
      sync.dewanSelectMatch(
        athlete: newAthleteA,
        category: SeniCategory.tunggal,
        arenaCode: 'GELANGGANG A',
      );

      await tester.pump(const Duration(milliseconds: 100));

      // Gelanggang B scoreboard must NOT show the new athlete from Gelanggang A!
      expect(find.text('ATLET ARENA A BARU'), findsNothing);
      expect(find.text(athleteB.name.toUpperCase()), findsWidgets);
    });
  });
}
