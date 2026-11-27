import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../services/app_link_helper.dart';
import '../../services/gelanggang_sync_service.dart';
import '../../services/platform_env.dart';
import '../../services/pusaka_seni_api_service.dart';
import '../../theme/app_theme.dart';

class GelanggangVerificationView extends StatefulWidget {
  final String roleName;
  final IconData roleIcon;
  final Color accentColor;
  final ValueChanged<String> onVerified;
  final VoidCallback onBack;
  final bool enableAnimation;

  const GelanggangVerificationView({
    super.key,
    required this.roleName,
    required this.roleIcon,
    required this.accentColor,
    required this.onVerified,
    required this.onBack,
    this.enableAnimation = true,
  });

  @override
  State<GelanggangVerificationView> createState() => _GelanggangVerificationViewState();
}

class _GelanggangVerificationViewState extends State<GelanggangVerificationView>
    with SingleTickerProviderStateMixin {
  String _pinCode = '';
  static const int _pinLength = 8;
  bool _isCameraActive = false;
  bool _isTorchOn = false;
  bool _isVerifying = false;
  String? _errorMessage;
  int _activeMethodTab = 0; // 0: Kode 8 Digit, 1: Scan QR (compact screens)

  bool get _isJuriRole => widget.roleName.toLowerCase().contains('juri');
  late int _selectedJuri;
  late String _syncedArena;

  late final TextEditingController _pinController;
  late final FocusNode _pinFocusNode;
  MobileScannerController? _scannerController;
  late AnimationController _laserAnimController;

  @override
  void initState() {
    super.initState();
    final sync = GelanggangSyncService.instance;
    _syncedArena = _currentTargetArena;
    final available = sync.getAvailableJudgesForThisDevice(arenaCode: _syncedArena);
    if (available.isNotEmpty && !available.contains(sync.selectedJuriNumber)) {
      _selectedJuri = available.first;
      sync.setSelectedJuriNumber(_selectedJuri);
    } else {
      _selectedJuri = sync.selectedJuriNumber;
    }
    sync.addListener(_handleGelanggangSync);
    sync.startRealtimeSync(arenaCode: _syncedArena);

    _pinController = TextEditingController(text: _pinCode);
    _pinFocusNode = FocusNode();
    _pinFocusNode.addListener(() {
      if (mounted) setState(() {});
    });

    _laserAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );
    if (widget.enableAnimation) {
      _laserAnimController.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    GelanggangSyncService.instance.removeListener(_handleGelanggangSync);
    GelanggangSyncService.instance.stopRealtimeSync(arenaCode: _syncedArena);
    _pinController.dispose();
    _pinFocusNode.dispose();
    _scannerController?.dispose();
    _laserAnimController.dispose();
    super.dispose();
  }

  void _handleGelanggangSync() {
    if (mounted) setState(() {});
  }

  String get _currentTargetArena {
    return GelanggangSyncService.instance.resolveKnownArenaCode(_pinCode);
  }

  void _onKeyPress(String val) {
    if (_pinCode.length < _pinLength) {
      setState(() {
        _errorMessage = null;
        _pinCode += val;
        _pinController.text = _pinCode;
        _pinController.selection = TextSelection.collapsed(offset: _pinCode.length);
      });
      if (_pinCode.length == _pinLength) {
        _verifyCode(_pinCode);
      }
    }
  }

  void _onDelete() {
    if (_pinCode.isNotEmpty) {
      setState(() {
        _errorMessage = null;
        _pinCode = _pinCode.substring(0, _pinCode.length - 1);
        _pinController.text = _pinCode;
        _pinController.selection = TextSelection.collapsed(offset: _pinCode.length);
      });
    }
  }

  void _onReset() {
    setState(() {
      _errorMessage = null;
      _pinCode = '';
      _pinController.text = '';
    });
  }

  Future<void> _onPaste() async {
    try {
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      if (data != null && data.text != null) {
        final clean = data.text!.replaceAll(RegExp(r'[^0-9A-Za-z]'), '');
        if (clean.isNotEmpty) {
          setState(() {
            _errorMessage = null;
            _pinCode = clean.length > _pinLength ? clean.substring(0, _pinLength) : clean;
            _pinController.text = _pinCode;
            _pinController.selection = TextSelection.collapsed(offset: _pinCode.length);
          });
          if (_pinCode.length == _pinLength) {
            _verifyCode(_pinCode);
          }
        }
      }
    } catch (_) {}
  }

  void _toggleCamera() {
    if (!kIsWeb && isWindowsDesktop()) {
      ScaffoldMessenger.of(context).removeCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Scan kamera QR tidak tersedia di Windows Desktop. Silakan masukkan kode 8 digit gelanggang.',
          ),
          backgroundColor: AppColors.amber,
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }

    setState(() {
      _isCameraActive = !_isCameraActive;
      if (_isCameraActive) {
        _scannerController ??= MobileScannerController(
          detectionSpeed: DetectionSpeed.normal,
          facing: CameraFacing.back,
          torchEnabled: false,
        );
        _scannerController?.start();
      } else {
        _scannerController?.stop();
      }
    });
  }

  void _onDetectBarcode(BarcodeCapture capture) {
    if (_isVerifying) return;
    for (final barcode in capture.barcodes) {
      final raw = barcode.rawValue ?? barcode.displayValue;
      if (raw != null && raw.trim().isNotEmpty) {
        _handleScannedBarcode(raw.trim());
        break;
      }
    }
  }

  void _handleScannedBarcode(String code) {
    final trimmed = code.trim();
    String extracted = trimmed;
    final parsedUri = Uri.tryParse(trimmed);
    if (parsedUri != null && (parsedUri.hasScheme || trimmed.contains('arena='))) {
      final route = AppLinkHelper.parseStartupRoute(parsedUri);
      if (route.arenaCode != null && route.arenaCode!.trim().isNotEmpty) {
        extracted = route.arenaCode!.trim();
      }
    }
    final cleanCode = extracted.replaceAll(RegExp(r'[^0-9A-Za-z\-]'), '').trim();

    setState(() {
      _errorMessage = null;
      _pinCode = cleanCode;
      _pinController.text = cleanCode;
      _isCameraActive = false;
    });
    _scannerController?.stop();

    _verifyCode(cleanCode);
  }

  Future<void> _verifyCode(String code) async {
    final clean = code.trim();
    if (_isVerifying || clean.isEmpty) return;
    setState(() {
      _isVerifying = true;
      _errorMessage = null;
    });

    try {
      final sync = GelanggangSyncService.instance;

      // Strict backend validation: only arena codes created by Event Admin
      // (registered in `/gelanggangs` and linked to an active Event) are accepted.
      final result = await PusakaSeniApiService().verifyGelanggangStrict(clean);

      if (!mounted) return;

      if (!result.isValid) {
        setState(() => _errorMessage = result.message);
        ScaffoldMessenger.of(context).removeCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.message),
            backgroundColor: AppColors.primary,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 4),
          ),
        );
        return;
      }

      final info = result.info!;
      final String arenaName = info.arenaLabel;
      final int? eventJuriCount = info.jumlahJuri;

      // Always pull Dewan's authoritative judge count & Timekeeper's live timer first
      // so non-Dewan devices never overwrite Dewan's activeJuriCount.
      try {
        await sync.pullArenaSync(arenaName);
      } catch (_) {}
      if (!mounted) return;

      // Apply event default judge count ONLY if Dewan has not set an authoritative count.
      final arenaState = sync.getArenaState(arenaName);
      if (!arenaState.hasDewanJuriCount &&
          eventJuriCount != null &&
          eventJuriCount >= 1 &&
          eventJuriCount <= 10) {
        arenaState.setActiveJuriCount(eventJuriCount);
      }

      if (_isJuriRole) {
        final available = sync.getAvailableJudgesForThisDevice(arenaCode: arenaName);
        if (available.isEmpty) {
          final fullMsg = 'Semua nomor juri sudah terisi di $arenaName!';
          setState(() => _errorMessage = fullMsg);
          ScaffoldMessenger.of(context).removeCurrentSnackBar();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(fullMsg),
              backgroundColor: AppColors.primary,
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 3),
            ),
          );
          return;
        }
        if (!available.contains(_selectedJuri)) {
          _selectedJuri = available.first;
        }
        sync.setSelectedJuriNumber(_selectedJuri);
        sync.claimJuri(_selectedJuri, arenaCode: arenaName);
      }

      sync.verifyGelanggang(
        arenaCode: arenaName,
        rawArenaCode: info.rawArenaCode.isNotEmpty ? info.rawArenaCode : clean,
        gelanggangId: info.gelanggangId,
        gelanggangDocId: info.gelanggangDocId,
        eventId: info.eventId,
        eventDocId: info.eventDocId,
        eventTitle: info.eventTitle,
        eventCode: info.eventCode,
        jumlahJuri: eventJuriCount,
      );

      final eventPrefix = info.eventTitle != null && info.eventTitle!.isNotEmpty
          ? '${info.eventTitle} • '
          : '';
      ScaffoldMessenger.of(context).removeCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_isJuriRole
              ? 'Terverifikasi: $eventPrefix$arenaName • Juri $_selectedJuri'
              : 'Terverifikasi: $eventPrefix$arenaName'),
          backgroundColor: AppColors.emerald,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );

      widget.onVerified(arenaName);
    } catch (_) {
      if (mounted) {
        const msg = 'Gagal memverifikasi kode gelanggang. Silakan coba lagi.';
        setState(() => _errorMessage = msg);
        ScaffoldMessenger.of(context).removeCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(msg),
            backgroundColor: AppColors.primary,
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 3),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isVerifying = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AppThemeController.instance,
      builder: (context, _) => Scaffold(
      backgroundColor: AppColors.background,
      body: Container(
        decoration: AppDecorations.pageBackground,
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 960),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                child: Column(
                  children: [
                    _buildTopBar(),
                    const SizedBox(height: 10),
                    Expanded(
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final isWide =
                              constraints.maxWidth >= 760 && constraints.maxHeight >= 460;

                          if (isWide) {
                            return SingleChildScrollView(
                              physics: const BouncingScrollPhysics(),
                              padding: const EdgeInsets.only(bottom: 12),
                              child: Column(
                                children: [
                                  if (_isJuriRole) ...[
                                    _buildJuriSelectorSection(),
                                    const SizedBox(height: 12),
                                  ],
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Expanded(flex: 5, child: _buildKeypadCard()),
                                      const SizedBox(width: 14),
                                      Expanded(flex: 5, child: _buildQrScannerCard()),
                                    ],
                                  ),
                                ],
                              ),
                            );
                          }

                          return SingleChildScrollView(
                            physics: const BouncingScrollPhysics(),
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Column(
                              children: [
                                if (_isJuriRole) ...[
                                  _buildJuriSelectorSection(),
                                  const SizedBox(height: 10),
                                ],
                                _buildMethodSwitcher(),
                                const SizedBox(height: 10),
                                _activeMethodTab == 0
                                    ? _buildKeypadCard()
                                    : _buildQrScannerCard(),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    ),
    );
  }

  Widget _buildMethodSwitcher() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: AppDecorations.card(radius: 14, elevated: false),
      child: Row(
        children: [
          _buildMethodTabItem(index: 0, icon: Icons.pin_rounded, label: 'Kode 8 Digit'),
          const SizedBox(width: 4),
          _buildMethodTabItem(
            index: 1,
            icon: Icons.qr_code_scanner_rounded,
            label: 'Scan QR Kamera',
          ),
        ],
      ),
    );
  }

  Widget _buildMethodTabItem({
    required int index,
    required IconData icon,
    required String label,
  }) {
    final isSelected = _activeMethodTab == index;
    return Expanded(
      child: InkWell(
        onTap: () {
          setState(() {
            _activeMethodTab = index;
            if (index == 0 && _isCameraActive) {
              _isCameraActive = false;
              _scannerController?.stop();
            }
          });
        },
        borderRadius: BorderRadius.circular(10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 8),
          decoration: BoxDecoration(
            color: isSelected
                ? widget.accentColor.withValues(alpha: 0.12)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected
                  ? widget.accentColor.withValues(alpha: 0.5)
                  : Colors.transparent,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 15,
                color: isSelected ? widget.accentColor : AppColors.textMuted,
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                    color: isSelected ? widget.accentColor : AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: AppDecorations.card(radius: 18),
      child: Row(
        children: [
          IconButton(
            onPressed: widget.onBack,
            tooltip: 'Kembali ke Pilihan Peran',
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 14),
            constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
            padding: EdgeInsets.zero,
            style: IconButton.styleFrom(
              backgroundColor: AppColors.surfaceMuted,
              foregroundColor: AppColors.textPrimary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: widget.accentColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(widget.roleIcon, color: widget.accentColor, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _isJuriRole ? '${widget.roleName} • Juri $_selectedJuri' : widget.roleName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  _isJuriRole
                      ? 'Perangkat Terkunci Sebagai Juri $_selectedJuri'
                      : 'Verifikasi Akses Gelanggang',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 10.5, color: AppColors.textMuted),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.emeraldSoft,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.emeraldBorder),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.circle, size: 6, color: AppColors.emerald),
                const SizedBox(width: 5),
                Text(
                  'Live',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: AppColors.emeraldText,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          const ThemeToggleButton(
            buttonSize: 30,
            iconSize: 16,
            borderRadius: 9,
          ),
        ],
      ),
    );
  }

  Widget _buildKeypadCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: AppDecorations.card(radius: 22),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: AppColors.amberSoft,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.amberBorder),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.asset(
                    'assets/images/app_logo_small.png',
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) => Icon(
                      Icons.pin_rounded,
                      color: widget.accentColor,
                      size: 20,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Kode Gelanggang (8 Digit)',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      'Masukkan 8 digit kode gelanggang untuk verifikasi & mengunci event',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 10.5, color: AppColors.textMuted),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // 8-Digit PIN Boxes
          Center(
            child: InkWell(
              onTap: () => _pinFocusNode.requestFocus(),
              borderRadius: BorderRadius.circular(12),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(_pinLength, (index) {
                    final hasChar = index < _pinCode.length;
                    final isCurrent = index == _pinCode.length;
                    return Container(
                      width: 34,
                      height: 44,
                      margin: const EdgeInsets.symmetric(horizontal: 2.5),
                      decoration: BoxDecoration(
                        color: hasChar ? AppColors.surface : AppColors.surfaceSoft,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: _errorMessage != null
                              ? AppColors.primary
                              : isCurrent
                                  ? widget.accentColor
                                  : hasChar
                                      ? AppColors.borderStrong
                                      : AppColors.border,
                          width: (_errorMessage != null || isCurrent) ? 1.8 : 1.0,
                        ),
                        boxShadow: isCurrent
                            ? [
                                BoxShadow(
                                  color: widget.accentColor.withValues(alpha: 0.15),
                                  blurRadius: 8,
                                ),
                              ]
                            : null,
                      ),
                      child: Center(
                        child: Text(
                          hasChar ? _pinCode[index] : '•',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            fontFamily: 'monospace',
                            color: hasChar ? AppColors.textPrimary : AppColors.borderStrong,
                          ),
                        ),
                      ),
                    );
                  }),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),

          // Unified Soft Keyboard & Paste Bar
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 300),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.surfaceSoft,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _pinFocusNode.hasFocus ? widget.accentColor : AppColors.border,
                    width: _pinFocusNode.hasFocus ? 1.5 : 1.0,
                  ),
                ),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () {
                        if (_pinFocusNode.hasFocus) {
                          _pinFocusNode.unfocus();
                        } else {
                          _pinFocusNode.requestFocus();
                        }
                      },
                      tooltip: _pinFocusNode.hasFocus
                          ? 'Tutup Keyboard HP'
                          : 'Buka Keyboard HP',
                      icon: Icon(
                        _pinFocusNode.hasFocus
                            ? Icons.keyboard_hide_rounded
                            : Icons.keyboard_rounded,
                        size: 16,
                        color: _pinFocusNode.hasFocus
                            ? widget.accentColor
                            : AppColors.sky,
                      ),
                      constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                      padding: EdgeInsets.zero,
                    ),
                    Expanded(
                      child: TextField(
                        controller: _pinController,
                        focusNode: _pinFocusNode,
                        keyboardType: TextInputType.text,
                        textCapitalization: TextCapitalization.characters,
                        textInputAction: TextInputAction.done,
                        inputFormatters: [
                          LengthLimitingTextInputFormatter(_pinLength),
                        ],
                        style: TextStyle(
                          fontSize: 13.5,
                          letterSpacing: 2.5,
                          fontFamily: 'monospace',
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                        textAlign: TextAlign.center,
                        decoration: InputDecoration(
                          hintText: 'Ketik kode gelanggang...',
                          hintStyle: TextStyle(
                            fontSize: 10.5,
                            letterSpacing: 0.4,
                            color: AppColors.textMuted,
                          ),
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(vertical: 8),
                        ),
                        onChanged: (val) {
                          setState(() {
                            _errorMessage = null;
                            _pinCode = val.trim();
                          });
                          if (_pinCode.length >= _pinLength) {
                            _verifyCode(_pinCode);
                          }
                        },
                        onSubmitted: (val) {
                          if (val.trim().isNotEmpty) {
                            _verifyCode(val.trim());
                          }
                        },
                      ),
                    ),
                    if (_pinCode.isNotEmpty)
                      IconButton(
                        onPressed: _onReset,
                        tooltip: 'Bersihkan',
                        icon: Icon(
                          Icons.clear_rounded,
                          size: 15,
                          color: AppColors.textMuted,
                        ),
                        constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                        padding: EdgeInsets.zero,
                      ),
                    IconButton(
                      onPressed: _onPaste,
                      tooltip: 'Tempel / Paste',
                      icon: const Icon(
                        Icons.content_paste_rounded,
                        size: 15,
                        color: AppColors.sky,
                      ),
                      constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                      padding: EdgeInsets.zero,
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (_errorMessage != null) ...[
            const SizedBox(height: 10),
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 340),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.primarySoft,
                    borderRadius: BorderRadius.circular(11),
                    border: Border.all(color: AppColors.primaryBorder),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(top: 1),
                        child: Icon(
                          Icons.gpp_bad_rounded,
                          size: 16,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primaryText,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
          const SizedBox(height: 10),

          // Tactile Soft-Elevated Touch Numeric Keypad
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 300),
              child: GridView.count(
                crossAxisCount: 3,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 7,
                crossAxisSpacing: 7,
                childAspectRatio: 2.1,
                children: [
                  ...['1', '2', '3', '4', '5', '6', '7', '8', '9'].map(
                    (val) => _buildKeypadButton(val, () => _onKeyPress(val)),
                  ),
                  _buildActionKeypadButton('Reset', _onReset, isDestructive: true),
                  _buildKeypadButton('0', () => _onKeyPress('0')),
                  _buildActionKeypadButton('Hapus', _onDelete, icon: Icons.backspace_rounded),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Explicit Verify Action Button (useful on Chrome/Windows & manual input)
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 300),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isVerifying || _pinCode.trim().isEmpty
                      ? null
                      : () => _verifyCode(_pinCode),
                  icon: _isVerifying
                      ? const SizedBox(
                          width: 15,
                          height: 15,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.verified_user_rounded, size: 16),
                  label: Text(
                    _isVerifying
                        ? 'Memverifikasi Gelanggang...'
                        : 'Verifikasi Kode Gelanggang',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: widget.accentColor,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: AppColors.surfaceMuted,
                    disabledForegroundColor: AppColors.textMuted,
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKeypadButton(String label, VoidCallback onTap) {
    return Material(
      color: AppColors.surfaceSoft,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildJuriSelectorSection() {
    final sync = GelanggangSyncService.instance;
    final String arena = _currentTargetArena;
    final activeCount = sync.getActiveJuriCount(arenaCode: arena);
    final totalJudges = activeCount > 0 ? activeCount : 8;
    final availableJudges = sync.getAvailableJudgesForThisDevice(arenaCode: arena);

    if (availableJudges.isNotEmpty && !availableJudges.contains(_selectedJuri)) {
      _selectedJuri = availableJudges.first;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) sync.setSelectedJuriNumber(_selectedJuri);
      });
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: AppDecorations.card(
        radius: 18,
        borderColor: widget.accentColor.withValues(alpha: 0.4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.badge_rounded, color: widget.accentColor, size: 16),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'PILIH NOMOR JURI PERANGKAT INI',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.5,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.primarySoft,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.primaryBorder),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.lock_rounded, size: 9.5, color: AppColors.primary),
                    SizedBox(width: 3),
                    Text(
                      'Terkunci di Layar Juri',
                      style: TextStyle(
                        fontSize: 8.5,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primaryText,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (availableJudges.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.primarySoft,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.primaryBorder),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline_rounded, color: AppColors.primary, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Semua nomor juri ($totalJudges Juri) telah dipilih di $arena. Tidak ada slot juri tersisa.',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primaryText,
                      ),
                    ),
                  ),
                ],
              ),
            )
          else
            Wrap(
              spacing: 7,
              runSpacing: 7,
              children: availableJudges.map((jNum) {
                final bool isSelected = jNum == _selectedJuri;

                return InkWell(
                  onTap: () {
                    setState(() => _selectedJuri = jNum);
                    sync.setSelectedJuriNumber(jNum);
                  },
                  borderRadius: BorderRadius.circular(10),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    constraints: const BoxConstraints(minWidth: 68),
                    padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
                    decoration: BoxDecoration(
                      color: isSelected ? AppColors.primary : AppColors.surfaceSoft,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isSelected ? AppColors.primary : AppColors.border,
                        width: isSelected ? 1.4 : 1.0,
                      ),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: AppColors.primary.withValues(alpha: 0.25),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ]
                          : null,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (isSelected) ...[
                          const Icon(Icons.check_rounded, color: Colors.white, size: 13),
                          const SizedBox(width: 4),
                        ],
                        Text(
                          'Juri $jNum',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                            color: isSelected ? Colors.white : AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          const SizedBox(height: 6),
          Text(
            availableJudges.isNotEmpty
                ? '✓ Juri yang sudah dipilih perangkat lain otomatis disembunyikan.'
                : '⚠ Hubungi Dewan Pertandingan untuk mengatur ulang slot juri.',
            style: TextStyle(fontSize: 9.5, color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }

  Widget _buildActionKeypadButton(
    String label,
    VoidCallback onTap, {
    bool isDestructive = false,
    IconData? icon,
  }) {
    return Material(
      color: isDestructive ? AppColors.primarySoft : AppColors.surfaceMuted,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isDestructive ? AppColors.primaryBorder : AppColors.border,
            ),
          ),
          child: Center(
            child: icon != null
                ? const Icon(Icons.backspace_rounded, size: 16, color: AppColors.primary)
                : Text(
                    label,
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.bold,
                      color: isDestructive ? AppColors.primaryText : AppColors.textSecondary,
                    ),
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildQrScannerCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: AppDecorations.card(radius: 22),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppColors.blueSoft,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.blueBorder),
                ),
                child: const Icon(
                  Icons.qr_code_scanner_rounded,
                  color: AppColors.blue,
                  size: 21,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Scan Barcode / QR Gelanggang',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    SizedBox(height: 1),
                    Text(
                      'Arahkan kamera ke QR Code pada meja arena',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 10.5, color: AppColors.textMuted),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          Center(
            child: Container(
              width: 210,
              height: 210,
              decoration: BoxDecoration(
                color: _isCameraActive ? Colors.black : AppColors.surfaceMuted,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: _isCameraActive ? AppColors.emerald : AppColors.borderStrong,
                  width: 1.8,
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (_isCameraActive)
                      MobileScanner(
                        controller: _scannerController,
                        onDetect: _onDetectBarcode,
                        errorBuilder: (context, error) {
                          return Container(
                            color: AppColors.surfaceSoft,
                            padding: const EdgeInsets.all(12),
                            child: Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.no_photography_rounded,
                                    color: AppColors.primary,
                                    size: 34,
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Akses kamera gagal: ${error.errorCode.name}\nPastikan izin kamera diberikan.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      )
                    else
                      Center(
                        child: Icon(
                          Icons.qr_code_2_rounded,
                          size: 112,
                          color: AppColors.borderStrong,
                        ),
                      ),

                    if (_isCameraActive)
                      AnimatedBuilder(
                        animation: _laserAnimController,
                        builder: (context, child) {
                          return Positioned(
                            top: _laserAnimController.value * 180 + 12,
                            left: 14,
                            right: 14,
                            child: Container(
                              height: 3,
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [
                                    Colors.transparent,
                                    AppColors.emerald,
                                    Color(0xFF34D399),
                                    Colors.transparent,
                                  ],
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.emerald.withValues(alpha: 0.7),
                                    blurRadius: 8,
                                    spreadRadius: 1.5,
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),

                    if (_isCameraActive)
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              onPressed: () async {
                                await _scannerController?.toggleTorch();
                                setState(() => _isTorchOn = !_isTorchOn);
                              },
                              tooltip: _isTorchOn ? 'Matikan Lampu' : 'Nyalakan Lampu',
                              icon: Icon(
                                _isTorchOn
                                    ? Icons.flash_on_rounded
                                    : Icons.flash_off_rounded,
                                size: 17,
                                color: _isTorchOn ? const Color(0xFFF59E0B) : Colors.white,
                              ),
                              constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
                              padding: EdgeInsets.zero,
                              style: IconButton.styleFrom(backgroundColor: Colors.black54),
                            ),
                            const SizedBox(width: 4),
                            IconButton(
                              onPressed: () => _scannerController?.switchCamera(),
                              tooltip: 'Ganti Kamera Depan/Belakang',
                              icon: const Icon(
                                Icons.flip_camera_ios_rounded,
                                size: 17,
                                color: Colors.white,
                              ),
                              constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
                              padding: EdgeInsets.zero,
                              style: IconButton.styleFrom(backgroundColor: Colors.black54),
                            ),
                          ],
                        ),
                      ),

                    Positioned.fill(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Container(
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: _isCameraActive
                                  ? AppColors.emerald.withValues(alpha: 0.75)
                                  : AppColors.borderStrong,
                              width: 1.5,
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),

                    Positioned(
                      bottom: 8,
                      left: 8,
                      right: 8,
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                          decoration: BoxDecoration(
                            color: _isCameraActive
                                ? Colors.black.withValues(alpha: 0.7)
                                : AppColors.surface.withValues(alpha: 0.92),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: _isCameraActive ? AppColors.emerald : AppColors.border,
                            ),
                          ),
                          child: Text(
                            _isCameraActive
                                ? 'Memindai QR Gelanggang...'
                                : 'Kamera Siap Digunakan',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.bold,
                              color: _isCameraActive
                                  ? const Color(0xFF6EE7B7)
                                  : AppColors.textSecondary,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),

          ElevatedButton.icon(
            onPressed: _toggleCamera,
            icon: Icon(
              _isCameraActive ? Icons.camera_alt_outlined : Icons.camera_alt_rounded,
              size: 16,
            ),
            label: Text(
              _isCameraActive ? 'Tutup Kamera HP' : 'Buka Kamera HP untuk Scan QR',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor:
                  _isCameraActive ? AppColors.textSecondary : AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 11),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 0,
            ),
          ),
        ],
      ),
    );
  }
}
