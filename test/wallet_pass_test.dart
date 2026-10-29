import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:nfc_manager/ndef_record.dart';
import 'package:wallet_nfc_demo/wallet_pass.dart';

void main() {
  group('WalletPassParser', () {
    test('recognizes an Apple pkpass URL', () {
      final pass = WalletPassParser.fromText(
        'https://example.com/passes/ticket.pkpass',
      );

      expect(pass.kind, WalletKind.apple);
      expect(pass.canOpen, isTrue);
    });

    test('recognizes a Google Wallet save URL', () {
      final pass = WalletPassParser.fromText(
        'https://pay.google.com/gp/v/save/example-token',
      );

      expect(pass.kind, WalletKind.google);
      expect(pass.canOpen, isTrue);
    });

    test('decodes an NDEF URI record', () {
      final message = NdefMessage(
        records: [
          NdefRecord(
            typeNameFormat: TypeNameFormat.wellKnown,
            type: Uint8List.fromList([0x55]),
            identifier: Uint8List(0),
            payload: Uint8List.fromList([
              0x04,
              ...'example.com/ticket.pkpass'.codeUnits,
            ]),
          ),
        ],
      );

      final pass = WalletPassParser.fromMessage(message);
      expect(pass.kind, WalletKind.apple);
      expect(pass.value, 'https://example.com/ticket.pkpass');
    });

    test('supports compact JSON payloads', () {
      final pass = WalletPassParser.fromText(
        '{"platform":"google","title":"Demo event","url":"https://wallet.google.com/demo"}',
      );

      expect(pass.kind, WalletKind.google);
      expect(pass.title, 'Demo event');
    });
  });
}
