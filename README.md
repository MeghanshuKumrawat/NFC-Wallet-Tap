# Wallet Tap

A one-screen Flutter demo that reads NFC NDEF tags containing either:

- an Apple Wallet `.pkpass` URL
- a Google Wallet Save/object URL
- a compact JSON object with `platform`, `title`, and `url`

The result is classified and can be opened in the matching wallet flow. Built-in
Apple and Google sample buttons make the result states testable without NFC
hardware.

## Run

```sh
flutter pub get
flutter run
```

Use a physical Android or iPhone device for NFC; simulators do not expose NFC
tag reading. On iOS, choose a development team and enable the NFC Tag Reading
capability for the app identifier before installing.

## Demo tag payloads

Program an NDEF URI or text record with one of these shapes:

```text
https://example.com/passes/event.pkpass
https://pay.google.com/gp/v/save/<signed-jwt>
{"platform":"apple","title":"Event pass","url":"https://example.com/event.pkpass"}
```

## Protocol boundary

This app reads ordinary NDEF tags. It does not impersonate a certified payment
or access terminal. Reading a pass directly from Apple Wallet requires Apple
VAS credentials and supported terminal hardware; Google Wallet Smart Tap has a
similar issuer/collector configuration and certification flow.
