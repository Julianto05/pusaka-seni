import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/scoring_models.dart';
import '../../services/gelanggang_sync_service.dart';
import '../../theme/app_theme.dart';
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
    sync.startRealtimeSync(arenaCode: _arenaCode);

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
    GelanggangSyncService.instance.stopRealtimeSync(arenaCode: _arenaCode);
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
      final clamped = state.activeJuriCount.clamp(1, 10);
      if (mounted) {
        setState(() {
          _juriNumber = clamped;
        });
      }
      sync.setSelectedJuriNumber(clamped);
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
      // Jika Dewan baru saja mengesahkan partai saat popup ringkasan skor terkunci,
      // tutup popup secara otomatis agar juri kembali ke layar standby.
      if (_isSummaryPopupShowing &&
          (sync.lastSyncAction == 'MATCH_FINALIZED' ||
              state.isMatchFinalized)) {
        if (mounted && Navigator.of(context, rootNavigator: true).canPop()) {
          Navigator.of(context, rootNavigator: true).pop();
        }
        _isSummaryPopupShowing = false;
        if (mounted) {
          ScaffoldMessenger.of(context).removeCurrentSnackBar();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Partai telah disahkan oleh Dewan Pertandingan!'),
              backgroundColor: AppColors.emerald,
              duration: Duration(seconds: 3),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }

      // Jika Dewan mereset slot juri ini sehingga status kembali not_ready,
      // tutup popup ringkasan (jika ada) dan tampilkan ulang popup READY.
      if ((sync.lastSyncAction == 'JURI_CLAIM_RELEASED' ||
              sync.lastSyncAction == 'JURI_CLAIMS_CLEARED') &&
          !sync.isJuriReady(_juriNumber, arenaCode: _arenaCode)) {
        if (_isSummaryPopupShowing &&
            mounted &&
            Navigator.of(context, rootNavigator: true).canPop()) {
          Navigator.of(context, rootNavigator: true).pop();
          _isSummaryPopupShowing = false;
        }
        if (mounted) {
          setState(() {
            _isScoreSubmitted = false;
            _lastSubmittedData = null;
          });
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted &&
                !_isReadyPopupShowing &&
                !sync.isJuriReady(_juriNumber, arenaCode: _arenaCode)) {
              _showJuriReadyPopup();
            }
          });
        }
      }

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
              backgroundColor: AppColors.surface,
              surfaceTintColor: Colors.transparent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
                side: BorderSide(
                  color: isReady
                      ? AppColors.emeraldBorder
                      : AppColors.primaryBorder,
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
                            padding: const EdgeInsets.all(9),
                            decoration: BoxDecoration(
                              color: isReady
                                  ? AppColors.emeraldSoft
                                  : AppColors.primarySoft,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isReady
                                    ? AppColors.emeraldBorder
                                    : AppColors.primaryBorder,
                              ),
                            ),
                            child: Icon(
                              isReady
                                  ? Icons.check_circle_rounded
                                  : Icons.sports_kabaddi_rounded,
                              color: isReady
                                  ? AppColors.emerald
                                  : AppColors.primary,
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
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w900,
                                    color: AppColors.textPrimary,
                                    letterSpacing: 0.4,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Builder(
                                  builder: (context) {
                                    final evTitle = currentSync
                                        .getArenaState(_arenaCode)
                                        .lockedEventTitle;
                                    final subtitle =
                                        evTitle != null && evTitle.isNotEmpty
                                            ? '${evTitle.toUpperCase()} • $_arenaCode • JURI $_juriNumber'
                                            : 'GELANGGANG $_arenaCode • JURI $_juriNumber';
                                    return Text(
                                      subtitle,
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.textSecondary,
                                      ),
                                    );
                                  },
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
                        padding: const EdgeInsets.all(13),
                        decoration: AppDecorations.softTile(
                          radius: 16,
                          color: AppColors.surfaceSoft,
                          borderColor: AppColors.border,
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
                                    color: AppColors.primary,
                                    borderRadius: BorderRadius.circular(7),
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
                                    color: AppColors.skySoft,
                                    borderRadius: BorderRadius.circular(7),
                                    border: Border.all(
                                      color: AppColors.skyBorder,
                                    ),
                                  ),
                                  child: Text(
                                    _category.title.toUpperCase(),
                                    style: TextStyle(
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.skyText,
                                    ),
                                  ),
                                ),
                                if (_athlete.pool.isNotEmpty)
                                  Text(
                                    'POOL ${_athlete.pool.toUpperCase()}',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.textMuted,
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _athlete.name,
                              style: TextStyle(
                                fontSize: 14.5,
                                fontWeight: FontWeight.w900,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _athlete.kontingen,
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            if (_category == SeniCategory.tunggal) ...[
                              const SizedBox(height: 10),
                              Container(
                                padding: const EdgeInsets.all(9),
                                decoration: BoxDecoration(
                                  color: AppColors.surface,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: AppColors.border),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        const Icon(
                                          Icons.format_list_numbered_rounded,
                                          color: AppColors.sky,
                                          size: 14,
                                        ),
                                        const SizedBox(width: 6),
                                        Expanded(
                                          child: Text(
                                            _bakuModeDescription,
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w800,
                                              color: AppColors.textPrimary,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 5),
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
                          Text(
                            'Status Juri: ',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 11,
                              vertical: 4.5,
                            ),
                            decoration: BoxDecoration(
                              color: isReady
                                  ? AppColors.emeraldSoft
                                  : AppColors.primarySoft,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: isReady
                                    ? AppColors.emeraldBorder
                                    : AppColors.primaryBorder,
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
                                        ? AppColors.emerald
                                        : AppColors.primary,
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
                                    fontWeight: FontWeight.w800,
                                    color: isReady
                                        ? AppColors.emeraldText
                                        : AppColors.primaryText,
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
                                backgroundColor: AppColors.emerald,
                                duration: const Duration(seconds: 2),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.emerald,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            elevation: 0,
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
                                letterSpacing: 0.4,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextButton(
                        onPressed: () => Navigator.of(ctx).pop(),
                        child: Text(
                          'Tutup / Konfirmasi Nanti',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textMuted,
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
      Color bg = AppColors.skySoft;
      Color border = AppColors.skyBorder;
      Color fg = AppColors.skyText;
      final l = entry.key.toLowerCase();
      if (l.contains('tangan')) {
        bg = AppColors.amberSoft;
        border = AppColors.amberBorder;
        fg = AppColors.amberText;
      } else if (l.contains('golok')) {
        bg = AppColors.blueSoft;
        border = AppColors.blueBorder;
        fg = AppColors.blueText;
      } else if (l.contains('toya')) {
        bg = AppColors.purpleSoft;
        border = AppColors.purpleBorder;
        fg = AppColors.purple;
      }

      final jurusInGroup = _jurusList
          .where((j) => j.weaponGroup == entry.key)
          .toList();
      final String rangeStr = jurusInGroup.length > 1
          ? 'Jurus ${jurusInGroup.first.jurusNumber}-${jurusInGroup.last.jurusNumber}'
          : 'Jurus ${jurusInGroup.first.jurusNumber}';

      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: border),
        ),
        child: Text(
          '${entry.key}: $rangeStr (${entry.value} grk)',
          style: TextStyle(
            fontSize: 9.5,
            color: fg,
            fontWeight: FontWeight.w700,
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

  String? _activeBakuJurusLabel() {
    if (!_category.isBaku || _jurusList.isEmpty) return null;
    if (_isCompleted) return 'Tuntas';
    if (_category == SeniCategory.beregu) return 'Beregu';
    final idx = _currentJurusIndex.clamp(0, _jurusList.length - 1);
    return _jurusList[idx].weaponGroup;
  }

  void _notifyScoringInProgress() {
    final sync = GelanggangSyncService.instance;
    final currentStatus = sync.getJuriStatus(
      _juriNumber,
      arenaCode: _arenaCode,
    );
    if (currentStatus != 'submitted') {
      final int? currJurus = _category.isBaku && _jurusList.isNotEmpty
          ? (_isCompleted ? _jurusList.length : _currentJurusIndex + 1)
          : null;
      final int? totJurus = _category.isBaku && _jurusList.isNotEmpty
          ? _jurusList.length
          : null;
      sync.juriStartScoring(
        juriNumber: _juriNumber,
        currentScore: _calculateCurrentScore(),
        currentJurus: currJurus,
        totalJurus: totJurus,
        jurusLabel: _activeBakuJurusLabel(),
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
    _notifyScoringInProgress();
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
      currentJurus: _jurusList.isNotEmpty
          ? (_isCompleted ? _jurusList.length : _currentJurusIndex + 1)
          : null,
      totalJurus: _jurusList.isNotEmpty ? _jurusList.length : null,
      jurusLabel: _activeBakuJurusLabel(),
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
      currentJurus: _jurusList.length,
      totalJurus: _jurusList.length,
      jurusLabel: 'Tuntas',
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
    final bool initiallyFinalized = GelanggangSyncService.instance
        .getArenaState(_arenaCode)
        .isMatchFinalized;

    showDialog(
      context: context,
      barrierDismissible: initiallyFinalized,
      builder: (ctx) {
        return ListenableBuilder(
          listenable: GelanggangSyncService.instance,
          builder: (dialogCtx, _) {
            final bool isMatchFinalized = GelanggangSyncService.instance
                .getArenaState(_arenaCode)
                .isMatchFinalized;

            return PopScope(
              canPop: isMatchFinalized,
              child: AlertDialog(
                backgroundColor: AppColors.surface,
                surfaceTintColor: Colors.transparent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                  side: BorderSide(color: AppColors.emeraldBorder, width: 1.5),
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
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: AppColors.emeraldSoft,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppColors.emeraldBorder,
                        width: 2,
                      ),
                    ),
                    child: const Icon(
                      Icons.check_circle_rounded,
                      color: AppColors.emerald,
                      size: 32,
                    ),
                  ),
                  const SizedBox(height: 12),

                  Text(
                    'NILAI JURI $_juriNumber BERHASIL DISINKRONKAN',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.5,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${_athlete.partai} • ${_category.title.toUpperCase()}',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: AppColors.skyText,
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Athlete info card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(11),
                    decoration: AppDecorations.softTile(
                      radius: 12,
                      color: AppColors.surfaceSoft,
                      borderColor: AppColors.border,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _athlete.name.toUpperCase(),
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w900,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${_athlete.kontingen} • ${_athlete.pool}',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondary,
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
                              vertical: 9,
                            ),
                            decoration: AppDecorations.softTile(
                              radius: 12,
                              color: AppColors.surfaceSoft,
                              borderColor: AppColors.border,
                            ),
                            child: Column(
                              children: [
                                Text(
                                  'Kebenaran',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: AppColors.textSecondary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  kebenaran.toStringAsFixed(2),
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w900,
                                    fontFamily: 'monospace',
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                Text(
                                  'Salah: ${mistakes ?? 0}x',
                                  style: const TextStyle(
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.primary,
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
                              vertical: 9,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.skySoft,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppColors.skyBorder),
                            ),
                            child: Column(
                              children: [
                                Text(
                                  'Kemantapan',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: AppColors.skyText,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '+${(kemantapan ?? 0.0).toStringAsFixed(2)}',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w900,
                                    fontFamily: 'monospace',
                                    color: AppColors.skyText,
                                  ),
                                ),
                                Text(
                                  'Bonus',
                                  style: TextStyle(
                                    fontSize: 9.5,
                                    color: AppColors.textMuted,
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
                      padding: const EdgeInsets.all(10),
                      decoration: AppDecorations.softTile(
                        radius: 12,
                        color: AppColors.surfaceSoft,
                        borderColor: AppColors.border,
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Nilai Awal Penampilan:',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                              Text(
                                ScoringGandaWidget.baseScore.toStringAsFixed(2),
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.emerald,
                                ),
                              ),
                            ],
                          ),
                          Divider(color: AppColors.border, height: 12),
                          _buildGandaPenaltyRow(
                            'Penalti Serang Bela:',
                            attackDefense,
                          ),
                          const SizedBox(height: 4),
                          _buildGandaPenaltyRow(
                            'Penalti Kemantapan:',
                            firmnessHarmony ?? 0.0,
                          ),
                          const SizedBox(height: 4),
                          _buildGandaPenaltyRow(
                            'Penalti Penjiwaan:',
                            soulfulness ?? 0.0,
                          ),
                          Divider(color: AppColors.border, height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Total Pengurangan Penalti:',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.primaryText,
                                ),
                              ),
                              Text(
                                '-${(attackDefense + (firmnessHarmony ?? 0.0) + (soulfulness ?? 0.0)).toStringAsFixed(2)}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.primary,
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
                      vertical: 14,
                      horizontal: 16,
                    ),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF059669), Color(0xFF047857)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.emerald.withValues(alpha: 0.28),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        const Text(
                          'TOTAL NILAI JURI AKHIR',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
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

                  // Waiting / Endorsed indicator
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 11,
                      vertical: 9,
                    ),
                    decoration: BoxDecoration(
                      color: isMatchFinalized
                          ? AppColors.emeraldSoft
                          : AppColors.skySoft,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isMatchFinalized
                            ? AppColors.emeraldBorder
                            : AppColors.skyBorder,
                      ),
                    ),
                    child: Row(
                      children: [
                        if (isMatchFinalized)
                          const Icon(
                            Icons.verified_rounded,
                            size: 16,
                            color: AppColors.emerald,
                          )
                        else
                          const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.sky,
                            ),
                          ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            isMatchFinalized
                                ? 'Partai telah disahkan Dewan. Menunggu partai berikutnya...'
                                : 'Menunggu Dewan Pertandingan mengesahkan partai atau memulai partai berikutnya...',
                            style: TextStyle(
                              fontSize: 10.5,
                              color: isMatchFinalized
                                  ? AppColors.emeraldText
                                  : AppColors.skyText,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Locked while waiting for Dewan; closeable only after Dewan finalizes
                  if (isMatchFinalized)
                    SizedBox(
                      width: double.infinity,
                      height: 44,
                      child: OutlinedButton(
                        onPressed: () {
                          Navigator.of(ctx).pop();
                        },
                        style: OutlinedButton.styleFrom(
                          backgroundColor: AppColors.surfaceSoft,
                          foregroundColor: AppColors.textPrimary,
                          side: BorderSide(color: AppColors.borderStrong),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            'TUTUP (MENUNGGU PARTAI BERIKUTNYA)',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                    )
                  else
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 11,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.amberSoft,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.amberBorder),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.lock_clock_rounded,
                            size: 15,
                            color: AppColors.amber,
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              'TERKUNCI — MENUNGGU PENGESAHAN DEWAN',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w800,
                                color: AppColors.amberText,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      );
          },
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
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.emeraldSoft,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.emeraldBorder, width: 1.2),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: const BoxDecoration(
              color: AppColors.emerald,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.check_rounded,
              color: Colors.white,
              size: 14,
            ),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Wrap(
                  spacing: 6,
                  runSpacing: 3,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      'NILAI JURI $_juriNumber: ${score.toStringAsFixed(2)} TERKUNCI',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w900,
                        color: AppColors.emeraldText,
                        letterSpacing: 0.4,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 1.5,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: AppColors.emeraldBorder),
                      ),
                      child: Text(
                        'SELESAI',
                        style: TextStyle(
                          fontSize: 8.5,
                          fontWeight: FontWeight.w800,
                          color: AppColors.emeraldText,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 1),
                Text(
                  'Terkirim ke Dewan. Layar penilaian akan otomatis kembali saat Dewan memilih partai berikutnya.',
                  style: TextStyle(
                    fontSize: 9.5,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          OutlinedButton.icon(
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
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800),
            ),
            style: OutlinedButton.styleFrom(
              backgroundColor: AppColors.surface,
              foregroundColor: AppColors.skyText,
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              side: BorderSide(color: AppColors.skyBorder),
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
          style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
        ),
        Text(
          value > 0 ? '-${value.toStringAsFixed(2)}' : '0.00',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: value > 0 ? AppColors.primary : AppColors.textPrimary,
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
      child: ListenableBuilder(
        listenable: AppThemeController.instance,
        builder: (context, _) => Scaffold(
        backgroundColor: AppColors.background,
        body: Container(
          decoration: AppDecorations.pageBackground,
          child: SafeArea(
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
                        juriStatus: GelanggangSyncService.instance
                            .getJuriStatus(
                              _juriNumber,
                              arenaCode: _arenaCode,
                            ),
                        onToggleReady: _showJuriReadyPopup,
                        // Live Timer synced from Time Keeper
                        timerRemainingSeconds: GelanggangSyncService.instance
                            .getArenaState(_arenaCode)
                            .timerRemainingSeconds,
                        timerStatus: GelanggangSyncService.instance
                            .getArenaState(_arenaCode)
                            .timerStatus,
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
      ),
      ),
    );
  }
}
