// How this file works:
// 1) Data/models are declared first (if any).
// 2) UI widgets are built in build() methods.
// 3) Helper methods are used to keep UI code clean.

// File purpose: This file handles user collection common screen/logic.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

Future<bool> canReadUserSubcollection({
  required String uid,
  required String subcollection,
}) async {
  try {
    await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection(subcollection)
        .limit(1)
        .get();
    return true;
  } on FirebaseException catch (e) {
    if (e.code == 'permission-denied') return false;
    rethrow;
  }
}

Widget userCollectionLoading() {
  return const Center(child: CircularProgressIndicator());
}

Widget userCollectionError(String text) {
  return Center(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
    ),
  );
}

// This class defines UserSubcollectionBody, used for this page/feature.
class UserSubcollectionBody extends StatelessWidget {
  final String uid;
  final String subcollection;
  final String loadLabel;
  final String permissionDeniedMessage;
  final String emptyText;
  final double separatorHeight;
  final Widget Function(
    BuildContext context,
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
    int index,
  )
  itemBuilder;

  const UserSubcollectionBody({
    super.key,
    required this.uid,
    required this.subcollection,
    required this.loadLabel,
    required this.permissionDeniedMessage,
    required this.emptyText,
    required this.itemBuilder,
    this.separatorHeight = 8,
  });

  @override
  // Builds and returns the UI for this widget.
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: canReadUserSubcollection(uid: uid, subcollection: subcollection),
      builder: (context, accessSnap) {
        if (accessSnap.connectionState == ConnectionState.waiting) {
          return userCollectionLoading();
        }
        if (accessSnap.hasError) {
          return userCollectionError('Failed to load $loadLabel.\n${accessSnap.error}');
        }
        if (accessSnap.data != true) {
          return userCollectionError(permissionDeniedMessage);
        }

        final stream = FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .collection(subcollection)
            .orderBy('createdAt', descending: true)
            .limit(100)
            .snapshots();

        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: stream,
          builder: (context, snap) {
            if (snap.hasError) {
              return userCollectionError('Failed to load $loadLabel.\n${snap.error}');
            }
            if (!snap.hasData) {
              return userCollectionLoading();
            }
            final docs = snap.data!.docs;

            if (docs.isEmpty) {
              return Center(
                child: Text(
                  emptyText,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              );
            }

            return ListView.separated(
              padding: const EdgeInsets.all(14),
              itemCount: docs.length,
              separatorBuilder: (_, __) {
                return SizedBox(height: separatorHeight);
              },
              itemBuilder: (context, i) {
                return itemBuilder(context, docs[i], i);
              },
            );
          },
        );
      },
    );
  }
}


