import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pusaka_seni_v2/models/scoring_models.dart';
import 'package:pusaka_seni_v2/services/gelanggang_sync_service.dart';
import 'package:pusaka_seni_v2/views/dewan/dewan_panel_view.dart';
import 'package:pusaka_seni_v2/views/monitoring/monitoring_scoreboard_view.dart';
import 'package:pusaka_seni_v2/views/scoring/scoring_panel_view.dart';
import 'package:pusaka_seni_v2/views/timekeeper/timekeeper_panel_view.dart';

void main() {
  group('Authoritative Dewan Judge Count & Timekeeper Timer Sync Tests', () {
    const arena = 'GELANGGANG SYNC-AUTHORITY';

    setUp(() {
      final sync = GelanggangSyncService.instance;
      sync.resetVerification(arenaCode: arena);
      sync.setActiveJuriCount(8, arenaCode: arena);
      sync.timekeeperSwitchMode(
        durationSeconds: 180,
        modeTitle: 'Standar (03:00)',
        arenaCode: arena,
      );
    });

    tearDown(() {
      GelanggangSyncService.instance.timekeeperStopTimer(arenaCode: arena);
      GelanggangSyncService.instance.resetVerification(arenaCode: arena);
    });

    test(
      'Remote Dewan juri_config syncs activeJuriCount and cannot be overwritten by Event default during verifyGelanggang',
      () {
        final sync = GelanggangSyncService.instance;
        final rev = DateTime.now().millisecondsSinceEpoch + 50000;

        // Remote Dewan sets activeJuriCount = 5 via dedicated juri_config record
        sync.applyRemoteSyncRecords(arena, [
          {
            'documentId': 'doc-jc-1',
            'penilai': 'sync|$arena|juri_config',
            'nilai': 5,
            'waktu': rev.toString(),
            'keterangan': jsonEncode({'jc': 5, 'dev': 'DEWAN_DEV'}),
          },
        ]);

        expect(sync.getActiveJuriCount(arenaCode: arena), 5);
        expect(sync.getArenaState(arena).hasDewanJuriCount, isTrue);

        // Another device (Juri/Monitoring/Timekeeper) verifies arena whose Strapi event has jumlah_juri = 4
        sync.verifyGelanggang(
          arenaCode: arena,
          eventId: '6',
          eventTitle: 'ABATA CAMPIO',
          jumlahJuri: 4,
        );

        // Dewan's authoritative count (5) MUST remain intact, NOT overwritten by 4!
        expect(sync.getActiveJuriCount(arenaCode: arena), 5);
      },
    );

    test(
      'Remote Timekeeper running timer uses server clock delta (zero device clock skew)',
      () {
        final sync = GelanggangSyncService.instance;
        final rev = DateTime.now().millisecondsSinceEpoch + 60000;
        final serverUpdatedAt = DateTime.utc(2026, 11, 26, 14, 0, 0);
        final serverNow = DateTime.utc(2026, 11, 26, 14, 0, 12); // exactly 12s later on server

        // Even if remote device clock `at` is wildly skewed (+300 seconds),
        // serverNow - updatedAt produces the exact 12s elapsed!
        sync.applyRemoteSyncRecords(
          arena,
          [
            {
              'documentId': 'doc-tm-skew',
              'penilai': 'sync|$arena|timer',
              'nilai': 180,
              'waktu': rev.toString(),
              'updatedAt': serverUpdatedAt.toIso8601String(),
              'keterangan': jsonEncode({
                'st': 'running',
                'rem': 180,
                'dur': 180,
                'mt': 'Standar (03:00)',
                'at': rev + 300000, // skewed device clock
                'dev': 'TK_DEV',
              }),
            },
          ],
          serverNow: serverNow,
        );

        final state = sync.getArenaState(arena);
        expect(state.timerStatus, 'running');
        expect(state.timerRemainingSeconds, 168); // 180 - 12 = 168 exact!
        sync.timekeeperStopTimer(arenaCode: arena);
      },
    );

    test(
      'Dewan selecting next athlete preserves Timekeeper active duration mode',
      () {
        final sync = GelanggangSyncService.instance;

        // Timekeeper switches mode to Tangan Kosong (01:20)
        sync.timekeeperSwitchMode(
          durationSeconds: 80,
          modeTitle: 'Tangan Kosong (01:20)',
          arenaCode: arena,
        );
        expect(sync.getArenaState(arena).targetDurationSeconds, 80);

        // Dewan selects next athlete without overriding targetDuration
        sync.dewanSelectMatch(
          athlete: AthleteModel.getSampleAthletes().first,
          category: SeniCategory.tunggal,
          arenaCode: arena,
        );

        final state = sync.getArenaState(arena);
        expect(state.targetDurationSeconds, 80);
        expect(state.timerRemainingSeconds, 80);
        expect(state.timerModeTitle, 'Tangan Kosong (01:20)');
      },
    );

    testWidgets(
      'Dewan judge count and Timekeeper live timer stay synced across Monitoring, Timekeeper, Dewan, and Juri panels',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(1280, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final sync = GelanggangSyncService.instance;
        sync.setActiveJuriCount(5, arenaCode: arena);
        sync.setSelectedJuriNumber(2);
        sync.juriSetReady(juriNumber: 2, isReady: true, arenaCode: arena);
        sync.timekeeperSyncTimer(
          remainingSeconds: 95,
          status: 'paused',
          targetDurationSeconds: 180,
          modeTitle: 'Standar (03:00)',
          arenaCode: arena,
        );

        // 1. Juri ScoringPanelView displays Timekeeper's exact synced 01:35 timer
        await tester.pumpWidget(
          const MaterialApp(home: ScoringPanelView(arenaCode: arena)),
        );
        await tester.pumpAndSettle();
        expect(find.text('01:35'), findsOneWidget);
        expect(tester.takeException(), isNull);

        // 2. TimekeeperPanelView displays Dewan's synced "5 Juri" badge & 01:35 timer
        await tester.pumpWidget(
          MaterialApp(
            home: TimekeeperPanelView(
              arenaCode: arena,
              onBackToPortal: () {},
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('5 Juri'), findsOneWidget);
        expect(find.text('01:35'), findsOneWidget);
        expect(tester.takeException(), isNull);

        // 3. MonitoringScoreboardView displays 5 judges (from Dewan) & Timekeeper's 01:35
        await tester.pumpWidget(
          MaterialApp(
            home: MonitoringScoreboardView(
              arenaCode: arena,
              onBackToPortal: () {},
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('JURI 5'), findsOneWidget);
        expect(find.text('JURI 6'), findsNothing);
        expect(find.textContaining('01:35'), findsWidgets);
        expect(tester.takeException(), isNull);

        // 4. DewanPanelView displays Timekeeper's exact 01:35
        await tester.pumpWidget(
          MaterialApp(
            home: DewanPanelView(
              arenaCode: arena,
              onBackToPortal: () {},
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.textContaining('01:35'), findsWidgets);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'Dewan Restart Slot Juri icon releases single stuck judge slot or all judge slots',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(1280, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final sync = GelanggangSyncService.instance;
        sync.setActiveJuriCount(5, arenaCode: arena);
        sync.claimJuri(2, arenaCode: arena, customDeviceId: 'STUCK_DEVICE_2');
        sync.claimJuri(3, arenaCode: arena, customDeviceId: 'STUCK_DEVICE_3');
        sync.juriSetReady(juriNumber: 2, isReady: true, arenaCode: arena);
        sync.juriStartScoring(
          juriNumber: 3,
          currentScore: 9.89,
          arenaCode: arena,
        );
        expect(sync.getJuriStatus(2, arenaCode: arena), 'ready');
        expect(sync.getJuriStatus(3, arenaCode: arena), 'scoring');

        // Confirm Juri 2 & Juri 3 are currently unavailable for a new device
        expect(
          sync.getAvailableJudgesForThisDevice(
            arenaCode: arena,
            customDeviceId: 'NEW_DEVICE',
          ),
          isNot(contains(3)),
        );

        await tester.pumpWidget(
          MaterialApp(
            home: DewanPanelView(
              arenaCode: arena,
              onBackToPortal: () {},
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Tap Restart Slot Juri icon button in Dewan panel
        final restartBtn = find.byTooltip('Restart Slot Juri');
        expect(restartBtn, findsOneWidget);
        await tester.tap(restartBtn);
        await tester.pumpAndSettle();

        expect(find.text('Restart Slot Juri'), findsOneWidget);
        expect(find.text('Reset Semua Slot Juri'), findsOneWidget);

        // 1. Release ONLY Juri 3 -> Juri 3 slot opens AND status immediately becomes not_ready
        await tester.tap(find.text('Juri 3').last);
        await tester.pumpAndSettle();

        final availAfterSingle = sync.getAvailableJudgesForThisDevice(
          arenaCode: arena,
          customDeviceId: 'NEW_DEVICE',
        );
        expect(availAfterSingle, contains(3));
        expect(availAfterSingle, isNot(contains(2)));
        expect(sync.getJuriStatus(3, arenaCode: arena), 'not_ready');
        expect(sync.isJuriReady(3, arenaCode: arena), isFalse);
        expect(sync.getJuriStatus(2, arenaCode: arena), 'ready');

        // 2. Open dialog again and tap Reset Semua Slot Juri -> ALL judges become not_ready
        await tester.tap(restartBtn);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Reset Semua Slot Juri'));
        await tester.pumpAndSettle();

        final availAfterAll = sync.getAvailableJudgesForThisDevice(
          arenaCode: arena,
          customDeviceId: 'NEW_DEVICE',
        );
        expect(availAfterAll, [1, 2, 3, 4, 5]);
        expect(sync.getJuriStatus(2, arenaCode: arena), 'not_ready');
        expect(sync.isJuriReady(2, arenaCode: arena), isFalse);
        expect(tester.takeException(), isNull);
      },
    );
  });
}
