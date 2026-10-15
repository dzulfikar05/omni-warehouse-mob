import 'package:flutter/material.dart';

class OpnameScannerScreen extends StatelessWidget {
  const OpnameScannerScreen({super.key, required this.sessionCode});
  final String sessionCode;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('OpnameScannerScreen')),
      body: const Center(child: Text('OpnameScannerScreen — Coming soon')),
    );
  }
}

