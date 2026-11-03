// lib/screens/template_selection_screen.dart
import 'package:flutter/material.dart';

class TemplateSelectionScreen extends StatelessWidget {
  const TemplateSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Choose Template')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            elevation: 2,
            child: ListTile(
              leading: const Icon(Icons.receipt_long),
              title: const Text('EzTempX1'),
              onTap: () {
                Navigator.pop(context, 'eztempx1');
              },
            ),
          ),
        ],
      ),
    );
  }
}
