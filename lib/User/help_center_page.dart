// How this file works:
// 1) Data/models are declared first (if any).
// 2) UI widgets are built in build() methods.
// 3) Helper methods are used to keep UI code clean.

// File purpose: This file handles help center page screen/logic.

import 'package:flutter/material.dart';

// This class defines HelpCenterPage, used for this page/feature.
class HelpCenterPage extends StatefulWidget {
  const HelpCenterPage({super.key});

  @override
  State<HelpCenterPage> createState() => _HelpCenterPageState();
}

// This class defines _HelpCenterPageState, used for this page/feature.
class _HelpCenterPageState extends State<HelpCenterPage> {
  static const _orange = Color(0xFFFF6A00);
  final _msgCtrl = TextEditingController();

  @override
  void dispose() {
    _msgCtrl.dispose();
    super.dispose();
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  void _submitSupport() {
    final message = _msgCtrl.text.trim();
    if (message.isEmpty) {
      _showSnack('Please describe your issue.');
      return;
    }
    if (message.length < 8) {
      _showSnack('Message is too short.');
      return;
    }
    _showSnack('Support request submitted');
    _msgCtrl.clear();
  }

  @override
  // Builds and returns the UI for this widget.
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Help Center'),
        backgroundColor: _orange,
        foregroundColor: Colors.black,
      ),
      body: ListView(
        padding: const EdgeInsets.all(14),
        children: [
          const Text(
            'FAQ',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          _faq(
            'How to use voice commands?',
            'Tap the mic icon on home and say/type commands like show vegetables.',
          ),
          _faq(
            'How does price tracker work?',
            'Track a product from product details, then open Price Tracker page.',
          ),
          _faq(
            'How to checkout?',
            'Add products to cart and click Checkout in Cart page.',
          ),
          const SizedBox(height: 16),
          const Text(
            'Contact Support',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _msgCtrl,
            maxLines: 4,
            decoration: const InputDecoration(
              hintText: 'Describe your issue',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 10),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _orange,
              foregroundColor: Colors.black,
            ),
            onPressed: _submitSupport,
            child: const Text(
              'Submit',
              style: TextStyle(fontWeight: FontWeight.w900),
            ),
          ),
        ],
      ),
    );
  }

  Widget _faq(String q, String a) {
    return ExpansionTile(
      tilePadding: EdgeInsets.zero,
      title: Text(q, style: const TextStyle(fontWeight: FontWeight.w800)),
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 12, right: 12, bottom: 10),
          child: Align(alignment: Alignment.centerLeft, child: Text(a)),
        ),
      ],
    );
  }
}


