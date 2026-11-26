import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pusaka_seni_v2/models/scoring_models.dart';
import 'package:pusaka_seni_v2/services/gelanggang_sync_service.dart';
import 'package:pusaka_seni_v2/views/portal/gelanggang_verification_view.dart';
import 'package:pusaka_seni_v2/views/scoring/components/scoring_header.dart';
import 'package:pusaka_seni_v2/views/scoring/scoring_panel_view.dart';

void main() {
  group('Juri Selection & Locked Role Tests', () {
    late GelanggangSyncService sync;

    setUp(() {
      sync = GelanggangSyncService.instance;
      sync.setActiveJuriCount(8);
      sync.setSelectedJuriNumber(1);
    });

    testWidgets('GelanggangVerificationView displays Juri Selection buttons and locks selected juri', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: GelanggangVerificationView(
            roleName: 'Juri Pertandingan',
            roleIcon: Icons.balance_rounded,
            accentColor: const Color(0xFFF59E0B),
            enableAnimation: false,
            onVerified: (arena) {},
            onBack: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Check that Juri Selector title is displayed
      expect(find.text('PILIH NOMOR JURI PERANGKAT INI'), findsOneWidget);
      expect(find.text('Terkunci di Layar Juri'), findsOneWidget);

      // Select Juri 3
      final juri3Button = find.text('Juri 3');
      expect(juri3Button, findsOneWidget);
      await tester.tap(juri3Button);
      await tester.pumpAndSettle();

      expect(sync.selectedJuriNumber, 3);

      // Select Juri 5
      final juri5Button = find.text('Juri 5');
      expect(juri5Button, findsOneWidget);
      await tester.tap(juri5Button);
      await tester.pumpAndSettle();

      expect(sync.selectedJuriNumber, 5);
    });

    testWidgets('ScoringHeader displays locked JURI badge without DropdownButton or PopupMenuButton', (tester) async {
      final sample = AthleteModel.getSampleAthletes().first;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ScoringHeader(
              arenaCode: 'GELANGGANG A',
              juriNumber: 3,
              athlete: sample,
              category: SeniCategory.tunggal,
              currentScore: 9.90,
              isFullScreen: false,
              onToggleFullScreen: () {},
              onBackToMenu: () {},
              juriStatus: 'ready',
              onToggleReady: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify that locked badge "JURI 3" is present
      expect(find.text('JURI 3'), findsOneWidget);

      // Verify that DropdownButton and PopupMenuButton are NOT present in header
      expect(find.byType(DropdownButton), findsNothing);
      expect(find.byType(PopupMenuButton), findsNothing);
      expect(find.byIcon(Icons.arrow_drop_down_rounded), findsNothing);
    });

    testWidgets('ScoringPanelView submits score, displays summary popup, and resets on Dewan next match', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      sync.setSelectedJuriNumber(2);
      final athlete1 = AthleteModel.getSampleAthletes()[0];
      sync.dewanSelectMatch(athlete: athlete1, category: SeniCategory.tunggal);

      await tester.pumpWidget(
        const MaterialApp(
          home: ScoringPanelView(),
        ),
      );
      await tester.pumpAndSettle();

      // 1. Initial ready dialog appears
      expect(find.text('KESIAPAN JURI 2'), findsOneWidget);

      // Juri 2 confirms readiness
      final readyBtn = find.textContaining('SAYA SIAP MENILAI');
      expect(readyBtn, findsOneWidget);
      await tester.tap(readyBtn);
      await tester.pumpAndSettle();

      expect(sync.isJuriReady(2), isTrue);

      // 2. Advance all 14 jurus to reach completion
      final nextJurusBtn = find.text('NEXT');
      expect(nextJurusBtn, findsOneWidget);
      for (int i = 0; i < 14; i++) {
        await tester.tap(nextJurusBtn);
        await tester.pumpAndSettle();
      }

      // 3. Now ScoringBakuTuntasWidget is visible. Select Kemantapan (+0.05)
      final kemantapanChip = find.text('+0.05');
      expect(kemantapanChip, findsOneWidget);
      await tester.tap(kemantapanChip);
      await tester.pumpAndSettle();

      // Confirm in Kemantapan dialog
      final confirmKemantapanBtn = find.text('Ya, Simpan');
      expect(confirmKemantapanBtn, findsOneWidget);
      await tester.tap(confirmKemantapanBtn);
      await tester.pumpAndSettle();

      // Clear any floating SnackBar so it doesn't obscure the submit button
      final submitBtn = find.textContaining('Sinkronkan Nilai');
      expect(submitBtn, findsOneWidget);
      ScaffoldMessenger.of(tester.element(submitBtn)).clearSnackBars();
      await tester.pumpAndSettle();

      // 4. Tap Submit Score ("Selesai & Sinkronkan Nilai" or "Sinkronkan Nilai")
      await tester.tap(submitBtn);
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      // 5. Verify that summary popup appears with Juri 2's synchronized score
      //    and stays LOCKED until Dewan finalizes or switches to next match
      expect(find.text('NILAI JURI 2 BERHASIL DISINKRONKAN'), findsOneWidget);
      expect(
        find.text(
          'Menunggu Dewan Pertandingan mengesahkan partai atau memulai partai berikutnya...',
        ),
        findsOneWidget,
      );
      expect(find.text('TERKUNCI — MENUNGGU PENGESAHAN DEWAN'), findsOneWidget);
      expect(find.text('TUTUP (MENUNGGU PARTAI BERIKUTNYA)'), findsNothing);

      // Tapping outside (barrier) MUST NOT dismiss the locked popup
      await tester.tapAt(const Offset(10, 10));
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.text('NILAI JURI 2 BERHASIL DISINKRONKAN'), findsOneWidget);

      // 5b. Dewan finalizes / endorses the match -> popup automatically closes!
      sync.dewanFinalizeMatch(9.95);
      await tester.pumpAndSettle();

      // Verify submitted standby banner is visible after Dewan finalization
      expect(find.text('NILAI JURI 2 BERHASIL DISINKRONKAN'), findsNothing);
      expect(find.textContaining('NILAI JURI 2:'), findsOneWidget);
      expect(find.textContaining('TERKUNCI'), findsOneWidget);

      // 6. Dewan switches to next athlete/partai
      final athlete2 = AthleteModel.getSampleAthletes()[1];
      sync.dewanSelectMatch(athlete: athlete2, category: SeniCategory.tunggal);
      await tester.pumpAndSettle();

      // Verify that Juri 2 automatically returns to fresh scoring and ready dialog appears for athlete2
      expect(find.text('KESIAPAN JURI 2'), findsOneWidget);
      expect(find.textContaining(athlete2.name), findsWidgets);
    });

    testWidgets('ScoringPanelView persists ongoing scoring state when Juri accidentally exits and returns', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      sync.clearJuriOngoingSessions();
      sync.setSelectedJuriNumber(1);
      final athlete = AthleteModel.getSampleAthletes()[0];
      sync.dewanSelectMatch(athlete: athlete, category: SeniCategory.tunggal);

      bool exitedToPortal = false;
      // Juri opens scoring panel
      await tester.pumpWidget(
        MaterialApp(
          home: ScoringPanelView(
            onBackToPortal: () {
              exitedToPortal = true;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Confirms ready
      expect(find.text('KESIAPAN JURI 1'), findsOneWidget);
      await tester.tap(find.textContaining('SAYA SIAP MENILAI'));
      await tester.pumpAndSettle();

      // In jurus 1: tap WRONG & NEXT (records 1 mistake in jurus 1, advances to jurus 2)
      final wrongBtn = find.text('WRONG & NEXT');
      expect(wrongBtn, findsOneWidget);
      await tester.tap(wrongBtn);
      await tester.pumpAndSettle();

      // In jurus 2: tap NEXT (0 mistakes, advances to jurus 3)
      final nextBtn = find.text('NEXT');
      expect(nextBtn, findsOneWidget);
      await tester.tap(nextBtn);
      await tester.pumpAndSettle();

      // In jurus 3: tap WRONG & NEXT (records 1 mistake in jurus 3, advances to jurus 4)
      await tester.tap(wrongBtn);
      await tester.pumpAndSettle();

      // Current score: 9.90 - 0.02 = 9.88
      expect(find.text('9.88'), findsWidgets);

      // Now simulate accidental exit: tap back button
      final backBtn = find.byTooltip('Kembali ke Menu');
      expect(backBtn, findsOneWidget);
      await tester.tap(backBtn);
      await tester.pumpAndSettle();
      expect(exitedToPortal, isTrue);

      // Unmount ScoringPanelView (simulating back at portal/home)
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();

      // Verify ongoing session was saved in sync service
      final savedSession = sync.getJuriOngoingSession(1);
      expect(savedSession, isNotNull);
      expect(savedSession!['currentJurusIndex'], 1); // Jurus 2 (0-indexed: 1)
      expect(savedSession['mistakesPerJurus'][0], 1);
      expect(savedSession['mistakesPerJurus'][1], 1);

      // Now Juri 1 returns to scoring panel
      await tester.pumpWidget(
        const MaterialApp(
          home: ScoringPanelView(),
        ),
      );
      await tester.pumpAndSettle();

      // Should NOT show ready popup because already marked ready and session restored
      expect(find.text('KESIAPAN JURI 1'), findsNothing);

      // Should be on Jurus 2
      expect(find.textContaining('Jurus 2'), findsWidgets);

      // Total score should still be 9.88 (not reset to 9.90)
      expect(find.text('9.88'), findsWidgets);
    });

    testWidgets('Judges already chosen by other devices are NOT displayed in GelanggangVerificationView', (tester) async {
      sync.clearClaimedJudges(arenaCode: 'GELANGGANG A');
      sync.setActiveJuriCount(8, arenaCode: 'GELANGGANG A');

      // Simulate Device 1 claiming Juri 1 and Device 2 claiming Juri 4 in GELANGGANG A
      sync.claimJuri(1, arenaCode: 'GELANGGANG A', customDeviceId: 'DEVICE_1');
      sync.claimJuri(4, arenaCode: 'GELANGGANG A', customDeviceId: 'DEVICE_2');

      // Now this device (with its own deviceId) opens GelanggangVerificationView
      await tester.pumpWidget(
        MaterialApp(
          home: GelanggangVerificationView(
            roleName: 'Juri Pertandingan',
            roleIcon: Icons.balance_rounded,
            accentColor: const Color(0xFFF59E0B),
            enableAnimation: false,
            onVerified: (arena) {},
            onBack: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Juri 1 and Juri 4 MUST NOT be displayed!
      expect(find.text('Juri 1'), findsNothing);
      expect(find.text('Juri 4'), findsNothing);

      // Remaining judges MUST be displayed
      expect(find.text('Juri 2'), findsOneWidget);
      expect(find.text('Juri 3'), findsOneWidget);
      expect(find.text('Juri 5'), findsOneWidget);
      expect(find.text('Juri 6'), findsOneWidget);
      expect(find.text('Juri 7'), findsOneWidget);
      expect(find.text('Juri 8'), findsOneWidget);
    });
  });
}

