import 'dart:convert';
import 'dart:io';
import '../models/scoring_models.dart';

class PusakaSeniApiService {
  static const String baseApiUrl = 'https://beseni-temp.pusakarinjani.my.id/api';
  static const String staticToken =
      'd184ac1ac83b201cafd536675c01356ea36bcbd608ca30a66f62a617887d2561fc8017dd07e98c30cc591690e626a271c3402dbf3d73529e72368522fa1159fbe249d8810975cee031bec033355e6fa258a713b5c1df4d89d02e08454f60ddd33de09f765579aee70784ed6b9aa54e866a1b642304306510dd7e470d93201447';

  final HttpClient _client = HttpClient()
    ..badCertificateCallback = ((X509Certificate cert, String host, int port) => true);

  // Singleton instance
  static final PusakaSeniApiService _instance = PusakaSeniApiService._internal();
  factory PusakaSeniApiService() => _instance;
  PusakaSeniApiService._internal();

  void _applyDefaultHeaders(HttpClientRequest request) {
    request.headers.set('Authorization', 'Bearer $staticToken');
    request.headers.set(
      'User-Agent',
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
    );
  }

  Future<dynamic> _get(String endpoint) async {
    final uri = Uri.parse('$baseApiUrl$endpoint');
    final request = await _client.getUrl(uri);
    _applyDefaultHeaders(request);
    request.headers.set('Accept', 'application/json');

    final response = await request.close();
    final body = await response.transform(utf8.decoder).join();
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return jsonDecode(body);
    }
    throw HttpException('Request failed: ${response.statusCode} - $body');
  }

  // Fetch Pesertas directly from live Strapi API
  Future<List<AthleteModel>> fetchPesertas() async {
    try {
      final json = await _get('/pesertas?populate=*');
      if (json is Map && json['data'] is List) {
        final list = json['data'] as List;
        final results = list.map((item) {
          final map = item is Map<String, dynamic>
              ? item
              : Map<String, dynamic>.from(item as Map);
          return AthleteModel.fromJson(map);
        }).toList();

        if (results.isNotEmpty) {
          return results;
        }
      }
    } catch (_) {
      // Graceful fallback to samples if offline
    }
    return AthleteModel.getSampleAthletes();
  }

  // Fetch Gelanggangs from live API
  Future<List<Map<String, dynamic>>> fetchGelanggangs() async {
    try {
      final json = await _get('/gelanggangs');
      if (json is Map && json['data'] is List) {
        return (json['data'] as List).cast<Map<String, dynamic>>();
      }
    } catch (_) {}
    return [
      {'arena_code': 'ARENA-A', 'description': 'Gelanggang 1', 'gelanggang_status': 'standby'},
      {'arena_code': 'ARENA-B', 'description': 'Gelanggang 2', 'gelanggang_status': 'standby'},
    ];
  }

  // Fetch Active Event info from live API
  Future<Map<String, dynamic>?> fetchActiveEvent() async {
    try {
      final json = await _get('/events?populate=*');
      if (json is Map && json['data'] is List && (json['data'] as List).isNotEmpty) {
        return (json['data'] as List).first as Map<String, dynamic>;
      }
    } catch (_) {}
    return null;
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
      final request = await _client.postUrl(uri);
      _applyDefaultHeaders(request);
      request.headers.set('Content-Type', 'application/json');

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

      request.write(jsonEncode({'data': dataMap}));
      final response = await request.close();
      await response.drain<void>();
      return response.statusCode >= 200 && response.statusCode < 300;
    } catch (_) {
      return false;
    }
  }
}
