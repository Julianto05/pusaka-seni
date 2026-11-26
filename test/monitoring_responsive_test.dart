import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pusaka_seni_v2/models/scoring_models.dart';
import 'package:pusaka_seni_v2/services/gelanggang_sync_service.dart';
import 'package:pusaka_seni_v2/views/monitoring/monitoring_scoreboard_view.dart';

void main() {
  setUp(() {
    final sync = GelanggangSyncService.instance;
    sync.setActiveJuriCount(5);
    final athlete = AthleteModel.getSampleAthletes().first;
    sync.dewanSelectMatch(athlete: athlete, category: SeniCategory.tunggal);
  });

  Widget createScoreboard() {
    return MaterialApp(
      home: MonitoringScoreboardView(
        onBackToPortal: () {},
      ),
    );
  }

  final testSizes = [
    // Ultra small / extreme edge cases
    const Size(300, 400),
    const Size(320, 480),
    const Size(360, 640),
    const Size(390, 844),
    const Size(412, 915),
    // Short landscape mobile (e.g. phones with keyboard or notch or small screens)
    const Size(550, 260),
    const Size(580, 280),
    const Size(600, 250),
    const Size(600, 280),
    const Size(640, 300),
    const Size(640, 320),
    const Size(667, 375),
    const Size(736, 414),
    const Size(800, 320),
    const Size(800, 360),
    const Size(844, 390),
    const Size(915, 412),
    // Tablets & TV Displays
    const Size(1024, 600),
    const Size(1024, 768),
    const Size(1280, 720),
    const Size(1920, 1080),
  ];

  for (final size in testSizes) {
    testWidgets('MonitoringScoreboardView renders without overflow on ${size.width}x${size.height}', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(createScoreboard());
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('MonitoringScoreboardView renders with long names and extreme penalties without overflow', (tester) async {
    final sync = GelanggangSyncService.instance;
    sync.setActiveJuriCount(8);
    final longAthlete = AthleteModel(
      documentId: 'doc99',
      id: '99',
      name: 'MUHAMMAD ABDURRAHMAN ASSIDDIQI AL-FARUQ',
      kontingen: 'KABUPATEN SUMATERA BARAT RAYA BERSATU',
      partai: 'Partai 10 FINAL KEJUARAAN',
      pool: 'Pool A FINAL EMAS',
      category: 'tunggal',
    );
    sync.dewanSelectMatch(athlete: longAthlete, category: SeniCategory.tunggal);

    tester.view.physicalSize = const Size(600, 280);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(createScoreboard());
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });

  testWidgets('MonitoringScoreboardView renders with 8 judges on short mobile landscape without overflow', (tester) async {
    final sync = GelanggangSyncService.instance;
    sync.setActiveJuriCount(8);

    tester.view.physicalSize = const Size(580, 270);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(createScoreboard());
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });
}
