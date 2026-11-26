import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pusaka_seni_v2/main.dart';
import 'package:pusaka_seni_v2/models/scoring_models.dart';
import 'package:pusaka_seni_v2/services/app_link_helper.dart';
import 'package:pusaka_seni_v2/services/gelanggang_sync_service.dart';
import 'package:pusaka_seni_v2/services/pusaka_seni_api_service.dart';
import 'package:pusaka_seni_v2/views/monitoring/monitoring_scoreboard_view.dart';
import 'package:pusaka_seni_v2/views/portal/gelanggang_verification_view.dart';
import 'package:pusaka_seni_v2/views/portal/scoring_portal_view.dart';
import 'package:url_launcher/link.dart';

void main() {
  group('Web/Windows Verification & Open Link in New Tab Tests', () {
    setUp(() {
      GelanggangSyncService.instance.resetVerification();
      PusakaSeniApiService.testVerifierOverride = null;
    });

    tearDown(() {
      GelanggangSyncService.instance.resetVerification();
      PusakaSeniApiService.testVerifierOverride = null;
    });

    test('AppLinkHelper builds and parses hash-fragment deep links cleanly', () {
      final uri = AppLinkHelper.buildRoleUri(
        role: 'monitoring',
        arenaCode: '23456789',
        baseUriOverride: Uri.parse('http://localhost:5000/'),
      );
      expect(uri.toString(), 'http://localhost:5000/#/?role=monitoring&arena=23456789');

      final parsed = AppLinkHelper.parseStartupRoute(uri);
      expect(parsed.role, 'monitoring');
      expect(parsed.arenaCode, '23456789');
      expect(parsed.juriNumber, isNull);

      final juriUri = AppLinkHelper.buildRoleUri(
        role: 'juri',
        arenaCode: '12345678',
        juriNumber: 3,
        baseUriOverride: Uri.parse('http://localhost:5000/'),
      );
      final parsedJuri = AppLinkHelper.parseStartupRoute(juriUri);
      expect(parsedJuri.role, 'juri');
      expect(parsedJuri.arenaCode, '12345678');
      expect(parsedJuri.juriNumber, 3);
    });

    testWidgets(
      'Opening deep link with role & arena in new tab navigates straight to panel',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(1280, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          PusakaSeniApp(
            enableAnimation: false,
            initialUri: Uri.parse(
              'http://localhost:5000/#/?role=monitoring&arena=12345678',
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(MonitoringScoreboardView), findsOneWidget);
        expect(GelanggangSyncService.instance.isGelanggangVerified, isTrue);
        expect(GelanggangSyncService.instance.activeArenaCode, 'GELANGGANG A');
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'Opening deep link with role only navigates directly to GelanggangVerificationView',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(1280, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          PusakaSeniApp(
            enableAnimation: false,
            initialUri: Uri.parse('http://localhost:5000/#/?role=dewan'),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(GelanggangVerificationView), findsOneWidget);
        expect(find.text('Dewan Pertandingan'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'ScoringPortalView wraps role cards with Link and displays new-tab buttons',
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

        // Each of the 4 role cards has Link widgets for native open-in-new-tab
        expect(find.byType(Link), findsWidgets);
        if (AppLinkHelper.supportsNewTab) {
          expect(find.byIcon(Icons.open_in_new_rounded), findsNWidgets(4));
        }
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'GelanggangVerificationView rejects arbitrary code and verifies admin-created code via explicit Verifikasi button',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(1280, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        PusakaSeniApiService.testVerifierOverride = (code) async {
          if (code == '234567') {
            return const GelanggangVerificationResult(
              status: GelanggangVerificationStatus.valid,
              info: VerifiedGelanggangInfo(
                gelanggangId: '717',
                gelanggangDocId: 'gel-1',
                rawArenaCode: '234567',
                arenaLabel: 'GELANGGANG 1 (234567)',
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

        String? verifiedArena;
        await tester.pumpWidget(
          MaterialApp(
            home: GelanggangVerificationView(
              roleName: 'Dewan Pertandingan',
              roleIcon: Icons.shield_rounded,
              accentColor: const Color(0xFFDC2626),
              enableAnimation: false,
              onVerified: (arena) => verifiedArena = arena,
              onBack: () {},
            ),
          ),
        );
        await tester.pumpAndSettle();

        // 1. Arbitrary/random code is rejected even when tapping explicit verify button
        await tester.enterText(find.byType(TextField), '999999');
        await tester.pumpAndSettle();

        final verifyBtn = find.text('Verifikasi Kode Gelanggang');
        expect(verifyBtn, findsOneWidget);
        await tester.tap(verifyBtn);
        await tester.pumpAndSettle();

        expect(verifiedArena, isNull);
        expect(
          find.textContaining('tidak ditemukan. Pastikan kode sudah dibuat oleh Admin Event.'),
          findsWidgets,
        );

        // 2. Valid admin-created code verifies cleanly via explicit Verifikasi button
        await tester.enterText(find.byType(TextField), '234567');
        await tester.pumpAndSettle();
        await tester.tap(verifyBtn);
        await tester.pumpAndSettle();

        expect(verifiedArena, 'GELANGGANG 1 (234567)');
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'Deep link with unregistered arena code is rejected and redirected back to GelanggangVerificationView',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(1280, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        PusakaSeniApiService.testVerifierOverride = (code) async {
          return GelanggangVerificationResult(
            status: GelanggangVerificationStatus.notFound,
            message:
                'Kode gelanggang "$code" tidak ditemukan. Pastikan kode sudah dibuat oleh Admin Event.',
          );
        };

        await tester.pumpWidget(
          PusakaSeniApp(
            enableAnimation: false,
            initialUri: Uri.parse(
              'http://localhost:5000/#/?role=monitoring&arena=99999999',
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(GelanggangVerificationView), findsOneWidget);
        expect(find.byType(MonitoringScoreboardView), findsNothing);
        expect(GelanggangSyncService.instance.isGelanggangVerified, isFalse);
        expect(tester.takeException(), isNull);
      },
    );
  });
}
