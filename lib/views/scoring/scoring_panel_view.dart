import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/scoring_models.dart';
import '../../services/gelanggang_sync_service.dart';
import 'components/modals/portrait_advisory_banner.dart';
import 'components/scoring_baku_widget.dart';
import 'components/scoring_ganda_widget.dart';
import 'components/scoring_header.dart';

class ScoringPanelView extends StatefulWidget {
  final VoidCallback? onBackToPortal;
  final String? arenaCode;

  const ScoringPanelView({super.key, this.onBackToPortal, this.arenaCode});

  @override
  State<ScoringPanelView> createState() => _ScoringPanelViewState();
}

class _ScoringPanelViewState extends State<ScoringPanelView> {
  // Arena & Juri Session
  late String _arenaCode;
  int _juriNumber = 1;
  bool _isFullScreen = false;
  bool _dismissPortraitAdvisory = false;

  // Active Category & Athlete
  late SeniCategory _category;
  late AthleteModel _athlete;

  // Baku State (Tunggal & Beregu)
  late List<JurusModel> _jurusList;
  int _currentJurusIndex = 0;
  late List<int> _mistakesPerJurus;
  bool _hasRecordedBakuAction = false;
  double? _scoreKemantapan;
  bool _isCompleted = false;

  // Ganda & Solo Kreatif State
  double? _attackDefense;
  double? _firmnessHarmony;
  double? _soulfulness;
  bool _isReadyPopupShowing = false;
  bool _isSummaryPopupShowing = false;
  bool _isScoreSubmitted = false;
  Map<String, dynamic>? _lastSubmittedData;

  @override
  void initState() {
    super.initState();
    final sync = GelanggangSyncService.instance;
    _arenaCode = widget.arenaCode ?? sync.activeArenaCode;
    _juriNumber = sync.selectedJuriNumber;
    sync.claimJuri(_juriNumber, arenaCode: _arenaCode);
    final state = sync.getArenaState(_arenaCode);
    _athlete = state.athlete;
    _category = state.category;
    sync.addListener(_handleGelanggangSync);

    final String matchKey =
        '${_athlete.id}_${_athlete.partai}_${_category.name}';
    final saved = sync.getJuriOngoingSession(
      _juriNumber,
      arenaCode: _arenaCode,
    );
    if (saved != null && saved['matchKey'] == matchKey) {
      _restoreOngoingSession(saved);
    } else {
      _initCategoryState();
    }

    // Tampilkan popup ready saat pertama kali masuk penilaian juri jika belum ready dan belum dinilai
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted &&
          !sync.isJuriReady(_juriNumber, arenaCode: _arenaCode) &&
          !_isCompleted &&
          !_isScoreSubmitted) {
        _showJuriReadyPopup();
      }
    });
  }

  @override
  void dispose() {
    GelanggangSyncService.instance.removeListener(_handleGelanggangSync);
    super.dispose();
  }

  void _handleGelanggangSync() {
    final sync = GelanggangSyncService.instance;
    if (sync.lastSyncArenaCode != null &&
        sync.lastSyncArenaCode !=
            GelanggangSyncService.normalizeArenaCode(_arenaCode)) {
      return;
    }
    final state = sync.getArenaState(_arenaCode);
    if (_juriNumber > state.activeJuriCount) {
      if (mounted) {
        setState(() {
          _juriNumber = state.activeJuriCount;
        });
      }
    }
    if (sync.lastSyncAction == 'ATHLETE_SELECTED') {
      if (mounted) {
        // Tutup popup ringkasan skor atau ready popup yang sedang terbuka
        if ((_isReadyPopupShowing || _isSummaryPopupShowing) &&
            Navigator.of(context).canPop()) {
          Navigator.of(context, rootNavigator: true).pop();
        }
        _isReadyPopupShowing = false;
        _isSummaryPopupShowing = false;

        setState(() {
          _athlete = state.athlete;
          _category = state.category;
          _isScoreSubmitted = false;
          _lastSubmittedData = null;
          _initCategoryState();
        });

        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            _showJuriReadyPopup();
          }
        });

        ScaffoldMessenger.of(context).removeCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.sync_rounded, color: Colors.white, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Dewan memilih partai: ${_athlete.name} (${_athlete.partai} - ${_category.title})',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            backgroundColor: const Color(0xFFDC2626),
            duration: const Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } else {
      // Periksa sinkronisasi perubahan mode timer dari Timekeeper
      if (_category == SeniCategory.tunggal && !_isScoreSubmitted) {
        final expectedJurusList = JurusModel.getTunggalJurusForMode(
          modeTitle: state.timerModeTitle,
          targetDurationSeconds: state.targetDurationSeconds,
        );
        final bool modeDiffers =
            expectedJurusList.length != _jurusList.length ||
            (expectedJurusList.isNotEmpty &&
                _jurusList.isNotEmpty &&
                expectedJurusList.first.weaponGroup !=
                    _jurusList.first.weaponGroup);
        if (modeDiffers &&
            (!_hasRecordedBakuAction || state.timerStatus == 'standby')) {
          _jurusList = expectedJurusList;
          _mistakesPerJurus = List.filled(_jurusList.length, 0);
          _currentJurusIndex = 0;
          _hasRecordedBakuAction = false;
          _scoreKemantapan = null;
          _isCompleted = false;
          _saveOngoingSession();
        }
      }
      if (mounted) setState(() {});
    }
  }

  void _showJuriReadyPopup() {
    if (!mounted || _isReadyPopupShowing) return;
    _isReadyPopupShowing = true;

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (dialogCtx, setDialogState) {
            final currentSync = GelanggangSyncService.instance;
            final isReady = currentSync.isJuriReady(
              _juriNumber,
              arenaCode: _arenaCode,
            );
            final status = currentSync.getJuriStatus(
              _juriNumber,
              arenaCode: _arenaCode,
            );

            return AlertDialog(
              backgroundColor: const Color(0xFF0F172A),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(
                  color: isReady
                      ? const Color(0xFF10B981).withValues(alpha: 0.6)
                      : const Color(0xFFDC2626).withValues(alpha: 0.6),
                  width: 1.5,
                ),
              ),
              contentPadding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
              content: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Top Icon & Title
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: isReady
                                  ? const Color(0xFF064E3B)
                                  : const Color(0xFF450A0A),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: isReady
                                    ? const Color(0xFF10B981)
                                    : const Color(0xFFDC2626),
                              ),
                            ),
                            child: Icon(
                              isReady
                                  ? Icons.check_circle_rounded
                                  : Icons.sports_kabaddi_rounded,
                              color: isReady
                                  ? const Color(0xFF6EE7B7)
                                  : const Color(0xFFFCA5A5),
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'KESIAPAN JURI $_juriNumber',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w900,
                                    color: Colors.white,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'GELANGGANG $_arenaCode • JURI $_juriNumber',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF94A3B8),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Athlete & Match Card
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E293B),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFF334155)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Wrap(
                              spacing: 6,
                              runSpacing: 4,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFDC2626),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    'PARTAI ${_athlete.partai}',
                                    style: const TextStyle(
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w900,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF334155),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    _category.title.toUpperCase(),
                                    style: const TextStyle(
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF38BDF8),
                                    ),
                                  ),
                                ),
                                if (_athlete.pool.isNotEmpty)
                                  Text(
                                    'POOL ${_athlete.pool.toUpperCase()}',
                                    style: const TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF94A3B8),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _athlete.name,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _athlete.kontingen,
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFFCBD5E1),
                              ),
                            ),
                            if (_category == SeniCategory.tunggal) ...[
                              const SizedBox(height: 10),
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF0F172A),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: const Color(0xFF334155),
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.format_list_numbered_rounded,
                                          color: Color(0xFF38BDF8),
                                          size: 14,
                                        ),
                                        SizedBox(width: 6),
                                        Expanded(
                                          child: Text(
                                            _bakuModeDescription,
                                            style: const TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                              color: Color(0xFFE2E8F0),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Wrap(
                                      spacing: 4,
                                      runSpacing: 4,
                                      children: _buildBakuWeaponChips(),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Status Pill
                      Wrap(
                        alignment: WrapAlignment.center,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          const Text(
                            'Status Juri: ',
                            style: TextStyle(
                              fontSize: 12,
                              color: Color(0xFF94A3B8),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: isReady
                                  ? const Color(0xFF064E3B)
                                  : const Color(0xFF450A0A),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: isReady
                                    ? const Color(0xFF10B981)
                                    : const Color(0xFFDC2626),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    color: isReady
                                        ? const Color(0xFF10B981)
                                        : const Color(0xFFDC2626),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  isReady
                                      ? (status == 'scoring'
                                            ? 'SEDANG MENILAI'
                                            : (status == 'submitted'
                                                  ? 'SUDAH MENILAI'
                                                  : 'SIAP MENILAI (READY)'))
                                      : 'BELUM READY',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: isReady
                                        ? const Color(0xFF6EE7B7)
                                        : const Color(0xFFFCA5A5),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Button Action
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            GelanggangSyncService.instance.juriSetReady(
                              juriNumber: _juriNumber,
                              isReady: true,
                              arenaCode: _arenaCode,
                            );
                            setDialogState(() {});
                            if (mounted) setState(() {});
                            Navigator.of(ctx).pop();
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Row(
                                  children: [
                                    const Icon(
                                      Icons.check_circle_rounded,
                                      color: Colors.white,
                                      size: 16,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Juri $_juriNumber SIAP Menilai Partai ${_athlete.partai}!',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                                backgroundColor: const Color(0xFF10B981),
                                duration: const Duration(seconds: 2),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF10B981),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 4,
                          ),
                          icon: const Icon(
                            Icons.check_circle_rounded,
                            size: 20,
                          ),
                          label: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              isReady
                                  ? 'SUDAH SIAP (KLIK ULANG UNTUK MEMASTIKAN)'
                                  : 'SAYA SIAP MENILAI (READY)',
                              style: const TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: () => Navigator.of(ctx).pop(),
                        child: const Text(
                          'Tutup / Konfirmasi Nanti',
                          style: TextStyle(
                            fontSize: 11.5,
                            color: Color(0xFF94A3B8),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    ).then((_) {
      _isReadyPopupShowing = false;
    });
  }

  String get _bakuModeDescription {
    final int totalGerakan = _jurusList.fold(
      0,
      (sum, j) => sum + j.totalGerakan,
    );
    final isTK = _jurusList.every(
      (j) => j.weaponGroup.toLowerCase().contains('tangan'),
    );
    final isSenjata = _jurusList.every(
      (j) => !j.weaponGroup.toLowerCase().contains('tangan'),
    );
    if (isTK) {
      return 'Tangan Kosong ${_jurusList.length} Jurus • Total $totalGerakan Gerakan';
    } else if (isSenjata) {
      return 'Senjata ${_jurusList.length} Jurus • Total $totalGerakan Gerakan';
    } else {
      return 'Standar ${_jurusList.length} Jurus • Total $totalGerakan Gerakan';
    }
  }

  List<Widget> _buildBakuWeaponChips() {
    final groups = <String, int>{};
    for (final j in _jurusList) {
      groups[j.weaponGroup] = (groups[j.weaponGroup] ?? 0) + j.totalGerakan;
    }
    return groups.entries.map((entry) {
      Color c = const Color(0xFF38BDF8);
      final l = entry.key.toLowerCase();
      if (l.contains('tangan')) {
        c = const Color(0xFFF59E0B);
      } else if (l.contains('golok')) {
        c = const Color(0xFF3B82F6);
      } else if (l.contains('toya')) {
        c = const Color(0xFFA855F7);
      }

      final jurusInGroup = _jurusList
          .where((j) => j.weaponGroup == entry.key)
          .toList();
      final String rangeStr = jurusInGroup.length > 1
          ? 'Jurus ${jurusInGroup.first.jurusNumber}-${jurusInGroup.last.jurusNumber}'
          : 'Jurus ${jurusInGroup.first.jurusNumber}';

      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: c.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: c.withValues(alpha: 0.4)),
        ),
        child: Text(
          '${entry.key}: $rangeStr (${entry.value} grk)',
          style: TextStyle(
            fontSize: 9.5,
            color: c,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }).toList();
  }

  void _restoreOngoingSession(Map<String, dynamic> saved) {
    final state = GelanggangSyncService.instance.getArenaState(_arenaCode);
    if (_category == SeniCategory.beregu) {
      _jurusList = JurusModel.getBereguJurus();
    } else {
      final savedTitle = saved['timerModeTitle'] as String?;
      final savedDuration = saved['targetDurationSeconds'] as int?;
      _jurusList = JurusModel.getTunggalJurusForMode(
        modeTitle: savedTitle ?? state.timerModeTitle,
        targetDurationSeconds: savedDuration ?? state.targetDurationSeconds,
      );
    }
    _currentJurusIndex =
        (saved['currentJurusIndex'] as int?)?.clamp(0, _jurusList.length - 1) ??
        0;
    if (saved['mistakesPerJurus'] != null) {
      _mistakesPerJurus = List<int>.from(saved['mistakesPerJurus'] as List);
      if (_mistakesPerJurus.length != _jurusList.length) {
        _mistakesPerJurus = List.filled(_jurusList.length, 0);
      }
    } else {
      _mistakesPerJurus = List.filled(_jurusList.length, 0);
    }
    _hasRecordedBakuAction =
        _currentJurusIndex > 0 || _mistakesPerJurus.any((m) => m > 0);
    _scoreKemantapan = saved['scoreKemantapan'] as double?;
    _isCompleted = saved['isCompleted'] as bool? ?? false;

    _attackDefense = saved['attackDefense'] as double?;
    _firmnessHarmony = saved['firmnessHarmony'] as double?;
    _soulfulness = saved['soulfulness'] as double?;

    _isScoreSubmitted = saved['isScoreSubmitted'] as bool? ?? false;
    if (saved['lastSubmittedData'] != null) {
      _lastSubmittedData = Map<String, dynamic>.from(
        saved['lastSubmittedData'] as Map,
      );
    }
  }

  void _saveOngoingSession() {
    final sync = GelanggangSyncService.instance;
    final state = sync.getArenaState(_arenaCode);
    final matchKey = '${_athlete.id}_${_athlete.partai}_${_category.name}';
    sync.saveJuriOngoingSession(
      juriNumber: _juriNumber,
      arenaCode: _arenaCode,
      sessionData: {
        'matchKey': matchKey,
        'timerModeTitle': state.timerModeTitle,
        'targetDurationSeconds': state.targetDurationSeconds,
        'currentJurusIndex': _currentJurusIndex,
        'mistakesPerJurus': List<int>.from(_mistakesPerJurus),
        'scoreKemantapan': _scoreKemantapan,
        'isCompleted': _isCompleted,
        'attackDefense': _attackDefense,
        'firmnessHarmony': _firmnessHarmony,
        'soulfulness': _soulfulness,
        'isScoreSubmitted': _isScoreSubmitted,
        'lastSubmittedData': _lastSubmittedData,
      },
    );
  }

  void _initCategoryState() {
    final state = GelanggangSyncService.instance.getArenaState(_arenaCode);
    if (_category == SeniCategory.beregu) {
      _jurusList = JurusModel.getBereguJurus();
      _mistakesPerJurus = List.filled(12, 0);
    } else {
      _jurusList = JurusModel.getTunggalJurusForMode(
        modeTitle: state.timerModeTitle,
        targetDurationSeconds: state.targetDurationSeconds,
      );
      _mistakesPerJurus = List.filled(_jurusList.length, 0);
    }
    _currentJurusIndex = 0;
    _hasRecordedBakuAction = false;
    _scoreKemantapan = null;
    _isCompleted = false;

    _attackDefense = null;
    _firmnessHarmony = null;
    _soulfulness = null;

    _saveOngoingSession();
  }

  void _handleBackToPortal() {
    _saveOngoingSession();
    if (widget.onBackToPortal != null) {
      widget.onBackToPortal!();
    } else {
      Navigator.of(context).maybePop();
    }
  }

  void _toggleFullScreen() {
    setState(() => _isFullScreen = !_isFullScreen);
    if (_isFullScreen) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    } else {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }
  }

  // --- SCORING GUARDS ---
  bool _ensureJuriReady() {
    if (!GelanggangSyncService.instance.isJuriReady(
      _juriNumber,
      arenaCode: _arenaCode,
    )) {
      _showJuriReadyPopup();
      return false;
    }
    return true;
  }

  // --- BAKU ACTIONS (NO VIBRATION) ---

  void _notifyScoringInProgress() {
    final sync = GelanggangSyncService.instance;
    final currentStatus = sync.getJuriStatus(
      _juriNumber,
      arenaCode: _arenaCode,
    );
    if (currentStatus != 'submitted') {
      sync.juriStartScoring(
        juriNumber: _juriNumber,
        currentScore: _calculateCurrentScore(),
        arenaCode: _arenaCode,
      );
    }
  }

  void _handleWrongAction() {
    if (!_ensureJuriReady()) return;
    if (_isCompleted) return;
    setState(() {
      _mistakesPerJurus[_currentJurusIndex]++;
      _hasRecordedBakuAction = true;
    });
    _notifyScoringInProgress();
    _saveOngoingSession();
  }

  void _handleNextAction() {
    if (!_ensureJuriReady()) return;
    if (_isCompleted) return;
    setState(() {
      _hasRecordedBakuAction = true;
      if (_currentJurusIndex < _jurusList.length - 1) {
        _currentJurusIndex++;
      } else {
        _isCompleted = true;
      }
    });
    _notifyScoringInProgress();
    _saveOngoingSession();
  }

  void _handleResetBaku() {
    if (!_ensureJuriReady()) return;
    setState(() {
      _currentJurusIndex = 0;
      _mistakesPerJurus = List.filled(_jurusList.length, 0);
      _hasRecordedBakuAction = false;
      _scoreKemantapan = null;
      _isCompleted = false;
    });
    _saveOngoingSession();
  }

  void _handleSelectKemantapan(double val) {
    if (!_ensureJuriReady()) return;
    setState(() {
      _scoreKemantapan = val;
    });

    final int totalMistakes = _mistakesPerJurus.fold(0, (sum, m) => sum + m);
    final double kebenaran = (9.90 - (totalMistakes * 0.01)).clamp(0.0, 9.90);
    final double total = kebenaran + val;
    GelanggangSyncService.instance.juriStartScoring(
      juriNumber: _juriNumber,
      currentScore: total,
      arenaCode: _arenaCode,
    );
    _saveOngoingSession();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Kemantapan +${val.toStringAsFixed(2)} berhasil dipilih untuk Juri $_juriNumber!',
        ),
        backgroundColor: const Color(0xFF0284C7),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _handleSubmitFinalBaku() {
    if (!_ensureJuriReady()) return;
    if (_isScoreSubmitted) {
      if (_lastSubmittedData != null) {
        _showSubmittedScorePopup(
          totalScore: _lastSubmittedData!['total'] ?? 0.0,
          kebenaran: _lastSubmittedData!['kebenaran'],
          kemantapan: _lastSubmittedData!['kemantapan'],
          mistakes: _lastSubmittedData!['mistakes'],
        );
      }
      return;
    }

    if (_scoreKemantapan == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Harap tentukan nilai kemantapan terlebih dahulu.'),
          backgroundColor: Color(0xFFDC2626),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final int totalMistakes = _mistakesPerJurus.fold(0, (sum, m) => sum + m);
    final double kebenaran = (9.90 - (totalMistakes * 0.01)).clamp(0.0, 9.90);
    final double totalFinal = kebenaran + (_scoreKemantapan ?? 0.0);

    setState(() {
      _isScoreSubmitted = true;
      _lastSubmittedData = {
        'total': totalFinal,
        'kebenaran': kebenaran,
        'kemantapan': _scoreKemantapan,
        'mistakes': totalMistakes,
      };
    });
    _saveOngoingSession();

    GelanggangSyncService.instance.juriSubmitScore(
      juriNumber: _juriNumber,
      score: totalFinal,
      kebenaran: kebenaran,
      kemantapan: _scoreKemantapan,
      arenaCode: _arenaCode,
    );

    _showSubmittedScorePopup(
      totalScore: totalFinal,
      kebenaran: kebenaran,
      kemantapan: _scoreKemantapan,
      mistakes: totalMistakes,
    );
  }

  // --- GANDA ACTIONS (NO VIBRATION) ---

  void _handleResetGanda() {
    if (!_ensureJuriReady()) return;
    if (_isScoreSubmitted) return;
    setState(() {
      _attackDefense = null;
      _firmnessHarmony = null;
      _soulfulness = null;
    });
    _saveOngoingSession();
  }

  void _handleSubmitGanda() {
    if (!_ensureJuriReady()) return;
    if (_isScoreSubmitted) {
      if (_lastSubmittedData != null) {
        _showSubmittedScorePopup(
          totalScore: _lastSubmittedData!['total'] ?? 0.0,
          attackDefense: _lastSubmittedData!['attackDefense'],
          firmnessHarmony: _lastSubmittedData!['firmnessHarmony'],
          soulfulness: _lastSubmittedData!['soulfulness'],
        );
      }
      return;
    }

    final double totalPenalty =
        (_attackDefense ?? 0.0) +
        (_firmnessHarmony ?? 0.0) +
        (_soulfulness ?? 0.0);
    final double total = (ScoringGandaWidget.baseScore - totalPenalty)
        .clamp(0.0, ScoringGandaWidget.baseScore);

    setState(() {
      _isScoreSubmitted = true;
      _lastSubmittedData = {
        'total': total,
        'totalPenalty': totalPenalty,
        'attackDefense': _attackDefense,
        'firmnessHarmony': _firmnessHarmony,
        'soulfulness': _soulfulness,
      };
    });
    _saveOngoingSession();

    GelanggangSyncService.instance.juriSubmitScore(
      juriNumber: _juriNumber,
      score: total,
      arenaCode: _arenaCode,
    );

    _showSubmittedScorePopup(
      totalScore: total,
      attackDefense: _attackDefense,
      firmnessHarmony: _firmnessHarmony,
      soulfulness: _soulfulness,
    );
  }

  void _showSubmittedScorePopup({
    required double totalScore,
    double? kebenaran,
    double? kemantapan,
    int? mistakes,
    double? attackDefense,
    double? firmnessHarmony,
    double? soulfulness,
  }) {
    if (!mounted) return;
    _isSummaryPopupShowing = true;

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: const Color(0xFF0F172A),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: Color(0xFF10B981), width: 1.5),
          ),
          contentPadding: const EdgeInsets.all(20),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Top Success Icon
                  Container(
                    width: 54,
                    height: 54,
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: const Color(0xFF10B981),
                        width: 2,
                      ),
                    ),
                    child: const Icon(
                      Icons.check_circle_rounded,
                      color: Color(0xFF10B981),
                      size: 32,
                    ),
                  ),
                  const SizedBox(height: 12),

                  Text(
                    'NILAI JURI $_juriNumber BERHASIL DISINKRONKAN',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.6,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${_athlete.partai} • ${_category.title.toUpperCase()}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF38BDF8),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Athlete info card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E293B),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFF334155)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _athlete.name.toUpperCase(),
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${_athlete.kontingen} • ${_athlete.pool}',
                          style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFF94A3B8),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Score detail cards
                  if (kebenaran != null) ...[
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1E293B),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: const Color(0xFF334155),
                              ),
                            ),
                            child: Column(
                              children: [
                                const Text(
                                  'Kebenaran',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Color(0xFF94A3B8),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  kebenaran.toStringAsFixed(2),
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                    fontFamily: 'monospace',
                                    color: Colors.white,
                                  ),
                                ),
                                Text(
                                  'Salah: ${mistakes ?? 0}x',
                                  style: const TextStyle(
                                    fontSize: 9,
                                    color: Color(0xFFF87171),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1E293B),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: const Color(0xFF334155),
                              ),
                            ),
                            child: Column(
                              children: [
                                const Text(
                                  'Kemantapan',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Color(0xFF94A3B8),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '+${(kemantapan ?? 0.0).toStringAsFixed(2)}',
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                    fontFamily: 'monospace',
                                    color: Color(0xFF38BDF8),
                                  ),
                                ),
                                const Text(
                                  'Bonus',
                                  style: TextStyle(
                                    fontSize: 9,
                                    color: Color(0xFF64748B),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                  ],

                  if (attackDefense != null) ...[
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E293B),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFF334155)),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Nilai Awal Penampilan:',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFF94A3B8),
                                ),
                              ),
                              Text(
                                ScoringGandaWidget.baseScore.toStringAsFixed(2),
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF10B981),
                                ),
                              ),
                            ],
                          ),
                          const Divider(color: Color(0xFF334155), height: 10),
                          _buildGandaPenaltyRow('Penalti Serang Bela:', attackDefense),
                          const SizedBox(height: 4),
                          _buildGandaPenaltyRow('Penalti Kemantapan:', firmnessHarmony ?? 0.0),
                          const SizedBox(height: 4),
                          _buildGandaPenaltyRow('Penalti Penjiwaan:', soulfulness ?? 0.0),
                          const Divider(color: Color(0xFF334155), height: 10),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Total Pengurangan Penalti:',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFFFCA5A5),
                                ),
                              ),
                              Text(
                                '-${(attackDefense + (firmnessHarmony ?? 0.0) + (soulfulness ?? 0.0)).toStringAsFixed(2)}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFFEF4444),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],

                  // Massive Total Score Card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      vertical: 12,
                      horizontal: 16,
                    ),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF065F46), Color(0xFF047857)],
                      ),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFF10B981)),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF10B981).withValues(alpha: 0.3),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        const Text(
                          'TOTAL NILAI JURI AKHIR',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.0,
                            color: Color(0xFFD1FAE5),
                          ),
                        ),
                        const SizedBox(height: 4),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            totalScore.toStringAsFixed(2),
                            style: const TextStyle(
                              fontSize: 48,
                              fontWeight: FontWeight.w900,
                              fontFamily: 'monospace',
                              color: Colors.white,
                              letterSpacing: 1.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Waiting indicator
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E293B),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: const Color(0xFF3B82F6).withValues(alpha: 0.4),
                      ),
                    ),
                    child: const Row(
                      children: [
                        SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Color(0xFF38BDF8),
                          ),
                        ),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Menunggu Dewan Pertandingan memulai partai berikutnya...',
                            style: TextStyle(
                              fontSize: 10.5,
                              color: Color(0xFFBAE6FD),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Close button
                  SizedBox(
                    width: double.infinity,
                    height: 44,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.of(ctx).pop();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF334155),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Text(
                        'TUTUP (MENUNGGU PARTAI BERIKUTNYA)',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    ).then((_) {
      _isSummaryPopupShowing = false;
    });
  }

  Widget _buildSubmittedStandbyBanner() {
    final double score =
        _lastSubmittedData?['total'] ?? _calculateCurrentScore();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF10B981), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF10B981).withValues(alpha: 0.2),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(5),
            decoration: const BoxDecoration(
              color: Color(0xFF065F46),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.check_rounded,
              color: Color(0xFF34D399),
              size: 15,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Text(
                      'NILAI JURI $_juriNumber: ${score.toStringAsFixed(2)} TERKUNCI',
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF6EE7B7),
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'SELESAI',
                        style: TextStyle(
                          fontSize: 8.5,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF6EE7B7),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 1),
                const Text(
                  'Terkirim ke Dewan. Layar penilaian akan otomatis kembali saat Dewan memilih partai berikutnya.',
                  style: TextStyle(fontSize: 9.5, color: Color(0xFF94A3B8)),
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          ElevatedButton.icon(
            onPressed: () {
              if (_lastSubmittedData != null) {
                _showSubmittedScorePopup(
                  totalScore: _lastSubmittedData!['total'] ?? 0.0,
                  kebenaran: _lastSubmittedData!['kebenaran'],
                  kemantapan: _lastSubmittedData!['kemantapan'],
                  mistakes: _lastSubmittedData!['mistakes'],
                  attackDefense: _lastSubmittedData!['attackDefense'],
                  firmnessHarmony: _lastSubmittedData!['firmnessHarmony'],
                  soulfulness: _lastSubmittedData!['soulfulness'],
                );
              }
            },
            icon: const Icon(Icons.receipt_long_rounded, size: 12),
            label: const Text(
              'Rincian',
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1E293B),
              foregroundColor: const Color(0xFF38BDF8),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(6),
                side: const BorderSide(color: Color(0xFF0284C7)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGandaPenaltyRow(String label, double value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
        ),
        Text(
          value > 0 ? '-${value.toStringAsFixed(2)}' : '0.00',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: value > 0 ? const Color(0xFFEF4444) : Colors.white,
          ),
        ),
      ],
    );
  }

  void _selectGandaAspect(VoidCallback apply) {
    if (!_ensureJuriReady()) return;
    setState(apply);
    _notifyScoringInProgress();
    _saveOngoingSession();
  }

  double _calculateCurrentScore() {
    if (_category.isBaku) {
      final int totalMistakes = _mistakesPerJurus.fold(0, (sum, m) => sum + m);
      final double kebenaran = (9.90 - (totalMistakes * 0.01)).clamp(0.0, 9.90);
      return kebenaran + (_scoreKemantapan ?? 0.0);
    } else {
      final double totalPenalty =
          (_attackDefense ?? 0.0) +
          (_firmnessHarmony ?? 0.0) +
          (_soulfulness ?? 0.0);
      return (ScoringGandaWidget.baseScore - totalPenalty)
          .clamp(0.0, ScoringGandaWidget.baseScore);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isPortrait =
        MediaQuery.of(context).orientation == Orientation.portrait;
    final currentScore = _calculateCurrentScore();

    final activeJurus =
        _category.isBaku && _currentJurusIndex < _jurusList.length
        ? _jurusList[_currentJurusIndex]
        : null;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _handleBackToPortal();
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF0F172A),
        body: SafeArea(
          top: !_isFullScreen,
          bottom: false,
          left: true,
          right: true,
          child: Stack(
            children: [
              // Main Layout Padding
              Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: _isFullScreen ? 6 : 8,
                  vertical: _isFullScreen ? 3 : 6,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Top App Header
                    ScoringHeader(
                      arenaCode: _arenaCode,
                      juriNumber: _juriNumber,
                      athlete: _athlete,
                      category: _category,
                      currentScore: currentScore,
                      isFullScreen: _isFullScreen,
                      onToggleFullScreen: _toggleFullScreen,
                      onBackToMenu: _handleBackToPortal,
                      juriStatus: GelanggangSyncService.instance.getJuriStatus(
                        _juriNumber,
                        arenaCode: _arenaCode,
                      ),
                      onToggleReady: _showJuriReadyPopup,
                      // Baku specific header indicators
                      currentJurusNumber: activeJurus?.jurusNumber,
                      totalJurusInGroup: activeJurus?.totalJurusInGroup,
                      currentJurusMistakes: _category.isBaku
                          ? (_currentJurusIndex < _mistakesPerJurus.length
                                ? _mistakesPerJurus[_currentJurusIndex]
                                : 0)
                          : null,
                      currentJurusGerakan: activeJurus?.totalGerakan,
                    ),
                    const SizedBox(height: 6),

                    if (_isScoreSubmitted) ...[
                      _buildSubmittedStandbyBanner(),
                      const SizedBox(height: 6),
                    ],

                    // Main Scoring View Body (Baku vs Ganda)
                    Expanded(
                      child: _category.isBaku
                          ? ScoringBakuWidget(
                              athlete: _athlete,
                              juriNumber: _juriNumber,
                              category: _category,
                              jurusList: _jurusList,
                              currentJurusIndex: _currentJurusIndex,
                              mistakesPerJurus: _mistakesPerJurus,
                              scoreKemantapan: _scoreKemantapan,
                              isCompleted: _isCompleted,
                              isJuriReady: GelanggangSyncService.instance
                                  .isJuriReady(_juriNumber, arenaCode: _arenaCode),
                              onRequireReady: _showJuriReadyPopup,
                              onWrongAction: _handleWrongAction,
                              onNextAction: _handleNextAction,
                              onResetAction: _handleResetBaku,
                              onSelectKemantapan: _handleSelectKemantapan,
                              onSubmitFinalScore: _handleSubmitFinalBaku,
                            )
                          : ScoringGandaWidget(
                              athlete: _athlete,
                              juriNumber: _juriNumber,
                              category: _category,
                              attackDefense: _attackDefense,
                              firmnessHarmony: _firmnessHarmony,
                              soulfulness: _soulfulness,
                              isJuriReady: GelanggangSyncService.instance
                                  .isJuriReady(_juriNumber, arenaCode: _arenaCode),
                              onRequireReady: _showJuriReadyPopup,
                              onSelectAttackDefense: (v) =>
                                  _selectGandaAspect(() => _attackDefense = v),
                              onSelectFirmnessHarmony: (v) =>
                                  _selectGandaAspect(() => _firmnessHarmony = v),
                              onSelectSoulfulness: (v) =>
                                  _selectGandaAspect(() => _soulfulness = v),
                              onResetAction: _handleResetGanda,
                              onSubmitScores: _handleSubmitGanda,
                            ),
                    ),
                  ],
                ),
              ),

              // Portrait Mode Advisory Overlay (Dismissible)
              if (isPortrait && !_dismissPortraitAdvisory)
                Positioned.fill(
                  child: PortraitAdvisoryBanner(
                    onDismiss: () {
                      setState(() => _dismissPortraitAdvisory = true);
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
