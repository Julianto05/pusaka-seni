import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pusaka_seni_v2/models/scoring_models.dart';
import 'package:pusaka_seni_v2/services/gelanggang_sync_service.dart';
import 'package:pusaka_seni_v2/views/dewan/dewan_panel_view.dart';
import 'package:pusaka_seni_v2/views/monitoring/monitoring_scoreboard_view.dart';
import 'package:pusaka_seni_v2/views/scoring/components/modals/athlete_selector_dialog.dart';
import 'package:pusaka_seni_v2/views/timekeeper/timekeeper_panel_view.dart';

void main() {
  group('Dewan Pertandingan & Instant Category Filter Tests', () {
    late GelanggangSyncService sync;

    setUp(() {
      sync = GelanggangSyncService.instance;
      sync.setActiveJuriCount(8);
      sync.timekeeperStopTimer();
      sync.timekeeperSwitchMode(
        durationSeconds: 180,
        modeTitle: 'Standar (03:00)',
      );
    });

    test('Dewan can configure active judge count (3, 5, 8) dynamically', () {
      expect(sync.activeJuriCount, 8);

      // Change to 3 judges
      sync.setActiveJuriCount(3);
      expect(sync.activeJuriCount, 3);
      expect(sync.juriScores.keys.toList(), containsAllInOrder([1, 2, 3]));
      expect(sync.juriScores.containsKey(4), isFalse);

      // Change to 5 judges
      sync.setActiveJuriCount(5);
      expect(sync.activeJuriCount, 5);
      expect(sync.juriScores.keys.toList(), containsAllInOrder([1, 2, 3, 4, 5]));
      expect(sync.juriScores.containsKey(6), isFalse);

      // Change back to 8 judges
      sync.setActiveJuriCount(8);
      expect(sync.activeJuriCount, 8);
      expect(sync.juriScores.length, 8);
    });

    test('Participant performance status (Sedang Tampil vs Selesai vs Belum)', () {
      final samples = AthleteModel.getSampleAthletes();
      final athlete1 = samples[0];
      final athlete2 = samples[1];

      // Dewan selects athlete1
      sync.dewanSelectMatch(
        athlete: athlete1,
        category: SeniCategory.fromString(athlete1.category),
      );

      // athlete1 is now performing
      expect(sync.isAthleteActive(athlete1), isTrue);
      expect(sync.isAthleteCompleted(athlete1), isFalse);

      // athlete2 is waiting (Belum Tampil)
      expect(sync.isAthleteActive(athlete2), isFalse);
      expect(sync.isAthleteCompleted(athlete2), isFalse);

      // Dewan finalizes athlete1 match with score 9.915
      sync.dewanFinalizeMatch(9.915);

      expect(sync.isAthleteCompleted(athlete1), isTrue);
      expect(sync.isAthleteActive(athlete1), isFalse);
      expect(sync.getAthleteScore(athlete1), closeTo(9.915, 0.001));

      // Now Dewan selects athlete2
      sync.dewanSelectMatch(
        athlete: athlete2,
        category: SeniCategory.fromString(athlete2.category),
      );

      expect(sync.isAthleteActive(athlete2), isTrue);
      expect(sync.isAthleteCompleted(athlete2), isFalse);

      // athlete1 remains completed
      expect(sync.isAthleteCompleted(athlete1), isTrue);
      expect(sync.isAthleteActive(athlete1), isFalse);
    });

    testWidgets('AthleteSelectorDialog instant category filter and status badges render',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final samples = AthleteModel.getSampleAthletes();
      SeniCategory activeCat = SeniCategory.tunggal;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AthleteSelectorDialog(
              currentAthlete: samples[0],
              currentCategory: activeCat,
              onAthleteSelected: (_) {},
              onCategoryChanged: (cat) => activeCat = cat,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Check category filter chips exist
      expect(find.text('Semua Kategori'), findsOneWidget);
      expect(find.text('Seni Tunggal'), findsOneWidget);
      expect(find.text('Seni Beregu'), findsOneWidget);

      // Tap 'Seni Tunggal'
      await tester.ensureVisible(find.text('Seni Tunggal'));
      await tester.tap(find.text('Seni Tunggal'));
      await tester.pumpAndSettle();

      expect(find.text('PESERTA SENI TUNGGAL'), findsOneWidget);

      // Tap 'Semua Kategori'
      await tester.ensureVisible(find.text('Semua Kategori'));
      await tester.tap(find.text('Semua Kategori'));
      await tester.pumpAndSettle();

      expect(find.text('SEMUA PESERTA'), findsOneWidget);
    });

    testWidgets('DewanPanelView renders judge selector chips and full screen button',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1024, 768);
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

      // Check judge selector chips
      expect(find.text('Juri Bertugas:'), findsOneWidget);
      expect(find.text('3 Juri'), findsOneWidget);
      expect(find.text('4 Juri'), findsOneWidget);
      expect(find.text('5 Juri'), findsOneWidget);
      expect(find.text('8 Juri'), findsOneWidget);

      // Tap 4 Juri chip
      await tester.tap(find.text('4 Juri'));
      await tester.pumpAndSettle();

      expect(sync.activeJuriCount, 4);

      // Tap 3 Juri chip
      await tester.tap(find.text('3 Juri'));
      await tester.pumpAndSettle();

      expect(sync.activeJuriCount, 3);

      // Check fullscreen toggle tooltip
      expect(find.byTooltip('Layar Penuh Dewan'), findsOneWidget);
    });

    testWidgets('MonitoringScoreboardView reflects active judge count from Dewan',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      sync.setActiveJuriCount(5);

      await tester.pumpWidget(
        MaterialApp(
          home: MonitoringScoreboardView(onBackToPortal: () {}),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('JURI 1'), findsOneWidget);
      expect(find.text('JURI 5'), findsOneWidget);
      expect(find.text('JURI 6'), findsNothing);

      // Check Standard Deviation and Median are displayed
      expect(find.text('STANDARD DEVIATION'), findsOneWidget);
      expect(find.text('MEDIAN'), findsOneWidget);
      expect(find.text('PENALTY'), findsOneWidget);
    });

    test('Judge readiness flow & 4 status color transitions (not_ready, ready, scoring, submitted)', () {
      final samples = AthleteModel.getSampleAthletes();
      sync.setActiveJuriCount(3);

      // Dewan selects a match -> all judges reset to not_ready
      sync.dewanSelectMatch(
        athlete: samples[0],
        category: SeniCategory.tunggal,
      );

      expect(sync.getJuriStatus(1), 'not_ready');
      expect(sync.getJuriStatus(2), 'not_ready');
      expect(sync.getJuriStatus(3), 'not_ready');
      expect(sync.isJuriReady(1), isFalse);
      expect(sync.countReadyJudges(), 0);

      // Juri 1 confirms ready (Hijau)
      sync.juriSetReady(juriNumber: 1, isReady: true);
      expect(sync.getJuriStatus(1), 'ready');
      expect(sync.isJuriReady(1), isTrue);
      expect(sync.countReadyJudges(), 1);

      // Juri 2 confirms ready (Hijau)
      sync.juriSetReady(juriNumber: 2, isReady: true);
      expect(sync.getJuriStatus(2), 'ready');
      expect(sync.countReadyJudges(), 2);

      // Juri 1 starts scoring (wrong/next/slider) -> status becomes scoring (Kuning)
      sync.juriStartScoring(juriNumber: 1, currentScore: 9.89);
      expect(sync.getJuriStatus(1), 'scoring');
      expect(sync.isJuriReady(1), isTrue);

      // Juri 1 finalizes and submits score -> status becomes submitted (Biru)
      sync.juriSubmitScore(juriNumber: 1, score: 9.89, kebenaran: 9.89, kemantapan: 0.0);
      expect(sync.getJuriStatus(1), 'submitted');
      expect(sync.isJuriSubmitted(1), isTrue);

      // Dewan selects a new match -> judges reset to not_ready again
      sync.dewanSelectMatch(
        athlete: samples[1],
        category: SeniCategory.ganda,
      );
      expect(sync.getJuriStatus(1), 'not_ready');
      expect(sync.getJuriStatus(2), 'not_ready');
      expect(sync.isJuriReady(1), isFalse);
      expect(sync.isJuriSubmitted(1), isFalse);
      expect(sync.countReadyJudges(), 0);
    });

    testWidgets('DewanPanelView displays 4 status color indicators for judges',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final samples = AthleteModel.getSampleAthletes();
      sync.setActiveJuriCount(3);
      sync.dewanSelectMatch(athlete: samples[0], category: SeniCategory.tunggal);

      // Juri 1 = not_ready, Juri 2 = ready, Juri 3 = scoring
      sync.juriSetReady(juriNumber: 2, isReady: true);
      sync.juriStartScoring(juriNumber: 3, currentScore: 9.85);

      await tester.pumpWidget(
        MaterialApp(
          home: DewanPanelView(onBackToPortal: () {}),
        ),
      );
      await tester.pumpAndSettle();

      // Check the 4 status badges
      expect(find.text('BELUM READY'), findsOneWidget); // Juri 1
      expect(find.text('READY'), findsOneWidget);       // Juri 2
      expect(find.text('MENILAI'), findsOneWidget);     // Juri 3

      // Now Juri 3 submits score -> changes to SELESAI
      sync.juriSubmitScore(juriNumber: 3, score: 9.85);
      await tester.pumpAndSettle();

      expect(find.text('SELESAI'), findsOneWidget);     // Juri 3
    });

    testWidgets('DewanPanelView displays live jurus indicator inside Juri box while scoring',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final samples = AthleteModel.getSampleAthletes();
      sync.setActiveJuriCount(4);
      sync.dewanSelectMatch(athlete: samples[0], category: SeniCategory.tunggal);

      // Juri 1 sedang menilai Jurus 3/14 (Tangan kosong), Juri 2 di Jurus 9/14 (Golok)
      sync.juriStartScoring(
        juriNumber: 1,
        currentScore: 9.89,
        currentJurus: 3,
        totalJurus: 14,
        jurusLabel: 'Tangan kosong',
      );
      sync.juriStartScoring(
        juriNumber: 2,
        currentScore: 9.87,
        currentJurus: 9,
        totalJurus: 14,
        jurusLabel: 'Golok',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: DewanPanelView(onBackToPortal: () {}),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Jurus 3/14 • T. Kosong'), findsOneWidget);
      expect(find.text('Jurus 9/14 • Golok'), findsOneWidget);

      // Juri 1 selesai dan mengirim nilai
      sync.juriSubmitScore(
        juriNumber: 1,
        score: 9.94,
        kebenaran: 9.89,
        kemantapan: 0.05,
        currentJurus: 14,
        totalJurus: 14,
        jurusLabel: 'Tuntas',
      );
      await tester.pumpAndSettle();

      expect(find.text('Tuntas (14/14)'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    test('Timekeeper syncs timer duration, category mode, and status to GelanggangSyncService', () {
      // 1. Standar 3 minutes default
      sync.timekeeperSyncTimer(
        remainingSeconds: 180,
        status: 'standby',
        targetDurationSeconds: 180,
        modeTitle: 'Standar (03:00)',
      );

      expect(sync.timerRemainingSeconds, 180);
      expect(sync.targetDurationSeconds, 180);
      expect(sync.timerStatus, 'standby');
      expect(sync.timerModeTitle, 'Standar (03:00)');
      expect(sync.timerStatusLabel, 'STANDBY');
      expect(sync.formattedTimerRemaining, '03:00');
      expect(sync.formattedTimerElapsed, '00 : 00');

      // 2. Timekeeper starts timer
      sync.timekeeperSyncTimer(
        remainingSeconds: 175,
        status: 'running',
      );
      expect(sync.timerRemainingSeconds, 175);
      expect(sync.timerStatus, 'running');
      expect(sync.timerStatusLabel, 'BERJALAN');
      expect(sync.formattedTimerRemaining, '02:55');
      expect(sync.formattedTimerElapsed, '00 : 05');

      // 3. Timekeeper pauses timer
      sync.timekeeperSyncTimer(
        remainingSeconds: 175,
        status: 'paused',
      );
      expect(sync.timerStatus, 'paused');
      expect(sync.timerStatusLabel, 'JEDA');

      // 4. Timekeeper switches mode to Usia Dini Tangan Kosong (80s / 01:20)
      sync.timekeeperSyncTimer(
        remainingSeconds: 80,
        status: 'standby',
        targetDurationSeconds: 80,
        modeTitle: 'Usia Dini Tangan Kosong (01:20)',
      );
      expect(sync.timerRemainingSeconds, 80);
      expect(sync.targetDurationSeconds, 80);
      expect(sync.timerModeTitle, 'Usia Dini Tangan Kosong (01:20)');
      expect(sync.formattedTimerRemaining, '01:20');
      expect(sync.formattedTimerElapsed, '00 : 00');

      // 5. Timekeeper stops / completes timer
      sync.timekeeperSyncTimer(
        remainingSeconds: 0,
        status: 'stopped',
      );
      expect(sync.timerStatus, 'stopped');
      expect(sync.timerStatusLabel, 'SELESAI');
      expect(sync.formattedTimerRemaining, '00:00');
      expect(sync.formattedTimerElapsed, '01 : 20');
    });

    testWidgets('DewanPanelView live timer syncs with Timekeeper controls',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      // 1. Initial Standar 03:00 Standby
      sync.timekeeperSyncTimer(
        remainingSeconds: 180,
        status: 'standby',
        targetDurationSeconds: 180,
        modeTitle: 'Standar (03:00)',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: DewanPanelView(onBackToPortal: () {}),
        ),
      );
      await tester.pumpAndSettle();

      // Check header live timer badge and juri card timer indicator
      expect(find.text('03:00'), findsOneWidget); // in header badge
      expect(find.text('STANDBY'), findsOneWidget); // in header badge
      expect(find.text('Standar (03:00)'), findsOneWidget); // subtitle

      // 2. Timekeeper starts timer -> timer becomes 02:45 BERJALAN
      sync.timekeeperSyncTimer(
        remainingSeconds: 165,
        status: 'running',
      );
      await tester.pumpAndSettle();

      expect(find.text('02:45'), findsOneWidget);
      expect(find.text('BERJALAN'), findsOneWidget);

      // 3. Timekeeper switches mode to Usia Dini Senjata (100s / 01:40)
      sync.timekeeperSyncTimer(
        remainingSeconds: 100,
        status: 'standby',
        targetDurationSeconds: 100,
        modeTitle: 'Usia Dini Senjata (01:40)',
      );
      await tester.pumpAndSettle();

      expect(find.text('01:40'), findsOneWidget);
      expect(find.text('Usia Dini Senjata (01:40)'), findsOneWidget);
    });

    testWidgets('MonitoringScoreboardView live timer syncs with Timekeeper controls',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      // 1. Initial state: Standar 180s, standby
      sync.timekeeperSyncTimer(
        remainingSeconds: 180,
        status: 'standby',
        targetDurationSeconds: 180,
        modeTitle: 'Standar (03:00)',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: MonitoringScoreboardView(onBackToPortal: () {}),
        ),
      );
      await tester.pumpAndSettle();

      // In Scoreboard Main Area:
      expect(find.text('TIME PERFORMANCE'), findsOneWidget);
      expect(find.text('00 : 00'), findsOneWidget);
      expect(find.text('Standar (03:00)'), findsOneWidget);

      // In Top Bar:
      expect(find.text('03:00 • STANDBY'), findsOneWidget);

      // 2. Timekeeper starts timer -> 15s elapsed
      sync.timekeeperSyncTimer(
        remainingSeconds: 165,
        status: 'running',
      );
      await tester.pumpAndSettle();

      expect(find.text('00 : 15'), findsOneWidget);
      expect(find.text('02:45 • BERJALAN'), findsOneWidget);

      // 3. Timekeeper switches to Usia Dini Tangan Kosong (01:20)
      sync.timekeeperSyncTimer(
        remainingSeconds: 80,
        status: 'standby',
        targetDurationSeconds: 80,
        modeTitle: 'Usia Dini Tangan Kosong (01:20)',
      );
      await tester.pumpAndSettle();

      expect(find.text('00 : 00'), findsOneWidget);
      expect(find.text('01:20 • STANDBY'), findsOneWidget);
      expect(find.text('Usia Dini Tangan Kosong (01:20)'), findsOneWidget);
    });

    testWidgets('Timekeeper timer runs continuously across accidental exit and syncs with Dewan and Monitor',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
        sync.timekeeperResetTimer();
      });

      final athlete = AthleteModel.getSampleAthletes().first;
      sync.dewanSelectMatch(athlete: athlete, category: SeniCategory.tunggal);

      // 1. Timekeeper opens panel
      bool exited = false;
      await tester.pumpWidget(
        MaterialApp(
          home: TimekeeperPanelView(
            onBackToPortal: () {
              exited = true;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Mulai Timer'), findsOneWidget);
      expect(find.text('03:00'), findsWidgets);
      expect(sync.timerStatus, 'standby');

      // 2. Timekeeper starts timer
      await tester.tap(find.text('Mulai Timer'));
      await tester.pump(const Duration(milliseconds: 100));

      expect(sync.timerStatus, 'running');
      expect(find.text('Jeda'), findsOneWidget);

      // Advance 2 seconds
      await tester.pump(const Duration(seconds: 2));
      expect(sync.timerRemainingSeconds, lessThanOrEqualTo(178));

      // 3. Timekeeper accidentally exits (clicks back to portal)
      final backBtn = find.byTooltip('Kembali ke Portal');
      expect(backBtn, findsOneWidget);
      await tester.tap(backBtn);
      await tester.pump(const Duration(milliseconds: 100));
      expect(exited, isTrue);

      // Unmount TimekeeperPanelView (simulating having returned to portal)
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 100));

      // Timer in GelanggangSyncService is STILL running!
      expect(sync.timerStatus, 'running');

      // 4. Advance another 3 seconds in the background
      await tester.pump(const Duration(seconds: 3));
      expect(sync.timerRemainingSeconds, lessThanOrEqualTo(175));

      // 5. Open DewanPanelView - Dewan is in sync with the live timer
      await tester.pumpWidget(
        MaterialApp(
          home: DewanPanelView(onBackToPortal: () {}),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('BERJALAN'), findsWidgets);
      expect(sync.timerRemainingSeconds, lessThanOrEqualTo(175));

      // 6. Timekeeper re-enters TimekeeperPanelView
      await tester.pumpWidget(
        MaterialApp(
          home: TimekeeperPanelView(onBackToPortal: () {}),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      // Still running, button says 'Jeda', time is NOT reset!
      expect(find.text('Jeda'), findsOneWidget);
      expect(sync.timerStatus, 'running');
      expect(sync.timerRemainingSeconds, lessThanOrEqualTo(175));

      // 7. Timekeeper pauses timer
      await tester.tap(find.text('Jeda'));
      await tester.pump(const Duration(milliseconds: 100));

      expect(sync.timerStatus, 'paused');
      expect(find.text('Mulai Timer'), findsOneWidget);

      // 8. Timekeeper resets timer
      await tester.tap(find.text('Reset'));
      await tester.pump(const Duration(milliseconds: 100));

      expect(sync.timerStatus, 'standby');
      expect(sync.timerRemainingSeconds, 180);
      expect(find.text('03:00'), findsWidgets);
    });

    testWidgets('Timer continues running past target time into overtime, updates indicator color, and only stops when stopped by timekeeper',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
        sync.timekeeperResetTimer();
      });

      final athlete = AthleteModel.getSampleAthletes().first;
      sync.dewanSelectMatch(athlete: athlete, category: SeniCategory.tunggal);

      // Start timer with 2 seconds remaining to reach overtime quickly
      sync.timekeeperSyncTimer(remainingSeconds: 2, status: 'running');
      expect(sync.isOvertime, isFalse);

      // 1. Mount TimekeeperPanelView
      await tester.pumpWidget(
        MaterialApp(
          home: TimekeeperPanelView(onBackToPortal: () {}),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      // Advance 1 second: remaining is 1
      await tester.pump(const Duration(seconds: 1));
      expect(sync.timerRemainingSeconds, 1);
      expect(sync.isOvertime, isFalse);

      // Advance 1 second: remaining is 0
      await tester.pump(const Duration(seconds: 1));
      expect(sync.timerRemainingSeconds, 0);

      // Advance 2 seconds: timer does NOT stop! It goes into overtime: -1, -2
      await tester.pump(const Duration(seconds: 2));
      expect(sync.timerRemainingSeconds, lessThan(0));
      expect(sync.isOvertime, isTrue);
      expect(sync.timerStatus, 'running'); // Timer is STILL running!
      expect(sync.formattedTimerRemaining, contains('-00:02'));
      expect(sync.timerElapsedSeconds, 182); // 180 + 2

      // Check Timekeeper visual overtime indicators
      expect(find.text('-00:02'), findsWidgets);
      expect(find.text('WAKTU MELEBIHI TARGET (LEWAT)'), findsOneWidget);
      expect(find.text('LEWAT WAKTU'), findsOneWidget);

      // 2. Mount MonitoringScoreboardView - check overtime styling
      await tester.pumpWidget(
        MaterialApp(
          home: MonitoringScoreboardView(onBackToPortal: () {}),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('LEWAT WAKTU'), findsWidgets);
      expect(find.text('03 : 02'), findsOneWidget); // elapsed time performance

      // Advance another second while on scoreboard
      await tester.pump(const Duration(seconds: 1));
      expect(sync.timerRemainingSeconds, -3);
      expect(find.text('03 : 03'), findsOneWidget); // updated live

      // 3. Mount DewanPanelView - check overtime sync
      await tester.pumpWidget(
        MaterialApp(
          home: DewanPanelView(onBackToPortal: () {}),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.textContaining('LEWAT WAKTU'), findsWidgets);
      expect(find.textContaining('-00:03'), findsWidgets);

      // 4. Timer ONLY stops when Timekeeper explicitly stops it
      sync.timekeeperStopTimer();
      await tester.pump(const Duration(milliseconds: 100));

      expect(sync.timerStatus, 'stopped');
      final stoppedSeconds = sync.timerRemainingSeconds;

      // Advance 5 seconds - timer is stopped, seconds do not change
      await tester.pump(const Duration(seconds: 5));
      expect(sync.timerRemainingSeconds, stoppedSeconds);
    });
  });
}

