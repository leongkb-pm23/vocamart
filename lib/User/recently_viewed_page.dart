// How this file works:
// 1) Data/models are declared first (if any).
// 2) UI widgets are built in build() methods.
// 3) Helper methods are used to keep UI code clean.

// File purpose: This file handles recently viewed page screen/logic.

import 'package:flutter/material.dart';

import 'package:fyp/User/detail_ui.dart';
import 'package:fyp/User/login.dart';
import 'package:fyp/components/product_list_page.dart';

// This class defines RecentlyViewedPage, used for this page/feature.
class RecentlyViewedPage extends StatelessWidget {
  const RecentlyViewedPage({super.key});

  @override
  // Builds and returns the UI for this widget.
  Widget build(BuildContext context) {
    return ProductListPage(
      title: 'Recently Viewed',
      emptyText: 'No recently viewed products',
      guestLockMessage: 'Login required to view recently viewed products.',
      onGuestLogin: () {
        Navigator.pushNamed(context, LoginPage.routeName);
      },
      productsBuilder: (store) {
        return store.recentlyViewedProducts;
      },
      itemBuilder: (context, _, p, __) {
        return ListTile(
          tileColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: Color(0xFFE6E6E6)),
          ),
          leading: const Icon(Icons.history_toggle_off),
          title: Text(
            p.name,
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
          subtitle: Text(
            p.isOutOfStock
                ? 'Out of stock'
                : 'Cheapest: ${p.cheapestStore} - RM ${p.lowestPrice.toStringAsFixed(2)}',
          ),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ProductDetailPage(product: p),
              ),
            );
          },
        );
      },
    );
  }
}


