// How this file works:
// 1) Data/models are declared first (if any).
// 2) UI widgets are built in build() methods.
// 3) Helper methods are used to keep UI code clean.

// File purpose: This file handles guest gate widgets screen/logic.

import 'package:flutter/material.dart';

// This class defines GuestLockedView, used for this page/feature.
class GuestLockedView extends StatelessWidget {
  final String message;
  final VoidCallback onLogin;
  final Color accentColor;

  const GuestLockedView({
    super.key,
    required this.message,
    required this.onLogin,
    this.accentColor = const Color(0xFFFF6A00),
  });

  @override
  // Builds and returns the UI for this widget.
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.lock_outline, size: 46, color: accentColor),
            const SizedBox(height: 10),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: accentColor,
                foregroundColor: Colors.black,
              ),
              onPressed: onLogin,
              child: const Text('Login'),
            ),
          ],
        ),
      ),
    );
  }
}


