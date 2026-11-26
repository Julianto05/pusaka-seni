import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:pusaka_seni_v2/models/scoring_models.dart';
import 'package:pusaka_seni_v2/services/gelanggang_sync_service.dart';

void main() {
  group('Cross-Device Cloud Sync Tests', () {
    late GelanggangSyncService sync;

    setUp(() {
      sync = GelanggangSyncService.instance;
      sync.cloudSyncEnabled = false;
    });

    test('Applies remote Dewan match selection, Juri claims/scores, penalties, and finalization', () {
      const arena = 'GELANGGANG SYNC_1';
      final baseRev = DateTime.now().millisecondsSinceEpoch + 10000;
      const matchVersion = 'match_rev_001';

      final records = <Map<String, dynamic>>[
        {
          'documentId': 'doc_match_1',
          'penilai': 'sync|$arena|match',
          'nilai': 0.0,
          'waktu': '$baseRev',
          'keterangan': jsonEncode({
            'mk': matchVersion,
            'id': '42',
            'doc': 'ath_doc_42',
            'n': 'Andi Pratama',
            'k': 'NTB',
            'c': 'tunggal',
            'p': 'PARTAI 07',
            'pl': 'POOL FINAL',
            'jc': 5,
            'fin': 0,
            'fs': 0.0,
            'dev': 'REMOTE_DEWAN',
          }),
        },
        {
          'documentId': 'doc_juri_1',
          'penilai': 'sync|$arena|juri|1',
          'nilai': 9.88,
          'waktu': '${baseRev + 10}',
          'keterangan': jsonEncode({
            'mk': matchVersion,
            'st': 'submitted',
            'sub': 1,
            'kb': 9.83,
            'km': 0.05,
            'dev': 'REMOTE_JURI_1',
          }),
        },
        {
          'documentId': 'doc_juri_2_stale',
          'penilai': 'sync|$arena|juri|2',
          'nilai': 9.10,
          'waktu': '${baseRev + 20}',
          'keterangan': jsonEncode({
            'mk': 'old_match_000',
            'st': 'submitted',
            'sub': 1,
            'kb': 9.10,
            'dev': 'REMOTE_JURI_2',
          }),
        },
        {
          'documentId': 'doc_pen_1',
          'penilai': 'sync|$arena|penalties',
          'nilai': 0.50,
          'waktu': '${baseRev + 30}',
          'keterangan': jsonEncode({
            'mk': matchVersion,
            't': 0.50,
            'p': [
              ['p1', 'Keluar Batas Gelanggang', 0.50],
            ],
            'dev': 'REMOTE_DEWAN',
          }),
        },
      ];

      sync.applyRemoteSyncRecords(arena, records);

      final state = sync.getArenaState(arena);
      expect(sync.lastSyncAction, 'ATHLETE_SELECTED');
      expect(state.matchVersion, matchVersion);
      expect(state.athlete.name, 'Andi Pratama');
      expect(state.athlete.kontingen, 'NTB');
      expect(state.category, SeniCategory.tunggal);
      expect(state.nomorPartai, 'PARTAI 07');
      expect(state.activeJuriCount, 5);

      // Juri 1 (matching matchVersion) applied completely
      expect(state.juriScores[1]?['score'], closeTo(9.88, 0.001));
      expect(state.juriScores[1]?['submitted'], isTrue);
      expect(state.juriScores[1]?['status'], 'submitted');

      // Juri 2 had old matchVersion: claim applies (so phone 2 keeps its slot),
      // but stale score 9.10 is NOT applied to the new match!
      expect(state.juriScores[2]?['submitted'], isFalse);
      expect(state.juriScores[2]?['score'], closeTo(9.90, 0.001));

      // Both Juri 1 and Juri 2 are hidden from this device's available judges list
      final available = sync.getAvailableJudgesForThisDevice(arenaCode: arena);
      expect(available, containsAll([3, 4, 5]));
      expect(available, isNot(contains(1)));
      expect(available, isNot(contains(2)));

      // Penalties synced accurately
      expect(state.penalties.length, 1);
      expect(state.calculateTotalPenalties(), closeTo(0.50, 0.001));

      // Now Dewan finalizes the match remotely (same matchVersion, higher rev)
      sync.applyRemoteSyncRecords(arena, [
        {
          'documentId': 'doc_match_1',
          'penilai': 'sync|$arena|match',
          'nilai': 9.38,
          'waktu': '${baseRev + 100}',
          'keterangan': jsonEncode({
            'mk': matchVersion,
            'id': '42',
            'doc': 'ath_doc_42',
            'n': 'Andi Pratama',
            'k': 'NTB',
            'c': 'tunggal',
            'p': 'PARTAI 07',
            'pl': 'POOL FINAL',
            'jc': 5,
            'fin': 1,
            'fs': 9.38,
            'dev': 'REMOTE_DEWAN',
          }),
        },
      ]);

      expect(state.isMatchFinalized, isTrue);
      expect(state.officialFinalScore, closeTo(9.38, 0.001));
      expect(sync.isAthleteCompleted(state.athlete, arenaCode: arena), isTrue);
    });

    test('Applies remote Timekeeper timer mode switch and running countdown anchor', () {
      const arena = 'GELANGGANG SYNC_2';
      final nowMs = DateTime.now().millisecondsSinceEpoch;
      final rev = nowMs + 20000;

      // 1. Remote Timekeeper switches to Tangan Kosong (80s)
      sync.applyRemoteSyncRecords(arena, [
        {
          'documentId': 'doc_timer_2',
          'penilai': 'sync|$arena|timer',
          'nilai': 80.0,
          'waktu': '$rev',
          'keterangan': jsonEncode({
            'st': 'standby',
            'rem': 80,
            'dur': 80,
            'mt': 'Tangan Kosong (01:20)',
            'at': nowMs,
            'dev': 'REMOTE_TK',
          }),
        },
      ]);

      final state = sync.getArenaState(arena);
      expect(state.targetDurationSeconds, 80);
      expect(state.timerRemainingSeconds, 80);
      expect(state.timerModeTitle, 'Tangan Kosong (01:20)');
      expect(state.timerStatus, 'standby');

      // 2. Remote Timekeeper started timer 3 seconds ago -> remaining adjusts automatically
      sync.applyRemoteSyncRecords(arena, [
        {
          'documentId': 'doc_timer_2',
          'penilai': 'sync|$arena|timer',
          'nilai': 80.0,
          'waktu': '${rev + 50}',
          'keterangan': jsonEncode({
            'st': 'running',
            'rem': 80,
            'dur': 80,
            'mt': 'Tangan Kosong (01:20)',
            'at': nowMs - 3000,
            'dev': 'REMOTE_TK',
          }),
        },
      ]);

      expect(state.timerStatus, 'running');
      expect(state.timerRemainingSeconds, inInclusiveRange(76, 78));

      // Cleanup timer
      sync.timekeeperStopTimer(arenaCode: arena);
    });

    test('Cloud sync maintains strict isolation between different arenas', () {
      const arenaA = 'GELANGGANG ISO_A';
      const arenaB = 'GELANGGANG ISO_B';
      final rev = DateTime.now().millisecondsSinceEpoch + 30000;

      // Pass Arena B records into Arena A merge -> must be ignored
      sync.applyRemoteSyncRecords(arenaA, [
        {
          'documentId': 'doc_b',
          'penilai': 'sync|$arenaB|match',
          'nilai': 0.0,
          'waktu': '$rev',
          'keterangan': jsonEncode({
            'mk': 'mk_b',
            'id': '99',
            'doc': 'doc_99',
            'n': 'Atlet Arena B',
            'k': 'Bali',
            'c': 'ganda',
            'p': 'PARTAI 99',
            'pl': 'POOL B',
            'jc': 3,
            'fin': 0,
            'fs': 0.0,
            'dev': 'DEV_B',
          }),
        },
      ]);

      expect(sync.getArenaState(arenaA).athlete.name, isNot('Atlet Arena B'));
      expect(sync.getArenaState(arenaA).matchVersion, isNot('mk_b'));
    });

    test('Remote claims_reset frees previously claimed judge slots', () {
      const arena = 'GELANGGANG SYNC_CLAIMS';
      final rev = DateTime.now().millisecondsSinceEpoch + 40000;

      sync.applyRemoteSyncRecords(arena, [
        {
          'documentId': 'doc_c1',
          'penilai': 'sync|$arena|juri|1',
          'nilai': 9.90,
          'waktu': '$rev',
          'keterangan': jsonEncode({
            'mk': '',
            'st': 'ready',
            'sub': 0,
            'kb': 9.90,
            'dev': 'OTHER_PHONE',
          }),
        },
      ]);
      expect(sync.getAvailableJudgesForThisDevice(arenaCode: arena), isNot(contains(1)));

      // Now receive a newer claims_reset
      sync.applyRemoteSyncRecords(arena, [
        {
          'documentId': 'doc_reset',
          'penilai': 'sync|$arena|claims_reset',
          'nilai': 0.0,
          'waktu': '${rev + 100}',
          'keterangan': jsonEncode({'dev': 'DEWAN_PHONE'}),
        },
      ]);
      expect(sync.getAvailableJudgesForThisDevice(arenaCode: arena), contains(1));
    });
  });
}
