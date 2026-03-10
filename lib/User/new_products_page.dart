// How this file works:
// 1) Data/models are declared first (if any).
// 2) UI widgets are built in build() methods.
// 3) Helper methods are used to keep UI code clean.


import 'package:flutter/material.dart';

import 'package:fyp/User/product_collection_page.dart';

// This class defines NewProductsPage, used for this page/feature.
class NewProductsPage extends StatelessWidget {

  const NewProductsPage({super.key});

  @override
  // Builds and returns the UI for this widget.
  Widget build(BuildContext context) {
    return ProductCollectionPage(
      title: 'Latest Products',
      searchHint: 'Search products',
      emptyWhenNoSearch: 'No latest products yet',
      emptyWhenSearch: 'No products found',
      fallbackIcon: Icons.new_releases_outlined,
      showOldPrice: false,
      source: (store) {
        return store.newProducts;
      },
    );
  }
}


