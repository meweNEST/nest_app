// In der NEUEN Datei: lib/test_screen.dart

import 'package:flutter/material.dart';

class MinimalTestScreen extends StatefulWidget {
  const MinimalTestScreen({super.key});

  @override
  State<MinimalTestScreen> createState() => _MinimalTestScreenState();
}

class _MinimalTestScreenState extends State<MinimalTestScreen> {
  int _counter = 0;

  void _increment() {
    setState(() {
      _counter++;
      // Diese Nachricht MUSST du im Terminal sehen, wenn der Button geht.
      print("--- BUTTON FUNKTIONIERT! Neuer Zähler: $_counter ---");
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.teal.shade50,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Das ist der ultimative Test.',
              style: TextStyle(fontSize: 22),
            ),
            const SizedBox(height: 20),
            Text(
              'Zähler: $_counter',
              style: const TextStyle(fontSize: 50, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 40),
            ElevatedButton(
              onPressed: _increment,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
              ),
              child: const Text(
                'DIESEN BUTTON DRÜCKEN',
                style: TextStyle(fontSize: 20),
              ),
            ),
            const SizedBox(height: 20),
            const Text('Erhöht sich der Zähler, wenn du klickst?'),
          ],
        ),
      ),
    );
  }
}
