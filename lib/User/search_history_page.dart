// How this file works:
// 1) Data/models are declared first (if any).
// 2) UI widgets are built in build() methods.
// 3) Helper methods are used to keep UI code clean.

// File purpose: This file handles search history page screen/logic.

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:fyp/components/guest_gate_widgets.dart';
import 'package:fyp/User/login.dart';
import 'package:fyp/components/user_collection_common.dart';

// This class defines SearchHistoryPage, used for this page/feature.
class SearchHistoryPage extends StatelessWidget {
  const SearchHistoryPage({super.key});
  static const _orange = Color(0xFFFF6A00);

  Widget _guestLocked(BuildContext context) {
    return GuestLockedView(
      message: 'Login required to view search history.',
      accentColor: _orange,
      onLogin: () {
        Navigator.pushNamed(context, LoginPage.routeName);
      },
    );
  }

  @override
  // Builds and returns the UI for this widget.
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null || user.isAnonymous) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Search History'),
          backgroundColor: _orange,
          foregroundColor: Colors.black,
        ),
        body: _guestLocked(context),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Search History'),
        backgroundColor: _orange,
        foregroundColor: Colors.black,
      ),
      body: UserSubcollectionBody(
        uid: user.uid,
        subcollection: 'search_history',
        loadLabel: 'search history',
        permissionDeniedMessage:
            'Permission denied for search history.\nUpdate Firestore rules for users/{uid}/search_history.',
        emptyText: 'No search history yet',
        separatorHeight: 8,
        itemBuilder: (context, doc, _) {
          final d = doc.data();
          final query = (d['query'] ?? '').toString();
          return ListTile(
            tileColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: const BorderSide(color: Color(0xFFE6E6E6)),
            ),
            leading: const Icon(Icons.history),
            title: Text(
              query,
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
          );
        },
      ),
    );
  }
}


