import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

class CafeScreen extends StatelessWidget {
  const CafeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Café'),
      ),
      body: const Center(
        child: Text(
          '☕ Café Screen\n\nComing soon!',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 18),
        ),
      ),
    );
  }
}
