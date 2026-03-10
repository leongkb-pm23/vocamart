// How this file works:
// 1) Data/models are declared first (if any).
// 2) UI widgets are built in build() methods.
// 3) Helper methods are used to keep UI code clean.

// File purpose: This file handles product list page screen/logic.

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'package:fyp/components/app_store.dart';
import 'package:fyp/components/guest_gate_widgets.dart';

typedef ProductListItemBuilder =
    Widget Function(
      BuildContext context,
      AppStore store,
      ProductItem product,
      bool isGuest,
    );

// This class defines ProductListPage, used for this page/feature.
class ProductListPage extends StatelessWidget {
  final String title;
  final String emptyText;
  final List<ProductItem> Function(AppStore store) productsBuilder;
  final ProductListItemBuilder itemBuilder;
  final String? guestLockMessage;
  final VoidCallback? onGuestLogin;
  final double separatorHeight;

  const ProductListPage({
    super.key,
    required this.title,
    required this.emptyText,
    required this.productsBuilder,
    required this.itemBuilder,
    this.guestLockMessage,
    this.onGuestLogin,
    this.separatorHeight = 10,
  });

  bool _isGuest() {
    final user = FirebaseAuth.instance.currentUser;
    return user == null || user.isAnonymous;
  }

  @override
  // Builds and returns the UI for this widget.
  Widget build(BuildContext context) {
    const orange = Color(0xFFFF6A00);
    final store = AppStore.instance;
    final isGuest = _isGuest();

    if (guestLockMessage != null && isGuest) {
      return Scaffold(
        appBar: AppBar(
          title: Text(title),
          backgroundColor: orange,
          foregroundColor: Colors.black,
        ),
        body: GuestLockedView(
          message: guestLockMessage!,
          accentColor: orange,
          onLogin: onGuestLogin ?? () {},
        ),
      );
    }

    return AnimatedBuilder(
      animation: store,
      builder: (context, _) {
        final products = productsBuilder(store);
        return Scaffold(
          appBar: AppBar(
            title: Text(title),
            backgroundColor: orange,
            foregroundColor: Colors.black,
          ),
          body: products.isEmpty
              ? Center(
                  child: Text(
                    emptyText,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(14),
                  itemCount: products.length,
                  separatorBuilder: (_, __) {
                    return SizedBox(height: separatorHeight);
                  },
                  itemBuilder: (context, i) {
                    return itemBuilder(context, store, products[i], isGuest);
                  },
                ),
        );
      },
    );
  }
}


