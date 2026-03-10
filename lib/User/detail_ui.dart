// How this file works:
// 1) Data/models are declared first (if any).
// 2) UI widgets are built in build() methods.
// 3) Helper methods are used to keep UI code clean.

// File purpose: This file handles detail ui screen/logic.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:fyp/components/app_store.dart';
import 'package:fyp/Admin/firestore_service.dart';

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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Please login to $action.')),
    );
  }

  List<Widget> _priceRows(ProductItem currentProduct) {
    // Build one row per store price to show comparison clearly.
    final rows = <Widget>[];
    for (final priceItem in currentProduct.prices) {
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
                child: Text(
                  priceItem.store,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
              Text(
                'RM ${priceItem.price.toStringAsFixed(2)}',
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  color: priceItem.price == currentProduct.lowestPrice
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
        final outOfStock = liveProduct.isOutOfStock;
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
                      : 'Stock available: ${liveProduct.quantity}',
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
                Text(liveProduct.description, style: const TextStyle(height: 1.3)),
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
                              content: Text('${liveProduct.name} added to cart'),
                            ),
                          );
                        },
                        icon: const Icon(Icons.add_shopping_cart),
                        label: Text(outOfStock ? 'Out of Stock' : 'Add to Cart'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                _ReviewSection(product: liveProduct),
              ],
            ),
          ),
        );
      },
    );
  }
}

// This class defines _ReviewSection, used for this page/feature.
class _ReviewSection extends StatefulWidget {
  final ProductItem product;
  const _ReviewSection({required this.product});

  @override
  State<_ReviewSection> createState() => _ReviewSectionState();
}

// This class defines _ReviewSectionState, used for this page/feature.
class _ReviewSectionState extends State<_ReviewSection> {
  final _svc = FirestoreService();
  final _commentCtrl = TextEditingController();
  int _rating = 5;
  bool _saving = false;

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _submitReview() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.isAnonymous) {
      _showSnack('Please login to submit a review.');
      return;
    }

    final comment = _commentCtrl.text.trim();
    if (comment.isEmpty) {
      _showSnack('Review comment cannot be empty.');
      return;
    }

    setState(() {
      _saving = true;
    });
    await _svc.upsertReview(
      productId: widget.product.id,
      productName: widget.product.name,
      rating: _rating,
      comment: comment,
    );

    if (!mounted) return;
    _commentCtrl.clear();
    setState(() {
      _saving = false;
    });
  }

  List<QueryDocumentSnapshot<Map<String, dynamic>>> _filteredDocs(
    QuerySnapshot<Map<String, dynamic>> snap,
  ) {
    final result = <QueryDocumentSnapshot<Map<String, dynamic>>>[];
    for (final doc in snap.docs) {
      final data = doc.data();
      final productId = (data['productId'] ?? '').toString();
      final status = (data['status'] ?? 'published').toString();
      if (productId == widget.product.id && status == 'published') {
        result.add(doc);
      }
    }
    return result;
  }

  List<Widget> _reviewCards(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    final cards = <Widget>[];
    final count = docs.length < 5 ? docs.length : 5;
    for (var i = 0; i < count; i++) {
      final data = docs[i].data();
      final rating = (data['rating'] is num) ? (data['rating'] as num).toInt() : 0;
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
                (data['userEmail'] ?? 'User').toString(),
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              Text('Rating: ${'*' * rating}'),
              Text((data['comment'] ?? '').toString()),
            ],
          ),
        ),
      );
    }
    return cards;
  }

  List<DropdownMenuItem<int>> _ratingItems() {
    final items = <DropdownMenuItem<int>>[];
    for (var i = 1; i <= 5; i++) {
      items.add(DropdownMenuItem<int>(value: i, child: Text('$i')));
    }
    return items;
  }

  @override
  void dispose() {
    _commentCtrl.dispose();
    super.dispose();
  }

  @override
  // Builds and returns the UI for this widget.
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
        Row(
          children: [
            const Text('Rating:'),
            const SizedBox(width: 8),
            DropdownButton<int>(
              value: _rating,
              items: _ratingItems(),
              onChanged: (v) {
                setState(() {
                  _rating = v ?? 5;
                });
              },
            ),
          ],
        ),
        TextField(
          controller: _commentCtrl,
          maxLines: 3,
          decoration: const InputDecoration(
            hintText: 'Write feedback',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 8),
        ElevatedButton(
          onPressed: _saving ? null : _submitReview,
          child: const Text('Submit Review'),
        ),
        const SizedBox(height: 10),
        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          // Listen review collection live, then filter by this product id.
          stream: _svc.reviewsStream(),
          builder: (context, snap) {
            if (!snap.hasData) return const SizedBox.shrink();
            final docs = _filteredDocs(snap.data!);

            if (docs.isEmpty) return const Text('No reviews yet');

            return Column(children: _reviewCards(docs));
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
                        decoration: const InputDecoration(labelText: 'Card Holder'),
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
                        decoration: const InputDecoration(labelText: 'Card Number'),
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
                  onPressed: saving
                      ? null
                      : () {
                    Navigator.pop(dialogContext);
                  },
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: saving
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
                        id: DateTime.now().millisecondsSinceEpoch.toString(),
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
                                      errorText = 'Voice phrase cannot be empty.';
                                    });
                                    return;
                                  }
                                  await store.setPaymentPhrase(ctrl.text.trim());
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



