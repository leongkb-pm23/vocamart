// How this file works:
// 1) Data/models are declared first (if any).
// 2) UI widgets are built in build() methods.
// 3) Helper methods are used to keep UI code clean.

// File purpose: This file handles notifications page screen/logic.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:fyp/components/user_collection_common.dart';

// This class defines NotificationsPage, used for this page/feature.
class NotificationsPage extends StatelessWidget {
  const NotificationsPage({super.key});
  static const _orange = Color(0xFFFF6A00);

  void _goBack(BuildContext context) {
    Navigator.maybePop(context);
  }

  Widget _loginRequiredView(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        backgroundColor: _orange,
        foregroundColor: Colors.black,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => _goBack(context),
        ),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Login required to view notifications',
                style: TextStyle(fontWeight: FontWeight.w800),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () => _goBack(context),
                icon: const Icon(Icons.arrow_back),
                label: const Text('Return'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _markAsRead(DocumentReference<Map<String, dynamic>> ref) async {
    await ref.set({'read': true}, SetOptions(merge: true));
  }

  @override
  // Builds and returns the UI for this widget.
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null || user.isAnonymous) {
      return _loginRequiredView(context);
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        backgroundColor: _orange,
        foregroundColor: Colors.black,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => _goBack(context),
        ),
      ),
      body: UserSubcollectionBody(
        uid: user.uid,
        subcollection: 'notifications',
        loadLabel: 'notifications',
        permissionDeniedMessage:
            'Permission denied for notifications.\nUpdate Firestore rules for users/{uid}/notifications.',
        emptyText: 'No notifications yet',
        separatorHeight: 8,
        itemBuilder: (context, d, _) {
          final n = d.data();
          final read = n['read'] == true;

          return ListTile(
            tileColor: read ? Colors.white : const Color(0xFFFFF7EE),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: const BorderSide(color: Color(0xFFE6E6E6)),
            ),
            leading: Icon(
              read ? Icons.notifications_none : Icons.notifications_active,
              color: _orange,
            ),
            title: Text(
              (n['title'] ?? '').toString(),
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
            subtitle: Text((n['message'] ?? '').toString()),
            onTap: () {
              _markAsRead(d.reference);
            },
          );
        },
      ),
    );
  }
}


