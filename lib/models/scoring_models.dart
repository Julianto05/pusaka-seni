// Models for Pusaka Seni Scoring IPSI System

enum SeniCategory {
  tunggal('Seni Tunggal', true),
  beregu('Seni Beregu', true),
  ganda('Seni Ganda', false),
  soloKreatif('Solo Kreatif', false);

  final String title;
  final bool isBaku;

  const SeniCategory(this.title, this.isBaku);

  static SeniCategory fromString(String? val) {
    if (val == null) return SeniCategory.tunggal;
    final lower = val.toLowerCase();
    if (lower.contains('beregu')) return SeniCategory.beregu;
    if (lower.contains('ganda')) return SeniCategory.ganda;
    if (lower.contains('solo') || lower.contains('kreatif') || lower.contains('kreasi')) {
      return SeniCategory.soloKreatif;
    }
    return SeniCategory.tunggal;
  }
}

class JurusModel {
  final int globalJurusIndex;
  final String weaponGroup;
  final int jurusNumber;
  final int totalJurusInGroup;
  final int totalGerakan;

  const JurusModel({
    required this.globalJurusIndex,
    required this.weaponGroup,
    required this.jurusNumber,
    required this.totalJurusInGroup,
    this.totalGerakan = 0,
  });

  /// Standar Resmi IPSI Seni Tunggal: 14 Jurus, Total 100 Gerakan
  /// Tangan Kosong: 50 gerakan (7 jurus: 7, 6, 5, 7, 6, 8, 11)
  /// Golok: 25 gerakan (3 jurus: 7, 6, 12)
  /// Toya/tongkat: 25 gerakan (4 jurus: 6, 5, 5, 9)
  static List<JurusModel> getTunggalJurus() {
    const tunggalData = [
      {'no': 1, 'group': 'Tangan kosong', 'sub': 1, 'inGroup': 7, 'gerakan': 7},
      {'no': 2, 'group': 'Tangan kosong', 'sub': 2, 'inGroup': 7, 'gerakan': 6},
      {'no': 3, 'group': 'Tangan kosong', 'sub': 3, 'inGroup': 7, 'gerakan': 5},
      {'no': 4, 'group': 'Tangan kosong', 'sub': 4, 'inGroup': 7, 'gerakan': 7},
      {'no': 5, 'group': 'Tangan kosong', 'sub': 5, 'inGroup': 7, 'gerakan': 6},
      {'no': 6, 'group': 'Tangan kosong', 'sub': 6, 'inGroup': 7, 'gerakan': 8},
      {'no': 7, 'group': 'Tangan kosong', 'sub': 7, 'inGroup': 7, 'gerakan': 11},
      {'no': 8, 'group': 'Golok', 'sub': 1, 'inGroup': 3, 'gerakan': 7},
      {'no': 9, 'group': 'Golok', 'sub': 2, 'inGroup': 3, 'gerakan': 6},
      {'no': 10, 'group': 'Golok', 'sub': 3, 'inGroup': 3, 'gerakan': 12},
      {'no': 11, 'group': 'Toya/tongkat', 'sub': 1, 'inGroup': 4, 'gerakan': 6},
      {'no': 12, 'group': 'Toya/tongkat', 'sub': 2, 'inGroup': 4, 'gerakan': 5},
      {'no': 13, 'group': 'Toya/tongkat', 'sub': 3, 'inGroup': 4, 'gerakan': 5},
      {'no': 14, 'group': 'Toya/tongkat', 'sub': 4, 'inGroup': 4, 'gerakan': 9},
    ];

    return tunggalData.map((d) {
      return JurusModel(
        globalJurusIndex: d['no'] as int,
        weaponGroup: d['group'] as String,
        jurusNumber: d['sub'] as int,
        totalJurusInGroup: d['inGroup'] as int,
        totalGerakan: d['gerakan'] as int,
      );
    }).toList();
  }

  /// Tunggal Tangan Kosong: 7 Jurus, Total 50 Gerakan (Jurus 1-7 Tangan Kosong)
  static List<JurusModel> getTunggalTanganKosongJurus() {
    return getTunggalJurus()
        .where((d) => d.weaponGroup.toLowerCase().contains('tangan'))
        .toList();
  }

  /// Tunggal Senjata: 7 Jurus, Total 50 Gerakan (Golok 3 Jurus + Toya 4 Jurus)
  /// Penilaian dimulai langsung dari gerakan senjata.
  static List<JurusModel> getTunggalSenjataJurus() {
    final senjataItems = getTunggalJurus()
        .where((d) => !d.weaponGroup.toLowerCase().contains('tangan'))
        .toList();

    return [
      for (int i = 0; i < senjataItems.length; i++)
        JurusModel(
          globalJurusIndex: i + 1,
          weaponGroup: senjataItems[i].weaponGroup,
          jurusNumber: senjataItems[i].jurusNumber,
          totalJurusInGroup: senjataItems[i].totalJurusInGroup,
          totalGerakan: senjataItems[i].totalGerakan,
        ),
    ];
  }

  /// Mengambil daftar jurus sesuai mode yang dipilih oleh Timekeeper
  /// - Standar (180s): 14 Jurus sampai Toya (100 Gerakan)
  /// - Tangan Kosong (80s): 7 Jurus Tangan Kosong saja (50 Gerakan)
  /// - Senjata (100s): 7 Jurus Senjata saja (Golok & Toya, 50 Gerakan)
  static List<JurusModel> getTunggalJurusForMode({
    String? modeTitle,
    int? targetDurationSeconds,
  }) {
    final title = modeTitle?.toLowerCase() ?? '';
    if (targetDurationSeconds == 80 || (title.contains('tangan kosong') && !title.contains('senjata'))) {
      return getTunggalTanganKosongJurus();
    }
    if (targetDurationSeconds == 100 || title.contains('senjata')) {
      return getTunggalSenjataJurus();
    }
    return getTunggalJurus();
  }

  static List<JurusModel> getBereguJurus() {
    return [
      for (int i = 1; i <= 12; i++)
        JurusModel(
          globalJurusIndex: i,
          weaponGroup: 'Tangan Kosong',
          jurusNumber: i,
          totalJurusInGroup: 12,
        ),
    ];
  }
}

class VerifiedGelanggangInfo {
  final String? gelanggangId;
  final String? gelanggangDocId;
  final String rawArenaCode;
  final String arenaLabel;
  final String? eventId;
  final String? eventDocId;
  final String? eventTitle;
  final String? eventCode;
  final int? jumlahJuri;

  const VerifiedGelanggangInfo({
    this.gelanggangId,
    this.gelanggangDocId,
    required this.rawArenaCode,
    required this.arenaLabel,
    this.eventId,
    this.eventDocId,
    this.eventTitle,
    this.eventCode,
    this.jumlahJuri,
  });

  /// Returns true only when this Gelanggang is linked to an Event created by
  /// an Event Admin on the backend.
  bool get hasValidEvent =>
      (eventId != null && eventId!.trim().isNotEmpty) ||
      (eventDocId != null && eventDocId!.trim().isNotEmpty);

  factory VerifiedGelanggangInfo.fromJson(Map<String, dynamic> json) {
    final rawCode = json['arena_code']?.toString().trim() ?? '';
    final desc = json['description']?.toString().trim() ?? '';
    final ev = json['event'] is Map ? json['event'] as Map : null;
    final evTitle = ev?['event_title']?.toString().trim();
    final evCode = ev?['event_code']?.toString().trim();

    String label;
    if (desc.isNotEmpty && rawCode.isNotEmpty) {
      label = desc.toUpperCase().contains(rawCode.toUpperCase())
          ? desc.toUpperCase()
          : '${desc.toUpperCase()} ($rawCode)';
    } else if (desc.isNotEmpty) {
      label = desc.toUpperCase();
    } else {
      label = rawCode.isNotEmpty ? 'GELANGGANG $rawCode' : 'GELANGGANG A';
    }

    return VerifiedGelanggangInfo(
      gelanggangId: json['id']?.toString(),
      gelanggangDocId: json['documentId']?.toString(),
      rawArenaCode: rawCode,
      arenaLabel: label,
      eventId: ev?['id']?.toString(),
      eventDocId: ev?['documentId']?.toString(),
      eventTitle: (evTitle != null && evTitle.isNotEmpty) ? evTitle : null,
      eventCode: (evCode != null && evCode.isNotEmpty) ? evCode : null,
      jumlahJuri: ev?['jumlah_juri'] is num
          ? (ev!['jumlah_juri'] as num).toInt()
          : null,
    );
  }
}

class AthleteModel {
  final String id;
  final String documentId;
  final String name;
  final String kontingen;
  final String category;
  final String pool;
  final String? poolDocId;
  final String partai;
  final String? eventId;
  final String? eventDocId;
  final String? gelanggangDocId;

  const AthleteModel({
    required this.id,
    required this.documentId,
    required this.name,
    required this.kontingen,
    required this.category,
    this.pool = 'Pool A',
    this.poolDocId,
    this.partai = 'Partai 1',
    this.eventId,
    this.eventDocId,
    this.gelanggangDocId,
  });

  factory AthleteModel.fromJson(
    Map<String, dynamic> json, {
    String? overridePartai,
    String? overridePoolName,
    String? overridePoolDocId,
    String? overrideCategory,
    String? overrideEventId,
    String? overrideEventDocId,
    String? overrideGelanggangDocId,
  }) {
    final poolMap = json['pool'] is Map ? json['pool'] as Map : null;
    final eventMap = json['event'] is Map ? json['event'] as Map : null;
    final poolName = overridePoolName ??
        poolMap?['pool_name']?.toString() ??
        poolMap?['nama_pool']?.toString() ??
        'Pool A';
    final poolDoc = overridePoolDocId ?? poolMap?['documentId']?.toString();
    final evId = overrideEventId ?? eventMap?['id']?.toString();
    final evDoc = overrideEventDocId ?? eventMap?['documentId']?.toString();

    return AthleteModel(
      id: json['id']?.toString() ?? '',
      documentId:
          json['documentId']?.toString() ?? json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Pesilat',
      kontingen: json['kontingen']?.toString() ??
          json['perguruan']?.toString() ??
          'Kontingen IPSI',
      category: overrideCategory ??
          json['kategori_seni']?.toString() ??
          poolMap?['kategori']?.toString() ??
          'tunggal',
      pool: poolName,
      poolDocId: poolDoc,
      partai: overridePartai ??
          json['nomor_partai']?.toString() ??
          (json['id'] != null ? 'Partai ${json['id']}' : 'Partai 1'),
      eventId: evId,
      eventDocId: evDoc,
      gelanggangDocId: overrideGelanggangDocId,
    );
  }

  static List<AthleteModel> getSampleAthletes() {
    return const [
      AthleteModel(
        id: '1',
        documentId: 'ath-001',
        name: 'Ahmad Fauzi & Rahmat Hidayat',
        kontingen: 'Jawa Barat',
        category: 'ganda',
        pool: 'Pool A - Babak Penyisihan',
        partai: 'Partai 1',
      ),
      AthleteModel(
        id: '2',
        documentId: 'ath-002',
        name: 'Budi Santoso',
        kontingen: 'DKI Jakarta',
        category: 'tunggal',
        pool: 'Pool A - Babak Penyisihan',
        partai: 'Partai 2',
      ),
      AthleteModel(
        id: '3',
        documentId: 'ath-003',
        name: 'Regu Putra Merpati Putih (3 Atlet)',
        kontingen: 'Jawa Timur',
        category: 'beregu',
        pool: 'Pool B - Babak Semifinal',
        partai: 'Partai 3',
      ),
      AthleteModel(
        id: '4',
        documentId: 'ath-004',
        name: 'Siti Nurhaliza (Solo Kreasi)',
        kontingen: 'Bali',
        category: 'solo_kreatif',
        pool: 'Pool A - Babak Final',
        partai: 'Partai 4',
      ),
      AthleteModel(
        id: '5',
        documentId: 'ath-005',
        name: 'Muhammad Ilham',
        kontingen: 'Jawa Tengah',
        category: 'tunggal',
        pool: 'Pool B - Babak Semifinal',
        partai: 'Partai 5',
      ),
      AthleteModel(
        id: '6',
        documentId: 'ath-006',
        name: 'Dwi Prasetyo & Bayu Setiawan',
        kontingen: 'DI Yogyakarta',
        category: 'ganda',
        pool: 'Pool A - Babak Final',
        partai: 'Partai 6',
      ),
    ];
  }
}

class PenaltyDeduction {
  final String id;
  final String label;
  final double deduction;
  final DateTime timestamp;

  const PenaltyDeduction({
    required this.id,
    required this.label,
    required this.deduction,
    required this.timestamp,
  });
}
