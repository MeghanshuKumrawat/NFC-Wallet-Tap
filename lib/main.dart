import 'package:flutter/material.dart';

import 'wallet_nfc_screen.dart';

void main() {
  runApp(const WalletNfcDemoApp());
}

class WalletNfcDemoApp extends StatelessWidget {
  const WalletNfcDemoApp({super.key});

  @override
  Widget build(BuildContext context) {
    const ink = Color(0xFF161B21);
    const lime = Color(0xFFD9FF6A);

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Wallet Tap',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: lime,
          brightness: Brightness.light,
          primary: ink,
          surface: const Color(0xFFF7F6F2),
        ),
        scaffoldBackgroundColor: const Color(0xFFF1F0EB),
        fontFamily: 'SF Pro Display',
      ),
      home: const WalletNfcScreen(),
    );
  }
}
