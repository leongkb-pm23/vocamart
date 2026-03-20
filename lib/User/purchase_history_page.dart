// How this file works:
// 1) Data/models are declared first (if any).
// 2) UI widgets are built in build() methods.
// 3) Helper methods are used to keep UI code clean.

// File purpose: This file handles purchase history page screen/logic.

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:fyp/components/app_store.dart';
import 'package:fyp/components/order_page_widgets.dart';
import 'package:fyp/User/order_review_page.dart';
import 'package:fyp/User/order_invoice_pdf.dart';

// This class defines PurchaseHistoryPage, used for this page/feature.
class PurchaseHistoryPage extends StatelessWidget {
  const PurchaseHistoryPage({super.key});
  static const _orange = Color(0xFFFF6A00);

  String _normalizeStatus(String raw) => raw.trim().toLowerCase();

  bool _canReviewOrder(OrderItem order) {
    final s = _normalizeStatus(order.status);
    final d = _normalizeStatus(order.deliveryStatus);
    return s == 'completed' || s == 'delivered' || d == 'delivered';
  }

  Widget _emptyView(BuildContext context) {
    return const OrderEmptyMessage(text: 'No order history yet');
  }

  Widget _orderCard(BuildContext context, OrderItem order) {
    final dateText = DateFormat('dd MMM yyyy, hh:mm a').format(order.createdAt);
    return OrderInfoCard(
      orderId: order.id,
      children: [
        const SizedBox(height: 4),
        Text('Date: $dateText', style: const TextStyle(color: Colors.black54)),
        Text(
          'Status: ${order.status}',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        if (order.deliveryStatus.trim().isNotEmpty)
          Text(
            'Delivery: ${order.deliveryStatus}',
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
          child: Wrap(
            alignment: WrapAlignment.end,
            spacing: 8,
            runSpacing: 8,
            children: [
              if (_canReviewOrder(order))
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _orange,
                    foregroundColor: Colors.black,
                  ),
                  onPressed:
                      () => Navigator.push(
                        context,
                        MaterialPageRoute<void>(
                          builder: (_) => OrderReviewPage(order: order),
                        ),
                      ),
                  icon: const Icon(Icons.rate_review_outlined),
                  label: const Text('Review Products'),
                ),
              OutlinedButton.icon(
                onPressed: () => OrderInvoicePdf.preview(context, order),
                icon: const Icon(Icons.picture_as_pdf_outlined),
                label: const Text('Invoice PDF'),
              ),
            ],
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
