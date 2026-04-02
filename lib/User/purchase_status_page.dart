// How this file works:
// 1) Data/models are declared first (if any).
// 2) UI widgets are built in build() methods.
// 3) Helper methods are used to keep UI code clean.

// File purpose: This file handles purchase status page screen/logic.

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:fyp/components/app_store.dart';
import 'package:fyp/components/order_page_widgets.dart';
import 'package:fyp/User/order_review_page.dart';
import 'package:fyp/User/order_invoice_pdf.dart';

// This class defines PurchaseStatusPage, used for this page/feature.
class PurchaseStatusPage extends StatelessWidget {
  final String status;

  const PurchaseStatusPage({super.key, required this.status});
  static const _orange = Color(0xFFFF6A00);

  Widget _emptyView(BuildContext context) {
    return OrderEmptyMessage(text: 'No orders in "$status"');
  }

  String _normalizeStatus(String raw) {
    return raw.trim().toLowerCase();
  }

  bool _isFinalOrCancelled(String statusRaw, String deliveryStatusRaw) {
    final s = _normalizeStatus(statusRaw);
    final d = _normalizeStatus(deliveryStatusRaw);
    return s == 'completed' ||
        s == 'delivered' ||
        s == 'cancelled' ||
        s == 'canceled' ||
        d == 'delivered' ||
        d == 'cancelled' ||
        d == 'canceled';
  }

  bool _isPickedUpByDeliveryMan(OrderItem order) {
    final s = _normalizeStatus(order.status);
    final d = _normalizeStatus(order.deliveryStatus);
    if (_isFinalOrCancelled(order.status, order.deliveryStatus)) return false;
    return d == 'on the way' || s == 'to receive' || s == 'shipping';
  }

  bool _isPacking(OrderItem order) {
    final s = _normalizeStatus(order.status);
    final d = _normalizeStatus(order.deliveryStatus);
    if (_isFinalOrCancelled(order.status, order.deliveryStatus)) return false;
    if (_isPickedUpByDeliveryMan(order)) return false;
    return s == 'to ship' ||
        s == 'packed' ||
        s == 'pending' ||
        s == 'processing' ||
        d == 'assigned';
  }

  bool _isToShipOrder(OrderItem order) {
    return _isPacking(order);
  }

  bool _isToReceiveOrder(OrderItem order) {
    final s = _normalizeStatus(order.status);
    final d = _normalizeStatus(order.deliveryStatus);
    return _isPickedUpByDeliveryMan(order) ||
        d == 'delivered' ||
        s == 'delivered' ||
        s == 'completed';
  }

  Color _statusColor(OrderItem order) {
    final s = _normalizeStatus(order.status);
    final d = _normalizeStatus(order.deliveryStatus);
    if (d == 'on the way' || s == 'to receive' || s == 'shipping') {
      return const Color(0xFF1565C0);
    }
    if (s == 'completed' || s == 'delivered') return const Color(0xFF2E7D32);
    if (s == 'cancelled' || s == 'canceled' || d == 'cancelled' || d == 'canceled') {
      return const Color(0xFFC62828);
    }
    return _orange;
  }

  String _displayStatus(OrderItem order) {
    final s = _normalizeStatus(order.status);
    if (s == 'packed') return 'PACKED DONE';
    if (_isPacking(order)) return 'PACKING';
    if (_isPickedUpByDeliveryMan(order)) return 'PICKED UP BY DELIVERY MAN';
    if (s.isEmpty) return 'TO SHIP';
    if (s == 'to ship') return 'TO SHIP';
    if (s == 'to receive') return 'TO RECEIVE';
    if (s == 'processing') return 'PROCESSING';
    if (s == 'shipping') return 'SHIPPING';
    if (s == 'on the way') return 'ON THE WAY';
    if (s == 'assigned') return 'ASSIGNED';
    if (s == 'pending') return 'PENDING';
    if (s == 'delivered') return 'DELIVERED';
    if (s == 'completed') return 'COMPLETED';
    if (s == 'cancelled') return 'CANCELLED';
    return order.status.toUpperCase();
  }

  String _displayDeliveryStatus(String raw) {
    final s = _normalizeStatus(raw);
    if (s.isEmpty) return '';
    if (s == 'on the way') return 'PICKED UP BY DELIVERY MAN';
    if (s == 'assigned') return 'WAITING FOR PICKUP';
    if (s == 'delivered') return 'DELIVERED';
    if (s == 'cancelled') return 'CANCELLED';
    return raw.toUpperCase();
  }

  int _orderQuantity(OrderItem order) {
    var total = 0;
    for (final item in order.items) {
      total += item.qty > 0 ? item.qty : 1;
    }
    return total;
  }

  bool _canUserCancelOrder(OrderItem order) {
    final s = _normalizeStatus(order.status);
    if (s == 'cancelled' || s == 'completed' || s == 'delivered') {
      return false;
    }
    return true;
  }

  bool _canReviewOrder(OrderItem order) {
    final s = _normalizeStatus(order.status);
    final d = _normalizeStatus(order.deliveryStatus);
    return s == 'completed' || s == 'delivered' || d == 'delivered';
  }

  Widget _orderCard(BuildContext context, OrderItem order) {
    final store = AppStore.instance;
    final itemLines = <String>[];
    for (final item in order.items) {
      final product = store.productById(item.productId);
      final name = (product?.name ?? item.productId).trim();
      if (name.isEmpty) continue;
      final qty = item.qty > 0 ? item.qty : 1;
      itemLines.add('$name x$qty');
    }
    final dateText = DateFormat('dd MMM yyyy, hh:mm a').format(order.createdAt);
    final statusText = _displayStatus(order);
    final statusColor = _statusColor(order);
    final deliveryStatusText = _displayDeliveryStatus(order.deliveryStatus);
    final quantity = _orderQuantity(order);

    return OrderInfoCard(
      orderId: order.id,
      children: [
        const SizedBox(height: 8),
        Row(
          children: [
            const CircleAvatar(
              backgroundColor: Color(0xFFFFF2E8),
              foregroundColor: _orange,
              child: Icon(Icons.receipt_long_outlined),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Order ${order.id}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Date: $dateText',
                    style: const TextStyle(
                      color: Colors.black54,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.13),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                statusText,
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  color: Colors.black87,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          'Quantity Bought: $quantity',
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 6),
        if (itemLines.isNotEmpty) ...[
          const Text(
            'Products:',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          ...itemLines.map(
            (line) => Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: Text(
                '- $line',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ),
          const SizedBox(height: 6),
        ],
        Text(
          'Total: RM ${order.total.toStringAsFixed(2)}',
          style: const TextStyle(fontWeight: FontWeight.w800, color: _orange),
        ),
        if (order.subtotal > 0)
          Text('Subtotal: RM ${order.subtotal.toStringAsFixed(2)}'),
        if (order.discount > 0)
          Text(
            'Discount: - RM ${order.discount.toStringAsFixed(2)}',
            style: const TextStyle(color: _orange),
          ),
        if (order.deliveryFee > 0)
          Text(
            'Delivery Fee: RM ${order.deliveryFee.toStringAsFixed(2)}'
            '${order.deliveryDistanceKm > 0 ? " (${order.deliveryDistanceKm.toStringAsFixed(1)} km)" : ""}',
          ),
        if (order.deliveryAddress.trim().isNotEmpty) ...[
          const SizedBox(height: 6),
          const Text(
            'Delivery Address:',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 2),
          Text(order.deliveryAddress),
        ],
        if (order.customerName.trim().isNotEmpty ||
            order.customerPhone.trim().isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            'Customer: ${order.customerName.trim().isEmpty ? '-' : order.customerName}',
          ),
          if (order.customerPhone.trim().isNotEmpty)
            Text('Phone: ${order.customerPhone}'),
        ],
        if (order.paymentType.trim().isNotEmpty ||
            order.paymentLast4.trim().isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            'Payment: ${order.paymentType} ${order.paymentLast4.isNotEmpty ? "**** ${order.paymentLast4}" : ""}',
          ),
        ],
        if (order.voucherCode.trim().isNotEmpty)
          Text('Voucher: ${order.voucherCode}'),
        if (deliveryStatusText.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            'Delivery: $deliveryStatusText',
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
        ],
        const SizedBox(height: 8),
        Text(
          _canUserCancelOrder(order)
              ? 'You can cancel this order before completion. Refund goes to wallet.'
              : 'Status updates are handled by system/admin.',
          style: const TextStyle(
            fontSize: 12,
            color: Colors.black54,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          alignment: WrapAlignment.end,
          spacing: 8,
          runSpacing: 8,
          children: [
            if (_canUserCancelOrder(order))
              OutlinedButton.icon(
                onPressed: () async {
                  final confirm =
                      await showDialog<bool>(
                        context: context,
                        builder:
                            (_) => AlertDialog(
                              title: const Text('Cancel Order'),
                              content: const Text(
                                'Cancel this order? If payment was completed, the amount will be refunded to your wallet.',
                              ),
                              actions: [
                                TextButton(
                                  onPressed:
                                      () => Navigator.pop(context, false),
                                  child: const Text('No'),
                                ),
                                ElevatedButton(
                                  onPressed: () => Navigator.pop(context, true),
                                  child: const Text('Yes, Cancel'),
                                ),
                              ],
                            ),
                      ) ??
                      false;
                  if (!confirm) return;

                  try {
                    final refunded = await store.cancelOrderWithRefund(
                      order.id,
                    );
                    if (!context.mounted) return;
                    final msg =
                        refunded
                            ? 'Order cancelled. Refund added to wallet.'
                            : 'Order cancelled.';
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(SnackBar(content: Text(msg)));
                  } catch (e) {
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Cannot cancel order: $e')),
                    );
                  }
                },
                icon: const Icon(Icons.cancel_outlined),
                label: const Text('Cancel Order'),
              ),
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
      ],
    );
  }

  @override
  // Builds and returns the UI for this widget.
  Widget build(BuildContext context) {
    return StoreOrderPage(
      title: status,
      appBarColor: _orange,
      ordersBuilder: (store) {
        if (_normalizeStatus(status) == 'to ship') {
          final rows = <OrderItem>[];
          for (final order in store.orders) {
            if (_isToShipOrder(order)) {
              rows.add(order);
            }
          }
          rows.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return rows;
        }

        if (_normalizeStatus(status) == 'to receive') {
          final rows = <OrderItem>[];
          for (final order in store.orders) {
            if (_isToReceiveOrder(order)) {
              rows.add(order);
            }
          }
          rows.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return rows;
        }

        return store.ordersByStatus(status);
      },
      orderCardBuilder: _orderCard,
      emptyBuilder: _emptyView,
    );
  }
}
