// How this file works:
// 1) Data/models are declared first (if any).
// 2) UI widgets are built in build() methods.
// 3) Helper methods are used to keep UI code clean.

// File purpose: This file handles price dropping page screen/logic.

import 'package:flutter/material.dart';

import 'package:fyp/User/product_collection_page.dart';

// This class defines PriceDroppingPage, used for this page/feature.
class PriceDroppingPage extends StatelessWidget {
  static const routeName = '/price-dropping';

  const PriceDroppingPage({super.key});

  @override
  // Builds and returns the UI for this widget.
  Widget build(BuildContext context) {
    return ProductCollectionPage(
      title: 'Price Dropping Products',
      searchHint: 'Search price drops...',
      emptyWhenNoSearch: 'No price-drop products yet',
      emptyWhenSearch: 'No products found',
      fallbackIcon: Icons.local_offer_outlined,
      showOldPrice: true,
      source: (store) {
        return store.priceDrops;
      },
    );
  }
}


