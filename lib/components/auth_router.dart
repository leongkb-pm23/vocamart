// How this file works:
// 1) Data/models are declared first (if any).
// 2) UI widgets are built in build() methods.
// 3) Helper methods are used to keep UI code clean.

// File purpose: This file handles auth router screen/logic.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'package:fyp/Admin/admin_panel_page.dart';
import 'package:fyp/delivery_man/delivery_panel_page.dart';
import 'package:fyp/User/homepage.dart';

// This class defines AuthRouter, used for this page/feature.
class AuthRouter {
  static void _goToAndClear(BuildContext context, Widget page) {
    // Clear back stack so user cannot go back to login with back button.
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => page),
      (route) {
        return false;
      },
    );
  }

  static Future<bool> _safeDocExists(
    DocumentReference<Map<String, dynamic>> ref,
  ) async {
    try {
      // A simple existence check for role documents.
      final snap = await ref.get();
      return snap.exists;
    } on FirebaseException catch (e) {
      // If rules deny access to role collections, treat as "not this role".
      if (e.code == 'permission-denied') return false;
      rethrow;
    }
  }

  static Future<void> goAfterLogin(BuildContext context) async {
    // Central place for role-based navigation right after successful login.
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    if (user.isAnonymous) {
      // Anonymous user always lands on normal Home (guest mode).
      if (!context.mounted) return;
      _goToAndClear(context, const HomePage());
      return;
    }

    final db = FirebaseFirestore.instance;
    // Check admin first (highest priority).
    final isAdmin = await _safeDocExists(db.collection('admins').doc(user.uid));
    var isDelivery = await _safeDocExists(
      db.collection('delivery_staff').doc(user.uid),
    );

    if (!isDelivery) {
      // Fallback for stricter rules where users can't read delivery_staff.
      try {
        // Some rule setups allow reading users/{uid} but not delivery_staff.
        // So we also check role flags in profile document.
        final userDoc = await db.collection('users').doc(user.uid).get();
        final data = userDoc.data() ?? const <String, dynamic>{};
        if ((data['role'] ?? '').toString().toLowerCase() == 'delivery' ||
            data['isDelivery'] == true) {
          isDelivery = true;
        }
      } on FirebaseException catch (_) {}
    }

    if (!context.mounted) return;

    // Route by role.
    if (isAdmin) {
      // Admin has highest priority route.
      _goToAndClear(context, const AdminPanelPage());
      return;
    }

    if (isDelivery) {
      // Delivery account opens delivery workflow screen.
      _goToAndClear(context, const DeliveryPanelPage());
      return;
    }

    // Default signed-in role is normal user -> Home page.
    _goToAndClear(context, const HomePage());
  }
}


