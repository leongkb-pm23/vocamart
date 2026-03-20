// How this file works:
// 1) Data/models are declared first (if any).
// 2) UI widgets are built in build() methods.
// 3) Helper methods are used to keep UI code clean.

// File purpose: This file handles voucher page screen/logic.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:fyp/components/app_store.dart';
import 'package:fyp/Admin/firestore_service.dart';

// This class defines VoucherPage, used for this page/feature.
class VoucherPage extends StatefulWidget {
  final bool showClaimablePromotions;
  const VoucherPage({super.key, this.showClaimablePromotions = true});

  @override
  State<VoucherPage> createState() => _VoucherPageState();
}

class VoucherStandalonePage extends StatelessWidget {
  const VoucherStandalonePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Voucher'),
        backgroundColor: _VoucherPageState.kOrange,
        foregroundColor: Colors.black,
      ),
      body: const SafeArea(child: VoucherPage(showClaimablePromotions: false)),
    );
  }
}

// This class defines _VoucherPageState, used for this page/feature.
class _VoucherPageState extends State<VoucherPage> {
  static const kOrange = Color(0xFFFF6A00);

  final _svc = FirestoreService();
  int _tab = 0;

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  List<VoucherItem> _eligibleVouchers(AppStore store) {
    final result = <VoucherItem>[];
    for (final voucher in store.vouchers) {
      if (store.cartTotal >= voucher.minSpend) {
        result.add(voucher);
      }
    }
    return result;
  }

  List<QueryDocumentSnapshot<Map<String, dynamic>>> _activePromos(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    final now = DateTime.now();
    final result = <QueryDocumentSnapshot<Map<String, dynamic>>>[];
    for (final doc in docs) {
      final data = doc.data();
      final active = data['isActive'];
      if (active is bool && !active) {
        continue;
      }

      final endAt = data['endAt'];
      if (endAt is Timestamp && !endAt.toDate().isAfter(now)) {
        continue;
      }

      result.add(doc);
    }
    result.sort((a, b) {
      final at = _docTime(a.data());
      final bt = _docTime(b.data());
      final cmp = bt.compareTo(at);
      if (cmp != 0) return cmp;
      return b.id.compareTo(a.id);
    });
    return result;
  }

  DateTime _docTime(Map<String, dynamic> data) {
    final value = data['updatedAt'] ?? data['createdAt'] ?? data['claimedAt'];
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return DateTime.fromMillisecondsSinceEpoch(0);
  }

  Set<String> _claimedIds(QuerySnapshot<Map<String, dynamic>>? snap) {
    final ids = <String>{};
    final docs = snap?.docs ?? const [];
    for (final doc in docs) {
      ids.add(doc.id);
    }
    return ids;
  }

  @override
  // Builds and returns the UI for this widget.
  Widget build(BuildContext context) {
    final store = AppStore.instance;

    return AnimatedBuilder(
      animation: store,
      builder: (context, _) {
        final allItems = store.vouchers;
        final eligibleItems = _eligibleVouchers(store);
        final myItems = _tab == 0 ? allItems : eligibleItems;

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Vouchers',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: kOrange,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      _TabText(
                        text: 'All',
                        active: _tab == 0,
                        onTap: () {
                          setState(() {
                            _tab = 0;
                          });
                        },
                      ),
                      const SizedBox(width: 14),
                      _TabText(
                        text: 'E-Commerce',
                        active: _tab == 1,
                        onTap: () {
                          setState(() {
                            _tab = 1;
                          });
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  _tab == 0
                      ? 'All your claimed vouchers'
                      : 'Usable now (min spend reached)',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Colors.black54,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 6),
            Expanded(
              child:
                  myItems.isEmpty
                      ? Center(
                        child: Text(
                          _tab == 0
                              ? 'No vouchers yet. Claim from promotions below.'
                              : 'No usable vouchers yet.\nAdd more items to cart.',
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                      )
                      : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
                        itemCount: myItems.length,
                        separatorBuilder: (_, __) {
                          return const SizedBox(height: 10);
                        },
                        itemBuilder: (_, i) {
                          final v = myItems[i];
                          final applied = store.appliedVoucher?.id == v.id;
                          final canApply = store.cartTotal >= v.minSpend;
                          return _VoucherCard(
                            brand: v.store,
                            off: '${v.percent}%',
                            minSpend:
                                'Min spend RM ${v.minSpend.toStringAsFixed(2)} - ${v.code}',
                            applied: applied,
                            canApply: canApply,
                            onCopy: () async {
                              await Clipboard.setData(
                                ClipboardData(text: v.code),
                              );
                              _showSnack('Copied code ${v.code}');
                            },
                            onApply: () async {
                              final msg = await store.applyVoucher(v.id);
                              _showSnack(msg);
                            },
                          );
                        },
                      ),
            ),
            if (widget.showClaimablePromotions) ...[
              const Divider(height: 1),
              Expanded(
                child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: _svc.publicPromosStream(),
                  builder: (context, snap) {
                    if (snap.hasError) {
                      return const Center(
                        child: Padding(
                          padding: EdgeInsets.all(16),
                          child: Text(
                            'Unable to load promotions right now.',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                      );
                    }
                    if (!snap.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final docs = _activePromos(snap.data!.docs);

                    if (docs.isEmpty) {
                      return const Center(
                        child: Text(
                          'No promotions available to claim.',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                      );
                    }

                    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                      stream: _svc.claimedPromosStream(),
                      builder: (context, claimedSnap) {
                        final claimedIds = _claimedIds(claimedSnap.data);

                        return ListView.separated(
                          padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
                          itemCount: docs.length,
                          separatorBuilder: (_, __) {
                            return const SizedBox(height: 10);
                          },
                          itemBuilder: (_, i) {
                            final d = docs[i];
                            final p = d.data();
                            final claimed = claimedIds.contains(d.id);
                            final title =
                                (p['title'] ?? 'Promotion').toString();
                            final storeName =
                                (p['storeName'] ?? 'Store').toString();
                            final code = (p['code'] ?? '').toString();

                            return Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFF7F1),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: const Color(0xFFFFE0CA),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '$storeName - $title',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text((p['description'] ?? '').toString()),
                                  if (code.trim().isNotEmpty) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      'Code: $code',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ],
                                  const SizedBox(height: 8),
                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: ElevatedButton(
                                      onPressed:
                                          claimed
                                              ? null
                                              : () async {
                                                final ok = await _svc
                                                    .claimPromoAsVoucher(
                                                      promoId: d.id,
                                                      promoData: p,
                                                    );
                                                _showSnack(
                                                  ok
                                                      ? 'Promotion claimed to My Vouchers.'
                                                      : 'You already claimed this promotion.',
                                                );
                                              },
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: kOrange,
                                        foregroundColor: Colors.black,
                                      ),
                                      child: Text(
                                        claimed ? 'Claimed' : 'Claim',
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}

// This class defines _TabText, used for this page/feature.
class _TabText extends StatelessWidget {
  final String text;
  final bool active;
  final VoidCallback onTap;

  const _TabText({
    required this.text,
    required this.active,
    required this.onTap,
  });

  @override
  // Builds and returns the UI for this widget.
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w800,
          color: active ? const Color(0xFFFF6A00) : Colors.black54,
        ),
      ),
    );
  }
}

// This class defines _VoucherCard, used for this page/feature.
class _VoucherCard extends StatelessWidget {
  final String brand;
  final String off;
  final String minSpend;
  final bool applied;
  final bool canApply;
  final VoidCallback onCopy;
  final VoidCallback onApply;

  const _VoucherCard({
    required this.brand,
    required this.off,
    required this.minSpend,
    required this.applied,
    required this.canApply,
    required this.onCopy,
    required this.onApply,
  });

  @override
  // Builds and returns the UI for this widget.
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F3F3),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 54,
                height: 34,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  brand,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      off,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFFFF6A00),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      minSpend,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: onCopy,
                  child: const Text('Copy Code'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton(
                  onPressed: applied ? null : onApply,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF6A00),
                    foregroundColor: Colors.black,
                  ),
                  child: Text(applied ? 'Applied' : 'Apply'),
                ),
              ),
            ],
          ),
          if (!canApply && !applied)
            const Padding(
              padding: EdgeInsets.only(top: 6),
              child: Text(
                'Add more items to meet min spend.',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
              ),
            ),
        ],
      ),
    );
  }
}
