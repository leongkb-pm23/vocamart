// How this file works:
// 1) Data/models are declared first (if any).
// 2) UI widgets are built in build() methods.
// 3) Helper methods are used to keep UI code clean.

// File purpose: This file handles activities page screen/logic.

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'package:fyp/components/app_store.dart';
import 'package:fyp/components/guest_gate_widgets.dart';
import 'package:fyp/User/login.dart';
import 'package:fyp/components/ui_cards.dart';

// This class defines ActivitiesPage, used for this page/feature.
class ActivitiesPage extends StatelessWidget {
  const ActivitiesPage({super.key});
  static const _orange = Color(0xFFFF6A00);

  bool _isGuest() {
    final user = FirebaseAuth.instance.currentUser;
    return user == null || user.isAnonymous;
  }

  Widget _guestLockedView(BuildContext context) {
    return GuestLockedView(
      message: 'Login required to view activities.',
      accentColor: _orange,
      onLogin: () {
        Navigator.pushNamed(context, LoginPage.routeName);
      },
    );
  }

  @override
  // Builds and returns the UI for this widget.
  Widget build(BuildContext context) {
    final isGuest = _isGuest();
    final store = AppStore.instance;

    if (isGuest) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('More Activities'),
          backgroundColor: _orange,
          foregroundColor: Colors.black,
        ),
        body: _guestLockedView(context),
      );
    }

    return AnimatedBuilder(
      animation: store,
      builder: (context, _) {
        final logs = store.activityLogs;
        return Scaffold(
          appBar: AppBar(
            title: const Text('More Activities'),
            backgroundColor: _orange,
            foregroundColor: Colors.black,
          ),
          body: logs.isEmpty
              ? const Center(
                  child: Text(
                    'No activities yet',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(14),
                  itemCount: logs.length,
                  separatorBuilder: (_, __) {
                    return const SizedBox(height: 8);
                  },
                  itemBuilder: (_, i) {
                    final row = logs[i].split('|');
                    final time = row.first;
                    final message = row.length > 1 ? row[1] : logs[i];

                    return AppCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            message,
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            time,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.black54,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        );
      },
    );
  }
}


