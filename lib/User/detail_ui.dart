// How this file works:
// 1) Data/models are declared first (if any).
// 2) UI widgets are built in build() methods.
// 3) Helper methods are used to keep UI code clean.

// File purpose: This file handles detail ui screen/logic.

import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:fyp/components/app_store.dart';

// This class defines ProductDetailPage, used for this page/feature.
class ProductDetailPage extends StatelessWidget {
  static const kOrange = Color(0xFFFF6A00);

  final ProductItem product;

  const ProductDetailPage({super.key, required this.product});

  bool _isHttpImageUrl(String? raw) {
    if (raw == null || raw.trim().isEmpty) return false;
    final uri = Uri.tryParse(raw.trim());
    return uri != null && (uri.scheme == 'http' || uri.scheme == 'https');
  }

  bool _isValidMoneyInput(String raw) {
    final parsed = double.tryParse(raw.trim());
    return parsed != null && parsed > 0;
  }

  bool _isGuest() {
    final user = FirebaseAuth.instance.currentUser;
    return user == null || user.isAnonymous;
  }

  void _showGuestBlocked(BuildContext context, String action) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Please login to $action.')));
  }

  List<Widget> _priceRows(ProductItem currentProduct) {
    // Build one row per store price to show comparison clearly.
    final rows = <Widget>[];
    final bestInStock = currentProduct.cheapestInStockPrice;
    for (final priceItem in currentProduct.prices) {
      final qty = priceItem.stockQty;
      final isOut = qty != null && qty <= 0;
      final isBestInStock =
          bestInStock != null &&
          bestInStock.storeId.trim().toLowerCase() ==
              priceItem.storeId.trim().toLowerCase() &&
          (bestInStock.price - priceItem.price).abs() < 0.0001;
      rows.add(
        Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFE6E6E6)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      priceItem.distanceKm == null
                          ? priceItem.store
                          : '${priceItem.store} (${priceItem.distanceKm!.toStringAsFixed(1)} km)',
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      qty == null
                          ? 'Qty: -'
                          : (qty <= 0 ? 'Qty: 0 (Out of stock)' : 'Qty: $qty'),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: isOut ? Colors.redAccent : Colors.black54,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                'RM ${priceItem.price.toStringAsFixed(2)}',
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  color:
                      isBestInStock
                          ? kOrange
                          : Colors.black,
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

    return AnimatedBuilder(
      animation: store,
      builder: (context, _) {
        final liveProduct = store.productById(product.id) ?? product;
        final availableQty = liveProduct.totalStoreStock;
        final outOfStock = availableQty <= 0 && !liveProduct.hasAnyStoreInStock;
        final liked = store.likedProductIds.contains(product.id);
        final tracked = store.trackedProductIds.contains(product.id);
        final target = store.trackedTargetPrice(product.id);

        return Scaffold(
          appBar: AppBar(
            title: Text(liveProduct.name),
            backgroundColor: kOrange,
            foregroundColor: Colors.black,
            actions: [
              IconButton(
                onPressed: () async {
                  if (_isGuest()) {
                    _showGuestBlocked(context, 'like products');
                    return;
                  }
                  await store.toggleLike(product.id);
                },
                icon: Icon(liked ? Icons.favorite : Icons.favorite_border),
              ),
            ],
          ),
          body: SafeArea(
            child: ListView(
              padding: const EdgeInsets.all(14),
              children: [
                Container(
                  height: 180,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F1F1),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child:
                      _isHttpImageUrl(product.imageUrl)
                          ? ClipRRect(
                            borderRadius: BorderRadius.circular(14),
                            child: Image.network(
                              product.imageUrl!,
                              width: double.infinity,
                              height: double.infinity,
                              fit: BoxFit.cover,
                              errorBuilder:
                                  (_, __, ___) => const Icon(
                                    Icons.local_grocery_store,
                                    size: 72,
                                    color: Colors.black45,
                                  ),
                            ),
                          )
                          : const Icon(
                            Icons.local_grocery_store,
                            size: 72,
                            color: Colors.black45,
                          ),
                ),
                const SizedBox(height: 14),
                Text(
                  liveProduct.name,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '${liveProduct.unit} - ${liveProduct.category}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: Colors.black54,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  outOfStock
                      ? 'Stock: 0'
                      : 'Stock available: $availableQty',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: outOfStock ? Colors.redAccent : Colors.black87,
                  ),
                ),
                if (outOfStock) ...[
                  const SizedBox(height: 6),
                  const Text(
                    'Out of stock',
                    style: TextStyle(
                      color: Colors.redAccent,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
                const SizedBox(height: 10),
                Text(
                  liveProduct.description,
                  style: const TextStyle(height: 1.3),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Price Comparison',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: kOrange,
                  ),
                ),
                const SizedBox(height: 8),
                if (liveProduct.prices.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 8),
                    child: Text(
                      'No price data available yet.',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  )
                else
                  ..._priceRows(liveProduct),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          if (_isGuest()) {
                            _showGuestBlocked(context, 'track prices');
                            return;
                          }
                          if (tracked) {
                            // If already tracked, pressing button again untracks it.
                            await store.toggleTrackProduct(product.id);
                            return;
                          }
                          final ctrl = TextEditingController();
                          final picked = await showDialog<double?>(
                            context: context,
                            builder: (dialogContext) {
                              String? errorText;
                              return StatefulBuilder(
                                builder: (dialogContext, setDialogState) {
                                  return AlertDialog(
                                    title: const Text('Track Target Price'),
                                    content: SingleChildScrollView(
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          TextField(
                                            controller: ctrl,
                                            keyboardType: TextInputType.number,
                                            decoration: const InputDecoration(
                                              labelText:
                                                  'Notify when price <= (RM)',
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
                                          if (!_isValidMoneyInput(raw)) {
                                            setDialogState(() {
                                              errorText =
                                                  'Enter a valid target price greater than 0.';
                                            });
                                            return;
                                          }
                                          Navigator.pop(
                                            dialogContext,
                                            double.parse(raw),
                                          );
                                        },
                                        child: const Text('Save'),
                                      ),
                                    ],
                                  );
                                },
                              );
                            },
                          );
                          // Create tracked item with optional target value.
                          await store.toggleTrackProduct(
                            product.id,
                            targetPrice: picked,
                          );
                        },
                        icon: Icon(
                          tracked ? Icons.visibility_off : Icons.track_changes,
                        ),
                        label: Text(
                          tracked
                              ? (target != null
                                  ? 'Untrack (<= RM ${target.toStringAsFixed(2)})'
                                  : 'Untrack Price')
                              : 'Track Price',
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: kOrange,
                          foregroundColor: Colors.black,
                        ),
                        onPressed: () async {
                          if (_isGuest()) {
                            _showGuestBlocked(context, 'add items to cart');
                            return;
                          }
                          if (outOfStock) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Product is out of stock.'),
                              ),
                            );
                            return;
                          }
                          // Cart write is done in AppStore so all pages stay in sync.
                          final ok = await store.addToCart(product.id);
                          if (!context.mounted) return;
                          if (!ok) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Product is out of stock.'),
                              ),
                            );
                            return;
                          }
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                '${liveProduct.name} added to cart',
                              ),
                            ),
                          );
                        },
                        icon: const Icon(Icons.add_shopping_cart),
                        label: Text(
                          outOfStock ? 'Out of Stock' : 'Add to Cart',
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                _ProductReviewsList(
                  productId: liveProduct.id,
                  productName: liveProduct.name,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ProductReviewsList extends StatelessWidget {
  final String productId;
  final String productName;

  const _ProductReviewsList({required this.productId, required this.productName});

  String _norm(String raw) {
    return raw.trim().toLowerCase();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Reviews',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w900,
            color: ProductDetailPage.kOrange,
          ),
        ),
        const SizedBox(height: 8),
        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream:
              FirebaseFirestore.instance
                  .collection('product_reviews')
                  .where('status', isEqualTo: 'published')
                  .snapshots(),
          builder: (context, snap) {
            if (snap.hasError) {
              return Text(
                'Unable to load reviews right now: ${snap.error}',
                style: TextStyle(
                  color: Colors.black54,
                  fontWeight: FontWeight.w700,
                ),
              );
            }
            if (!snap.hasData) {
              return const SizedBox.shrink();
            }

            final rows = <QueryDocumentSnapshot<Map<String, dynamic>>>[];
            final targetPid = _norm(productId);
            final targetName = _norm(productName);
            for (final doc in snap.data!.docs) {
              final data = doc.data();
              final pid = _norm((data['productId'] ?? data['productID'] ?? data['product_id'] ?? '').toString());
              if (pid == targetPid) {
                rows.add(doc);
                continue;
              }
              // Legacy fallback when old review docs used inconsistent productId.
              final reviewName = _norm((data['productName'] ?? data['title'] ?? '').toString());
              if (reviewName.isNotEmpty && reviewName == targetName) {
                rows.add(doc);
              }
            }
            rows.sort((a, b) {
              DateTime asDate(Object? value) {
                if (value is Timestamp) return value.toDate();
                if (value is DateTime) return value;
                return DateTime.fromMillisecondsSinceEpoch(0);
              }

              final aData = a.data();
              final bData = b.data();
              final aTime = asDate(aData['updatedAt'] ?? aData['createdAt']);
              final bTime = asDate(bData['updatedAt'] ?? bData['createdAt']);
              return bTime.compareTo(aTime);
            });

            if (rows.isEmpty) {
              return Text('No reviews yet for product ID: $productId');
            }

            final cards = <Widget>[];
            final count = rows.length < 5 ? rows.length : 5;
            for (var i = 0; i < count; i++) {
              final data = rows[i].data();
              final rating =
                  (data['rating'] is num) ? (data['rating'] as num).toInt() : 0;
              final stars = '*' * rating.clamp(0, 5);
              cards.add(
                Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFE6E6E6)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        (data['userName'] ?? data['userEmail'] ?? 'User')
                            .toString(),
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      Text('Rating: $stars'),
                      Text((data['comment'] ?? '').toString()),
                    ],
                  ),
                ),
              );
            }

            return Column(children: cards);
          },
        ),
      ],
    );
  }
}

// This class defines CardDetailPage, used for this page/feature.
class CardDetailPage extends StatelessWidget {
  const CardDetailPage({super.key});

  String? _required(String? v, String label) {
    if (v == null || v.trim().isEmpty) return '$label is required.';
    return null;
  }

  String? _validateCardNumber(String? v) {
    final value = (v ?? '').trim();
    if (value.isEmpty) return 'Card number is required.';
    if (!RegExp(r'^\d{12,19}$').hasMatch(value)) {
      return 'Card number must be 12-19 digits.';
    }
    return null;
  }

  String _formatExpiry(String input) {
    final digits = input.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) return '';
    if (digits.length <= 2) return digits;
    final mm = digits.substring(0, 2);
    final yy = digits.substring(2, digits.length > 4 ? 4 : digits.length);
    return '$mm/$yy';
  }

  String? _validateExpiry(String? v) {
    final value = (v ?? '').trim();
    if (value.isEmpty) return 'Expiry is required.';
    if (!RegExp(r'^(0[1-9]|1[0-2])\/\d{2}$').hasMatch(value)) {
      return 'Expiry must be MM/YY.';
    }

    final parts = value.split('/');
    final month = int.parse(parts[0]);
    final year2 = int.parse(parts[1]);
    final now = DateTime.now();
    final currentYear2 = now.year % 100;
    final currentMonth = now.month;

    if (year2 < currentYear2 ||
        (year2 == currentYear2 && month < currentMonth)) {
      return 'Card is expired.';
    }

    return null;
  }

  Future<void> _showAddCard(BuildContext context) async {
    final formKey = GlobalKey<FormState>();
    final typeCtrl = TextEditingController(text: 'Visa');
    final holderCtrl = TextEditingController();
    final numberCtrl = TextEditingController();
    final expiryCtrl = TextEditingController();

    bool saving = false;

    // Dialog validates card details field-by-field while typing.
    await showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            return AlertDialog(
              title: const Text('Add Payment Method'),
              content: SingleChildScrollView(
                child: Form(
                  key: formKey,
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        controller: typeCtrl,
                        textInputAction: TextInputAction.next,
                        validator: (v) => _required(v, 'Card type'),
                        decoration: const InputDecoration(
                          labelText: 'Type (Visa/Master)',
                        ),
                      ),
                      TextFormField(
                        controller: holderCtrl,
                        textInputAction: TextInputAction.next,
                        validator: (v) => _required(v, 'Card holder'),
                        decoration: const InputDecoration(
                          labelText: 'Card Holder',
                        ),
                      ),
                      TextFormField(
                        controller: numberCtrl,
                        textInputAction: TextInputAction.next,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(19),
                        ],
                        validator: _validateCardNumber,
                        decoration: const InputDecoration(
                          labelText: 'Card Number',
                        ),
                      ),
                      TextFormField(
                        controller: expiryCtrl,
                        textInputAction: TextInputAction.done,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(4),
                        ],
                        onChanged: (value) {
                          final formatted = _formatExpiry(value);
                          if (formatted != expiryCtrl.text) {
                            expiryCtrl.value = TextEditingValue(
                              text: formatted,
                              selection: TextSelection.collapsed(
                                offset: formatted.length,
                              ),
                            );
                          }
                        },
                        validator: _validateExpiry,
                        decoration: const InputDecoration(
                          labelText: 'Expiry (MM/YY)',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed:
                      saving
                          ? null
                          : () {
                            Navigator.pop(dialogContext);
                          },
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed:
                      saving
                          ? null
                          : () async {
                            if (!formKey.currentState!.validate()) return;

                            final type = typeCtrl.text.trim();
                            final holder = holderCtrl.text.trim();
                            final raw = numberCtrl.text.trim();
                            final expiry = expiryCtrl.text.trim();

                            final last4 = raw.substring(raw.length - 4);
                            setDialogState(() => saving = true);
                            await AppStore.instance.addPaymentMethod(
                              PaymentMethodItem(
                                id:
                                    DateTime.now().millisecondsSinceEpoch
                                        .toString(),
                                type: type,
                                holderName: holder,
                                last4: last4,
                                expiry: expiry,
                              ),
                            );
                            if (dialogContext.mounted) {
                              Navigator.pop(dialogContext);
                            }
                          },
                  child: Text(saving ? 'Saving...' : 'Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  // Builds and returns the UI for this widget.
  Widget build(BuildContext context) {
    final store = AppStore.instance;

    return AnimatedBuilder(
      animation: store,
      builder: (context, _) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('Card Detail'),
            backgroundColor: const Color(0xFFFF6A00),
            foregroundColor: Colors.black,
            actions: [
              IconButton(
                onPressed: () {
                  _showAddCard(context);
                },
                icon: const Icon(Icons.add_card),
              ),
              IconButton(
                icon: const Icon(Icons.key_outlined),
                onPressed: () async {
                  // Voice phrase is used by payment verification screen.
                  final ctrl = TextEditingController();
                  await showDialog(
                    context: context,
                    builder: (dialogContext) {
                      String? errorText;
                      return StatefulBuilder(
                        builder: (dialogContext, setDialogState) {
                          return AlertDialog(
                            title: const Text('Set Payment Voice Phrase'),
                            content: SingleChildScrollView(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  TextField(
                                    controller: ctrl,
                                    decoration: const InputDecoration(
                                      labelText:
                                          'Example: my voice is my password',
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
                                onPressed: () async {
                                  if (ctrl.text.trim().isEmpty) {
                                    setDialogState(() {
                                      errorText =
                                          'Voice phrase cannot be empty.';
                                    });
                                    return;
                                  }
                                  await store.setPaymentPhrase(
                                    ctrl.text.trim(),
                                  );
                                  if (context.mounted) {
                                    Navigator.pop(dialogContext);
                                  }
                                },
                                child: const Text('Save'),
                              ),
                            ],
                          );
                        },
                      );
                    },
                  );
                },
              ),
            ],
          ),
          body:
              store.payments.isEmpty
                  ? const Center(
                    child: Text(
                      'No payment methods',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                  )
                  : ListView.separated(
                    padding: const EdgeInsets.all(14),
                    itemCount: store.payments.length,
                    separatorBuilder: (_, __) {
                      return const SizedBox(height: 10);
                    },
                    itemBuilder: (_, i) {
                      final card = store.payments[i];
                      return ListTile(
                        tileColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: const BorderSide(color: Color(0xFFE6E6E6)),
                        ),
                        title: Text(
                          '${card.type} **** ${card.last4}',
                          style: const TextStyle(fontWeight: FontWeight.w900),
                        ),
                        subtitle: Text('${card.holderName} - ${card.expiry}'),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () async {
                            await store.deletePaymentMethod(card.id);
                          },
                        ),
                      );
                    },
                  ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () {
              _showAddCard(context);
            },
            backgroundColor: const Color(0xFFFF6A00),
            foregroundColor: Colors.black,
            label: const Text('Add Card'),
            icon: const Icon(Icons.add),
          ),
        );
      },
    );
  }
}
