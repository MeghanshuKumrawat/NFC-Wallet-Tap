import 'dart:convert';

import 'package:nfc_manager/ndef_record.dart';

enum WalletKind { apple, google, unknown }

class WalletPass {
  const WalletPass({
    required this.kind,
    required this.title,
    required this.value,
    required this.source,
  });

  final WalletKind kind;
  final String title;
  final String value;
  final String source;

  bool get canOpen {
    final uri = Uri.tryParse(value);
    return uri != null &&
        (uri.scheme == 'https' ||
            uri.scheme == 'http' ||
            uri.scheme == 'pkpass');
  }
}

class WalletPassParser {
  static const _uriPrefixes = <int, String>{
    0x00: '',
    0x01: 'http://www.',
    0x02: 'https://www.',
    0x03: 'http://',
    0x04: 'https://',
    0x05: 'tel:',
    0x06: 'mailto:',
    0x23: 'urn:nfc:',
  };

  static WalletPass fromMessage(NdefMessage message) {
    if (message.records.isEmpty) {
      throw const FormatException('The NFC tag does not contain any records.');
    }

    final values = message.records
        .map(_decodeRecord)
        .where((value) => value.trim().isNotEmpty)
        .toList();

    if (values.isEmpty) {
      throw const FormatException('No readable text or link was found.');
    }

    for (final value in values) {
      final parsed = fromText(value, source: 'NFC tag');
      if (parsed.kind != WalletKind.unknown) return parsed;
    }

    return fromText(values.first, source: 'NFC tag');
  }

  static WalletPass fromText(String input, {String source = 'NFC tag'}) {
    final value = input.trim();
    final jsonPass = _fromJson(value, source);
    if (jsonPass != null) return jsonPass;

    final lower = value.toLowerCase();
    if (lower.contains('.pkpass') ||
        lower.startsWith('pkpass:') ||
        lower.contains('apple.com/wallet')) {
      return WalletPass(
        kind: WalletKind.apple,
        title: 'Apple Wallet pass',
        value: value,
        source: source,
      );
    }

    if (lower.contains('pay.google.com/gp/v/') ||
        lower.contains('wallet.google.com') ||
        lower.contains('googlewallet')) {
      return WalletPass(
        kind: WalletKind.google,
        title: 'Google Wallet card',
        value: value,
        source: source,
      );
    }

    return WalletPass(
      kind: WalletKind.unknown,
      title: 'NFC payload',
      value: value,
      source: source,
    );
  }

  static WalletPass? _fromJson(String input, String source) {
    if (!input.startsWith('{')) return null;
    try {
      final data = jsonDecode(input);
      if (data is! Map<String, dynamic>) return null;
      final platform = '${data['platform'] ?? data['wallet'] ?? ''}'
          .toLowerCase();
      final value = '${data['url'] ?? data['passUrl'] ?? data['value'] ?? ''}'
          .trim();
      if (value.isEmpty) return null;
      final kind = platform.contains('apple')
          ? WalletKind.apple
          : platform.contains('google')
          ? WalletKind.google
          : fromText(value, source: source).kind;
      return WalletPass(
        kind: kind,
        title: '${data['title'] ?? _defaultTitle(kind)}',
        value: value,
        source: source,
      );
    } on FormatException {
      return null;
    }
  }

  static String _defaultTitle(WalletKind kind) => switch (kind) {
    WalletKind.apple => 'Apple Wallet pass',
    WalletKind.google => 'Google Wallet card',
    WalletKind.unknown => 'NFC payload',
  };

  static String _decodeRecord(NdefRecord record) {
    final type = utf8.decode(record.type, allowMalformed: true);
    final payload = record.payload;

    if (record.typeNameFormat == TypeNameFormat.wellKnown && type == 'U') {
      if (payload.isEmpty) return '';
      final prefix = _uriPrefixes[payload.first] ?? '';
      return '$prefix${utf8.decode(payload.sublist(1), allowMalformed: true)}';
    }

    if (record.typeNameFormat == TypeNameFormat.wellKnown && type == 'T') {
      if (payload.isEmpty) return '';
      final languageLength = payload.first & 0x3F;
      final start = 1 + languageLength;
      if (start >= payload.length) return '';
      return utf8.decode(payload.sublist(start), allowMalformed: true);
    }

    return utf8.decode(payload, allowMalformed: true);
  }
}
