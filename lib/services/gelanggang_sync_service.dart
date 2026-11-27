import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import '../models/scoring_models.dart';
import 'platform_env.dart';
import 'pusaka_seni_api_service.dart';

/// Isolated state for a specific Gelanggang / Arena.
/// Ensures that Gelanggang A, Gelanggang B, and any other arena
/// maintain strictly independent athletes, scoring, penalties, and timers.
class GelanggangArenaState {
  final String arenaCode;

  // Locked backend identity populated after Gelanggang verification
  bool isVerified = false;
  String? lockedGelanggangId;
  String? lockedGelanggangDocId;
  String? lockedRawArenaCode;
  String? lockedEventId;
  String? lockedEventDocId;
  String? lockedEventTitle;
  String? lockedEventCode;

  String matchVersion = '';
  late AthleteModel athlete;
  late SeniCategory category;
  String nomorPartai;
  String pool;

  // Live Timer State (Independent timer per arena; Timekeeper is sole authority)
  Timer? activeTimer;
  Timer? timerHeartbeat;
  bool isTimerAuthority = false;
  int targetDurationSeconds = 180;
  int timerRemainingSeconds = 180;
  String timerStatus = 'standby'; // 'standby', 'running', 'paused', 'stopped'
  String timerModeTitle = 'Standar (03:00)';

  // Active Judges Configuration (3, 4, 5, 8, 10; Dewan is sole authority)
  int activeJuriCount = 8;
  bool hasDewanJuriCount = false;
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
    this.nomorPartai = '-',
    this.pool = '-',
  }) {
    athlete = initialAthlete ?? AthleteModel.empty;
    category = initialCategory ?? SeniCategory.tunggal;
    _initJuriScores();
  }

  Map<String, dynamic> _defaultJuriEntry() => {
    'score': 9.90,
    'kebenaran': 9.90,
    'kemantapan': null,
    'currentJurus': null,
    'totalJurus': null,
    'jurusLabel': null,
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
  static final GelanggangSyncService _instance =
      GelanggangSyncService._internal();
  static GelanggangSyncService get instance => _instance;

  static const Duration _pollInterval = Duration(milliseconds: 1500);

  static bool _isTestEnvironment() {
    if (kIsWeb) return false;
    return isFlutterTestEnvironment();
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
  final Map<String, Future<void>> _pullInFlight = {};
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
      return GelanggangArenaState(
        arenaCode: normalized,
        initialAthlete: AthleteModel.empty,
        initialCategory: SeniCategory.tunggal,
        nomorPartai: '-',
        pool: '-',
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

  GelanggangArenaState getArenaState(String arenaCode) =>
      _ensureArenaState(arenaCode);
  GelanggangArenaState get currentArenaState =>
      _ensureArenaState(_activeArenaCode);

  /// Resolves a raw/partial arena code against already-known arenas in memory
  /// (matching canonical `arenaCode` or `lockedRawArenaCode`) WITHOUT creating
  /// phantom arena states with default 8 judges while the user is typing digits.
  String resolveKnownArenaCode(String rawInput) {
    final clean = rawInput.trim();
    if (clean.isEmpty) return _activeArenaCode;
    final upper = clean.toUpperCase();
    final normalized = normalizeArenaCode(clean);

    if (_arenaStates.containsKey(normalized)) {
      return normalized;
    }

    for (final entry in _arenaStates.entries) {
      final raw = entry.value.lockedRawArenaCode?.trim().toUpperCase();
      if (raw != null && raw.isNotEmpty && raw == upper) {
        return entry.key;
      }
      if (entry.key.contains('($upper)')) {
        return entry.key;
      }
    }

    return _activeArenaCode;
  }

  // Active Gelanggang Info
  String get activeArenaCode => _activeArenaCode;
  bool get isGelanggangVerified => _isGelanggangVerified;
  String? get lockedEventId => currentArenaState.lockedEventId;
  String? get lockedEventDocId => currentArenaState.lockedEventDocId;
  String? get lockedEventTitle => currentArenaState.lockedEventTitle;
  String? get lockedEventCode => currentArenaState.lockedEventCode;
  String? get lockedGelanggangId => currentArenaState.lockedGelanggangId;
  String? get lockedGelanggangDocId => currentArenaState.lockedGelanggangDocId;
  String? get lockedRawArenaCode => currentArenaState.lockedRawArenaCode;
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
  int get timerElapsedSeconds => math.max(
    0,
    currentArenaState.targetDurationSeconds -
        currentArenaState.timerRemainingSeconds,
  );

  String get formattedTimerRemaining {
    final sec = currentArenaState.timerRemainingSeconds;
    final int absSec = sec.abs();
    final int m = absSec ~/ 60;
    final int s = absSec % 60;
    final formatted =
        '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
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
  int getActiveJuriCount({String? arenaCode}) =>
      _resolveState(arenaCode).activeJuriCount;
  Map<int, Map<String, dynamic>> get juriScores =>
      Map.unmodifiable(currentArenaState.juriScores);
  List<PenaltyDeduction> get penalties =>
      List.unmodifiable(currentArenaState.penalties);
  bool get isMatchFinalized => currentArenaState.isMatchFinalized;
  double get officialFinalScore => currentArenaState.officialFinalScore;

  /// Canonical unique identity key for a participant.
  /// Strictly uses `documentId` -> `id` -> `name|kontingen`.
  /// NEVER uses `partai` (`nomor_partai`), because multiple participants in the
  /// same pool/schedule share the same `nomor_partai`.
  static String athleteIdentityKey(AthleteModel a) {
    final doc = a.documentId.trim();
    if (doc.isNotEmpty) return 'doc:$doc';
    final id = a.id.trim();
    if (id.isNotEmpty) return 'id:$id';
    final name = a.name.trim();
    if (name.isNotEmpty && name != AthleteModel.empty.name) {
      return 'name:${name.toLowerCase()}|${a.kontingen.trim().toLowerCase()}';
    }
    return '';
  }

  /// Strict identity equality check between two participants.
  /// Never matches by shared `partai` (`nomor_partai`) so other participants in
  /// the same pool never inherit active status or finalized scores.
  static bool isSameAthlete(AthleteModel a, AthleteModel b) {
    final docA = a.documentId.trim();
    final docB = b.documentId.trim();
    if (docA.isNotEmpty && docB.isNotEmpty) {
      return docA == docB;
    }
    if (docA.isNotEmpty || docB.isNotEmpty) {
      final idA = a.id.trim();
      final idB = b.id.trim();
      if (idA.isNotEmpty && idB.isNotEmpty) {
        return idA == idB;
      }
      return false;
    }
    final idA = a.id.trim();
    final idB = b.id.trim();
    if (idA.isNotEmpty && idB.isNotEmpty) {
      return idA == idB;
    }
    if (idA.isNotEmpty || idB.isNotEmpty) {
      return false;
    }
    final nameA = a.name.trim();
    final nameB = b.name.trim();
    if (nameA.isEmpty ||
        nameB.isEmpty ||
        nameA == AthleteModel.empty.name ||
        nameB == AthleteModel.empty.name) {
      return false;
    }
    return nameA.toLowerCase() == nameB.toLowerCase() &&
        a.kontingen.trim().toLowerCase() == b.kontingen.trim().toLowerCase();
  }

  /// Merges official finalized scores fetched from backend `/score-akhirs`
  /// (keyed by `doc:<documentId>` or `id:<id>`) into the arena state.
  void hydrateFinalizedScores(
    Map<String, double> scoresByIdentity, {
    String? arenaCode,
  }) {
    if (scoresByIdentity.isEmpty) return;
    final state = _resolveState(arenaCode);
    state.finalizedAthletes.addAll(scoresByIdentity);
    notifyListeners();
  }

  bool isAthleteCompleted(AthleteModel a, {String? arenaCode}) {
    return getAthleteScore(a, arenaCode: arenaCode) != null;
  }

  bool isAthleteActive(AthleteModel a, {String? arenaCode}) {
    final state = _resolveState(arenaCode);
    if (state.isMatchFinalized) return false;
    if (athleteIdentityKey(state.athlete).isEmpty) return false;
    return isSameAthlete(state.athlete, a);
  }

  double? getAthleteScore(AthleteModel a, {String? arenaCode}) {
    final finalized = _resolveState(arenaCode).finalizedAthletes;
    final doc = a.documentId.trim();
    if (doc.isNotEmpty) {
      final byDoc = finalized['doc:$doc'];
      if (byDoc != null) return byDoc;
      final id = a.id.trim();
      if (id.isNotEmpty) {
        return finalized['id:$id'];
      }
      return null;
    }
    final id = a.id.trim();
    if (id.isNotEmpty) {
      return finalized['id:$id'];
    }
    final key = athleteIdentityKey(a);
    if (key.isEmpty) return null;
    return finalized[key];
  }

  String getJuriStatus(int juriNumber, {String? arenaCode}) {
    return _resolveState(
          arenaCode,
        ).juriScores[juriNumber]?['status']?.toString() ??
        'not_ready';
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
  /// If a pull for [arenaCode] is already in flight, callers await that same
  /// in-flight request so authoritative Dewan/Timekeeper state is guaranteed
  /// to be applied before proceeding.
  Future<void> pullArenaSync(String arenaCode) {
    if (!cloudSyncEnabled) return Future.value();
    final targetArena = normalizeArenaCode(arenaCode);
    final existing = _pullInFlight[targetArena];
    if (existing != null) return existing;

    final future = _executePullArenaSync(targetArena);
    _pullInFlight[targetArena] = future;
    future.whenComplete(() {
      if (identical(_pullInFlight[targetArena], future)) {
        _pullInFlight.remove(targetArena);
      }
    });
    return future;
  }

  Future<void> _executePullArenaSync(String targetArena) async {
    try {
      final api = PusakaSeniApiService();
      final records = await api.fetchSyncRecords(targetArena);
      if (records.isNotEmpty) {
        applyRemoteSyncRecords(
          targetArena,
          records,
          serverNow: api.lastServerTime,
        );
      }
    } catch (_) {
      // Offline-resilient: continue operating locally until connection returns
    }
  }

  String _syncKey(String arenaCode, String topic) => 'sync|$arenaCode|$topic';

  void _pushSyncKey({
    required String arenaCode,
    required String topic,
    required double nilai,
    required String label,
    required Map<String, dynamic> payload,
    Duration? debounce,
  }) {
    final state = _ensureArenaState(arenaCode);
    final key = _syncKey(arenaCode, topic);
    final rev = _nextRevisionMs();
    state.keyRevisions[key] = rev;

    if (!cloudSyncEnabled) return;

    final encodedPayload = jsonEncode(payload);
    Future<void> send() async {
      final docId = await PusakaSeniApiService().upsertSyncRecord(
        syncKey: key,
        nilai: nilai,
        waktu: rev.toString(),
        keterangan: label,
        syncPayload: encodedPayload,
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

  Map<String, dynamic> _buildTimerPayload(
    GelanggangArenaState state,
    int anchorMs,
  ) {
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
    bool forceRelease = false,
  }) {
    final entry = state.juriScores[juriNumber] ?? state._defaultJuriEntry();
    final map = <String, dynamic>{
      'mk': state.matchVersion,
      'st': entry['status']?.toString() ?? 'not_ready',
      'sub': entry['submitted'] == true ? 1 : 0,
      'kb': double.parse(
        ((entry['kebenaran'] as num?)?.toDouble() ?? 9.90).toStringAsFixed(2),
      ),
      'dev': overrideDeviceId ?? (state.claimedJuriDevices[juriNumber] ?? ''),
    };
    if (forceRelease) {
      map['rel'] = 1;
    }
    if (entry['kemantapan'] != null) {
      map['km'] = double.parse(
        (entry['kemantapan'] as num).toDouble().toStringAsFixed(2),
      );
    }
    if (entry['currentJurus'] != null) {
      map['cj'] = (entry['currentJurus'] as num).toInt();
    }
    if (entry['totalJurus'] != null) {
      map['tj'] = (entry['totalJurus'] as num).toInt();
    }
    final jl = entry['jurusLabel']?.toString();
    if (jl != null && jl.isNotEmpty) {
      map['jl'] = _truncate(jl, 16);
    }
    return map;
  }

  Map<String, dynamic> _buildPenaltiesPayload(GelanggangArenaState state) {
    final total = double.parse(
      state.calculateTotalPenalties().toStringAsFixed(2),
    );
    final List<List<dynamic>> items = [];
    for (final p in state.penalties) {
      final candidate = [
        _truncate(p.id, 14),
        _truncate(p.label, 24),
        double.parse(p.deduction.toStringAsFixed(2)),
      ];
      items.add(candidate);
      final encoded = jsonEncode({
        'mk': state.matchVersion,
        't': total,
        'p': items,
        'dev': _deviceId,
      });
      if (encoded.length > 245) {
        items.removeLast();
        break;
      }
    }
    return {'mk': state.matchVersion, 't': total, 'p': items, 'dev': _deviceId};
  }

  String _juriStatusIndonesian(String status) {
    switch (status) {
      case 'ready':
        return 'Siap';
      case 'scoring':
        return 'Menilai';
      case 'submitted':
        return 'Selesai';
      case 'not_ready':
      default:
        return 'Belum Siap';
    }
  }

  void _pushJuriConfigState(String arenaCode) {
    final state = _ensureArenaState(arenaCode);
    _pushSyncKey(
      arenaCode: arenaCode,
      topic: 'juri_config',
      nilai: state.activeJuriCount.toDouble(),
      label: 'Pengaturan Jumlah Juri (${state.activeJuriCount} Juri)',
      payload: {'jc': state.activeJuriCount, 'dev': _deviceId},
    );
  }

  void _pushMatchState(String arenaCode) {
    final state = _ensureArenaState(arenaCode);
    final statusPrefix = state.isMatchFinalized
        ? 'Pengesahan Partai'
        : 'Partai Aktif';
    _pushSyncKey(
      arenaCode: arenaCode,
      topic: 'match',
      nilai: state.officialFinalScore,
      label: '$statusPrefix - ${state.athlete.name} (${state.nomorPartai})',
      payload: _buildMatchPayload(state),
    );
  }

  void _pushTimerState(String arenaCode) {
    final state = _ensureArenaState(arenaCode);
    final anchorMs = DateTime.now().millisecondsSinceEpoch;
    final int absSec = state.timerRemainingSeconds.abs();
    final String mmss =
        '${(absSec ~/ 60).toString().padLeft(2, '0')}:${(absSec % 60).toString().padLeft(2, '0')}';
    final String timeText = state.timerRemainingSeconds < 0 ? '-$mmss' : mmss;
    _pushSyncKey(
      arenaCode: arenaCode,
      topic: 'timer',
      nilai: state.timerRemainingSeconds.toDouble(),
      label:
          'Timer Pertandingan (${state.timerModeTitle} • ${state.timerStatus.toUpperCase()} $timeText)',
      payload: _buildTimerPayload(state, anchorMs),
    );
  }

  void _startTimerHeartbeat(String targetArena, GelanggangArenaState state) {
    state.timerHeartbeat?.cancel();
    if (!cloudSyncEnabled) return;
    state.timerHeartbeat = Timer.periodic(const Duration(seconds: 2), (_) {
      if (state.timerStatus == 'running' && state.isTimerAuthority) {
        _pushTimerState(targetArena);
      } else {
        state.timerHeartbeat?.cancel();
        state.timerHeartbeat = null;
      }
    });
  }

  void _stopTimerHeartbeat(GelanggangArenaState state) {
    state.timerHeartbeat?.cancel();
    state.timerHeartbeat = null;
  }

  void _pushJuriState(
    String arenaCode,
    int juriNumber, {
    String? overrideDeviceId,
    bool forceRelease = false,
    Duration? debounce,
  }) {
    final state = _ensureArenaState(arenaCode);
    final entry = state.juriScores[juriNumber] ?? state._defaultJuriEntry();
    final score = (entry['score'] as num?)?.toDouble() ?? 9.90;
    final status = entry['status']?.toString() ?? 'not_ready';
    final currentJurus = entry['currentJurus'];
    final String label;
    if (forceRelease) {
      label = 'Reset Slot Juri $juriNumber (Dewan)';
    } else if (currentJurus != null && status == 'scoring') {
      label =
          'nilai juri - Juri $juriNumber (${_juriStatusIndonesian(status)} • Jurus $currentJurus)';
    } else {
      label =
          'nilai juri - Juri $juriNumber (${_juriStatusIndonesian(status)})';
    }
    _pushSyncKey(
      arenaCode: arenaCode,
      topic: 'juri|$juriNumber',
      nilai: score,
      label: label,
      payload: _buildJuriPayload(
        state,
        juriNumber,
        overrideDeviceId: overrideDeviceId,
        forceRelease: forceRelease,
      ),
      debounce: debounce,
    );
  }

  void _pushPenaltiesState(String arenaCode) {
    final state = _ensureArenaState(arenaCode);
    final total = state.calculateTotalPenalties();
    final label = state.penalties.isEmpty
        ? 'Hukuman Dewan (Tidak Ada)'
        : 'Hukuman Dewan (Total -${total.toStringAsFixed(2)})';
    _pushSyncKey(
      arenaCode: arenaCode,
      topic: 'penalties',
      nilai: total,
      label: label,
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
  void applyRemoteSyncRecords(
    String arenaCode,
    List<Map<String, dynamic>> records, {
    DateTime? serverNow,
  }) {
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
      if (docId != null &&
          docId.isNotEmpty &&
          !state.remoteDocIds.containsKey(key)) {
        state.remoteDocIds[key] = docId;
      }
    }

    if (latestByKey.isEmpty) return;

    bool changed = false;
    String emittedAction = 'CLOUD_SYNC_UPDATED';

    // 1. Apply claims_reset first if newer (resets claims & sets all judges back to not_ready)
    final claimsResetKey = _syncKey(targetArena, 'claims_reset');
    if (latestByKey.containsKey(claimsResetKey)) {
      final rev = revByKey[claimsResetKey] ?? 0;
      if (rev > state.claimsResetRevision) {
        state.claimsResetRevision = rev;
        state.keyRevisions[claimsResetKey] = rev;
        state.clearClaimedJudges();
        state._initJuriScores();
        state.juriOngoingSessions.clear();
        emittedAction = 'JURI_CLAIMS_CLEARED';
        changed = true;
      }
    }

    // 1b. Apply dedicated Dewan activeJuriCount config if newer
    final juriConfigKey = _syncKey(targetArena, 'juri_config');
    int appliedJuriConfigRev = state.keyRevisions[juriConfigKey] ?? 0;
    if (latestByKey.containsKey(juriConfigKey)) {
      final rec = latestByKey[juriConfigKey]!;
      final rev = revByKey[juriConfigKey] ?? 0;
      if (rev > appliedJuriConfigRev) {
        final data = _decodeSyncRecordPayload(rec);
        final remoteCount =
            (data?['jc'] as num?)?.toInt() ?? (rec['nilai'] as num?)?.toInt();
        if (remoteCount != null && remoteCount >= 1 && remoteCount <= 10) {
          state.keyRevisions[juriConfigKey] = rev;
          appliedJuriConfigRev = rev;
          state.hasDewanJuriCount = true;
          if (state.activeJuriCount != remoteCount) {
            state.setActiveJuriCount(remoteCount);
            emittedAction = 'JURI_COUNT_CHANGED';
            changed = true;
          }
        }
      }
    }

    // 2. Apply match record FIRST so matchVersion is up to date for juri & penalties
    final matchKey = _syncKey(targetArena, 'match');
    if (latestByKey.containsKey(matchKey)) {
      final rec = latestByKey[matchKey]!;
      final rev = revByKey[matchKey] ?? 0;
      final localRev = state.keyRevisions[matchKey] ?? 0;
      if (rev > localRev) {
        final data = _decodeSyncRecordPayload(rec);
        if (data != null) {
          state.keyRevisions[matchKey] = rev;
          final remoteMk = data['mk']?.toString() ?? '';
          final isNewMatch =
              remoteMk.isNotEmpty && remoteMk != state.matchVersion;

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
          final remoteJuriCount =
              (data['jc'] as num?)?.toInt() ?? state.activeJuriCount;
          final remoteFinalized = data['fin'] == 1 || data['fin'] == true;
          final remoteFinalScore =
              (data['fs'] as num?)?.toDouble() ??
              (rec['nilai'] as num?)?.toDouble() ??
              0.0;

          // Respect dedicated Dewan juri_config if it is newer than match
          if (rev >= appliedJuriConfigRev) {
            state.hasDewanJuriCount = true;
            if (remoteJuriCount != state.activeJuriCount) {
              state.setActiveJuriCount(remoteJuriCount);
            }
          }

          final wasFinalized = state.isMatchFinalized;
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
            if (remoteFinalized && !wasFinalized) {
              emittedAction = 'MATCH_FINALIZED';
            }
          }

          if (remoteFinalized) {
            _recordFinalizedAthlete(state, remoteFinalScore);
          }
          changed = true;
        }
      }
    }

    // 3. Apply timer record (Timekeeper is sole authoritative source of time)
    final timerKey = _syncKey(targetArena, 'timer');
    if (latestByKey.containsKey(timerKey)) {
      final rec = latestByKey[timerKey]!;
      final rev = revByKey[timerKey] ?? 0;
      final localRev = state.keyRevisions[timerKey] ?? 0;
      if (rev > localRev) {
        final data = _decodeSyncRecordPayload(rec);
        if (data != null) {
          state.keyRevisions[timerKey] = rev;
          final remoteDev = data['dev']?.toString() ?? '';
          if (remoteDev.isNotEmpty && remoteDev != _deviceId) {
            state.isTimerAuthority = false;
            _stopTimerHeartbeat(state);
          }

          final st = data['st']?.toString() ?? 'standby';
          final rem =
              (data['rem'] as num?)?.toInt() ??
              (rec['nilai'] as num?)?.toInt() ??
              state.targetDurationSeconds;
          final dur =
              (data['dur'] as num?)?.toInt() ?? state.targetDurationSeconds;
          final mt = data['mt']?.toString() ?? state.timerModeTitle;
          final at = (data['at'] as num?)?.toInt() ?? rev;

          state.targetDurationSeconds = dur;
          state.timerModeTitle = mt;
          state.timerStatus = st;

          if (st == 'running') {
            int elapsedSec = 0;
            final updatedAtRaw = rec['updatedAt']?.toString();
            final remoteServerUpdatedAt = updatedAtRaw != null
                ? DateTime.tryParse(updatedAtRaw)?.toUtc()
                : null;
            if (serverNow != null && remoteServerUpdatedAt != null) {
              // Clock-skew-free delta using Strapi's own server clock
              elapsedSec = math.max(
                0,
                serverNow.toUtc().difference(remoteServerUpdatedAt).inSeconds,
              );
            } else {
              final nowMs = DateTime.now().millisecondsSinceEpoch;
              elapsedSec = math.max(0, ((nowMs - at) / 1000).round());
            }
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
        final data = _decodeSyncRecordPayload(rec);
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
      if (juriNum == null || juriNum < 1 || juriNum > state.activeJuriCount) {
        continue;
      }

      final rec = entry.value;
      final rev = revByKey[key] ?? 0;
      final localRev = state.keyRevisions[key] ?? 0;
      if (rev <= localRev) continue;

      final data = _decodeSyncRecordPayload(rec);
      if (data == null) continue;

      state.keyRevisions[key] = rev;

      // Apply judge device claim (if newer than claimsResetRevision)
      if (rev > state.claimsResetRevision) {
        final remoteDev = data['dev']?.toString() ?? '';
        final forceRelease = data['rel'] == 1 || data['rel'] == true;
        if (forceRelease) {
          state.claimedJuriDevices.remove(juriNum);
          state.juriScores[juriNum] = state._defaultJuriEntry();
          state.juriOngoingSessions.remove(juriNum);
          if (emittedAction == 'CLOUD_SYNC_UPDATED') {
            emittedAction = 'JURI_CLAIM_RELEASED';
          }
          changed = true;
          continue;
        } else if (remoteDev.isNotEmpty) {
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
        final remoteCurrentJurus = (data['cj'] as num?)?.toInt();
        final remoteTotalJurus = (data['tj'] as num?)?.toInt();
        final remoteJurusLabel = data['jl']?.toString();

        state.juriScores[juriNum] = {
          'score': remoteScore,
          'kebenaran': remoteKebenaran,
          'kemantapan': remoteKemantapan,
          'currentJurus': remoteCurrentJurus,
          'totalJurus': remoteTotalJurus,
          'jurusLabel': remoteJurusLabel,
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

  /// Decodes sync payload preferentially from `gerakan_ke` (clean draft sync
  /// format where `keterangan` stays human-readable), with fallback to
  /// `keterangan` for backward compatibility with legacy sync records.
  Map<String, dynamic>? _decodeSyncRecordPayload(Map<String, dynamic> rec) {
    final fromGerakan = _decodePayload(rec['gerakan_ke']?.toString());
    if (fromGerakan != null) return fromGerakan;
    return _decodePayload(rec['keterangan']?.toString());
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

  void _recordFinalizedAthlete(
    GelanggangArenaState state,
    double officialScore,
  ) {
    final doc = state.athlete.documentId.trim();
    final id = state.athlete.id.trim();
    if (doc.isNotEmpty) {
      state.finalizedAthletes['doc:$doc'] = officialScore;
      if (id.isNotEmpty) {
        state.finalizedAthletes['id:$id'] = officialScore;
      }
      return;
    }
    if (id.isNotEmpty) {
      state.finalizedAthletes['id:$id'] = officialScore;
      return;
    }
    final fallbackKey = athleteIdentityKey(state.athlete);
    if (fallbackKey.isNotEmpty) {
      state.finalizedAthletes[fallbackKey] = officialScore;
    }
  }

  // ===========================================================================
  // LOCAL ACTIONS (UPDATE LOCAL STATE INSTANTLY + PUSH TO CLOUD)
  // ===========================================================================

  /// 1. Verifikasi Gelanggang (from 8-digit code or QR Scan)
  /// Locks the verified Gelanggang & Event ID so all panels display the
  /// verified event title and fetch athletes strictly for this arena/event.
  void verifyGelanggang({
    required String arenaCode,
    String? rawArenaCode,
    String? gelanggangId,
    String? gelanggangDocId,
    String? eventId,
    String? eventDocId,
    String? eventTitle,
    String? eventCode,
    int? jumlahJuri,
  }) {
    final normalized = normalizeArenaCode(arenaCode);
    _activeArenaCode = normalized;
    _isGelanggangVerified = true;
    final state = _ensureArenaState(normalized);
    state.isVerified = true;
    if (rawArenaCode != null && rawArenaCode.trim().isNotEmpty) {
      state.lockedRawArenaCode = rawArenaCode.trim();
    }
    if (gelanggangId != null && gelanggangId.trim().isNotEmpty) {
      state.lockedGelanggangId = gelanggangId.trim();
    }
    if (gelanggangDocId != null && gelanggangDocId.trim().isNotEmpty) {
      state.lockedGelanggangDocId = gelanggangDocId.trim();
    }
    if (eventId != null && eventId.trim().isNotEmpty) {
      state.lockedEventId = eventId.trim();
    }
    if (eventDocId != null && eventDocId.trim().isNotEmpty) {
      state.lockedEventDocId = eventDocId.trim();
    }
    if (eventTitle != null && eventTitle.trim().isNotEmpty) {
      state.lockedEventTitle = eventTitle.trim();
    }
    if (eventCode != null && eventCode.trim().isNotEmpty) {
      state.lockedEventCode = eventCode.trim();
    }
    if (!state.hasDewanJuriCount &&
        jumlahJuri != null &&
        jumlahJuri >= 1 &&
        jumlahJuri <= 10) {
      state.setActiveJuriCount(jumlahJuri);
    }
    _emitSync('GELANGGANG_VERIFIED', normalized);
    unawaited(pullArenaSync(normalized));
  }

  /// Resets verification lock (useful when switching event or in tests).
  void resetVerification({String? arenaCode}) {
    _isGelanggangVerified = false;
    final state = _resolveState(arenaCode);
    state.isVerified = false;
    state.hasDewanJuriCount = false;
    state.lockedGelanggangId = null;
    state.lockedGelanggangDocId = null;
    state.lockedRawArenaCode = null;
    state.lockedEventId = null;
    state.lockedEventDocId = null;
    state.lockedEventTitle = null;
    state.lockedEventCode = null;
    _emitSync('GELANGGANG_RESET', state.arenaCode);
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
    _stopTimerHeartbeat(state);
    // Preserve Timekeeper's active mode duration unless explicitly overridden
    if (targetDuration != null) {
      state.targetDurationSeconds = targetDuration;
      if (state.targetDurationSeconds == 80) {
        state.timerModeTitle = 'Tangan Kosong (01:20)';
      } else if (state.targetDurationSeconds == 100) {
        state.timerModeTitle = 'Senjata (01:40)';
      } else {
        state.timerModeTitle = 'Standar (03:00)';
      }
    }
    state.timerRemainingSeconds = state.targetDurationSeconds;
    state.timerStatus = 'standby';
    final existingScore = getAthleteScore(athlete, arenaCode: targetArena);
    state.isMatchFinalized = existingScore != null;
    state.officialFinalScore = existingScore ?? 0.0;
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
          poolDocId: athlete.poolDocId,
          penilai: 'dewan',
          nilai: 9.90,
          keterangan:
              'Partai Dimulai oleh Dewan (${athlete.partai}) di $targetArena',
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

  /// Cek apakah slot juri sedang diklaim oleh suatu perangkat
  bool isJuriClaimed(int juriNumber, {String? arenaCode}) {
    final targetArena = normalizeArenaCode(arenaCode ?? _activeArenaCode);
    final state = _ensureArenaState(targetArena);
    final dev = state.claimedJuriDevices[juriNumber];
    return dev != null && dev.isNotEmpty;
  }

  /// Reset / buka kunci 1 slot juri tertentu oleh Dewan agar perangkat baru bisa masuk
  /// dan status juri otomatis kembali menjadi Belum Ready (`not_ready`).
  void releaseJuriClaim(int juriNumber, {String? arenaCode}) {
    final targetArena = normalizeArenaCode(arenaCode ?? _activeArenaCode);
    final state = _ensureArenaState(targetArena);
    state.claimedJuriDevices.remove(juriNumber);
    state.juriScores[juriNumber] = state._defaultJuriEntry();
    state.juriOngoingSessions.remove(juriNumber);
    _pushJuriState(
      targetArena,
      juriNumber,
      overrideDeviceId: '',
      forceRelease: true,
    );
    _emitSync('JURI_CLAIM_RELEASED', targetArena);
  }

  /// Reset semua klaim juri di arena tertentu dan kembalikan status seluruh juri
  /// secara otomatis menjadi Belum Ready (`not_ready`).
  void clearClaimedJudges({String? arenaCode}) {
    final targetArena = normalizeArenaCode(arenaCode ?? _activeArenaCode);
    final state = _ensureArenaState(targetArena);
    state.clearClaimedJudges();
    state._initJuriScores();
    state.juriOngoingSessions.clear();
    state.claimsResetRevision = _nextRevisionMs();
    _pushSyncKey(
      arenaCode: targetArena,
      topic: 'claims_reset',
      nilai: 0,
      label: 'Reset Semua Slot Juri (Dewan)',
      payload: {'dev': _deviceId},
    );
    _emitSync('JURI_CLAIMS_CLEARED', targetArena);
  }

  /// Ambil daftar nomor juri yang tersedia untuk perangkat ini
  List<int> getAvailableJudgesForThisDevice({
    String? arenaCode,
    String? customDeviceId,
  }) {
    final targetArena = normalizeArenaCode(arenaCode ?? _activeArenaCode);
    final state = _ensureArenaState(targetArena);
    final devId = customDeviceId ?? _deviceId;
    final int count = state.activeJuriCount > 0 ? state.activeJuriCount : 8;
    return List.generate(
      count,
      (i) => i + 1,
    ).where((jNum) => !state.isJuriClaimedByOther(jNum, devId)).toList();
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
  Map<String, dynamic>? getJuriOngoingSession(
    int juriNumber, {
    String? arenaCode,
  }) {
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
    int? currentJurus,
    int? totalJurus,
    String? jurusLabel,
    String? arenaCode,
  }) {
    final targetArena = normalizeArenaCode(arenaCode ?? _activeArenaCode);
    final state = _ensureArenaState(targetArena);
    final current = state.juriScores[juriNumber] ?? {};
    if (current['submitted'] == true) return;
    state.juriScores[juriNumber] = {
      ...current,
      'score': currentScore ?? current['score'] ?? 9.90,
      'currentJurus': currentJurus ?? current['currentJurus'],
      'totalJurus': totalJurus ?? current['totalJurus'],
      'jurusLabel': jurusLabel ?? current['jurusLabel'],
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
    int? currentJurus,
    int? totalJurus,
    String? jurusLabel,
    String? arenaCode,
  }) {
    final targetArena = normalizeArenaCode(arenaCode ?? _activeArenaCode);
    final state = _ensureArenaState(targetArena);
    final current = state.juriScores[juriNumber] ?? {};
    state.juriScores[juriNumber] = {
      'score': score,
      'kebenaran': kebenaran ?? score,
      'kemantapan': kemantapan,
      'currentJurus': currentJurus ?? current['currentJurus'],
      'totalJurus': totalJurus ?? current['totalJurus'],
      'jurusLabel': jurusLabel ?? current['jurusLabel'],
      'isReady': true,
      'status': 'submitted',
      'submitted': true,
      'updatedAt': DateTime.now().toIso8601String(),
    };
    _pushJuriState(targetArena, juriNumber);
    if (cloudSyncEnabled && state.athlete.documentId.isNotEmpty) {
      final keterangan = kemantapan != null
          ? 'Nilai Akhir Baku (Kebenaran: ${(kebenaran ?? score).toStringAsFixed(2)}, Kemantapan: +${kemantapan.toStringAsFixed(2)})'
          : 'Nilai Akhir Juri $juriNumber';
      unawaited(
        PusakaSeniApiService().postScore(
          athleteDocId: state.athlete.documentId,
          poolDocId: state.athlete.poolDocId,
          penilai: 'juri $juriNumber',
          nilai: score,
          keterangan: keterangan,
        ),
      );
    }
    _emitSync('JURI_SCORE_UPDATED', targetArena);
  }

  /// Start / Resume Live Timer (ticks continuously across app until stopped by Timekeeper)
  void timekeeperStartTimer({String? arenaCode}) {
    final targetArena = normalizeArenaCode(arenaCode ?? _activeArenaCode);
    final state = _ensureArenaState(targetArena);
    state.isTimerAuthority = true;
    state.timerStatus = 'running';

    _startLocalDisplayTimer(targetArena, state);
    _startTimerHeartbeat(targetArena, state);
    _pushTimerState(targetArena);
    _emitSync('TIMEKEEPER_TIMER_SYNC', targetArena);
  }

  /// Pause Live Timer
  void timekeeperPauseTimer({String? arenaCode}) {
    final targetArena = normalizeArenaCode(arenaCode ?? _activeArenaCode);
    final state = _ensureArenaState(targetArena);
    state.isTimerAuthority = true;
    state.activeTimer?.cancel();
    state.activeTimer = null;
    _stopTimerHeartbeat(state);
    state.timerStatus = 'paused';
    _pushTimerState(targetArena);
    _emitSync('TIMEKEEPER_TIMER_SYNC', targetArena);
  }

  /// Stop Live Timer
  void timekeeperStopTimer({String? arenaCode}) {
    final targetArena = normalizeArenaCode(arenaCode ?? _activeArenaCode);
    final state = _ensureArenaState(targetArena);
    state.isTimerAuthority = true;
    state.activeTimer?.cancel();
    state.activeTimer = null;
    _stopTimerHeartbeat(state);
    state.timerStatus = 'stopped';
    _pushTimerState(targetArena);
    _emitSync('TIMEKEEPER_TIMER_SYNC', targetArena);
  }

  /// Reset Live Timer
  void timekeeperResetTimer({String? arenaCode}) {
    final targetArena = normalizeArenaCode(arenaCode ?? _activeArenaCode);
    final state = _ensureArenaState(targetArena);
    state.isTimerAuthority = true;
    state.activeTimer?.cancel();
    state.activeTimer = null;
    _stopTimerHeartbeat(state);
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
    state.isTimerAuthority = true;
    state.activeTimer?.cancel();
    state.activeTimer = null;
    _stopTimerHeartbeat(state);
    state.targetDurationSeconds = durationSeconds;
    state.timerRemainingSeconds = durationSeconds;
    state.timerModeTitle = modeTitle;
    state.timerStatus = 'standby';
    _pushTimerState(targetArena);
    _emitSync('TIMEKEEPER_TIMER_SYNC', targetArena);
  }

  /// Timekeeper sinkronisasi timer ke Dewan, Juri & Scoreboard
  void timekeeperSyncTimer({
    required int remainingSeconds,
    required String status,
    int? targetDurationSeconds,
    String? modeTitle,
    String? arenaCode,
  }) {
    final targetArena = normalizeArenaCode(arenaCode ?? _activeArenaCode);
    final state = _ensureArenaState(targetArena);
    state.isTimerAuthority = true;
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
      _startTimerHeartbeat(targetArena, state);
    } else {
      state.activeTimer?.cancel();
      state.activeTimer = null;
      _stopTimerHeartbeat(state);
    }
    _pushTimerState(targetArena);
    _emitSync('TIMEKEEPER_TIMER_SYNC', targetArena);
  }

  /// 6. Dewan input hukuman
  void dewanAddPenalty(PenaltyDeduction penalty, {String? arenaCode}) {
    final targetArena = normalizeArenaCode(arenaCode ?? _activeArenaCode);
    final state = _ensureArenaState(targetArena);
    state.penalties.add(penalty);
    _pushPenaltiesState(targetArena);
    if (cloudSyncEnabled && state.athlete.documentId.isNotEmpty) {
      unawaited(
        PusakaSeniApiService().postScore(
          athleteDocId: state.athlete.documentId,
          poolDocId: state.athlete.poolDocId,
          penilai: 'dewan',
          nilai: -penalty.deduction,
          keterangan: 'Hukuman Dewan: ${penalty.label}',
        ),
      );
    }
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
  /// Dewan adalah otoritas utama; semua perangkat (Juri, Timekeeper, Monitoring) sinkron ke sini.
  void setActiveJuriCount(int count, {String? arenaCode}) {
    final targetArena = normalizeArenaCode(arenaCode ?? _activeArenaCode);
    final state = _ensureArenaState(targetArena);
    state.hasDewanJuriCount = true;
    state.setActiveJuriCount(count);
    _pushJuriConfigState(targetArena);
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
    if (cloudSyncEnabled && state.athlete.documentId.isNotEmpty) {
      final nilaiJuriMap = <String, double>{};
      for (int i = 1; i <= state.activeJuriCount; i++) {
        final s = (state.juriScores[i]?['score'] as num?)?.toDouble() ?? 9.90;
        nilaiJuriMap['juri $i'] = double.parse(s.toStringAsFixed(2));
      }
      final int elapsed = math.max(
        0,
        state.targetDurationSeconds - state.timerRemainingSeconds,
      );
      final String akurasiWaktu =
          '${(elapsed ~/ 60).toString().padLeft(2, '0')}:${(elapsed % 60).toString().padLeft(2, '0')}';
      unawaited(
        PusakaSeniApiService().postScoreAkhir(
          athleteDocId: state.athlete.documentId,
          poolDocId: state.athlete.poolDocId,
          nilaiJuri: nilaiJuriMap,
          standarDeviasi: state.calculateStandardDeviation(),
          akumulasi: officialScore,
          akurasiWaktu: akurasiWaktu,
        ),
      );
    }
    _emitSync('MATCH_FINALIZED', targetArena);
  }
}
