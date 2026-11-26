import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import '../models/scoring_models.dart';
import 'pusaka_seni_api_service.dart';

/// Isolated state for a specific Gelanggang / Arena.
/// Ensures that Gelanggang A, Gelanggang B, and any other arena
/// maintain strictly independent athletes, scoring, penalties, and timers.
class GelanggangArenaState {
  final String arenaCode;

  String matchVersion = '';
  late AthleteModel athlete;
  late SeniCategory category;
  String nomorPartai;
  String pool;

  // Live Timer State (Independent timer per arena)
  Timer? activeTimer;
  int targetDurationSeconds = 180;
  int timerRemainingSeconds = 180;
  String timerStatus = 'standby'; // 'standby', 'running', 'paused', 'stopped'
  String timerModeTitle = 'Standar (03:00)';

  // Active Judges Configuration (3, 4, 5, 8, 10)
  int activeJuriCount = 8;
  final Map<int, Map<String, dynamic>> juriScores = {};

  // Dewan Penalties & Match Finalization
  final List<PenaltyDeduction> penalties = [];
  bool isMatchFinalized = false;
  double officialFinalScore = 0.0;
  final Map<String, double> finalizedAthletes = {};

  // Ongoing Juri Sessions (persists across accidental exit/re-entry)
  final Map<int, Map<String, dynamic>> juriOngoingSessions = {};

  // Claimed Judges by Device ID: juriNumber -> deviceId
  final Map<int, String> claimedJuriDevices = {};

  // Cloud sync bookkeeping per sync key (prevents stale overwrites & duplicates)
  final Map<String, String> remoteDocIds = {};
  final Map<String, int> keyRevisions = {};
  int claimsResetRevision = 0;

  GelanggangArenaState({
    required this.arenaCode,
    AthleteModel? initialAthlete,
    SeniCategory? initialCategory,
    this.nomorPartai = 'PARTAI 01',
    this.pool = 'POOL A',
  }) {
    athlete = initialAthlete ?? AthleteModel.getSampleAthletes()[0];
    category = initialCategory ?? SeniCategory.tunggal;
    _initJuriScores();
  }

  Map<String, dynamic> _defaultJuriEntry() => {
        'score': 9.90,
        'kebenaran': 9.90,
        'kemantapan': null,
        'isReady': false,
        'status': 'not_ready', // 'not_ready', 'ready', 'scoring', 'submitted'
        'submitted': false,
      };

  void _initJuriScores() {
    juriScores.clear();
    for (int i = 1; i <= activeJuriCount; i++) {
      juriScores[i] = _defaultJuriEntry();
    }
  }

  void setActiveJuriCount(int count) {
    if (count < 1 || count > 10) return;
    activeJuriCount = count;
    for (int i = 1; i <= count; i++) {
      juriScores.putIfAbsent(i, _defaultJuriEntry);
    }
    juriScores.removeWhere((key, _) => key > count);
    claimedJuriDevices.removeWhere((key, _) => key > count);
  }

  bool isJuriClaimedByOther(int juriNumber, String currentDeviceId) {
    final claimingDevice = claimedJuriDevices[juriNumber];
    return claimingDevice != null && claimingDevice != currentDeviceId;
  }

  int? claimJuri(int juriNumber, String deviceId) {
    int? previousJuri;
    claimedJuriDevices.removeWhere((k, dev) {
      if (dev == deviceId && k != juriNumber) {
        previousJuri = k;
        return true;
      }
      return false;
    });
    claimedJuriDevices[juriNumber] = deviceId;
    return previousJuri;
  }

  void clearClaimedJudges() {
    claimedJuriDevices.clear();
  }

  bool isJuriReady(int juriNumber) {
    final s = juriScores[juriNumber]?['status']?.toString();
    return s == 'ready' || s == 'scoring' || s == 'submitted';
  }

  bool isJuriSubmitted(int juriNumber) {
    return juriScores[juriNumber]?['submitted'] == true;
  }

  int countReadyJudges() {
    int count = 0;
    for (int i = 1; i <= activeJuriCount; i++) {
      if (isJuriReady(i)) count++;
    }
    return count;
  }

  double calculateTotalPenalties() {
    return penalties.fold(0.0, (total, p) => total + p.deduction);
  }

  List<double> _activeJuriScoreValues() {
    final List<double> scores = [];
    for (int i = 1; i <= activeJuriCount; i++) {
      final j = juriScores[i];
      if (j != null) {
        scores.add((j['score'] as num?)?.toDouble() ?? 9.90);
      }
    }
    return scores;
  }

  double calculateJuriMedian() {
    final scores = _activeJuriScoreValues();
    if (scores.isEmpty) return 9.90;
    scores.sort();
    final int n = scores.length;
    if (n % 2 == 1) {
      return scores[n ~/ 2];
    }
    return (scores[(n ~/ 2) - 1] + scores[n ~/ 2]) / 2.0;
  }

  double calculateStandardDeviation() {
    if (activeJuriCount < 2) return 0.0;
    final scores = _activeJuriScoreValues();
    if (scores.length < 2) return 0.0;
    final double mean = scores.reduce((a, b) => a + b) / scores.length;
    final double sumSquaredDiff = scores.fold(
      0.0,
      (acc, s) => acc + math.pow(s - mean, 2),
    );
    return math.sqrt(sumSquaredDiff / scores.length);
  }
}

/// Centralized state manager for synchronization between:
/// - Dewan Pertandingan (authority / match controller)
/// - Juri (judges 1-10)
/// - Time Keeper (timer sync)
/// - Monitoring Scoreboard (public arena display)
///
/// Supports full isolation per Gelanggang (Arena Code) AND cross-device
/// real-time synchronization via the Pusaka Seni backend API so separate
/// devices running the app stay synchronized automatically.
class GelanggangSyncService extends ChangeNotifier {
  static final GelanggangSyncService _instance = GelanggangSyncService._internal();
  static GelanggangSyncService get instance => _instance;

  static const Duration _pollInterval = Duration(milliseconds: 1500);

  static bool _isTestEnvironment() {
    if (kIsWeb) return false;
    try {
      return Platform.environment.containsKey('FLUTTER_TEST');
    } catch (_) {
      return false;
    }
  }

  static String normalizeArenaCode(String code) {
    final clean = code.toUpperCase().trim();
    if (clean == '12345678' ||
        clean == 'ARENA-A' ||
        clean == 'ARENA_A' ||
        clean == 'GELANGGANG A' ||
        clean == 'GELANGGANG-A' ||
        clean == 'GELANGGANG_A') {
      return 'GELANGGANG A';
    }
    if (clean == '87654321' ||
        clean == 'ARENA-B' ||
        clean == 'ARENA_B' ||
        clean == 'GELANGGANG B' ||
        clean == 'GELANGGANG-B' ||
        clean == 'GELANGGANG_B') {
      return 'GELANGGANG B';
    }
    return clean;
  }

  static String _truncate(String input, int maxLen) {
    final trimmed = input.trim();
    if (trimmed.length <= maxLen) return trimmed;
    return trimmed.substring(0, maxLen);
  }

  /// Controls whether live cloud push/pull runs automatically.
  /// Enabled in production apps; disabled by default under `flutter test`
  /// to keep unit & widget tests fast and deterministic.
  bool cloudSyncEnabled = !_isTestEnvironment();

  // Registry of isolated arena states keyed by normalized arena code
  final Map<String, GelanggangArenaState> _arenaStates = {};

  // Reference-counted polling timers per arena
  final Map<String, int> _syncRefCounts = {};
  final Map<String, Timer> _pollTimers = {};
  final Set<String> _pullInFlight = {};
  final Map<String, Timer> _debouncedPushes = {};

  String _activeArenaCode = 'GELANGGANG A';
  bool _isGelanggangVerified = false;
  int _lastRevMs = 0;

  int _selectedJuriNumber = 1; // Locked juri assigned to this mobile device
  late final String _deviceId =
      'D${DateTime.now().microsecondsSinceEpoch.toRadixString(36).substring(math.max(0, DateTime.now().microsecondsSinceEpoch.toRadixString(36).length - 5))}${math.Random().nextInt(1296).toRadixString(36).padLeft(2, '0')}';

  String? _lastSyncAction;
  String? _lastSyncArenaCode;

  GelanggangSyncService._internal() {
    _ensureArenaState('GELANGGANG A');
  }

  int _nextRevisionMs() {
    final now = DateTime.now().millisecondsSinceEpoch;
    _lastRevMs = now > _lastRevMs ? now : _lastRevMs + 1;
    return _lastRevMs;
  }

  GelanggangArenaState _ensureArenaState(String arenaCode) {
    final normalized = normalizeArenaCode(arenaCode);
    return _arenaStates.putIfAbsent(normalized, () {
      final samples = AthleteModel.getSampleAthletes();
      final bool isB = normalized.contains('B') || normalized.contains('2');
      final defaultAthlete = isB && samples.length > 1 ? samples[1] : samples[0];
      final defaultCat = isB ? SeniCategory.ganda : SeniCategory.tunggal;

      return GelanggangArenaState(
        arenaCode: normalized,
        initialAthlete: defaultAthlete,
        initialCategory: defaultCat,
        nomorPartai: isB ? 'PARTAI 02' : 'PARTAI 01',
        pool: isB ? 'POOL B' : 'POOL A',
      );
    });
  }

  GelanggangArenaState _resolveState(String? arenaCode) =>
      arenaCode != null ? _ensureArenaState(arenaCode) : currentArenaState;

  void _emitSync(String action, String? arenaCode) {
    _lastSyncAction = action;
    _lastSyncArenaCode = arenaCode;
    notifyListeners();
  }

  GelanggangArenaState getArenaState(String arenaCode) => _ensureArenaState(arenaCode);
  GelanggangArenaState get currentArenaState => _ensureArenaState(_activeArenaCode);

  // Active Gelanggang Info
  String get activeArenaCode => _activeArenaCode;
  bool get isGelanggangVerified => _isGelanggangVerified;
  String? get lastSyncAction => _lastSyncAction;
  String? get lastSyncArenaCode => _lastSyncArenaCode;
  int get selectedJuriNumber => _selectedJuriNumber;

  // Active match getters (delegating to current active arena)
  AthleteModel get athlete => currentArenaState.athlete;
  SeniCategory get category => currentArenaState.category;
  String get nomorPartai => currentArenaState.nomorPartai;
  String get pool => currentArenaState.pool;
  int get targetDurationSeconds => currentArenaState.targetDurationSeconds;

  int get timerRemainingSeconds => currentArenaState.timerRemainingSeconds;
  String get timerStatus => currentArenaState.timerStatus;
  String get timerModeTitle => currentArenaState.timerModeTitle;
  bool get isOvertime => currentArenaState.timerRemainingSeconds < 0;
  int get timerElapsedSeconds =>
      math.max(0, currentArenaState.targetDurationSeconds - currentArenaState.timerRemainingSeconds);

  String get formattedTimerRemaining {
    final sec = currentArenaState.timerRemainingSeconds;
    final int absSec = sec.abs();
    final int m = absSec ~/ 60;
    final int s = absSec % 60;
    final formatted = '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    return sec < 0 ? '-$formatted' : formatted;
  }

  String get formattedTimerElapsed {
    final int elapsed = timerElapsedSeconds;
    final int m = elapsed ~/ 60;
    final int s = elapsed % 60;
    return '${m.toString().padLeft(2, '0')} : ${s.toString().padLeft(2, '0')}';
  }

  String get timerStatusLabel {
    final sec = currentArenaState.timerRemainingSeconds;
    final status = currentArenaState.timerStatus.toLowerCase();
    if (sec < 0) {
      return status == 'paused' ? 'LEWAT (JEDA)' : 'LEWAT WAKTU';
    }
    switch (status) {
      case 'running':
        return 'BERJALAN';
      case 'paused':
        return 'JEDA';
      case 'stopped':
        return 'SELESAI';
      case 'standby':
      default:
        return 'STANDBY';
    }
  }

  int get activeJuriCount => currentArenaState.activeJuriCount;
  int getActiveJuriCount({String? arenaCode}) => _resolveState(arenaCode).activeJuriCount;
  Map<int, Map<String, dynamic>> get juriScores => Map.unmodifiable(currentArenaState.juriScores);
  List<PenaltyDeduction> get penalties => List.unmodifiable(currentArenaState.penalties);
  bool get isMatchFinalized => currentArenaState.isMatchFinalized;
  double get officialFinalScore => currentArenaState.officialFinalScore;

  bool isAthleteCompleted(AthleteModel a, {String? arenaCode}) {
    final finalized = _resolveState(arenaCode).finalizedAthletes;
    return (a.documentId.isNotEmpty && finalized.containsKey(a.documentId)) ||
        (a.partai.isNotEmpty && finalized.containsKey(a.partai)) ||
        (a.id.isNotEmpty && finalized.containsKey(a.id)) ||
        (a.name.isNotEmpty && finalized.containsKey(a.name));
  }

  bool isAthleteActive(AthleteModel a, {String? arenaCode}) {
    final state = _resolveState(arenaCode);
    if (state.isMatchFinalized) return false;
    final bool matchDoc = state.athlete.documentId.isNotEmpty &&
        a.documentId.isNotEmpty &&
        state.athlete.documentId == a.documentId;
    final bool matchPartai = state.athlete.partai.isNotEmpty &&
        a.partai.isNotEmpty &&
        state.athlete.partai.toLowerCase().trim() == a.partai.toLowerCase().trim();
    final bool matchName = state.athlete.name.isNotEmpty &&
        a.name.isNotEmpty &&
        state.athlete.name.toLowerCase().trim() == a.name.toLowerCase().trim();
    return matchDoc || matchPartai || matchName;
  }

  double? getAthleteScore(AthleteModel a, {String? arenaCode}) {
    final finalized = _resolveState(arenaCode).finalizedAthletes;
    return finalized[a.documentId] ??
        finalized[a.partai] ??
        finalized[a.id] ??
        finalized[a.name];
  }

  String getJuriStatus(int juriNumber, {String? arenaCode}) {
    return _resolveState(arenaCode).juriScores[juriNumber]?['status']?.toString() ?? 'not_ready';
  }

  bool isJuriReady(int juriNumber, {String? arenaCode}) =>
      _resolveState(arenaCode).isJuriReady(juriNumber);

  bool isJuriSubmitted(int juriNumber, {String? arenaCode}) =>
      _resolveState(arenaCode).isJuriSubmitted(juriNumber);

  int countReadyJudges({String? arenaCode}) =>
      _resolveState(arenaCode).countReadyJudges();

  double calculateTotalPenalties({String? arenaCode}) =>
      _resolveState(arenaCode).calculateTotalPenalties();

  double calculateJuriMedian({String? arenaCode}) =>
      _resolveState(arenaCode).calculateJuriMedian();

  double calculateStandardDeviation({String? arenaCode}) =>
      _resolveState(arenaCode).calculateStandardDeviation();

  // ===========================================================================
  // CROSS-DEVICE CLOUD SYNC (REAL-TIME POLLING & PUSH)
  // ===========================================================================

  /// Starts reference-counted real-time cloud synchronization for [arenaCode].
  /// Call from `initState()` of active role views and pair with [stopRealtimeSync]
  /// in `dispose()`.
  void startRealtimeSync({String? arenaCode}) {
    final targetArena = normalizeArenaCode(arenaCode ?? _activeArenaCode);
    _ensureArenaState(targetArena);
    _syncRefCounts[targetArena] = (_syncRefCounts[targetArena] ?? 0) + 1;

    if (!cloudSyncEnabled) return;
    if (!_pollTimers.containsKey(targetArena)) {
      unawaited(pullArenaSync(targetArena));
      _pollTimers[targetArena] = Timer.periodic(_pollInterval, (_) {
        unawaited(pullArenaSync(targetArena));
      });
    }
  }

  /// Stops one listener reference for real-time sync on [arenaCode].
  /// Cancels the polling timer when no views are observing [arenaCode].
  void stopRealtimeSync({String? arenaCode}) {
    final targetArena = normalizeArenaCode(arenaCode ?? _activeArenaCode);
    final nextCount = (_syncRefCounts[targetArena] ?? 1) - 1;
    if (nextCount <= 0) {
      _syncRefCounts.remove(targetArena);
      _pollTimers.remove(targetArena)?.cancel();
    } else {
      _syncRefCounts[targetArena] = nextCount;
    }
  }

  /// Pulls the latest cloud state for [arenaCode] and merges remote updates.
  Future<void> pullArenaSync(String arenaCode) async {
    if (!cloudSyncEnabled) return;
    final targetArena = normalizeArenaCode(arenaCode);
    if (_pullInFlight.contains(targetArena)) return;
    _pullInFlight.add(targetArena);
    try {
      final records = await PusakaSeniApiService().fetchSyncRecords(targetArena);
      if (records.isNotEmpty) {
        applyRemoteSyncRecords(targetArena, records);
      }
    } catch (_) {
      // Offline-resilient: continue operating locally until connection returns
    } finally {
      _pullInFlight.remove(targetArena);
    }
  }

  String _syncKey(String arenaCode, String topic) => 'sync|$arenaCode|$topic';

  void _pushSyncKey({
    required String arenaCode,
    required String topic,
    required double nilai,
    required Map<String, dynamic> payload,
    Duration? debounce,
  }) {
    final state = _ensureArenaState(arenaCode);
    final key = _syncKey(arenaCode, topic);
    final rev = _nextRevisionMs();
    state.keyRevisions[key] = rev;

    if (!cloudSyncEnabled) return;

    final keterangan = jsonEncode(payload);
    Future<void> send() async {
      final docId = await PusakaSeniApiService().upsertSyncRecord(
        syncKey: key,
        nilai: nilai,
        waktu: rev.toString(),
        keterangan: keterangan,
        existingDocId: state.remoteDocIds[key],
      );
      if (docId != null && docId.isNotEmpty) {
        state.remoteDocIds[key] = docId;
      }
    }

    if (debounce != null) {
      _debouncedPushes[key]?.cancel();
      _debouncedPushes[key] = Timer(debounce, () {
        _debouncedPushes.remove(key);
        unawaited(send());
      });
    } else {
      _debouncedPushes.remove(key)?.cancel();
      unawaited(send());
    }
  }

  Map<String, dynamic> _buildMatchPayload(GelanggangArenaState state) {
    return {
      'mk': state.matchVersion,
      'id': _truncate(state.athlete.id, 12),
      'doc': _truncate(state.athlete.documentId, 28),
      'n': _truncate(state.athlete.name, 38),
      'k': _truncate(state.athlete.kontingen, 24),
      'c': state.category.name,
      'p': _truncate(state.nomorPartai, 16),
      'pl': _truncate(state.pool, 20),
      'jc': state.activeJuriCount,
      'fin': state.isMatchFinalized ? 1 : 0,
      'fs': double.parse(state.officialFinalScore.toStringAsFixed(4)),
      'dev': _deviceId,
    };
  }

  Map<String, dynamic> _buildTimerPayload(GelanggangArenaState state, int anchorMs) {
    return {
      'st': state.timerStatus,
      'rem': state.timerRemainingSeconds,
      'dur': state.targetDurationSeconds,
      'mt': _truncate(state.timerModeTitle, 28),
      'at': anchorMs,
      'dev': _deviceId,
    };
  }

  Map<String, dynamic> _buildJuriPayload(
    GelanggangArenaState state,
    int juriNumber, {
    String? overrideDeviceId,
  }) {
    final entry = state.juriScores[juriNumber] ?? state._defaultJuriEntry();
    final map = <String, dynamic>{
      'mk': state.matchVersion,
      'st': entry['status']?.toString() ?? 'not_ready',
      'sub': entry['submitted'] == true ? 1 : 0,
      'kb': double.parse(((entry['kebenaran'] as num?)?.toDouble() ?? 9.90).toStringAsFixed(2)),
      'dev': overrideDeviceId ?? (state.claimedJuriDevices[juriNumber] ?? ''),
    };
    if (entry['kemantapan'] != null) {
      map['km'] = double.parse((entry['kemantapan'] as num).toDouble().toStringAsFixed(2));
    }
    return map;
  }

  Map<String, dynamic> _buildPenaltiesPayload(GelanggangArenaState state) {
    final total = double.parse(state.calculateTotalPenalties().toStringAsFixed(2));
    final List<List<dynamic>> items = [];
    for (final p in state.penalties) {
      final candidate = [
        _truncate(p.id, 14),
        _truncate(p.label, 24),
        double.parse(p.deduction.toStringAsFixed(2)),
      ];
      items.add(candidate);
      final encoded = jsonEncode({'mk': state.matchVersion, 't': total, 'p': items, 'dev': _deviceId});
      if (encoded.length > 245) {
        items.removeLast();
        break;
      }
    }
    return {
      'mk': state.matchVersion,
      't': total,
      'p': items,
      'dev': _deviceId,
    };
  }

  void _pushMatchState(String arenaCode) {
    final state = _ensureArenaState(arenaCode);
    _pushSyncKey(
      arenaCode: arenaCode,
      topic: 'match',
      nilai: state.officialFinalScore,
      payload: _buildMatchPayload(state),
    );
  }

  void _pushTimerState(String arenaCode) {
    final state = _ensureArenaState(arenaCode);
    final anchorMs = DateTime.now().millisecondsSinceEpoch;
    _pushSyncKey(
      arenaCode: arenaCode,
      topic: 'timer',
      nilai: state.timerRemainingSeconds.toDouble(),
      payload: _buildTimerPayload(state, anchorMs),
    );
  }

  void _pushJuriState(
    String arenaCode,
    int juriNumber, {
    String? overrideDeviceId,
    Duration? debounce,
  }) {
    final state = _ensureArenaState(arenaCode);
    final score = (state.juriScores[juriNumber]?['score'] as num?)?.toDouble() ?? 9.90;
    _pushSyncKey(
      arenaCode: arenaCode,
      topic: 'juri|$juriNumber',
      nilai: score,
      payload: _buildJuriPayload(state, juriNumber, overrideDeviceId: overrideDeviceId),
      debounce: debounce,
    );
  }

  void _pushPenaltiesState(String arenaCode) {
    final state = _ensureArenaState(arenaCode);
    _pushSyncKey(
      arenaCode: arenaCode,
      topic: 'penalties',
      nilai: state.calculateTotalPenalties(),
      payload: _buildPenaltiesPayload(state),
    );
  }

  void _startLocalDisplayTimer(String targetArena, GelanggangArenaState state) {
    state.activeTimer?.cancel();
    state.activeTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      state.timerRemainingSeconds--;
      _emitSync('TIMEKEEPER_TIMER_SYNC', targetArena);
    });
  }

  /// Merges a batch of remote sync records fetched from Strapi into [arenaCode].
  /// Exposed so cross-device synchronization can also be thoroughly unit-tested.
  void applyRemoteSyncRecords(String arenaCode, List<Map<String, dynamic>> records) {
    final targetArena = normalizeArenaCode(arenaCode);
    final state = _ensureArenaState(targetArena);
    final prefix = 'sync|$targetArena|';

    // Deduplicate: keep only the newest record per sync key (highest `waktu` rev)
    final Map<String, Map<String, dynamic>> latestByKey = {};
    final Map<String, int> revByKey = {};

    for (final rec in records) {
      final key = rec['penilai']?.toString() ?? '';
      if (!key.startsWith(prefix)) continue;

      final rev = int.tryParse(rec['waktu']?.toString() ?? '') ?? 0;
      final prevRev = revByKey[key] ?? -1;
      if (rev >= prevRev) {
        revByKey[key] = rev;
        latestByKey[key] = rec;
      }
      final docId = rec['documentId']?.toString();
      if (docId != null && docId.isNotEmpty && !state.remoteDocIds.containsKey(key)) {
        state.remoteDocIds[key] = docId;
      }
    }

    if (latestByKey.isEmpty) return;

    bool changed = false;
    String emittedAction = 'CLOUD_SYNC_UPDATED';

    // 1. Apply claims_reset first if newer
    final claimsResetKey = _syncKey(targetArena, 'claims_reset');
    if (latestByKey.containsKey(claimsResetKey)) {
      final rev = revByKey[claimsResetKey] ?? 0;
      if (rev > state.claimsResetRevision) {
        state.claimsResetRevision = rev;
        state.keyRevisions[claimsResetKey] = rev;
        state.clearClaimedJudges();
        changed = true;
      }
    }

    // 2. Apply match record FIRST so matchVersion is up to date for juri & penalties
    final matchKey = _syncKey(targetArena, 'match');
    if (latestByKey.containsKey(matchKey)) {
      final rec = latestByKey[matchKey]!;
      final rev = revByKey[matchKey] ?? 0;
      final localRev = state.keyRevisions[matchKey] ?? 0;
      if (rev > localRev) {
        final data = _decodePayload(rec['keterangan']?.toString());
        if (data != null) {
          state.keyRevisions[matchKey] = rev;
          final remoteMk = data['mk']?.toString() ?? '';
          final isNewMatch = remoteMk.isNotEmpty && remoteMk != state.matchVersion;

          final remoteCategoryName = data['c']?.toString() ?? '';
          final remoteCategory = SeniCategory.values.firstWhere(
            (c) => c.name == remoteCategoryName,
            orElse: () => SeniCategory.fromString(remoteCategoryName),
          );
          final remotePartai = data['p']?.toString() ?? state.nomorPartai;
          final remotePool = data['pl']?.toString() ?? state.pool;
          final remoteAthlete = AthleteModel(
            id: data['id']?.toString() ?? state.athlete.id,
            documentId: data['doc']?.toString() ?? state.athlete.documentId,
            name: data['n']?.toString() ?? state.athlete.name,
            kontingen: data['k']?.toString() ?? state.athlete.kontingen,
            category: remoteCategory.name,
            pool: remotePool,
            partai: remotePartai,
          );
          final remoteJuriCount = (data['jc'] as num?)?.toInt() ?? state.activeJuriCount;
          final remoteFinalized = data['fin'] == 1 || data['fin'] == true;
          final remoteFinalScore =
              (data['fs'] as num?)?.toDouble() ?? (rec['nilai'] as num?)?.toDouble() ?? 0.0;

          if (remoteJuriCount != state.activeJuriCount) {
            state.setActiveJuriCount(remoteJuriCount);
          }

          if (isNewMatch) {
            state.matchVersion = remoteMk;
            state.athlete = remoteAthlete;
            state.category = remoteCategory;
            state.nomorPartai = remotePartai;
            state.pool = remotePool;
            state.isMatchFinalized = remoteFinalized;
            state.officialFinalScore = remoteFinalScore;
            state.penalties.clear();
            state._initJuriScores();
            state.juriOngoingSessions.clear();
            emittedAction = 'ATHLETE_SELECTED';
          } else {
            if (remoteMk.isNotEmpty) {
              state.matchVersion = remoteMk;
            }
            state.athlete = remoteAthlete;
            state.category = remoteCategory;
            state.nomorPartai = remotePartai;
            state.pool = remotePool;
            state.isMatchFinalized = remoteFinalized;
            state.officialFinalScore = remoteFinalScore;
          }

          if (remoteFinalized) {
            _recordFinalizedAthlete(state, remoteFinalScore);
          }
          changed = true;
        }
      }
    }

    // 3. Apply timer record
    final timerKey = _syncKey(targetArena, 'timer');
    if (latestByKey.containsKey(timerKey)) {
      final rec = latestByKey[timerKey]!;
      final rev = revByKey[timerKey] ?? 0;
      final localRev = state.keyRevisions[timerKey] ?? 0;
      if (rev > localRev) {
        final data = _decodePayload(rec['keterangan']?.toString());
        if (data != null) {
          state.keyRevisions[timerKey] = rev;
          final st = data['st']?.toString() ?? 'standby';
          final rem = (data['rem'] as num?)?.toInt() ??
              (rec['nilai'] as num?)?.toInt() ??
              state.targetDurationSeconds;
          final dur = (data['dur'] as num?)?.toInt() ?? state.targetDurationSeconds;
          final mt = data['mt']?.toString() ?? state.timerModeTitle;
          final at = (data['at'] as num?)?.toInt() ?? rev;

          state.targetDurationSeconds = dur;
          state.timerModeTitle = mt;
          state.timerStatus = st;

          if (st == 'running') {
            final nowMs = DateTime.now().millisecondsSinceEpoch;
            final elapsedSec = math.max(0, ((nowMs - at) / 1000).round());
            state.timerRemainingSeconds = rem - elapsedSec;
            _startLocalDisplayTimer(targetArena, state);
          } else {
            state.activeTimer?.cancel();
            state.activeTimer = null;
            state.timerRemainingSeconds = rem;
          }
          if (emittedAction != 'ATHLETE_SELECTED') {
            emittedAction = 'TIMEKEEPER_TIMER_SYNC';
          }
          changed = true;
        }
      }
    }

    // 4. Apply penalties record
    final penaltiesKey = _syncKey(targetArena, 'penalties');
    if (latestByKey.containsKey(penaltiesKey)) {
      final rec = latestByKey[penaltiesKey]!;
      final rev = revByKey[penaltiesKey] ?? 0;
      final localRev = state.keyRevisions[penaltiesKey] ?? 0;
      if (rev > localRev) {
        final data = _decodePayload(rec['keterangan']?.toString());
        if (data != null) {
          final remoteMk = data['mk']?.toString() ?? '';
          if (state.matchVersion.isEmpty || remoteMk == state.matchVersion) {
            state.keyRevisions[penaltiesKey] = rev;
            state.penalties.clear();
            final rawItems = data['p'];
            double decodedSum = 0.0;
            if (rawItems is List) {
              for (final item in rawItems) {
                if (item is List && item.length >= 3) {
                  final ded = (item[2] as num?)?.toDouble() ?? 0.0;
                  decodedSum += ded;
                  state.penalties.add(
                    PenaltyDeduction(
                      id: item[0].toString(),
                      label: item[1].toString(),
                      deduction: ded,
                      timestamp: DateTime.fromMillisecondsSinceEpoch(rev),
                    ),
                  );
                }
              }
            }
            final exactTotal = (data['t'] as num?)?.toDouble() ?? 0.0;
            final diff = exactTotal - decodedSum;
            if (diff > 0.001) {
              state.penalties.add(
                PenaltyDeduction(
                  id: 'sync_overflow',
                  label: 'Hukuman Lainnya',
                  deduction: double.parse(diff.toStringAsFixed(2)),
                  timestamp: DateTime.fromMillisecondsSinceEpoch(rev),
                ),
              );
            }
            changed = true;
          }
        }
      }
    }

    // 5. Apply per-juri records (claims + live readiness/scores)
    final juriPrefix = '${prefix}juri|';
    for (final entry in latestByKey.entries) {
      final key = entry.key;
      if (!key.startsWith(juriPrefix)) continue;

      final juriNum = int.tryParse(key.substring(juriPrefix.length));
      if (juriNum == null || juriNum < 1 || juriNum > state.activeJuriCount) continue;

      final rec = entry.value;
      final rev = revByKey[key] ?? 0;
      final localRev = state.keyRevisions[key] ?? 0;
      if (rev <= localRev) continue;

      final data = _decodePayload(rec['keterangan']?.toString());
      if (data == null) continue;

      state.keyRevisions[key] = rev;

      // Apply judge device claim (if newer than claimsResetRevision)
      if (rev > state.claimsResetRevision) {
        final remoteDev = data['dev']?.toString() ?? '';
        if (remoteDev.isNotEmpty) {
          state.claimedJuriDevices[juriNum] = remoteDev;
        } else if (state.claimedJuriDevices[juriNum] != _deviceId) {
          state.claimedJuriDevices.remove(juriNum);
        }
        changed = true;
      }

      // Apply judge status/score ONLY if it belongs to the active match
      final remoteMk = data['mk']?.toString() ?? '';
      if (state.matchVersion.isEmpty || remoteMk == state.matchVersion) {
        final remoteStatus = data['st']?.toString() ?? 'not_ready';
        final remoteSub = data['sub'] == 1 || data['sub'] == true;
        final remoteScore = (rec['nilai'] as num?)?.toDouble() ?? 9.90;
        final remoteKebenaran = (data['kb'] as num?)?.toDouble() ?? remoteScore;
        final remoteKemantapan = (data['km'] as num?)?.toDouble();

        state.juriScores[juriNum] = {
          'score': remoteScore,
          'kebenaran': remoteKebenaran,
          'kemantapan': remoteKemantapan,
          'isReady': remoteStatus != 'not_ready',
          'status': remoteStatus,
          'submitted': remoteSub,
        };
        changed = true;
      }
    }

    if (changed) {
      _emitSync(emittedAction, targetArena);
    }
  }

  Map<String, dynamic>? _decodePayload(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) {
        return Map<String, dynamic>.from(decoded);
      }
    } catch (_) {}
    return null;
  }

  void _recordFinalizedAthlete(GelanggangArenaState state, double officialScore) {
    for (final key in [
      state.athlete.documentId,
      state.athlete.partai,
      state.athlete.id,
      state.athlete.name,
    ]) {
      if (key.isNotEmpty) {
        state.finalizedAthletes[key] = officialScore;
      }
    }
  }

  // ===========================================================================
  // LOCAL ACTIONS (UPDATE LOCAL STATE INSTANTLY + PUSH TO CLOUD)
  // ===========================================================================

  /// 1. Verifikasi Gelanggang (from 8-digit code or QR Scan)
  void verifyGelanggang({required String arenaCode}) {
    final normalized = normalizeArenaCode(arenaCode);
    _activeArenaCode = normalized;
    _isGelanggangVerified = true;
    _ensureArenaState(normalized);
    _emitSync('GELANGGANG_VERIFIED', normalized);
    unawaited(pullArenaSync(normalized));
  }

  /// 2. Dewan Memilih Partai / Atlet (Master Sync: Hanya juri, monitor, timekeeper gelanggang ini yang berubah)
  void dewanSelectMatch({
    required AthleteModel athlete,
    required SeniCategory category,
    String? nomorPartai,
    String? pool,
    int? targetDuration,
    String? arenaCode,
  }) {
    final targetArena = normalizeArenaCode(arenaCode ?? _activeArenaCode);
    final state = _ensureArenaState(targetArena);

    state.matchVersion = _nextRevisionMs().toString();
    state.athlete = athlete;
    state.category = category;
    state.nomorPartai = nomorPartai ?? athlete.partai;
    state.pool = pool ?? athlete.pool;
    state.activeTimer?.cancel();
    state.activeTimer = null;
    state.targetDurationSeconds = targetDuration ?? 180;
    state.timerRemainingSeconds = state.targetDurationSeconds;
    if (state.targetDurationSeconds == 80) {
      state.timerModeTitle = 'Tangan Kosong (01:20)';
    } else if (state.targetDurationSeconds == 100) {
      state.timerModeTitle = 'Senjata (01:40)';
    } else {
      state.timerModeTitle = 'Standar (03:00)';
    }
    state.timerStatus = 'standby';
    state.isMatchFinalized = isAthleteCompleted(athlete, arenaCode: targetArena);
    state.officialFinalScore = state.finalizedAthletes[athlete.documentId] ?? 0.0;
    state.penalties.clear();

    // Reset juri scores and ongoing sessions ONLY for this arena
    state._initJuriScores();
    state.juriOngoingSessions.clear();

    // Push master match, timer reset, and cleared penalties to cloud for all devices
    _pushMatchState(targetArena);
    _pushTimerState(targetArena);
    _pushPenaltiesState(targetArena);

    // Post official match log to server
    if (cloudSyncEnabled && athlete.documentId.isNotEmpty) {
      try {
        PusakaSeniApiService().postScore(
          athleteDocId: athlete.documentId,
          penilai: 'dewan',
          nilai: 9.90,
          keterangan: 'Partai Dimulai oleh Dewan (${athlete.partai}) di $targetArena',
        );
      } catch (_) {}
    }

    _emitSync('ATHLETE_SELECTED', targetArena);
  }

  /// Atur nomor juri yang ditugaskan pada perangkat ini (Terkunci)
  void setSelectedJuriNumber(int juri) {
    if (juri < 1) return;
    _selectedJuriNumber = juri;
    _emitSync('SELECTED_JURI_CHANGED', _activeArenaCode);
  }

  /// Klaim nomor juri untuk perangkat ini di arena tertentu
  void claimJuri(int juriNumber, {String? arenaCode, String? customDeviceId}) {
    final targetArena = normalizeArenaCode(arenaCode ?? _activeArenaCode);
    final state = _ensureArenaState(targetArena);
    final devId = customDeviceId ?? _deviceId;
    final previousJuri = state.claimJuri(juriNumber, devId);

    if (previousJuri != null) {
      _pushJuriState(targetArena, previousJuri, overrideDeviceId: '');
    }
    _pushJuriState(targetArena, juriNumber, overrideDeviceId: devId);
    _emitSync('JURI_CLAIMED', targetArena);
  }

  /// Reset semua klaim juri di arena tertentu
  void clearClaimedJudges({String? arenaCode}) {
    final targetArena = normalizeArenaCode(arenaCode ?? _activeArenaCode);
    final state = _ensureArenaState(targetArena);
    state.clearClaimedJudges();
    state.claimsResetRevision = _nextRevisionMs();
    _pushSyncKey(
      arenaCode: targetArena,
      topic: 'claims_reset',
      nilai: 0,
      payload: {'dev': _deviceId},
    );
    _emitSync('JURI_CLAIMS_CLEARED', targetArena);
  }

  /// Ambil daftar nomor juri yang tersedia untuk perangkat ini
  List<int> getAvailableJudgesForThisDevice({String? arenaCode, String? customDeviceId}) {
    final targetArena = normalizeArenaCode(arenaCode ?? _activeArenaCode);
    final state = _ensureArenaState(targetArena);
    final devId = customDeviceId ?? _deviceId;
    final int count = state.activeJuriCount > 0 ? state.activeJuriCount : 8;
    return List.generate(count, (i) => i + 1)
        .where((jNum) => !state.isJuriClaimedByOther(jNum, devId))
        .toList();
  }

  /// Simpan sesi penilaian juri yang sedang berjalan agar tidak hilang jika keluar sementara
  void saveJuriOngoingSession({
    required int juriNumber,
    required Map<String, dynamic> sessionData,
    String? arenaCode,
  }) {
    _resolveState(arenaCode).juriOngoingSessions[juriNumber] = sessionData;
  }

  /// Ambil sesi penilaian juri yang sedang berjalan untuk dilanjutkan
  Map<String, dynamic>? getJuriOngoingSession(int juriNumber, {String? arenaCode}) {
    return _resolveState(arenaCode).juriOngoingSessions[juriNumber];
  }

  /// Hapus sesi penilaian juri
  void clearJuriOngoingSessions({String? arenaCode}) {
    _resolveState(arenaCode).juriOngoingSessions.clear();
  }

  /// 3. Juri konfirmasi siap menilai (Ready)
  void juriSetReady({
    required int juriNumber,
    required bool isReady,
    String? arenaCode,
  }) {
    final targetArena = normalizeArenaCode(arenaCode ?? _activeArenaCode);
    final state = _ensureArenaState(targetArena);
    final current = state.juriScores[juriNumber] ?? {};
    state.juriScores[juriNumber] = {
      ...current,
      'isReady': isReady,
      'status': isReady ? 'ready' : 'not_ready',
    };
    _pushJuriState(targetArena, juriNumber);
    _emitSync('JURI_READY_CHANGED', targetArena);
  }

  /// 4. Juri mulai / sedang melakukan input penilaian (Kuning)
  void juriStartScoring({
    required int juriNumber,
    double? currentScore,
    String? arenaCode,
  }) {
    final targetArena = normalizeArenaCode(arenaCode ?? _activeArenaCode);
    final state = _ensureArenaState(targetArena);
    final current = state.juriScores[juriNumber] ?? {};
    if (current['submitted'] == true) return;
    state.juriScores[juriNumber] = {
      ...current,
      'score': currentScore ?? current['score'] ?? 9.90,
      'isReady': true,
      'status': 'scoring',
    };
    _pushJuriState(
      targetArena,
      juriNumber,
      debounce: const Duration(milliseconds: 250),
    );
    _emitSync('JURI_SCORING_IN_PROGRESS', targetArena);
  }

  /// 5. Juri mengirim / menyelesaikan skor akhir
  void juriSubmitScore({
    required int juriNumber,
    required double score,
    double? kebenaran,
    double? kemantapan,
    String? arenaCode,
  }) {
    final targetArena = normalizeArenaCode(arenaCode ?? _activeArenaCode);
    final state = _ensureArenaState(targetArena);
    state.juriScores[juriNumber] = {
      'score': score,
      'kebenaran': kebenaran ?? score,
      'kemantapan': kemantapan,
      'isReady': true,
      'status': 'submitted',
      'submitted': true,
      'updatedAt': DateTime.now().toIso8601String(),
    };
    _pushJuriState(targetArena, juriNumber);
    _emitSync('JURI_SCORE_UPDATED', targetArena);
  }

  /// Start / Resume Live Timer (ticks continuously across app until stopped by Timekeeper)
  void timekeeperStartTimer({String? arenaCode}) {
    final targetArena = normalizeArenaCode(arenaCode ?? _activeArenaCode);
    final state = _ensureArenaState(targetArena);
    state.timerStatus = 'running';

    _startLocalDisplayTimer(targetArena, state);
    _pushTimerState(targetArena);
    _emitSync('TIMEKEEPER_TIMER_SYNC', targetArena);
  }

  /// Pause Live Timer
  void timekeeperPauseTimer({String? arenaCode}) {
    final targetArena = normalizeArenaCode(arenaCode ?? _activeArenaCode);
    final state = _ensureArenaState(targetArena);
    state.activeTimer?.cancel();
    state.activeTimer = null;
    state.timerStatus = 'paused';
    _pushTimerState(targetArena);
    _emitSync('TIMEKEEPER_TIMER_SYNC', targetArena);
  }

  /// Stop Live Timer
  void timekeeperStopTimer({String? arenaCode}) {
    final targetArena = normalizeArenaCode(arenaCode ?? _activeArenaCode);
    final state = _ensureArenaState(targetArena);
    state.activeTimer?.cancel();
    state.activeTimer = null;
    state.timerStatus = 'stopped';
    _pushTimerState(targetArena);
    _emitSync('TIMEKEEPER_TIMER_SYNC', targetArena);
  }

  /// Reset Live Timer
  void timekeeperResetTimer({String? arenaCode}) {
    final targetArena = normalizeArenaCode(arenaCode ?? _activeArenaCode);
    final state = _ensureArenaState(targetArena);
    state.activeTimer?.cancel();
    state.activeTimer = null;
    state.timerRemainingSeconds = state.targetDurationSeconds;
    state.timerStatus = 'standby';
    _pushTimerState(targetArena);
    _emitSync('TIMEKEEPER_TIMER_SYNC', targetArena);
  }

  /// Switch Time Mode (Standar 3m, Tangan Kosong 1m20s, Senjata 1m40s)
  void timekeeperSwitchMode({
    required int durationSeconds,
    required String modeTitle,
    String? arenaCode,
  }) {
    final targetArena = normalizeArenaCode(arenaCode ?? _activeArenaCode);
    final state = _ensureArenaState(targetArena);
    if (state.timerStatus == 'running') return;
    state.activeTimer?.cancel();
    state.activeTimer = null;
    state.targetDurationSeconds = durationSeconds;
    state.timerRemainingSeconds = durationSeconds;
    state.timerModeTitle = modeTitle;
    state.timerStatus = 'standby';
    _pushTimerState(targetArena);
    _emitSync('TIMEKEEPER_TIMER_SYNC', targetArena);
  }

  /// Timekeeper sinkronisasi timer ke Dewan & Scoreboard
  void timekeeperSyncTimer({
    required int remainingSeconds,
    required String status,
    int? targetDurationSeconds,
    String? modeTitle,
    String? arenaCode,
  }) {
    final targetArena = normalizeArenaCode(arenaCode ?? _activeArenaCode);
    final state = _ensureArenaState(targetArena);
    state.timerRemainingSeconds = remainingSeconds;
    state.timerStatus = status;
    if (targetDurationSeconds != null) {
      state.targetDurationSeconds = targetDurationSeconds;
    }
    if (modeTitle != null) {
      state.timerModeTitle = modeTitle;
    }
    if (status == 'running') {
      if (state.activeTimer == null || !state.activeTimer!.isActive) {
        timekeeperStartTimer(arenaCode: targetArena);
        return;
      }
    } else {
      state.activeTimer?.cancel();
      state.activeTimer = null;
    }
    _pushTimerState(targetArena);
    _emitSync('TIMEKEEPER_TIMER_SYNC', targetArena);
  }

  /// 6. Dewan input hukuman
  void dewanAddPenalty(PenaltyDeduction penalty, {String? arenaCode}) {
    final targetArena = normalizeArenaCode(arenaCode ?? _activeArenaCode);
    _ensureArenaState(targetArena).penalties.add(penalty);
    _pushPenaltiesState(targetArena);
    _emitSync('DEWAN_PENALTY_ADDED', targetArena);
  }

  /// 7. Dewan membatalkan hukuman
  void dewanRemovePenalty(int index, {String? arenaCode}) {
    final targetArena = normalizeArenaCode(arenaCode ?? _activeArenaCode);
    final state = _ensureArenaState(targetArena);
    if (index >= 0 && index < state.penalties.length) {
      state.penalties.removeAt(index);
      _pushPenaltiesState(targetArena);
      _emitSync('DEWAN_PENALTY_REMOVED', targetArena);
    }
  }

  /// 8. Dewan mengatur jumlah juri yang bertugas (3, 4, 5, 8, atau 10)
  void setActiveJuriCount(int count, {String? arenaCode}) {
    final targetArena = normalizeArenaCode(arenaCode ?? _activeArenaCode);
    _ensureArenaState(targetArena).setActiveJuriCount(count);
    _pushMatchState(targetArena);
    _emitSync('JURI_COUNT_CHANGED', targetArena);
  }

  /// 9. Dewan mengesahkan nilai partai secara resmi
  void dewanFinalizeMatch(double officialScore, {String? arenaCode}) {
    final targetArena = normalizeArenaCode(arenaCode ?? _activeArenaCode);
    final state = _ensureArenaState(targetArena);
    state.isMatchFinalized = true;
    state.officialFinalScore = officialScore;
    _recordFinalizedAthlete(state, officialScore);
    _pushMatchState(targetArena);
    _emitSync('MATCH_FINALIZED', targetArena);
  }
}
