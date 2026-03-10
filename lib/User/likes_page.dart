// How this file works:
// 1) Data/models are declared first (if any).
// 2) UI widgets are built in build() methods.
// 3) Helper methods are used to keep UI code clean.

// File purpose: This file handles likes page screen/logic.

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'package:fyp/components/app_store.dart';
import 'package:fyp/User/detail_ui.dart';
import 'package:fyp/components/product_list_page.dart';

// This class defines LikesPage, used for this page/feature.
class LikesPage extends StatelessWidget {
  const LikesPage({super.key});

  bool _isGuest() {
    final user = FirebaseAuth.instance.currentUser;
    return user == null || user.isAnonymous;
  }

  void _showLoginMessage(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Please login to like products.')),
    );
  }

  Future<void> _openDetails(
    BuildContext context, {
    required AppStore store,
    required ProductItem product,
  }) async {
    await store.markViewed(product.id);
    if (!context.mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) {
          return ProductDetailPage(product: product);
        },
      ),
    );
  }

  @override
  // Builds and returns the UI for this widget.
  Widget build(BuildContext context) {
    return ProductListPage(
      title: 'My Likes',
      emptyText: 'No liked products yet',
      productsBuilder: (store) {
        return store.likedProducts;
      },
      itemBuilder: (context, store, p, isGuest) {
        return ListTile(
          tileColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: Color(0xFFE6E6E6)),
          ),
          title: Text(
            p.name,
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
          subtitle: Text(
            p.isOutOfStock
                ? 'Out of stock'
                : 'From RM ${p.lowestPrice.toStringAsFixed(2)}',
          ),
          leading: const Icon(Icons.favorite, color: Colors.redAccent),
          trailing: IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: () async {
              if (_isGuest()) {
                _showLoginMessage(context);
                return;
              }
              await store.toggleLike(p.id);
            },
          ),
          onTap: () async {
            await _openDetails(
              context,
              store: store,
              product: p,
            );
          },
        );
      },
    );
  }
}


