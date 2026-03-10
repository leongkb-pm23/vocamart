// How this file works:
// 1) Data/models are declared first (if any).
// 2) UI widgets are built in build() methods.
// 3) Helper methods are used to keep UI code clean.

// File purpose: This file handles product collection page screen/logic.

import 'package:flutter/material.dart';

import 'package:fyp/components/app_store.dart';
import 'package:fyp/User/detail_ui.dart';
import 'package:fyp/components/product_grid_widgets.dart';

// This class defines ProductCollectionPage, used for this page/feature.
class ProductCollectionPage extends StatefulWidget {
  final String title;
  final String searchHint;
  final String emptyWhenNoSearch;
  final String emptyWhenSearch;
  final IconData fallbackIcon;
  final bool showOldPrice;
  final List<ProductItem> Function(AppStore store) source;

  const ProductCollectionPage({
    super.key,
    required this.title,
    required this.searchHint,
    required this.emptyWhenNoSearch,
    required this.emptyWhenSearch,
    required this.fallbackIcon,
    required this.showOldPrice,
    required this.source,
  });

  @override
  State<ProductCollectionPage> createState() => _ProductCollectionPageState();
}

// This class defines _ProductCollectionPageState, used for this page/feature.
class _ProductCollectionPageState extends State<ProductCollectionPage> {
  String _search = '';

  List<ProductItem> _filteredItems(AppStore store) {
    final keyword = _search.trim().toLowerCase();
    final items = widget.source(store);
    if (keyword.isEmpty) return items;

    final result = <ProductItem>[];
    for (final product in items) {
      if (product.name.toLowerCase().contains(keyword)) {
        result.add(product);
      }
    }
    return result;
  }

  @override
  // Builds and returns the UI for this widget.
  Widget build(BuildContext context) {
    final store = AppStore.instance;

    return AnimatedBuilder(
      animation: store,
      builder: (context, _) {
        final items = _filteredItems(store);

        return Scaffold(
          appBar: AppBar(
            title: Text(widget.title),
            backgroundColor: const Color(0xFFFF6A00),
            foregroundColor: Colors.black,
          ),
          body: SafeArea(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 18),
              children: [
                ProductSearchBox(
                  hintText: widget.searchHint,
                  onChanged: (v) {
                    setState(() {
                      _search = v;
                    });
                  },
                ),
                const SizedBox(height: 14),
                if (items.isEmpty)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      child: Text(
                        _search.trim().isEmpty
                            ? widget.emptyWhenNoSearch
                            : widget.emptyWhenSearch,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                  )
                else
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: items.length,
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      childAspectRatio: 0.72,
                    ),
                    itemBuilder: (_, index) {
                      final p = items[index];
                      return ProductGridCard(
                        title: p.name,
                        price: p.isOutOfStock
                            ? 'Out of stock'
                            : 'RM ${p.lowestPrice.toStringAsFixed(2)}',
                        stockQty: p.quantity,
                        oldPrice: widget.showOldPrice &&
                                p.oldPrice != null &&
                                !p.isOutOfStock
                            ? 'RM ${p.oldPrice!.toStringAsFixed(2)}'
                            : null,
                        isOutOfStock: p.isOutOfStock,
                        imageUrl: p.imageUrl,
                        fallbackIcon: widget.fallbackIcon,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) {
                                return ProductDetailPage(product: p);
                              },
                            ),
                          );
                        },
                      );
                    },
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}


