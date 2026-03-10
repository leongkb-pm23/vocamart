// How this file works:
// 1) Data/models are declared first (if any).
// 2) UI widgets are built in build() methods.
// 3) Helper methods are used to keep UI code clean.

// File purpose: This file handles purchase history page screen/logic.

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:fyp/components/app_store.dart';
import 'package:fyp/components/order_page_widgets.dart';
import 'package:fyp/User/order_invoice_pdf.dart';

// This class defines PurchaseHistoryPage, used for this page/feature.
class PurchaseHistoryPage extends StatelessWidget {
  const PurchaseHistoryPage({super.key});
  static const _orange = Color(0xFFFF6A00);

  Widget _emptyView(BuildContext context) {
    return const OrderEmptyMessage(
      text: 'No order history yet',
    );
  }

  Widget _orderCard(BuildContext context, OrderItem order) {
    final dateText = DateFormat('dd MMM yyyy, hh:mm a').format(order.createdAt);
    return OrderInfoCard(
      orderId: order.id,
      children: [
        const SizedBox(height: 4),
        Text(
          'Date: $dateText',
          style: const TextStyle(color: Colors.black54),
        ),
        Text(
          'Status: ${order.status}',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        Text('Items: ${order.items.length}'),
        Text(
          'Total: RM ${order.total.toStringAsFixed(2)}',
          style: const TextStyle(color: _orange),
        ),
        const SizedBox(height: 10),
        Align(
          alignment: Alignment.centerRight,
          child: OutlinedButton.icon(
            onPressed: () => OrderInvoicePdf.preview(context, order),
            icon: const Icon(Icons.picture_as_pdf_outlined),
            label: const Text('Invoice PDF'),
          ),
        ),
      ],
    );
  }

  @override
  // Builds and returns the UI for this widget.
  Widget build(BuildContext context) {
    return StoreOrderPage(
      title: 'Purchase History',
      appBarColor: _orange,
      ordersBuilder: (store) {
        return store.orders;
      },
      orderCardBuilder: _orderCard,
      emptyBuilder: _emptyView,
    );
  }
}




