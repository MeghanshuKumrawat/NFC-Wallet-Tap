import 'package:nfc_manager/nfc_manager.dart';
import 'package:nfc_manager_ndef/nfc_manager_ndef.dart';

import 'wallet_pass.dart';

class NfcWalletReader {
  Future<NfcAvailability> availability() =>
      NfcManager.instance.checkAvailability();

  Future<void> start({
    required void Function(WalletPass pass) onRead,
    required void Function(String message) onError,
  }) async {
    await NfcManager.instance.startSession(
      pollingOptions: const {
        NfcPollingOption.iso14443,
        NfcPollingOption.iso15693,
      },
      alertMessageIos: 'Hold your iPhone near the NFC tag.',
      invalidateAfterFirstReadIos: true,
      onSessionErrorIos: (error) => onError(error.message),
      onDiscovered: (tag) async {
        try {
          final ndef = Ndef.from(tag);
          if (ndef == null) {
            throw const FormatException('This tag is not NDEF formatted.');
          }
          final message = ndef.cachedMessage ?? await ndef.read();
          if (message == null) {
            throw const FormatException('The NFC tag is empty.');
          }
          final pass = WalletPassParser.fromMessage(message);
          await NfcManager.instance.stopSession(
            alertMessageIos: 'Wallet link read successfully.',
          );
          onRead(pass);
        } catch (error) {
          await NfcManager.instance.stopSession(
            errorMessageIos: 'Could not read this tag.',
          );
          onError(_messageFor(error));
        }
      },
    );
  }

  Future<void> stop() => NfcManager.instance.stopSession();

  String _messageFor(Object error) {
    if (error is FormatException) return error.message.toString();
    return 'Could not read the NFC tag. Please try again.';
  }
}
