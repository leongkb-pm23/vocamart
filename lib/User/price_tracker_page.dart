// How this file works:
// 1) Data/models are declared first (if any).
// 2) UI widgets are built in build() methods.
// 3) Helper methods are used to keep UI code clean.

// File purpose: This file handles price tracker page screen/logic.

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'package:fyp/components/app_store.dart';
import 'package:fyp/User/detail_ui.dart';
import 'package:fyp/components/ui_cards.dart';

// This class defines PriceTrackerPage, used for this page/feature.
class PriceTrackerPage extends StatelessWidget {
  static const kOrange = Color(0xFFFF6A00);

  const PriceTrackerPage({super.key});

  void _showSnack(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<double?> _pickTargetPrice(
    BuildContext context, {
    double? currentTarget,
  }) async {
    // Returns null if dialog is cancelled.
    final ctrl = TextEditingController(text: currentTarget?.toStringAsFixed(2) ?? '');
    final picked = await showDialog<double?>(
      context: context,
      builder: (dialogContext) {
        String? errorText;
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            return AlertDialog(
              title: const Text('Set Target Price'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: ctrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Notify when <= RM',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    if (errorText != null) ...[
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          errorText!,
                          style: const TextStyle(
                            color: Colors.red,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(dialogContext);
                  },
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    final raw = ctrl.text.trim();
                    if (raw.isEmpty) {
                      Navigator.pop(dialogContext, null);
                      return;
                    }
                    final value = double.tryParse(raw);
                    if (value == null || value <= 0) {
                      setDialogState(() {
                        errorText = 'Enter a valid number greater than 0, or leave empty.';
                      });
                      return;
                    }
                    Navigator.pop(dialogContext, value);
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
    return picked;
  }

  Future<void> _openDetails(BuildContext context, ProductItem product) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ProductDetailPage(product: product),
      ),
    );
  }

  Future<void> _removeTracked(
    BuildContext context,
    AppStore store,
    String productId,
    bool isGuest,
  ) async {
    if (isGuest) {
      _showSnack(context, 'Please login to track prices.');
      return;
    }
    // toggleTrackProduct removes item when it is already tracked.
    await store.toggleTrackProduct(productId);
  }

  Future<void> _addItemToCart(
    BuildContext context,
    AppStore store,
    ProductItem product,
    bool isGuest,
  ) async {
    if (isGuest) {
      _showSnack(context, 'Please login to add items to cart.');
      return;
    }
    if (product.isOutOfStock) {
      _showSnack(context, '${product.name} is out of stock.');
      return;
    }
    final ok = await store.addToCart(product.id);
    if (!context.mounted) return;
    if (!ok) {
      _showSnack(context, '${product.name} is out of stock.');
      return;
    }
    _showSnack(context, '${product.name} added to cart');
  }

  Future<void> _setTarget(
    BuildContext context,
    AppStore store,
    ProductItem product,
    double? target,
    bool isGuest,
  ) async {
    if (isGuest) {
      _showSnack(context, 'Please login to track prices.');
      return;
    }
    // User can update target without removing tracked item.
    final picked = await _pickTargetPrice(context, currentTarget: target);
    await store.setTrackTargetPrice(product.id, picked);
  }

  List<Widget> _priceRows(ProductItem product) {
    final rows = <Widget>[];
    for (final item in product.prices) {
      rows.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  item.store,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              Text(
                'RM ${item.price.toStringAsFixed(2)}',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: item.price == product.lowestPrice ? kOrange : Colors.black,
                ),
              ),
            ],
          ),
        ),
      );
    }
    return rows;
  }

  @override
  // Builds and returns the UI for this widget.
  Widget build(BuildContext context) {
    final store = AppStore.instance;
    final user = FirebaseAuth.instance.currentUser;
    final isGuest = user == null || user.isAnonymous;

    return AnimatedBuilder(
      animation: store,
      builder: (context, _) {
        // Always read latest tracked list from AppStore.
        final tracked = store.trackedProducts;

        return Scaffold(
          appBar: AppBar(
            title: const Text('Price Tracker'),
            backgroundColor: kOrange,
            foregroundColor: Colors.black,
          ),
          body: tracked.isEmpty
              ? const Center(
                child: Padding(
                  padding: EdgeInsets.all(18),
                  child: Text(
                    'No tracked product yet. Open any product and tap Track Price.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              )
              : ListView.separated(
                padding: const EdgeInsets.all(14),
                itemCount: tracked.length,
                separatorBuilder: (_, __) {
                  return const SizedBox(height: 10);
                },
                itemBuilder: (_, i) {
                  final p = tracked[i];
                  final target = store.trackedTargetPrice(p.id);
                  return AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                p.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                            IconButton(
                              onPressed: () async {
                                await _removeTracked(
                                  context,
                                  store,
                                  p.id,
                                  isGuest,
                                );
                              },
                              icon: const Icon(Icons.delete_outline),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        ..._priceRows(p),
                        const SizedBox(height: 4),
                        Text(
                          'Cheapest: ${p.cheapestStore}',
                          style: const TextStyle(
                            color: kOrange,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        if (p.isOutOfStock)
                          const Text(
                            'Out of stock',
                            style: TextStyle(
                              color: Colors.redAccent,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        if (target != null)
                          Text(
                            'Target: RM ${target.toStringAsFixed(2)}',
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () async {
                                  await _openDetails(context, p);
                                },
                                child: const Text('Details'),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: kOrange,
                                  foregroundColor: Colors.black,
                                  alignment: Alignment.center,
                                ),
                                onPressed: () async {
                                  await _addItemToCart(
                                    context,
                                    store,
                                    p,
                                    isGuest,
                                  );
                                },
                                child: Text(
                                  p.isOutOfStock ? 'Out of Stock' : 'Add to Cart',
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () async {
                                  await _setTarget(
                                    context,
                                    store,
                                    p,
                                    target,
                                    isGuest,
                                  );
                                },
                                child: const Text('Target'),
                              ),
                            ),
                          ],
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


