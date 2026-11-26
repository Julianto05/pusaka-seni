import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import '../models/scoring_models.dart';
import 'pusaka_seni_api_service.dart';

/// Isolated state for a specific Gelanggang / Arena.
/// Ensures that Gelanggang A, Gelanggang B, and any other arena
/// maintain strictly independent athletes, scoring, penalties, and timers.
class GelanggangArenaState {
  final String arenaCode;

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

  void claimJuri(int juriNumber, String deviceId) {
    claimedJuriDevices.removeWhere((_, dev) => dev == deviceId);
    claimedJuriDevices[juriNumber] = deviceId;
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
/// Supports full isolation per Gelanggang (Arena Code), so multiple
/// arenas run completely independently without score or timer crosstalk.
class GelanggangSyncService extends ChangeNotifier {
  static final GelanggangSyncService _instance = GelanggangSyncService._internal();
  static GelanggangSyncService get instance => _instance;

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

  // Registry of isolated arena states keyed by normalized arena code
  final Map<String, GelanggangArenaState> _arenaStates = {};

  String _activeArenaCode = 'GELANGGANG A';
  bool _isGelanggangVerified = false;

  int _selectedJuriNumber = 1; // Locked juri assigned to this mobile device
  late final String _deviceId =
      'DEV_${DateTime.now().microsecondsSinceEpoch}_${math.Random().nextInt(99999)}';

  String? _lastSyncAction;
  String? _lastSyncArenaCode;

  GelanggangSyncService._internal() {
    _ensureArenaState('GELANGGANG A');
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

  /// 1. Verifikasi Gelanggang (from 8-digit code or QR Scan)
  void verifyGelanggang({required String arenaCode}) {
    final normalized = normalizeArenaCode(arenaCode);
    _activeArenaCode = normalized;
    _isGelanggangVerified = true;
    _ensureArenaState(normalized);
    _emitSync('GELANGGANG_VERIFIED', normalized);
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

    state.athlete = athlete;
    state.category = category;
    state.nomorPartai = nomorPartai ?? athlete.partai;
    state.pool = pool ?? athlete.pool;
    state.activeTimer?.cancel();
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

    // Post match announcement to server
    try {
      if (athlete.documentId.isNotEmpty) {
        PusakaSeniApiService().postScore(
          athleteDocId: athlete.documentId,
          penilai: 'dewan',
          nilai: 9.90,
          keterangan: 'Partai Dimulai oleh Dewan (${athlete.partai}) di $targetArena',
        );
      }
    } catch (_) {}

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
    state.claimJuri(juriNumber, customDeviceId ?? _deviceId);
    _emitSync('JURI_CLAIMED', targetArena);
  }

  /// Reset semua klaim juri di arena tertentu
  void clearClaimedJudges({String? arenaCode}) {
    final targetArena = normalizeArenaCode(arenaCode ?? _activeArenaCode);
    _ensureArenaState(targetArena).clearClaimedJudges();
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
    _emitSync('JURI_SCORE_UPDATED', targetArena);
  }

  /// Start / Resume Live Timer (ticks continuously across app until stopped by Timekeeper)
  void timekeeperStartTimer({String? arenaCode}) {
    final targetArena = normalizeArenaCode(arenaCode ?? _activeArenaCode);
    final state = _ensureArenaState(targetArena);
    state.timerStatus = 'running';

    state.activeTimer?.cancel();
    state.activeTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      state.timerRemainingSeconds--;
      _emitSync('TIMEKEEPER_TIMER_SYNC', targetArena);
    });

    _emitSync('TIMEKEEPER_TIMER_SYNC', targetArena);
  }

  /// Pause Live Timer
  void timekeeperPauseTimer({String? arenaCode}) {
    final targetArena = normalizeArenaCode(arenaCode ?? _activeArenaCode);
    final state = _ensureArenaState(targetArena);
    state.activeTimer?.cancel();
    state.activeTimer = null;
    state.timerStatus = 'paused';
    _emitSync('TIMEKEEPER_TIMER_SYNC', targetArena);
  }

  /// Stop Live Timer
  void timekeeperStopTimer({String? arenaCode}) {
    final targetArena = normalizeArenaCode(arenaCode ?? _activeArenaCode);
    final state = _ensureArenaState(targetArena);
    state.activeTimer?.cancel();
    state.activeTimer = null;
    state.timerStatus = 'stopped';
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
    _emitSync('TIMEKEEPER_TIMER_SYNC', targetArena);
  }

  /// 6. Dewan input hukuman
  void dewanAddPenalty(PenaltyDeduction penalty, {String? arenaCode}) {
    final targetArena = normalizeArenaCode(arenaCode ?? _activeArenaCode);
    _ensureArenaState(targetArena).penalties.add(penalty);
    _emitSync('DEWAN_PENALTY_ADDED', targetArena);
  }

  /// 7. Dewan membatalkan hukuman
  void dewanRemovePenalty(int index, {String? arenaCode}) {
    final targetArena = normalizeArenaCode(arenaCode ?? _activeArenaCode);
    final state = _ensureArenaState(targetArena);
    if (index >= 0 && index < state.penalties.length) {
      state.penalties.removeAt(index);
      _emitSync('DEWAN_PENALTY_REMOVED', targetArena);
    }
  }

  /// 8. Dewan mengatur jumlah juri yang bertugas (3, 4, 5, 8, atau 10)
  void setActiveJuriCount(int count, {String? arenaCode}) {
    final targetArena = normalizeArenaCode(arenaCode ?? _activeArenaCode);
    _ensureArenaState(targetArena).setActiveJuriCount(count);
    _emitSync('JURI_COUNT_CHANGED', targetArena);
  }

  /// 9. Dewan mengesahkan nilai partai secara resmi
  void dewanFinalizeMatch(double officialScore, {String? arenaCode}) {
    final targetArena = normalizeArenaCode(arenaCode ?? _activeArenaCode);
    final state = _ensureArenaState(targetArena);
    state.isMatchFinalized = true;
    state.officialFinalScore = officialScore;
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
    _emitSync('MATCH_FINALIZED', targetArena);
  }
}
