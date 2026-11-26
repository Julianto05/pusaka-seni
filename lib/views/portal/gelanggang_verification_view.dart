import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../services/gelanggang_sync_service.dart';
import '../../services/pusaka_seni_api_service.dart';

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
  List<Map<String, dynamic>> _liveGelanggangs = [];

  // Juri Device Assignment (Locked per mobile device)
  bool get _isJuriRole => widget.roleName.toLowerCase().contains('juri');
  late int _selectedJuri;
  late String _syncedArena;

  // Controllers for soft keyboard on mobile devices
  late final TextEditingController _pinController;
  late final FocusNode _pinFocusNode;

  // Controller for device mobile camera barcode/QR scanner
  MobileScannerController? _scannerController;

  // Animation controller for QR scanner laser
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

    _loadLiveGelanggangs();
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
    if (mounted) {
      setState(() {});
    }
  }

  String get _currentTargetArena {
    if (_pinCode.isNotEmpty) {
      return GelanggangSyncService.normalizeArenaCode(_pinCode);
    }
    return GelanggangSyncService.instance.activeArenaCode;
  }

  Future<void> _loadLiveGelanggangs() async {
    try {
      final list = await PusakaSeniApiService().fetchGelanggangs();
      if (mounted) {
        setState(() {
          _liveGelanggangs = list;
        });
      }
    } catch (_) {}
  }

  void _onKeyPress(String val) {
    if (_pinCode.length < _pinLength) {
      setState(() {
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
        _pinCode = _pinCode.substring(0, _pinCode.length - 1);
        _pinController.text = _pinCode;
        _pinController.selection = TextSelection.collapsed(offset: _pinCode.length);
      });
    }
  }

  void _onReset() {
    setState(() {
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
        final code = raw.trim();
        _handleScannedBarcode(code);
        break;
      }
    }
  }

  void _handleScannedBarcode(String code) {
    final cleanCode = code.replaceAll(RegExp(r'[^0-9A-Za-z\s\-]'), '').trim();
    final upper = cleanCode.toUpperCase();
    String? arenaName;

    if (upper == '87654321' || upper.contains('ARENA-B') || upper.contains('GELANGGANG B') || upper.endsWith(' B')) {
      arenaName = 'GELANGGANG B';
    } else if (upper == '12345678' || upper.contains('ARENA-A') || upper.contains('GELANGGANG A') || upper.endsWith(' A')) {
      arenaName = 'GELANGGANG A';
    }

    setState(() {
      _pinCode = cleanCode;
      _pinController.text = cleanCode;
      _isCameraActive = false;
    });
    _scannerController?.stop();

    _verifyCode(cleanCode, customArenaName: arenaName);
  }

  void _verifyCode(String code, {String? customArenaName}) {
    if (_isVerifying) return;
    setState(() => _isVerifying = true);

    String arenaName = customArenaName ?? '';

    if (arenaName.isEmpty) {
      final clean = code.trim().toUpperCase();
      if (clean == '12345678' || clean == 'ARENA-A' || clean == 'GELANGGANG A' || clean == 'A') {
        arenaName = 'GELANGGANG A';
      } else if (clean == '87654321' || clean == 'ARENA-B' || clean == 'GELANGGANG B' || clean == 'B') {
        arenaName = 'GELANGGANG B';
      } else {
        // Match against live gelanggangs from API
        for (final g in _liveGelanggangs) {
          final c = g['arena_code']?.toString().toUpperCase() ?? '';
          final desc = g['description']?.toString().toUpperCase() ?? '';
          if (c == clean || clean.contains(c) || desc == clean || desc.contains(clean)) {
            arenaName = g['description']?.toString() ?? g['arena_code']?.toString() ?? clean;
            break;
          }
        }
        if (arenaName.isEmpty) {
          arenaName = clean.startsWith('GELANGGANG') || clean.startsWith('ARENA')
              ? clean
              : 'GELANGGANG $clean';
        }
      }
    }

    Timer(const Duration(milliseconds: 300), () async {
      if (!mounted) return;
      final sync = GelanggangSyncService.instance;
      if (_isJuriRole) {
        await sync.pullArenaSync(arenaName);
        if (!mounted) return;
        final available = sync.getAvailableJudgesForThisDevice(arenaCode: arenaName);
        if (available.isEmpty) {
          setState(() => _isVerifying = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Semua nomor juri sudah terisi di $arenaName!'),
              backgroundColor: const Color(0xFFDC2626),
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
      sync.verifyGelanggang(arenaCode: arenaName);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_isJuriRole
              ? 'Gelanggang Terverifikasi: $arenaName • Bertugas: Juri $_selectedJuri'
              : 'Kode Gelanggang Terverifikasi: $arenaName'),
          backgroundColor: const Color(0xFF10B981),
          duration: const Duration(seconds: 2),
        ),
      );

      widget.onVerified(arenaName);
    });
  }

  void _simulateScanQR(String arenaName, String code) {
    setState(() {
      _pinCode = code;
      _pinController.text = code;
    });
    _verifyCode(code, customArenaName: arenaName);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Column(
            children: [
              // 1. Top Bar
              _buildTopBar(),
              const SizedBox(height: 10),

              // 2. Responsive Verification View
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final isWide = constraints.maxWidth >= 780 && constraints.maxHeight >= 480;

                    if (isWide) {
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Left Box: 8-digit Pin Input & Keypad
                          Expanded(
                            flex: 5,
                            child: SingleChildScrollView(
                              physics: const BouncingScrollPhysics(),
                              child: _buildKeypadCard(),
                            ),
                          ),
                          const SizedBox(width: 12),

                          // Right Box: QR Scanner
                          Expanded(
                            flex: 5,
                            child: SingleChildScrollView(
                              physics: const BouncingScrollPhysics(),
                              child: _buildQrScannerCard(),
                            ),
                          ),
                        ],
                      );
                    } else {
                      // Compact / Narrow Screen: Smooth scrollable
                      return SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
                        child: Column(
                          children: [
                            _buildKeypadCard(),
                            const SizedBox(height: 12),
                            _buildQrScannerCard(),
                          ],
                        ),
                      );
                    }
                  },
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
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF334155)),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: widget.onBack,
            tooltip: 'Kembali ke Pilihan Peran',
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 14),
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            padding: EdgeInsets.zero,
            style: IconButton.styleFrom(
              backgroundColor: const Color(0xFF0F172A),
              foregroundColor: const Color(0xFFCBD5E1),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
          const SizedBox(width: 8),

          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: widget.accentColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(widget.roleIcon, color: widget.accentColor, size: 18),
          ),
          const SizedBox(width: 8),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _isJuriRole ? '${widget.roleName} • Juri $_selectedJuri' : widget.roleName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _isJuriRole
                      ? 'Perangkat Terkunci Sebagai Juri $_selectedJuri'
                      : 'Verifikasi 8 Digit Gelanggang',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8)),
                ),
              ],
            ),
          ),

          // Server live indicator
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
            decoration: BoxDecoration(
              color: const Color(0xFF0F172A),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.4)),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.circle, size: 6, color: Color(0xFF10B981)),
                SizedBox(width: 4),
                Text(
                  'Live',
                  style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF6EE7B7),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKeypadCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF334155)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 48,
            height: 48,
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              color: const Color(0xFF0F172A),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFD97706).withValues(alpha: 0.4)),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFF59E0B).withValues(alpha: 0.2),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.asset(
                'assets/images/app_logo_small.png',
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) => Icon(
                  Icons.pin_rounded,
                  color: widget.accentColor,
                  size: 24,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Kode Gelanggang (8 Digit)',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 2),
          const Text(
            'Ketik 8 digit angka arena gelanggang atau pilih dari daftar aktif',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
          ),
          const SizedBox(height: 10),

          // Pilihan Nomor Juri (khusus Role Juri Pertandingan)
          if (_isJuriRole) ...[
            _buildJuriSelectorSection(),
            const SizedBox(height: 10),
          ],

          // 8-Digit Pin Display Box (Clickable to open soft keyboard)
          InkWell(
            onTap: () {
              _pinFocusNode.requestFocus();
            },
            borderRadius: BorderRadius.circular(10),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(_pinLength, (index) {
                  final hasChar = index < _pinCode.length;
                  final isCurrent = index == _pinCode.length;
                  return Container(
                    width: 32,
                    height: 42,
                    margin: const EdgeInsets.symmetric(horizontal: 2.5),
                    decoration: BoxDecoration(
                      color: hasChar ? const Color(0xFF0F172A) : const Color(0xFF0F172A).withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isCurrent
                            ? widget.accentColor
                            : hasChar
                                ? Colors.white54
                                : const Color(0xFF334155),
                        width: isCurrent ? 2.0 : 1.0,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        hasChar ? _pinCode[index] : '•',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'monospace',
                          color: hasChar ? Colors.white : const Color(0xFF64748B),
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ),
          ),
          const SizedBox(height: 8),

          // Mobile Keyboard Trigger & Quick Paste button
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 6,
            runSpacing: 6,
            children: [
              // Button to trigger device soft keyboard
              InkWell(
                onTap: () {
                  if (_pinFocusNode.hasFocus) {
                    _pinFocusNode.unfocus();
                  } else {
                    _pinFocusNode.requestFocus();
                  }
                },
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: _pinFocusNode.hasFocus
                        ? widget.accentColor.withValues(alpha: 0.25)
                        : const Color(0xFF0F172A),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: _pinFocusNode.hasFocus ? widget.accentColor : const Color(0xFF334155),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _pinFocusNode.hasFocus ? Icons.keyboard_hide_rounded : Icons.keyboard_rounded,
                        size: 14,
                        color: _pinFocusNode.hasFocus ? widget.accentColor : const Color(0xFF38BDF8),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        _pinFocusNode.hasFocus ? 'Tutup Keyboard HP' : 'Buka Keyboard HP',
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.bold,
                          color: _pinFocusNode.hasFocus ? Colors.white : const Color(0xFFCBD5E1),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Paste button
              InkWell(
                onTap: _onPaste,
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F172A),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFF334155)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.content_paste_rounded, size: 13, color: Color(0xFF38BDF8)),
                      SizedBox(width: 4),
                      Text(
                        'Tempel / Paste',
                        style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFFCBD5E1)),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Direct Mobile Phone Soft Keyboard Input Field
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 270),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: _pinFocusNode.hasFocus ? widget.accentColor : const Color(0xFF334155),
                  width: _pinFocusNode.hasFocus ? 1.5 : 1.0,
                ),
              ),
              child: TextField(
                controller: _pinController,
                focusNode: _pinFocusNode,
                keyboardType: TextInputType.text,
                textCapitalization: TextCapitalization.characters,
                textInputAction: TextInputAction.done,
                inputFormatters: [
                  LengthLimitingTextInputFormatter(_pinLength),
                ],
                style: const TextStyle(
                  fontSize: 14,
                  letterSpacing: 3,
                  fontFamily: 'monospace',
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
                textAlign: TextAlign.center,
                decoration: InputDecoration(
                  hintText: 'Ketik kode via keyboard HP...',
                  hintStyle: const TextStyle(
                    fontSize: 10.5,
                    letterSpacing: 0.5,
                    color: Color(0xFF64748B),
                  ),
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(vertical: 8),
                  prefixIcon: Icon(
                    Icons.edit_note_rounded,
                    size: 16,
                    color: _pinFocusNode.hasFocus ? widget.accentColor : const Color(0xFF94A3B8),
                  ),
                  prefixIconConstraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                  suffixIcon: _pinCode.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded, size: 14, color: Color(0xFF94A3B8)),
                          onPressed: _onReset,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                        )
                      : null,
                ),
                onChanged: (val) {
                  setState(() {
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
          ),
          const SizedBox(height: 10),

          // Interactive Touch Numeric Keypad
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 270),
            child: GridView.count(
              crossAxisCount: 3,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 6,
              crossAxisSpacing: 6,
              childAspectRatio: 1.8,
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
          const SizedBox(height: 12),

          // Live Arena Quick Presets
          const Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'PILIH ARENA AKTIF:',
              style: TextStyle(
                fontSize: 9.5,
                fontWeight: FontWeight.bold,
                color: Color(0xFF94A3B8),
                letterSpacing: 0.8,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _buildArenaChip(label: 'GELANGGANG A', code: '12345678'),
              _buildArenaChip(label: 'GELANGGANG B', code: '87654321'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildKeypadButton(String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF0F172A),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFF334155)),
        ),
        child: Center(
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.white,
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

    // Auto-align _selectedJuri to first available if current selection is not available
    if (availableJudges.isNotEmpty && !availableJudges.contains(_selectedJuri)) {
      _selectedJuri = availableJudges.first;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          sync.setSelectedJuriNumber(_selectedJuri);
        }
      });
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: widget.accentColor.withValues(alpha: 0.5),
          width: 1.2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.badge_rounded, color: widget.accentColor, size: 14),
              const SizedBox(width: 6),
              const Expanded(
                child: Text(
                  'PILIH NOMOR JURI PERANGKAT INI',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.5,
                    color: Colors.white,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFDC2626).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0xFFDC2626), width: 0.8),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.lock_rounded, size: 9, color: Color(0xFFFCA5A5)),
                    SizedBox(width: 3),
                    Text(
                      'Terkunci di Layar Juri',
                      style: TextStyle(
                        fontSize: 8.5,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFFCA5A5),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Wrap list of available juri buttons (claimed judges are NOT displayed)
          if (availableJudges.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF450A0A),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFDC2626)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline_rounded, color: Color(0xFFFCA5A5), size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Semua nomor juri ($totalJudges Juri) telah dipilih di $arena. Tidak ada slot juri tersisa.',
                      style: const TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFFCA5A5),
                      ),
                    ),
                  ),
                ],
              ),
            )
          else
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: availableJudges.map((jNum) {
                final bool isSelected = jNum == _selectedJuri;

                return InkWell(
                  onTap: () {
                    setState(() {
                      _selectedJuri = jNum;
                    });
                    sync.setSelectedJuriNumber(jNum);
                  },
                  borderRadius: BorderRadius.circular(6),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    constraints: const BoxConstraints(minWidth: 62),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                    decoration: BoxDecoration(
                      color: isSelected ? const Color(0xFFDC2626) : const Color(0xFF1E293B),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: isSelected ? const Color(0xFFFCA5A5) : const Color(0xFF334155),
                        width: isSelected ? 1.4 : 1.0,
                      ),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: const Color(0xFFDC2626).withValues(alpha: 0.4),
                                blurRadius: 5,
                                offset: const Offset(0, 1),
                              ),
                            ]
                          : null,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (isSelected) ...[
                          const Icon(Icons.check_rounded, color: Colors.white, size: 12),
                          const SizedBox(width: 3),
                        ],
                        Text(
                          'Juri $jNum',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: isSelected ? FontWeight.w900 : FontWeight.w600,
                            color: isSelected ? Colors.white : const Color(0xFFCBD5E1),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          const SizedBox(height: 5),
          Text(
            availableJudges.isNotEmpty
                ? '✓ Juri yang sudah dipilih otomatis tidak ditampilkan untuk mencegah pemilihan ganda.'
                : '⚠ Silakan hubungi Dewan Pertandingan untuk mengatur ulang juri yang bertugas.',
            style: const TextStyle(
              fontSize: 9,
              color: Color(0xFF94A3B8),
              fontStyle: FontStyle.italic,
            ),
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
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        decoration: BoxDecoration(
          color: isDestructive
              ? const Color(0xFF450A0A)
              : const Color(0xFF0F172A),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isDestructive ? const Color(0xFF991B1B) : const Color(0xFF334155),
          ),
        ),
        child: Center(
          child: icon != null
              ? Icon(icon, size: 16, color: const Color(0xFFEF4444))
              : Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: isDestructive ? const Color(0xFFFCA5A5) : const Color(0xFF94A3B8),
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildArenaChip({
    required String label,
    required String code,
  }) {
    return InkWell(
      onTap: () {
        setState(() {
          _pinCode = code;
        });
        _verifyCode(code, customArenaName: label);
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: const Color(0xFF0F172A),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFF38BDF8).withValues(alpha: 0.5)),
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.stadium_rounded, size: 13, color: Color(0xFF38BDF8)),
              const SizedBox(width: 4),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                '($code)',
                style: const TextStyle(
                  fontSize: 9,
                  fontFamily: 'monospace',
                  color: Color(0xFF94A3B8),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQrScannerCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF334155)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFF2563EB).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.qr_code_scanner_rounded, color: Color(0xFF60A5FA), size: 24),
          ),
          const SizedBox(height: 8),
          const Text(
            'Scan Barcode / QR Gelanggang',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 2),
          const Text(
            'Arahkan kamera HP ke QR Code yang tercetak pada meja arena atau tiket gelanggang',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
          ),
          const SizedBox(height: 12),

          // Camera QR Viewport Box with Live Mobile Scanner
          Container(
            width: 220,
            height: 220,
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: _isCameraActive
                    ? const Color(0xFF10B981)
                    : const Color(0xFF475569),
                width: 2,
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Live Camera feed via MobileScanner
                  if (_isCameraActive)
                    MobileScanner(
                      controller: _scannerController,
                      onDetect: _onDetectBarcode,
                      errorBuilder: (context, error) {
                        return Container(
                          color: const Color(0xFF0F172A),
                          padding: const EdgeInsets.all(12),
                          child: Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.no_photography_rounded, color: Color(0xFFEF4444), size: 36),
                                const SizedBox(height: 8),
                                Text(
                                  'Akses kamera gagal: ${error.errorCode.name}\nPastikan izin akses kamera diberikan pada HP.',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(fontSize: 10.5, color: Colors.white70),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    )
                  else
                    // Inactive Background Icon
                    Center(
                      child: Opacity(
                        opacity: 0.35,
                        child: const Icon(
                          Icons.qr_code_2_rounded,
                          size: 130,
                          color: Colors.white24,
                        ),
                      ),
                    ),

                  // Animated Scanning Laser Bar
                  if (_isCameraActive)
                    AnimatedBuilder(
                      animation: _laserAnimController,
                      builder: (context, child) {
                        return Positioned(
                          top: _laserAnimController.value * 190 + 10,
                          left: 15,
                          right: 15,
                          child: Container(
                            height: 3,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [
                                  Colors.transparent,
                                  Color(0xFF10B981),
                                  Color(0xFF34D399),
                                  Colors.transparent,
                                ],
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF10B981).withValues(alpha: 0.8),
                                  blurRadius: 8,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),

                  // Camera Control Buttons (Torch & Camera Switch)
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
                              _isTorchOn ? Icons.flash_on_rounded : Icons.flash_off_rounded,
                              size: 18,
                              color: _isTorchOn ? const Color(0xFFF59E0B) : Colors.white,
                            ),
                            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                            padding: EdgeInsets.zero,
                            style: IconButton.styleFrom(
                              backgroundColor: Colors.black54,
                            ),
                          ),
                          const SizedBox(width: 4),
                          IconButton(
                            onPressed: () => _scannerController?.switchCamera(),
                            tooltip: 'Ganti Kamera Depan/Belakang',
                            icon: const Icon(Icons.flip_camera_ios_rounded, size: 18, color: Colors.white),
                            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                            padding: EdgeInsets.zero,
                            style: IconButton.styleFrom(
                              backgroundColor: Colors.black54,
                            ),
                          ),
                        ],
                      ),
                    ),

                  // Target Box Frame
                  Positioned.fill(
                    child: Padding(
                      padding: const EdgeInsets.all(22),
                      child: Container(
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: _isCameraActive
                                ? const Color(0xFF10B981).withValues(alpha: 0.7)
                                : Colors.white12,
                            width: 1.5,
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),

                  // Center Status Text
                  Positioned(
                    bottom: 8,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.75),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          _isCameraActive
                              ? 'Arahkan kamera ke Barcode / QR Gelanggang...'
                              : 'Kamera HP Siap Digunakan',
                          style: TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.bold,
                            color: _isCameraActive ? const Color(0xFF34D399) : Colors.white70,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Toggle Camera Scan Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
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
                backgroundColor: _isCameraActive ? const Color(0xFF0F172A) : const Color(0xFFDC2626),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                elevation: 0,
              ),
            ),
          ),
          const SizedBox(height: 8),

          // Direct QR Scan Simulator Action
          OutlinedButton.icon(
            onPressed: () => _simulateScanQR('GELANGGANG A', '12345678'),
            icon: const Icon(Icons.flash_on_rounded, size: 14, color: Color(0xFFF59E0B)),
            label: const Text(
              'Simulasi Scan QR Arena A (Tes Tanpa Kamera)',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFFCBD5E1),
              side: const BorderSide(color: Color(0xFF475569)),
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ],
      ),
    );
  }
}
