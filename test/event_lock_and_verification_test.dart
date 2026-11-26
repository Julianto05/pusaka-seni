import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pusaka_seni_v2/services/gelanggang_sync_service.dart';
import 'package:pusaka_seni_v2/services/pusaka_seni_api_service.dart';
import 'package:pusaka_seni_v2/views/dewan/dewan_panel_view.dart';
import 'package:pusaka_seni_v2/views/monitoring/monitoring_scoreboard_view.dart';
import 'package:pusaka_seni_v2/views/portal/gelanggang_verification_view.dart';
import 'package:pusaka_seni_v2/views/portal/scoring_portal_view.dart';

void main() {
  group('Event Lock & Post-Verification Display Tests', () {
    setUp(() {
      GelanggangSyncService.instance.resetVerification();
    });

    tearDown(() {
      GelanggangSyncService.instance.resetVerification();
    });

    testWidgets(
      'GelanggangVerificationView no longer renders PILIH ARENA AKTIF quick presets',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(1280, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          MaterialApp(
            home: GelanggangVerificationView(
              roleName: 'Dewan Pertandingan',
              roleIcon: Icons.shield_rounded,
              accentColor: const Color(0xFFDC2626),
              enableAnimation: false,
              onVerified: (_) {},
              onBack: () {},
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('PILIH ARENA AKTIF'), findsNothing);
        expect(find.text('GELANGGANG A'), findsNothing);
        expect(find.text('GELANGGANG B'), findsNothing);
        expect(find.text('Kode Gelanggang (8 Digit)'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'Event name is hidden before verification and displayed after Gelanggang verification',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(1280, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

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

        // Before verification: no event name displayed, shows Belum Verifikasi
        expect(find.text('Belum Verifikasi'), findsOneWidget);
        expect(find.textContaining('ABATA CAMPIO'), findsNothing);

        // Perform verification with locked Event ID & Gelanggang
        GelanggangSyncService.instance.verifyGelanggang(
          arenaCode: 'GELANGGANG 1 (23456789)',
          rawArenaCode: '23456789',
          gelanggangId: '717',
          gelanggangDocId: 'ixsc01579srddp0ydojtreq3',
          eventId: '6',
          eventDocId: 'l94u7vb17hfhrj11y6culgbg',
          eventTitle: 'ABATA CAMPIO',
          eventCode: 'ABT-87645',
          jumlahJuri: 4,
        );
        await tester.pumpAndSettle();

        // After verification: Event Name and locked arena are displayed
        expect(find.text('Belum Verifikasi'), findsNothing);
        expect(find.text('ABATA CAMPIO (ABT-87645)'), findsOneWidget);
        expect(find.text('GELANGGANG 1 (23456789)'), findsOneWidget);

        // MonitoringScoreboardView displays locked event title
        await tester.pumpWidget(
          MaterialApp(
            home: MonitoringScoreboardView(
              arenaCode: 'GELANGGANG 1 (23456789)',
              onBackToPortal: () {},
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('ABATA CAMPIO'), findsOneWidget);

        // DewanPanelView shows locked event title and respects locked jumlah_juri = 4
        await tester.pumpWidget(
          MaterialApp(
            home: DewanPanelView(
              arenaCode: 'GELANGGANG 1 (23456789)',
              onBackToPortal: () {},
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.textContaining('ABATA CAMPIO'), findsWidgets);
        expect(
          GelanggangSyncService.instance
              .getArenaState('GELANGGANG 1 (23456789)')
              .activeJuriCount,
          4,
        );
        expect(tester.takeException(), isNull);
      },
    );

    test(
      'extractAthletesFromJadwals strictly locks athletes to verified Event ID & Gelanggang',
      () {
        final mockJadwals = [
          {
            'nomor_partai': 'Partai 01',
            'event': {'id': 6, 'documentId': 'ev-abata'},
            'gelanggang': {'id': 717, 'documentId': 'gel-1'},
            'pool': {
              'documentId': 'pool-a',
              'pool_name': 'Pool A (Tunggal)',
              'kategori': 'tunggal',
              'pesertas': [
                {
                  'id': 101,
                  'documentId': 'peserta-1',
                  'name': 'Atlet Event Abata Gelanggang 1',
                  'kontingen': 'NTB',
                },
              ],
            },
          },
          // Different event -> must be filtered out!
          {
            'nomor_partai': 'Partai 02',
            'event': {'id': 99, 'documentId': 'ev-other'},
            'gelanggang': {'id': 717, 'documentId': 'gel-1'},
            'pool': {
              'documentId': 'pool-b',
              'pool_name': 'Pool B (Tunggal)',
              'kategori': 'tunggal',
              'pesertas': [
                {
                  'id': 102,
                  'documentId': 'peserta-other-event',
                  'name': 'Atlet Event Lain',
                  'kontingen': 'Jawa Barat',
                },
              ],
            },
          },
          // Different gelanggang -> must be filtered out!
          {
            'nomor_partai': 'Partai 03',
            'event': {'id': 6, 'documentId': 'ev-abata'},
            'gelanggang': {'id': 721, 'documentId': 'gel-2'},
            'pool': {
              'documentId': 'pool-c',
              'pool_name': 'Pool C (Tunggal)',
              'kategori': 'tunggal',
              'pesertas': [
                {
                  'id': 103,
                  'documentId': 'peserta-other-gelanggang',
                  'name': 'Atlet Gelanggang Lain',
                  'kontingen': 'Bali',
                },
              ],
            },
          },
        ];

        final filtered = PusakaSeniApiService.extractAthletesFromJadwals(
          mockJadwals,
          lockedEventId: '6',
          lockedEventDocId: 'ev-abata',
          lockedGelanggangDocId: 'gel-1',
        );

        expect(filtered.length, 1);
        expect(filtered.first.name, 'Atlet Event Abata Gelanggang 1');
        expect(filtered.first.partai, 'Partai 01');
        expect(filtered.first.poolDocId, 'pool-a');
        expect(filtered.first.eventDocId, 'ev-abata');
        expect(filtered.first.gelanggangDocId, 'gel-1');
      },
    );
  });
}
