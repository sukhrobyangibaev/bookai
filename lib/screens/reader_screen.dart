import 'package:flutter/material.dart';

class ReaderScreen extends StatelessWidget {
  const ReaderScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reader'),
      ),
      body: const Center(
        child: Text(
          'Reader Screen',
          style: TextStyle(fontSize: 24),
        ),
      ),
    );
  }
}
