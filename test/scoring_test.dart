import 'package:flutter_test/flutter_test.dart';
import 'package:pusaka_seni_v2/models/scoring_models.dart';

void main() {
  group('Pusaka Seni Scoring Engine Tests', () {
    test(
      'Tunggal has 14 jurus, 100 movements total according to IPSI rules',
      () {
        final jurusList = JurusModel.getTunggalJurus();
        expect(jurusList.length, 14);

        final tanganKosong = jurusList
            .where((j) => j.weaponGroup.toLowerCase().contains('tangan kosong'))
            .toList();
        expect(tanganKosong.length, 7);
        expect(tanganKosong.fold(0, (sum, j) => sum + j.totalGerakan), 50);

        final golok = jurusList
            .where((j) => j.weaponGroup.toLowerCase().contains('golok'))
            .toList();
        expect(golok.length, 3);
        expect(golok.fold(0, (sum, j) => sum + j.totalGerakan), 25);

        final toya = jurusList
            .where((j) => j.weaponGroup.toLowerCase().contains('toya'))
            .toList();
        expect(toya.length, 4);
        expect(toya.fold(0, (sum, j) => sum + j.totalGerakan), 25);

        final totalGerakan = jurusList.fold(
          0,
          (sum, j) => sum + j.totalGerakan,
        );
        expect(totalGerakan, 100);
      },
    );

    test('Beregu has 12 jurus total', () {
      final jurusList = JurusModel.getBereguJurus();
      expect(jurusList.length, 12);
      expect(jurusList.every((j) => j.weaponGroup == 'Tangan Kosong'), isTrue);
    });

    test('Baku score starts at 9.90 and deducts 0.01 per mistake', () {
      const double initialScore = 9.90;
      int mistakes = 3;
      double kebenaran = (initialScore - (mistakes * 0.01)).clamp(0.0, 9.90);
      expect(kebenaran, closeTo(9.87, 0.001));

      // With Kemantapan +0.05
      double kemantapan = 0.05;
      double total = kebenaran + kemantapan;
      expect(total, closeTo(9.92, 0.001));
    });

    test(
      'Ganda and Solo Kreatif deduct penalties (0.01 - 0.30) from base performance score 9.90',
      () {
        const double baseScore = 9.90;

        // Example 1: base 9.90 with single penalty 0.10 -> 9.80
        double penalty1 = 0.10;
        double result1 = (baseScore - penalty1).clamp(0.0, baseScore);
        expect(result1, closeTo(9.80, 0.001));

        // Example 2: 3 aspects deductions (ad: 0.15, fh: 0.18, sf: 0.20 -> total penalty 0.53)
        double ad = 0.15;
        double fh = 0.18;
        double sf = 0.20;
        double totalPenalty = ad + fh + sf;
        double finalScore = (baseScore - totalPenalty).clamp(0.0, baseScore);
        expect(totalPenalty, closeTo(0.53, 0.001));
        expect(finalScore, closeTo(9.37, 0.001));

        // Example 3: Sempurna (tanpa penalti 0.00) -> 9.90
        double perfectScore = (baseScore - 0.0).clamp(0.0, baseScore);
        expect(perfectScore, closeTo(9.90, 0.001));
      },
    );

    test('Tunggal Tangan Kosong has 7 jurus and 50 movements total', () {
      final jurusList = JurusModel.getTunggalTanganKosongJurus();
      expect(jurusList.length, 7);
      expect(
        jurusList.every((j) => j.weaponGroup.toLowerCase().contains('tangan')),
        isTrue,
      );
      expect(jurusList.fold(0, (sum, j) => sum + j.totalGerakan), 50);
    });

    test(
      'Tunggal Senjata has 7 jurus and 50 movements total starting from weapon',
      () {
        final jurusList = JurusModel.getTunggalSenjataJurus();
        expect(jurusList.length, 7);
        expect(jurusList.first.weaponGroup, 'Golok');
        expect(jurusList.last.weaponGroup, 'Toya/tongkat');
        expect(jurusList.fold(0, (sum, j) => sum + j.totalGerakan), 50);
        expect(jurusList.first.globalJurusIndex, 1);
        expect(jurusList.last.globalJurusIndex, 7);
      },
    );

    test(
      'getTunggalJurusForMode accurately maps Timekeeper mode selection',
      () {
        // Standar
        final standarList = JurusModel.getTunggalJurusForMode(
          modeTitle: 'Standar (03:00)',
          targetDurationSeconds: 180,
        );
        expect(standarList.length, 14);

        // Tangan Kosong
        final tkList = JurusModel.getTunggalJurusForMode(
          modeTitle: 'Tangan Kosong (01:20)',
          targetDurationSeconds: 80,
        );
        expect(tkList.length, 7);
        expect(
          tkList.every((j) => j.weaponGroup.toLowerCase().contains('tangan')),
          isTrue,
        );

        // Senjata
        final senjataList = JurusModel.getTunggalJurusForMode(
          modeTitle: 'Senjata (01:40)',
          targetDurationSeconds: 100,
        );
        expect(senjataList.length, 7);
        expect(senjataList.first.weaponGroup, 'Golok');
        expect(senjataList.last.weaponGroup, 'Toya/tongkat');
      },
    );

    test('Category parsing from string works as expected', () {
      expect(SeniCategory.fromString('tunggal'), SeniCategory.tunggal);
      expect(SeniCategory.fromString('beregu'), SeniCategory.beregu);
      expect(SeniCategory.fromString('ganda'), SeniCategory.ganda);
      expect(SeniCategory.fromString('solo_kreatif'), SeniCategory.soloKreatif);
      expect(SeniCategory.fromString('solo'), SeniCategory.soloKreatif);
    });
  });
}
