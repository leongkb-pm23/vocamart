// How this file works:
// 1) Data/models are declared first (if any).
// 2) UI widgets are built in build() methods.
// 3) Helper methods are used to keep UI code clean.

// File purpose: This file handles wallet voucher discount page screen/logic.

import 'package:flutter/material.dart';

import 'package:fyp/components/app_store.dart';

// This class defines WalletVoucherDiscountPage, used for this page/feature.
class WalletVoucherDiscountPage extends StatelessWidget {
  const WalletVoucherDiscountPage({super.key});
  static const _orange = Color(0xFFFF6A00);

  Widget _emptyView() {
    return const Center(
      child: Text(
        'No vouchers available',
        style: TextStyle(fontWeight: FontWeight.w800),
      ),
    );
  }

  Widget _voucherCard(BuildContext context, dynamic voucher) {
    final store = AppStore.instance;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF9F9F9),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE6E6E6)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: _orange,
            foregroundColor: Colors.black,
            child: Text('${voucher.percent}%'),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${voucher.store} Voucher',
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                Text('Min spend RM ${voucher.minSpend.toStringAsFixed(2)}'),
                Text(
                  'Code: ${voucher.code}',
                  style: const TextStyle(color: _orange),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () async {
              await store.deleteVoucher(voucher.id);
            },
            icon: const Icon(Icons.delete_outline),
          ),
        ],
      ),
    );
  }

  @override
  // Builds and returns the UI for this widget.
  Widget build(BuildContext context) {
    final store = AppStore.instance;

    return AnimatedBuilder(
      animation: store,
      builder: (context, _) {
        final vouchers = store.vouchers;

        return Scaffold(
          appBar: AppBar(
            title: const Text('Voucher / Discounts'),
            backgroundColor: _orange,
            foregroundColor: Colors.black,
          ),
          body:
              vouchers.isEmpty
                  ? _emptyView()
                  : ListView.separated(
                    padding: const EdgeInsets.all(14),
                    itemCount: vouchers.length,
                    separatorBuilder: (_, __) {
                      return const SizedBox(height: 10);
                    },
                    itemBuilder: (_, i) {
                      return _voucherCard(context, vouchers[i]);
                    },
                  ),
        );
      },
    );
  }
}



