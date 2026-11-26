import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import '../models/scoring_models.dart';

class PusakaSeniApiService {
  static const String baseUrl = 'https://beseni-temp.pusakarinjani.my.id';
  static const String baseApiUrl = '$baseUrl/api';
  static const String staticToken =
      'd184ac1ac83b201cafd536675c01356ea36bcbd608ca30a66f62a617887d2561fc8017dd07e98c30cc591690e626a271c3402dbf3d73529e72368522fa1159fbe249d8810975cee031bec033355e6fa258a713b5c1df4d89d02e08454f60ddd33de09f765579aee70784ed6b9aa54e866a1b642304306510dd7e470d93201447';
  static const Duration _timeout = Duration(seconds: 8);

  final http.Client _client = http.Client();

  /// Last server wall-clock timestamp parsed from HTTP `Date` response header.
  /// Used to eliminate cross-device clock skew when syncing live timers.
  DateTime? lastServerTime;

  static DateTime? _parseHttpDate(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    // RFC 1123: "Thu, 26 Nov 2026 14:40:12 GMT"
    final match = RegExp(
      r'^[A-Za-z]{3},\s+(\d{1,2})\s+([A-Za-z]{3})\s+(\d{4})\s+(\d{2}):(\d{2}):(\d{2})\s+GMT$',
    ).firstMatch(raw.trim());
    if (match == null) return DateTime.tryParse(raw.trim())?.toUtc();
    const months = {
      'Jan': 1, 'Feb': 2, 'Mar': 3, 'Apr': 4, 'May': 5, 'Jun': 6,
      'Jul': 7, 'Aug': 8, 'Sep': 9, 'Oct': 10, 'Nov': 11, 'Dec': 12,
    };
    final month = months[match.group(2)];
    if (month == null) return null;
    return DateTime.utc(
      int.parse(match.group(3)!),
      month,
      int.parse(match.group(1)!),
      int.parse(match.group(4)!),
      int.parse(match.group(5)!),
      int.parse(match.group(6)!),
    );
  }

  // Singleton instance
  static final PusakaSeniApiService _instance =
      PusakaSeniApiService._internal();
  factory PusakaSeniApiService() => _instance;
  PusakaSeniApiService._internal();

  Map<String, String> _headers({bool isJson = false}) {
    final headers = <String, String>{
      'Authorization': 'Bearer $staticToken',
      'Accept': 'application/json',
    };
    if (isJson) {
      headers['Content-Type'] = 'application/json';
    }
    // Browsers manage User-Agent automatically and reject manual overrides.
    if (!kIsWeb) {
      headers['User-Agent'] =
          'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36';
    }
    return headers;
  }

  Future<dynamic> _get(String endpoint) async {
    final uri = Uri.parse('$baseApiUrl$endpoint');
    final response = await _client
        .get(uri, headers: _headers())
        .timeout(_timeout);
    final serverDate = _parseHttpDate(response.headers['date']);
    if (serverDate != null) {
      lastServerTime = serverDate;
    }
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return jsonDecode(response.body);
    }
    throw Exception('Request failed: ${response.statusCode} - ${response.body}');
  }

  /// Extracts athletes scheduled in a specific Gelanggang from Strapi `/jadwals`
  /// records, enforcing [lockedEventId] / [lockedEventDocId] when present so
  /// athletes from other events or gelanggangs never leak into this arena.
  static List<AthleteModel> extractAthletesFromJadwals(
    List<dynamic> jadwals, {
    String? lockedEventId,
    String? lockedEventDocId,
    String? lockedGelanggangDocId,
  }) {
    final List<AthleteModel> results = [];
    final Set<String> seenKeys = {};

    for (final rawJadwal in jadwals) {
      if (rawJadwal is! Map) continue;
      final jadwal = Map<String, dynamic>.from(rawJadwal);

      // Enforce locked event if the jadwal carries an event relation
      final jadwalEvent =
          jadwal['event'] is Map ? jadwal['event'] as Map : null;
      if (jadwalEvent != null) {
        final jEvDoc = jadwalEvent['documentId']?.toString() ?? '';
        final jEvId = jadwalEvent['id']?.toString() ?? '';
        if (lockedEventDocId != null &&
            lockedEventDocId.isNotEmpty &&
            jEvDoc.isNotEmpty &&
            jEvDoc != lockedEventDocId) {
          continue;
        }
        if (lockedEventId != null &&
            lockedEventId.isNotEmpty &&
            jEvId.isNotEmpty &&
            jEvId != lockedEventId) {
          continue;
        }
      }

      // Enforce locked gelanggang if the jadwal carries a gelanggang relation
      final jadwalGel =
          jadwal['gelanggang'] is Map ? jadwal['gelanggang'] as Map : null;
      if (jadwalGel != null &&
          lockedGelanggangDocId != null &&
          lockedGelanggangDocId.isNotEmpty) {
        final jGelDoc = jadwalGel['documentId']?.toString() ?? '';
        if (jGelDoc.isNotEmpty && jGelDoc != lockedGelanggangDocId) {
          continue;
        }
      }

      final poolMap = jadwal['pool'] is Map ? jadwal['pool'] as Map : null;
      if (poolMap == null) continue;

      final poolName = poolMap['pool_name']?.toString() ??
          poolMap['nama_pool']?.toString() ??
          'Pool A';
      final poolDocId = poolMap['documentId']?.toString();
      final poolCategory = poolMap['kategori']?.toString();
      final nomorPartai = jadwal['nomor_partai']?.toString().trim();
      final pesertas = poolMap['pesertas'];
      if (pesertas is! List) continue;

      for (final rawPeserta in pesertas) {
        if (rawPeserta is! Map) continue;
        final pesertaMap = Map<String, dynamic>.from(rawPeserta);
        final docId = pesertaMap['documentId']?.toString() ??
            pesertaMap['id']?.toString() ??
            '';
        final dedupeKey = docId.isNotEmpty
            ? docId
            : '${pesertaMap['name']}_${nomorPartai ?? ''}';
        if (!seenKeys.add(dedupeKey)) continue;

        results.add(
          AthleteModel.fromJson(
            pesertaMap,
            overridePartai: (nomorPartai != null && nomorPartai.isNotEmpty)
                ? nomorPartai
                : null,
            overridePoolName: poolName,
            overridePoolDocId: poolDocId,
            overrideCategory: poolCategory,
            overrideEventId: lockedEventId ?? jadwalEvent?['id']?.toString(),
            overrideEventDocId:
                lockedEventDocId ?? jadwalEvent?['documentId']?.toString(),
            overrideGelanggangDocId:
                lockedGelanggangDocId ?? jadwalGel?['documentId']?.toString(),
          ),
        );
      }
    }
    return results;
  }

  /// Verifies an 8-digit (or textual) arena code against Strapi `/gelanggangs`
  /// and returns its linked Event metadata so the app can lock the Event ID.
  Future<VerifiedGelanggangInfo?> verifyGelanggangByCode(String code) async {
    final clean = code.trim();
    if (clean.isEmpty) return null;
    try {
      final encoded = Uri.encodeQueryComponent(clean);
      final exact = await _get(
        '/gelanggangs?filters[arena_code][\$eq]=$encoded&populate[event]=true',
      );
      if (exact is Map &&
          exact['data'] is List &&
          (exact['data'] as List).isNotEmpty) {
        final first = (exact['data'] as List).first;
        if (first is Map) {
          return VerifiedGelanggangInfo.fromJson(
            Map<String, dynamic>.from(first),
          );
        }
      }

      // Secondary fallback: match against full list (handles case/description match)
      final all = await fetchGelanggangs();
      final upper = clean.toUpperCase();
      for (final g in all) {
        final ac = g['arena_code']?.toString().trim().toUpperCase() ?? '';
        final desc = g['description']?.toString().trim().toUpperCase() ?? '';
        if (ac == upper ||
            (ac.isNotEmpty && upper.contains(ac)) ||
            (desc.isNotEmpty && desc == upper)) {
          return VerifiedGelanggangInfo.fromJson(g);
        }
      }
    } catch (_) {}
    return null;
  }

  // Fetch Pesertas scoped to the locked Event ID & verified Gelanggang
  Future<List<AthleteModel>> fetchPesertas({
    String? eventId,
    String? eventDocId,
    String? gelanggangDocId,
    String? rawArenaCode,
    bool fallbackToSample = true,
  }) async {
    final bool hasGelanggangFilter =
        (gelanggangDocId != null && gelanggangDocId.isNotEmpty) ||
        (rawArenaCode != null && rawArenaCode.isNotEmpty);
    final bool hasEventFilter =
        (eventDocId != null && eventDocId.isNotEmpty) ||
        (eventId != null && eventId.isNotEmpty);

    try {
      // 1. Primary: Fetch athletes scheduled in this specific Gelanggang
      //    (and locked Event when present) via `/jadwals`.
      if (hasGelanggangFilter) {
        final String gelFilter =
            (gelanggangDocId != null && gelanggangDocId.isNotEmpty)
            ? 'filters[gelanggang][documentId][\$eq]=${Uri.encodeQueryComponent(gelanggangDocId)}'
            : 'filters[gelanggang][arena_code][\$eq]=${Uri.encodeQueryComponent(rawArenaCode!)}';
        final json = await _get(
          '/jadwals?$gelFilter&populate[pool][populate][pesertas]=true&populate[event]=true&populate[gelanggang]=true&sort=nomor_partai:asc&pagination[pageSize]=100',
        );
        if (json is Map && json['data'] is List) {
          final scheduled = extractAthletesFromJadwals(
            json['data'] as List,
            lockedEventId: eventId,
            lockedEventDocId: eventDocId,
            lockedGelanggangDocId: gelanggangDocId,
          );
          if (scheduled.isNotEmpty) {
            return scheduled;
          }
        }
      }

      // 2. Secondary: If locked to an Event ID (e.g. jadwal pools not assigned yet),
      //    fetch pesertas directly linked to that locked Event.
      if (hasEventFilter) {
        final String evFilter = (eventDocId != null && eventDocId.isNotEmpty)
            ? 'filters[event][documentId][\$eq]=${Uri.encodeQueryComponent(eventDocId)}'
            : 'filters[event][id][\$eq]=${Uri.encodeQueryComponent(eventId!)}';
        final json = await _get(
          '/pesertas?$evFilter&populate[pool]=true&populate[event]=true&pagination[pageSize]=100',
        );
        if (json is Map && json['data'] is List) {
          final list = (json['data'] as List)
              .whereType<Map>()
              .map(
                (item) => AthleteModel.fromJson(
                  Map<String, dynamic>.from(item),
                  overrideEventId: eventId,
                  overrideEventDocId: eventDocId,
                  overrideGelanggangDocId: gelanggangDocId,
                ),
              )
              .toList();
          if (list.isNotEmpty) {
            return list;
          }
        }
      }

      // 3. Unscoped fallback (only when no event/gelanggang lock is active)
      if (!hasGelanggangFilter && !hasEventFilter) {
        final json = await _get(
          '/pesertas?populate[pool]=true&populate[event]=true&pagination[pageSize]=100',
        );
        if (json is Map && json['data'] is List) {
          final list = (json['data'] as List)
              .whereType<Map>()
              .map(
                (item) =>
                    AthleteModel.fromJson(Map<String, dynamic>.from(item)),
              )
              .toList();
          if (list.isNotEmpty) {
            return list;
          }
        }
      }
    } catch (_) {
      // Graceful fallback to samples if offline
    }
    return fallbackToSample ? AthleteModel.getSampleAthletes() : [];
  }

  // Fetch Gelanggangs from live API (including linked event config)
  Future<List<Map<String, dynamic>>> fetchGelanggangs() async {
    try {
      final json = await _get('/gelanggangs?populate[event]=true');
      if (json is Map && json['data'] is List) {
        return (json['data'] as List)
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      }
    } catch (_) {}
    return [
      {
        'arena_code': '12345678',
        'description': 'GELANGGANG A',
        'gelanggang_status': 'standby',
      },
      {
        'arena_code': '87654321',
        'description': 'GELANGGANG B',
        'gelanggang_status': 'standby',
      },
    ];
  }

  // Fetch Active Event info from live API
  Future<Map<String, dynamic>?> fetchActiveEvent() async {
    try {
      final json = await _get('/events?populate=*');
      if (json is Map &&
          json['data'] is List &&
          (json['data'] as List).isNotEmpty) {
        return Map<String, dynamic>.from((json['data'] as List).first as Map);
      }
    } catch (_) {}
    return null;
  }

  // Post official Score Akhir (final match summary) to live Strapi API
  Future<bool> postScoreAkhir({
    required String athleteDocId,
    required Map<String, double> nilaiJuri,
    required double standarDeviasi,
    required double akumulasi,
    required String akurasiWaktu,
    String? poolDocId,
  }) async {
    if (athleteDocId.isEmpty) return false;
    try {
      final uri = Uri.parse('$baseApiUrl/score-akhirs');
      final dataMap = <String, dynamic>{
        'peserta': athleteDocId,
        'nilai_juri': nilaiJuri,
        'standar_daviasi': double.parse(standarDeviasi.toStringAsFixed(4)),
        'akumulasi': double.parse(akumulasi.toStringAsFixed(4)),
        'akurasi_waktu': akurasiWaktu,
      };
      if (poolDocId != null && poolDocId.isNotEmpty) {
        dataMap['pool'] = poolDocId;
      }

      final response = await _client
          .post(
            uri,
            headers: _headers(isJson: true),
            body: jsonEncode({'data': dataMap}),
          )
          .timeout(_timeout);
      return response.statusCode >= 200 && response.statusCode < 300;
    } catch (_) {
      return false;
    }
  }

  // Post Score to live API
  Future<bool> postScore({
    required String athleteDocId,
    required String penilai,
    required double nilai,
    required String keterangan,
    String? jurusKe,
    String? poolDocId,
  }) async {
    try {
      final uri = Uri.parse('$baseApiUrl/scores');
      final dataMap = <String, dynamic>{
        'peserta': athleteDocId,
        'pool': poolDocId,
        'waktu': '',
        'penilai': penilai,
        'nilai': nilai,
        'keterangan': keterangan,
      };
      if (jurusKe != null) {
        dataMap['jurus_ke'] = jurusKe;
      }

      final response = await _client
          .post(
            uri,
            headers: _headers(isJson: true),
            body: jsonEncode({'data': dataMap}),
          )
          .timeout(_timeout);
      return response.statusCode >= 200 && response.statusCode < 300;
    } catch (_) {
      return false;
    }
  }

  /// Fetch all live sync records for a specific canonical arena code.
  Future<List<Map<String, dynamic>>> fetchSyncRecords(String arenaCode) async {
    try {
      final prefix = Uri.encodeQueryComponent('sync|$arenaCode|');
      final json = await _get(
        '/scores?filters[penilai][\$startsWith]=$prefix&sort=updatedAt:desc,id:desc&pagination[pageSize]=50',
      );
      if (json is Map && json['data'] is List) {
        return (json['data'] as List)
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      }
    } catch (_) {}
    return [];
  }

  /// Upsert a single sync state record keyed by [syncKey] (stored in `penilai`).
  /// Returns the Strapi `documentId` if successful, or null on failure.
  Future<String?> upsertSyncRecord({
    required String syncKey,
    required double nilai,
    required String waktu,
    required String keterangan,
    String? existingDocId,
  }) async {
    final safeKeterangan =
        keterangan.length > 255 ? keterangan.substring(0, 255) : keterangan;
    final payload = jsonEncode({
      'data': {
        'penilai': syncKey,
        'nilai': nilai,
        'waktu': waktu,
        'keterangan': safeKeterangan,
      },
    });

    try {
      String? targetDocId = existingDocId;
      if (targetDocId == null) {
        final encodedKey = Uri.encodeQueryComponent(syncKey);
        final existing = await _get(
          '/scores?filters[penilai][\$eq]=$encodedKey&sort=updatedAt:desc,id:desc&pagination[limit]=1',
        );
        if (existing is Map &&
            existing['data'] is List &&
            (existing['data'] as List).isNotEmpty) {
          final first = (existing['data'] as List).first;
          if (first is Map) {
            targetDocId = first['documentId']?.toString();
          }
        }
      }

      if (targetDocId != null && targetDocId.isNotEmpty) {
        final putUri = Uri.parse('$baseApiUrl/scores/$targetDocId');
        final putRes = await _client
            .put(putUri, headers: _headers(isJson: true), body: payload)
            .timeout(_timeout);
        if (putRes.statusCode >= 200 && putRes.statusCode < 300) {
          final decoded = jsonDecode(putRes.body);
          if (decoded is Map && decoded['data'] is Map) {
            return decoded['data']['documentId']?.toString() ?? targetDocId;
          }
          return targetDocId;
        }
        if (putRes.statusCode != 404) {
          return null;
        }
      }

      final postUri = Uri.parse('$baseApiUrl/scores');
      final postRes = await _client
          .post(postUri, headers: _headers(isJson: true), body: payload)
          .timeout(_timeout);
      if (postRes.statusCode >= 200 && postRes.statusCode < 300) {
        final decoded = jsonDecode(postRes.body);
        if (decoded is Map && decoded['data'] is Map) {
          return decoded['data']['documentId']?.toString();
        }
      }
    } catch (_) {}
    return null;
  }
}
