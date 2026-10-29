import 'dart:async';

import 'package:flutter/material.dart';
import 'package:nfc_manager/nfc_manager.dart';
import 'package:url_launcher/url_launcher.dart';

import 'nfc_wallet_reader.dart';
import 'wallet_pass.dart';

enum ScanState { idle, scanning, success, error }

class WalletNfcScreen extends StatefulWidget {
  const WalletNfcScreen({super.key, this.reader});

  final NfcWalletReader? reader;

  @override
  State<WalletNfcScreen> createState() => _WalletNfcScreenState();
}

class _WalletNfcScreenState extends State<WalletNfcScreen>
    with SingleTickerProviderStateMixin {
  late final NfcWalletReader _reader = widget.reader ?? NfcWalletReader();
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );

  ScanState _state = ScanState.idle;
  WalletPass? _pass;
  String? _error;

  @override
  void dispose() {
    _pulse.dispose();
    if (_state == ScanState.scanning) unawaited(_reader.stop());
    super.dispose();
  }

  Future<void> _scan() async {
    setState(() {
      _state = ScanState.scanning;
      _error = null;
      _pass = null;
    });
    _pulse.repeat();

    try {
      final availability = await _reader.availability();
      if (!mounted) return;
      if (availability != NfcAvailability.enabled) {
        _showError(
          availability == NfcAvailability.disabled
              ? 'NFC is turned off. Enable it in Settings and try again.'
              : 'This device does not support NFC scanning.',
        );
        return;
      }
      await _reader.start(
        onRead: (pass) {
          if (!mounted) return;
          _pulse.stop();
          setState(() {
            _state = ScanState.success;
            _pass = pass;
          });
        },
        onError: (message) {
          if (mounted) _showError(message);
        },
      );
    } catch (_) {
      if (mounted) _showError('Unable to start NFC. Please try again.');
    }
  }

  void _showError(String message) {
    _pulse.stop();
    setState(() {
      _state = ScanState.error;
      _error = message;
    });
  }

  void _loadDemo(WalletKind kind) {
    final pass = kind == WalletKind.apple
        ? WalletPassParser.fromText(
            'https://demo.example.com/event-pass.pkpass',
            source: 'Sample data',
          )
        : WalletPassParser.fromText(
            'https://pay.google.com/gp/v/save/demo-wallet-token',
            source: 'Sample data',
          );
    _pulse.stop();
    setState(() {
      _state = ScanState.success;
      _pass = pass;
      _error = null;
    });
  }

  Future<void> _openPass() async {
    final uri = Uri.tryParse(_pass?.value ?? '');
    if (uri == null ||
        !await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (mounted) _showError('No app is available to open this wallet link.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
              sliver: SliverList.list(
                children: [
                  const _Header(),
                  const SizedBox(height: 28),
                  _ScannerCard(state: _state, pulse: _pulse, onScan: _scan),
                  const SizedBox(height: 18),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 260),
                    child: switch (_state) {
                      ScanState.success => _PassResult(
                        key: ValueKey(_pass?.value),
                        pass: _pass!,
                        onOpen: _pass!.canOpen ? _openPass : null,
                      ),
                      ScanState.error => _ErrorCard(
                        key: ValueKey(_error),
                        message: _error!,
                        onRetry: _scan,
                      ),
                      _ => const _HowItWorks(key: ValueKey('how-it-works')),
                    },
                  ),
                  const SizedBox(height: 18),
                  _DemoButtons(onSelected: _loadDemo),
                  const SizedBox(height: 18),
                  const _ProtocolNote(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: const Color(0xFF161B21),
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Icon(
            Icons.contactless_rounded,
            color: Color(0xFFD9FF6A),
          ),
        ),
        const SizedBox(width: 13),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'WALLET TAP',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 2.2,
                  color: Color(0xFF6A706F),
                ),
              ),
              Text(
                'NFC pass reader',
                style: TextStyle(
                  fontSize: 24,
                  height: 1.1,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF161B21),
                ),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(100),
          ),
          child: const Row(
            children: [
              Icon(Icons.circle, size: 8, color: Color(0xFF65A84D)),
              SizedBox(width: 6),
              Text(
                'READY',
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ScannerCard extends StatelessWidget {
  const _ScannerCard({
    required this.state,
    required this.pulse,
    required this.onScan,
  });

  final ScanState state;
  final Animation<double> pulse;
  final VoidCallback onScan;

  @override
  Widget build(BuildContext context) {
    final scanning = state == ScanState.scanning;
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
      decoration: BoxDecoration(
        color: const Color(0xFF161B21),
        borderRadius: BorderRadius.circular(30),
        boxShadow: const [
          BoxShadow(
            color: Color(0x24161B21),
            blurRadius: 30,
            offset: Offset(0, 15),
          ),
        ],
      ),
      child: Column(
        children: [
          SizedBox(
            width: 172,
            height: 172,
            child: AnimatedBuilder(
              animation: pulse,
              builder: (context, child) {
                final value = scanning ? pulse.value : 0.0;
                return Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      width: 130 + (value * 34),
                      height: 130 + (value * 34),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: const Color(
                            0xFFD9FF6A,
                          ).withValues(alpha: .45 - value * .35),
                          width: 2,
                        ),
                      ),
                    ),
                    Container(
                      width: 118,
                      height: 118,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Color(0xFFD9FF6A),
                      ),
                      child: Icon(
                        scanning ? Icons.sensors_rounded : Icons.nfc_rounded,
                        size: 54,
                        color: const Color(0xFF161B21),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          Text(
            scanning ? 'Hold near the NFC tag' : 'Tap to read a wallet pass',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 21,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            scanning
                ? 'Keep the phone steady until it vibrates'
                : 'Reads Apple .pkpass and Google Wallet links from NDEF tags',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFFADB3B3),
              fontSize: 13,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 22),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: scanning ? null : onScan,
              style: FilledButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: const Color(0xFF161B21),
                disabledBackgroundColor: const Color(0xFF30363C),
                disabledForegroundColor: Colors.white70,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              icon: scanning
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.contactless_rounded),
              label: Text(scanning ? 'SCANNING…' : 'START NFC SCAN'),
            ),
          ),
        ],
      ),
    );
  }
}

class _PassResult extends StatelessWidget {
  const _PassResult({super.key, required this.pass, this.onOpen});

  final WalletPass pass;
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    final isApple = pass.kind == WalletKind.apple;
    final known = pass.kind != WalletKind.unknown;
    final accent = isApple ? const Color(0xFF161B21) : const Color(0xFF4285F4);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE1E2DD)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: accent,
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(
                  known ? Icons.wallet_rounded : Icons.code_rounded,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      pass.title,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      pass.source,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF727876),
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.check_circle_rounded, color: Color(0xFF65A84D)),
            ],
          ),
          const SizedBox(height: 18),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFF4F4F0),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(
              pass.value,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 12,
                height: 1.45,
                fontFamily: 'monospace',
              ),
            ),
          ),
          if (onOpen != null) ...[
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: onOpen,
                icon: const Icon(Icons.open_in_new_rounded),
                label: Text(
                  isApple ? 'OPEN PKPASS LINK' : 'OPEN IN GOOGLE WALLET',
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({super.key, required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFFFE8E1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded, color: Color(0xFF9F3626)),
          const SizedBox(width: 12),
          Expanded(child: Text(message, style: const TextStyle(height: 1.4))),
          TextButton(onPressed: onRetry, child: const Text('RETRY')),
        ],
      ),
    );
  }
}

class _HowItWorks extends StatelessWidget {
  const _HowItWorks({super.key});

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        Expanded(
          child: _MiniStep(number: '01', label: 'Start scan'),
        ),
        SizedBox(width: 8),
        Icon(Icons.arrow_forward_rounded, size: 18, color: Color(0xFF9B9F9D)),
        SizedBox(width: 8),
        Expanded(
          child: _MiniStep(number: '02', label: 'Tap tag'),
        ),
        SizedBox(width: 8),
        Icon(Icons.arrow_forward_rounded, size: 18, color: Color(0xFF9B9F9D)),
        SizedBox(width: 8),
        Expanded(
          child: _MiniStep(number: '03', label: 'Open pass'),
        ),
      ],
    );
  }
}

class _MiniStep extends StatelessWidget {
  const _MiniStep({required this.number, required this.label});

  final String number;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          number,
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w900,
            color: Color(0xFF777D7A),
          ),
        ),
        const SizedBox(height: 3),
        Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
        ),
      ],
    );
  }
}

class _DemoButtons extends StatelessWidget {
  const _DemoButtons({required this.onSelected});

  final void Function(WalletKind kind) onSelected;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () => onSelected(WalletKind.apple),
            icon: const Icon(Icons.apple_rounded),
            label: const Text('APPLE SAMPLE'),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () => onSelected(WalletKind.google),
            icon: const Icon(Icons.wallet_rounded, color: Color(0xFF4285F4)),
            label: const Text('GOOGLE SAMPLE'),
          ),
        ),
      ],
    );
  }
}

class _ProtocolNote extends StatelessWidget {
  const _ProtocolNote();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFE8E7E1),
        borderRadius: BorderRadius.circular(18),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded, size: 20, color: Color(0xFF5C625F)),
          SizedBox(width: 11),
          Expanded(
            child: Text(
              'Demo mode reads NDEF tags containing a wallet link. Reading a pass directly from Apple Wallet or Google Wallet requires certified VAS / Smart Tap terminal credentials.',
              style: TextStyle(
                fontSize: 12,
                height: 1.5,
                color: Color(0xFF5C625F),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
