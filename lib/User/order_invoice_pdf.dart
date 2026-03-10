import 'dart:typed_data';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import 'package:fyp/components/app_store.dart';

class _InvoiceRow {
  final String name;
  final int qty;
  final double unitPrice;

  const _InvoiceRow({
    required this.name,
    required this.qty,
    required this.unitPrice,
  });

  double get lineTotal => unitPrice * qty;
}

class OrderInvoicePdf {
  static Future<void> preview(BuildContext context, OrderItem order) async {
    try {
      final bytes = await _build(order);
      await Printing.layoutPdf(
        name: 'vocamart_invoice_${order.id}.pdf',
        onLayout: (_) async => bytes,
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to generate invoice: $e')));
    }
  }

  static Future<Uint8List> _build(OrderItem order) async {
    final rows = _rowsFromOrder(order);
    final customerEmail = FirebaseAuth.instance.currentUser?.email ?? '';
    final invoiceDate = DateFormat(
      'dd MMM yyyy, hh:mm a',
    ).format(order.createdAt);

    final subtotal = order.subtotal > 0 ? order.subtotal : _rowsSubtotal(rows);
    final discount = order.discount > 0 ? order.discount : 0.0;
    final deliveryFee = order.deliveryFee > 0 ? order.deliveryFee : 0.0;
    final total =
        order.total > 0 ? order.total : (subtotal - discount + deliveryFee);

    final doc = pw.Document();
    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        build:
            (context) => [
              pw.Container(
                padding: const pw.EdgeInsets.all(14),
                decoration: pw.BoxDecoration(
                  color: PdfColors.orange100,
                  borderRadius: pw.BorderRadius.circular(10),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          'VOCAMART INVOICE',
                          style: pw.TextStyle(
                            fontSize: 20,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.deepOrange900,
                          ),
                        ),
                        pw.SizedBox(height: 4),
                        pw.Text('Order ID: ${order.id}'),
                        pw.Text('Date: $invoiceDate'),
                        pw.Text('Status: ${order.status}'),
                      ],
                    ),
                    pw.Text(
                      'PAID',
                      style: pw.TextStyle(
                        fontSize: 18,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.green700,
                      ),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 14),
              pw.Text(
                'Bill To',
                style: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              pw.SizedBox(height: 6),
              pw.Text(
                order.customerName.trim().isEmpty
                    ? 'Customer'
                    : order.customerName,
              ),
              if (customerEmail.trim().isNotEmpty) pw.Text(customerEmail),
              if (order.customerPhone.trim().isNotEmpty)
                pw.Text(order.customerPhone),
              if (order.deliveryAddress.trim().isNotEmpty) ...[
                pw.SizedBox(height: 4),
                pw.Text(order.deliveryAddress.replaceAll('\n', ', ')),
              ],
              pw.SizedBox(height: 16),
              pw.Text(
                'Items',
                style: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              pw.SizedBox(height: 8),
              pw.Table(
                border: pw.TableBorder.all(color: PdfColors.grey300),
                columnWidths: {
                  0: const pw.FlexColumnWidth(5),
                  1: const pw.FlexColumnWidth(1.4),
                  2: const pw.FlexColumnWidth(2),
                  3: const pw.FlexColumnWidth(2),
                },
                children: [
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(
                      color: PdfColors.grey200,
                    ),
                    children: [
                      _cell('Product', bold: true),
                      _cell('Qty', bold: true, align: pw.TextAlign.right),
                      _cell('Unit (RM)', bold: true, align: pw.TextAlign.right),
                      _cell('Line (RM)', bold: true, align: pw.TextAlign.right),
                    ],
                  ),
                  ...rows.map(
                    (row) => pw.TableRow(
                      children: [
                        _cell(row.name),
                        _cell('${row.qty}', align: pw.TextAlign.right),
                        _cell(
                          row.unitPrice.toStringAsFixed(2),
                          align: pw.TextAlign.right,
                        ),
                        _cell(
                          row.lineTotal.toStringAsFixed(2),
                          align: pw.TextAlign.right,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 14),
              pw.Align(
                alignment: pw.Alignment.centerRight,
                child: pw.Container(
                  width: 220,
                  padding: const pw.EdgeInsets.all(10),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColors.grey300),
                    borderRadius: pw.BorderRadius.circular(8),
                  ),
                  child: pw.Column(
                    children: [
                      _sumRow('Subtotal', subtotal),
                      _sumRow('Discount', -discount),
                      _sumRow('Delivery Fee', deliveryFee),
                      pw.Divider(color: PdfColors.grey400),
                      _sumRow('Total Paid', total, bold: true),
                    ],
                  ),
                ),
              ),
              if (order.paymentType.trim().isNotEmpty ||
                  order.paymentLast4.trim().isNotEmpty)
                pw.Padding(
                  padding: const pw.EdgeInsets.only(top: 12),
                  child: pw.Text(
                    'Payment: ${order.paymentType} ${order.paymentLast4.isNotEmpty ? "**** ${order.paymentLast4}" : ""}',
                  ),
                ),
              if (order.voucherCode.trim().isNotEmpty)
                pw.Padding(
                  padding: const pw.EdgeInsets.only(top: 4),
                  child: pw.Text('Voucher: ${order.voucherCode}'),
                ),
            ],
      ),
    );

    return doc.save();
  }

  static List<_InvoiceRow> _rowsFromOrder(OrderItem order) {
    final store = AppStore.instance;
    final rows = <_InvoiceRow>[];
    for (final item in order.items) {
      final product = store.productById(item.productId);
      final name = (product?.name ?? item.productId).trim();
      final qty = item.qty > 0 ? item.qty : 1;
      final unitPrice = product?.lowestPrice ?? 0;
      rows.add(
        _InvoiceRow(
          name: name.isEmpty ? item.productId : name,
          qty: qty,
          unitPrice: unitPrice,
        ),
      );
    }
    return rows;
  }

  static double _rowsSubtotal(List<_InvoiceRow> rows) {
    var total = 0.0;
    for (final row in rows) {
      total += row.lineTotal;
    }
    return total;
  }

  static pw.Widget _cell(
    String text, {
    bool bold = false,
    pw.TextAlign align = pw.TextAlign.left,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(8),
      child: pw.Text(
        text,
        textAlign: align,
        style: pw.TextStyle(
          fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
          fontSize: 10.5,
        ),
      ),
    );
  }

  static pw.Widget _sumRow(String label, double value, {bool bold = false}) {
    final sign = value < 0 ? '- ' : '';
    final amount = value.abs().toStringAsFixed(2);
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(
        children: [
          pw.Expanded(
            child: pw.Text(
              label,
              style: pw.TextStyle(
                fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
              ),
            ),
          ),
          pw.Text(
            '$sign RM $amount',
            style: pw.TextStyle(
              fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}
