// How this file works:
// 1) Decides which page the signed-in user should see.
// 2) Checks Firestore role collections in one place only.
// 3) Prevents duplicate role logic across login pages and main.dart.
//
// File purpose: Central auth/role router.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'package:fyp/Admin/admin_panel_page.dart';
import 'package:fyp/delivery_man/delivery_panel_page.dart';
import 'package:fyp/super_admin/super_admin_panel_page.dart';
import 'package:fyp/User/homepage.dart';
import 'package:fyp/User/login.dart';

class AuthRouterGate extends StatelessWidget {
  const AuthRouterGate({super.key});

  Future<bool> _safeDocExists(
      DocumentReference<Map<String, dynamic>> ref,
      ) async {
    try {
      final snap = await ref.get();
      return snap.exists;
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') return false;
      rethrow;
    }
  }

  Future<String> _roleFor(User user) async {
    if (user.isAnonymous) return 'guest';

    final db = FirebaseFirestore.instance;

    final isSuperAdmin = await _safeDocExists(
      db.collection('super_admins').doc(user.uid),
    );
    if (isSuperAdmin) return 'super_admin';

    final isAdmin = await _safeDocExists(
      db.collection('admins').doc(user.uid),
    );
    if (isAdmin) return 'admin';

    var isDelivery = await _safeDocExists(
      db.collection('delivery_staff').doc(user.uid),
    );
    if (isDelivery) return 'delivery';

    try {
      final userDoc = await db.collection('users').doc(user.uid).get();
      final data = userDoc.data() ?? const <String, dynamic>{};
      final role = (data['role'] ?? '').toString().toLowerCase().trim();

      if (role == 'super_admin') return 'super_admin';
      if (role == 'admin') return 'admin';
      if (role == 'delivery' || data['isDelivery'] == true) {
        return 'delivery';
      }
    } on FirebaseException catch (_) {}

    return 'user';
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final authUser = snap.data;
        if (authUser == null) {
          return const LoginPage();
        }

        return FutureBuilder<String>(
          future: _roleFor(authUser),
          builder: (context, roleSnap) {
            if (roleSnap.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }

            final role = roleSnap.data ?? 'user';

            if (role == 'super_admin') {
              return const SuperAdminPanelPage();
            }

            if (role == 'admin') {
              return const AdminPanelPage();
            }

            if (role == 'delivery') {
              return const DeliveryPanelPage();
            }

            return const HomePage();
          },
        );
      },
    );
  }

  static Future<void> goAfterLogin(BuildContext context) async {
    if (!context.mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const AuthRouterGate()),
          (route) => false,
    );
  }
}