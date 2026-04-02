import 'package:flutter/material.dart';

import 'package:fyp/Admin/firestore_service.dart';
import 'package:fyp/components/app_store.dart';

class OrderReviewPage extends StatefulWidget {
  final OrderItem order;

  const OrderReviewPage({super.key, required this.order});

  @override
  State<OrderReviewPage> createState() => _OrderReviewPageState();
}

class _OrderReviewPageState extends State<OrderReviewPage> {
  final _svc = FirestoreService();
  final Set<String> _submittingProductIds = <String>{};
  final Set<String> _reviewedKeys = <String>{};
  bool _loadingReviewed = true;

  String _reviewKey(String productId, String storeId) {
    return '${productId.trim().toLowerCase()}|${storeId.trim().toLowerCase()}';
  }

  Future<void> _loadReviewed() async {
    try {
      final keys = await _svc.currentUserReviewedProductKeys();
      if (!mounted) return;
      setState(() {
        _reviewedKeys
          ..clear()
          ..addAll(keys);
        _loadingReviewed = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loadingReviewed = false;
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _loadReviewed();
  }

  void _showMsg(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _openReviewDialog({
    required String productId,
    required String productName,
    String? purchasedStoreId,
  }) async {
    var rating = 5;
    final commentCtrl = TextEditingController();
    var saving = false;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            return AlertDialog(
              title: Text('Review: $productName'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Rating'),
                    const SizedBox(height: 8),
                    DropdownButton<int>(
                      value: rating,
                      items:
                          List.generate(
                            5,
                            (i) => DropdownMenuItem<int>(
                              value: i + 1,
                              child: Text('${i + 1}'),
                            ),
                          ).toList(),
                      onChanged:
                          saving
                              ? null
                              : (value) {
                                setDialogState(() {
                                  rating = value ?? 5;
                                });
                              },
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: commentCtrl,
                      maxLines: 4,
                      enabled: !saving,
                      decoration: const InputDecoration(
                        hintText: 'Write your review',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed:
                      saving ? null : () => Navigator.pop(dialogContext),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed:
                      saving
                          ? null
                          : () async {
                            final comment = commentCtrl.text.trim();
                            if (comment.isEmpty) {
                              _showMsg('Review comment cannot be empty.');
                              return;
                            }

                            setDialogState(() {
                              saving = true;
                            });
                            setState(() {
                              _submittingProductIds.add(productId);
                            });

                            try {
                              await _svc.upsertReview(
                                productId: productId,
                                productName: productName,
                                rating: rating,
                                comment: comment,
                                storeId: purchasedStoreId,
                              );

                              if (!mounted) return;
                              if (dialogContext.mounted) {
                                Navigator.pop(dialogContext);
                              }
                              if (mounted) {
                                setState(() {
                                  _reviewedKeys.add(
                                    _reviewKey(productId, purchasedStoreId ?? ''),
                                  );
                                  _reviewedKeys.add(
                                    _reviewKey(productId, ''),
                                  );
                                });
                              }
                              _showMsg(
                                'Review saved successfully.',
                              );
                            } catch (e) {
                              _showMsg(
                                e.toString().replaceFirst('Bad state: ', ''),
                              );
                              if (dialogContext.mounted) {
                                setDialogState(() {
                                  saving = false;
                                });
                              }
                            } finally {
                              if (mounted) {
                                setState(() {
                                  _submittingProductIds.remove(productId);
                                });
                              }
                            }
                          },
                  child: const Text('Submit Review'),
                ),
              ],
            );
          },
        );
      },
    );

    commentCtrl.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = AppStore.instance;
    final rows = <CartItem>[];
    final seen = <String>{};

    for (final item in widget.order.items) {
      final pid = item.productId.trim();
      final sid = item.storeId.trim().toLowerCase();
      final key = '$pid|$sid';
      if (pid.isEmpty || seen.contains(key)) continue;
      seen.add(key);
      rows.add(item);
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Review Purchased Products'),
        backgroundColor: const Color(0xFFFF6A00),
        foregroundColor: Colors.black,
      ),
      body: ListView(
        padding: const EdgeInsets.all(14),
        children: [
          Text(
            'Order ${widget.order.id}',
            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
          ),
          const SizedBox(height: 6),
          const Text(
            'Submit reviews for received products. These reviews appear in Admin > Reviews.',
            style: TextStyle(color: Colors.black54, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          if (rows.isEmpty)
            const Text('No items found for this order.')
          else
            ...rows.map((item) {
              final product = store.productById(item.productId);
              final productId = item.productId.trim();
              final productName = (product?.name ?? productId).trim();
              final isSubmitting = _submittingProductIds.contains(productId);
              final reviewed =
                  _reviewedKeys.contains(_reviewKey(productId, item.storeId)) ||
                  _reviewedKeys.contains(_reviewKey(productId, ''));
              final qty = item.qty > 0 ? item.qty : 1;

              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(12),
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
                            productName.isEmpty ? productId : productName,
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Qty received: $qty',
                            style: const TextStyle(color: Colors.black54),
                          ),
                        ],
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed:
                          (isSubmitting || reviewed || _loadingReviewed)
                              ? null
                              : () => _openReviewDialog(
                                productId: productId,
                                productName:
                                    productName.isEmpty ? productId : productName,
                                purchasedStoreId: item.storeId,
                              ),
                      icon: const Icon(Icons.rate_review_outlined),
                      label: Text(
                        _loadingReviewed
                            ? 'Checking...'
                            : reviewed
                            ? 'Reviewed'
                            : isSubmitting
                            ? 'Submitting...'
                            : 'Write Review',
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }
}
