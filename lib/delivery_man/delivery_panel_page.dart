// How this file works:
// 1) Data/models are declared first (if any).
// 2) UI widgets are built in build() methods.
// 3) Helper methods are used to keep UI code clean.

// File purpose: This file handles delivery panel page screen/logic.

import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:fyp/components/confirm_dialog.dart';
import 'package:fyp/Admin/firestore_service.dart';
import 'package:fyp/User/login.dart';
import 'package:fyp/components/ui_cards.dart';

// This class defines DeliveryPanelPage, used for this page/feature.
class DeliveryPanelPage extends StatelessWidget {
  const DeliveryPanelPage({super.key});

  DateTime _latestAssignmentTime(Map<String, dynamic> data) {
    final value = data['updatedAt'] ?? data['assignedAt'] ?? data['createdAt'];
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return DateTime.fromMillisecondsSinceEpoch(0);
  }

  String _userIdFromOrderPath(String orderPath) {
    // Expected format: users/{uid}/orders/{orderId}
    final parts = orderPath.split('/');
    if (parts.length >= 4 && parts[0] == 'users' && parts[2] == 'orders') {
      return parts[1];
    }
    return '';
  }

  Future<String> _loadAddressFromUserProfile(String orderPath) async {
    // Some old orders may miss address, so fallback to users/{uid}.address.
    final userId = _userIdFromOrderPath(orderPath);
    if (userId.isEmpty) return '';
    try {
      final doc =
          await FirebaseFirestore.instance.collection('users').doc(userId).get();
      final data = doc.data() ?? const <String, dynamic>{};
      return _text(data['address'] ?? data['location']);
    } on FirebaseException catch (_) {
      return '';
    }
  }

  String _text(Object? value, {String fallback = ''}) {
    if (value == null) return fallback;
    final text = value.toString().trim();
    if (text.isEmpty) return fallback;
    return text;
  }

  String _orderIdFromPath(String orderPath) {
    final parts = orderPath.split('/');
    if (parts.length >= 4) return parts[3];
    return orderPath;
  }

  Color _statusColor(String status) {
    if (status == 'Delivered') return const Color(0xFF2E7D32);
    if (status == 'On The Way') return const Color(0xFF1565C0);
    return const Color(0xFFEF6C00);
  }

  String _money(dynamic value) {
    final amount = value is num ? value.toDouble() : 0.0;
    return 'RM ${amount.toStringAsFixed(2)}';
  }

  Widget _infoCard(String text, {bool loading = false}) {
    return AppCard(
      child: loading
          ? const Center(child: CircularProgressIndicator())
          : Text(
              text,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
    );
  }

  Future<void> _logout(BuildContext context) async {
    final navigator = Navigator.of(context);
    await FirebaseAuth.instance.signOut();
    navigator.pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginPage()),
      (route) {
        return false;
      },
    );
  }

  Future<void> _openMap(String address) async {
    // Try Google Maps first; fallback to OpenStreetMap if unavailable.
    final normalized = address.replaceAll('\n', ' ').trim();
    if (normalized.isEmpty) return;

    final q = Uri.encodeComponent(normalized);
    final googleUri = Uri.parse('https://www.google.com/maps/search/?api=1&query=$q');
    final osmUri = Uri.parse('https://www.openstreetmap.org/search?query=$q');

    final openedGoogle = await launchUrl(
      googleUri,
      mode: LaunchMode.externalApplication,
    );
    if (!openedGoogle) {
      await launchUrl(osmUri, mode: LaunchMode.externalApplication);
    }
  }

  Widget _streamError(Object? error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          'Failed to load deliveries.\n$error',
          textAlign: TextAlign.center,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
    );
  }

  @override
  // Builds and returns the UI for this widget.
  Widget build(BuildContext context) {
    const kOrange = Color(0xFF00695C);
    final svc = FirestoreService();

    return Scaffold(
      backgroundColor: const Color(0xFFF2F7F6),
      appBar: AppBar(
        title: const Text('Delivery Panel'),
        backgroundColor: kOrange,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.person_outline),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) {
                    return const DeliveryProfilePage();
                  },
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              final ok = await showConfirmDialog(
                context,
                title: 'Logout',
                message: 'Are you sure you want to logout?',
                confirmText: 'Logout',
              );
              if (!ok) return;
              if (!context.mounted) return;
              await _logout(context);
            },
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: svc.myAssignedDeliveriesStream(),
        builder: (context, snap) {
          if (snap.hasError) return _streamError(snap.error);
          if (!snap.hasData) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            return const Center(
              child: Text(
                'Unable to read assigned deliveries.',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
            );
          }
          final docs = [...snap.data!.docs];
          // Show latest assignment first for delivery workflow.
          docs.sort((a, b) {
            final aTime = _latestAssignmentTime(a.data());
            final bTime = _latestAssignmentTime(b.data());
            final compare = bTime.compareTo(aTime);
            if (compare != 0) return compare;
            return b.id.compareTo(a.id);
          });

          if (docs.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'No assigned deliveries yet.\nIf rules were changed recently, re-assign orders once from Admin panel.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            );
          }

          int assignedCount = 0;
          int onTheWayCount = 0;
          int deliveredCount = 0;
          for (final doc in docs) {
            final status = _text(
              doc.data()['deliveryStatus'],
              fallback: _text(doc.data()['status'], fallback: 'Assigned'),
            );
            if (status == 'Delivered') {
              deliveredCount += 1;
            } else if (status == 'On The Way') {
              onTheWayCount += 1;
            } else {
              assignedCount += 1;
            }
          }

          return Column(
            children: [
              Container(
                width: double.infinity,
                margin: const EdgeInsets.fromLTRB(14, 14, 14, 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF00695C), Color(0xFF26A69A)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Delivery Overview',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 17,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        _panelStat('Assigned', assignedCount.toString()),
                        const SizedBox(width: 8),
                        _panelStat('On The Way', onTheWayCount.toString()),
                        const SizedBox(width: 8),
                        _panelStat('Delivered', deliveredCount.toString()),
                      ],
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                  itemCount: docs.length,
                  separatorBuilder: (_, __) {
                    return const SizedBox(height: 10);
                  },
                  itemBuilder: (_, i) {
                    final d = docs[i];
                    final assignData = d.data();
                    // assigned_orders keeps link to the real order document.
                    final orderPath = (assignData['orderPath'] ?? '').toString();

                    if (orderPath.isEmpty) {
                      return _infoCard('Invalid assignment data.');
                    }

                    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                      stream: FirebaseFirestore.instance.doc(orderPath).snapshots(),
                      builder: (context, orderSnap) {
                        if (!orderSnap.hasData) {
                          return _infoCard('', loading: true);
                        }

                        if (!orderSnap.data!.exists) {
                          return _infoCard('Order no longer exists.');
                        }

                        final o = orderSnap.data!.data() ?? const {};
                        final status = _text(o['deliveryStatus'], fallback: 'Assigned');
                        final orderAddress = _text(
                          o['deliveryAddress'] ??
                              o['address'] ??
                              assignData['deliveryAddress'],
                        );
                        final customer = _text(o['customerPhone']);
                        final fee = (o['deliveryFee'] is num)
                            ? (o['deliveryFee'] as num).toDouble()
                            : (assignData['deliveryFee'] is num)
                            ? (assignData['deliveryFee'] as num).toDouble()
                            : 5.0;
                        final isOnTheWay = status == 'On The Way';
                        final isDelivered = status == 'Delivered';
                        Widget buildOrderCard(String address) {
                          // Local helper widget so both direct and fallback address use same UI.
                          return Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: const Color(0xFFE2E8E7)),
                              boxShadow: const [
                                BoxShadow(
                                  color: Color(0x11000000),
                                  blurRadius: 8,
                                  offset: Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          'Order #${_orderIdFromPath(orderPath)}',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w900,
                                            fontSize: 15,
                                          ),
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 5,
                                        ),
                                        decoration: BoxDecoration(
                                          color: _statusColor(status).withValues(alpha: 0.12),
                                          borderRadius: BorderRadius.circular(999),
                                        ),
                                        child: Text(
                                          status,
                                          style: TextStyle(
                                            color: _statusColor(status),
                                            fontWeight: FontWeight.w900,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Fee: ${_money(fee)}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFF00695C),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text('Address: $address'),
                                  if (customer.isNotEmpty) Text('Customer: $customer'),
                                  const SizedBox(height: 10),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: [
                                      ElevatedButton.icon(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor:
                                          isOnTheWay
                                              ? const Color(0xFF1565C0)
                                              : Colors.grey.shade200,
                                          foregroundColor:
                                          isOnTheWay
                                              ? Colors.white
                                              : Colors.black87,
                                        ),
                                        onPressed: () async {
                                          final ok = await showConfirmDialog(
                                            context,
                                            title: 'Update Delivery',
                                            message:
                                            'Set delivery status to "On The Way"?',
                                            confirmText: 'Update',
                                          );
                                          if (!ok) return;
                                          await svc.updateOrderByPath(
                                            orderPath: orderPath,
                                            data: {
                                              // Keep user/admin status aligned with delivery status.
                                              'deliveryStatus': 'On The Way',
                                              'status': 'To Receive',
                                            },
                                          );
                                        },
                                        icon: const Icon(Icons.local_shipping_outlined),
                                        label: const Text('On The Way'),
                                      ),
                                      ElevatedButton.icon(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor:
                                          isDelivered
                                              ? const Color(0xFF2E7D32)
                                              : Colors.grey.shade200,
                                          foregroundColor:
                                          isDelivered
                                              ? Colors.white
                                              : Colors.black87,
                                        ),
                                        onPressed: () async {
                                          final ok = await showConfirmDialog(
                                            context,
                                            title: 'Update Delivery',
                                            message:
                                            'Set delivery status to "Delivered"?',
                                            confirmText: 'Update',
                                          );
                                          if (!ok) return;
                                          await svc.updateOrderByPath(
                                            orderPath: orderPath,
                                            data: {
                                              'deliveryStatus': 'Delivered',
                                              // Completed when parcel is confirmed delivered.
                                              'status': 'Completed',
                                            },
                                          );
                                        },
                                        icon: const Icon(Icons.check_circle_outline),
                                        label: const Text('Delivered'),
                                      ),
                                      OutlinedButton.icon(
                                        onPressed: () async {
                                          if (address.trim().isEmpty ||
                                              address == 'No address') {
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              const SnackBar(
                                                content: Text(
                                                  'No address found for this order.',
                                                ),
                                              ),
                                            );
                                            return;
                                          }
                                          final ok = await showConfirmDialog(
                                            context,
                                            title: 'Open Route',
                                            message: 'Open route in OpenStreetMap?',
                                            confirmText: 'Open',
                                          );
                                          if (!ok) return;
                                          await _openMap(address);
                                        },
                                        icon: const Icon(Icons.map_outlined),
                                        label: const Text('Route'),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        }

                        if (orderAddress.isNotEmpty) {
                          return buildOrderCard(orderAddress);
                        }

                        return FutureBuilder<String>(
                          future: _loadAddressFromUserProfile(orderPath),
                          builder: (context, addrSnap) {
                            if (addrSnap.connectionState == ConnectionState.waiting) {
                              return _infoCard('', loading: true);
                            }
                            final fallbackAddress = _text(
                              addrSnap.data,
                              fallback: 'No address',
                            );
                            return buildOrderCard(fallbackAddress);
                          },
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _panelStat(String label, String value) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// This class defines DeliveryProfilePage, used for this page/feature.
class DeliveryProfilePage extends StatelessWidget {
  const DeliveryProfilePage({super.key});
  static const double _defaultDeliveryFee = 5.0;

  Future<bool> _confirmLogout(BuildContext context) async {
    return showConfirmDialog(
      context,
      title: 'Logout',
      message: 'Are you sure you want to logout?',
      confirmText: 'Logout',
    );
  }

  Future<void> _logout(BuildContext context) async {
    final navigator = Navigator.of(context);
    await FirebaseAuth.instance.signOut();
    navigator.pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginPage()),
      (route) {
        return false;
      },
    );
  }

  String _pickName(Map<String, dynamic> data) {
    for (final key in const ['name', 'fullName', 'displayName', 'username']) {
      final v = (data[key] ?? '').toString().trim();
      if (v.isNotEmpty) return v;
    }
    return 'Delivery Staff';
  }

  DateTime _asDate(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return DateTime.fromMillisecondsSinceEpoch(0);
  }

  List<DateTime> _monthRange(DateTime month) {
    final start = DateTime(month.year, month.month, 1);
    final end = DateTime(month.year, month.month + 1, 1);
    return [start, end];
  }

  Future<List<Map<String, dynamic>>> _loadMonthlySalaryRows(
    String uid,
    DateTime month,
  ) async {
    final range = _monthRange(month);
    final start = range[0];
    final end = range[1];
    final rows = <Map<String, dynamic>>[];
    final seen = <String>{};

    void addOrderRow(String orderId, Map<String, dynamic> data, {String? key}) {
      final uniqueKey = key ?? orderId;
      if (seen.contains(uniqueKey)) return;

      final status = (data['deliveryStatus'] ?? '').toString();
      if (status != 'Delivered') return;

      final deliveredAt = _asDate(
        data['updatedAt'] ?? data['deliveredAt'] ?? data['createdAt'],
      );
      if (deliveredAt.isBefore(start) || !deliveredAt.isBefore(end)) return;

      final fee = (data['deliveryFee'] is num)
          ? (data['deliveryFee'] as num).toDouble()
          : _defaultDeliveryFee;
      final customer = (data['customerName'] ?? data['customerPhone'] ?? '-')
          .toString()
          .trim();
      final address = (data['deliveryAddress'] ?? data['address'] ?? '-')
          .toString()
          .trim();

      rows.add({
        'orderId': orderId,
        'customer': customer.isEmpty ? '-' : customer,
        'address': address.isEmpty ? '-' : address,
        'fee': fee <= 0 ? 0.0 : fee,
        'deliveredAt': deliveredAt,
      });
      seen.add(uniqueKey);
    }

    try {
      final byUid = await FirebaseFirestore.instance
          .collectionGroup('orders')
          .where('deliveryUid', isEqualTo: uid)
          .get();
      for (final doc in byUid.docs) {
        addOrderRow(
          doc.id,
          doc.data(),
          key: doc.reference.path,
        );
      }
    } on FirebaseException catch (_) {}

    try {
      final byId = await FirebaseFirestore.instance
          .collectionGroup('orders')
          .where('deliveryId', isEqualTo: uid)
          .get();
      for (final doc in byId.docs) {
        addOrderRow(
          doc.id,
          doc.data(),
          key: doc.reference.path,
        );
      }
    } on FirebaseException catch (_) {}

    // Fallback for setups where order docs are missing delivery uid/id,
    // but assigned_orders still contains orderPath.
    if (rows.isEmpty) {
      try {
        final assigned = await FirebaseFirestore.instance
            .collection('delivery_staff')
            .doc(uid)
            .collection('assigned_orders')
            .get();

        for (final doc in assigned.docs) {
          final path = (doc.data()['orderPath'] ?? '').toString().trim();
          if (path.isEmpty) continue;
          try {
            final orderSnap = await FirebaseFirestore.instance.doc(path).get();
            if (!orderSnap.exists) continue;
            addOrderRow(
              orderSnap.id,
              orderSnap.data() ?? const <String, dynamic>{},
              key: path,
            );
          } on FirebaseException catch (_) {}
        }
      } on FirebaseException catch (_) {}
    }

    rows.sort((a, b) {
      final ad = a['deliveredAt'] as DateTime;
      final bd = b['deliveredAt'] as DateTime;
      return ad.compareTo(bd);
    });

    return rows;
  }

  pw.Widget _pdfCell(
    String text, {
    bool bold = false,
    PdfColor? background,
    pw.TextAlign align = pw.TextAlign.left,
  }) {
    return pw.Container(
      color: background,
      padding: const pw.EdgeInsets.all(7),
      child: pw.Text(
        text,
        textAlign: align,
        style: pw.TextStyle(
          fontSize: 10,
          fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
        ),
      ),
    );
  }

  Future<Uint8List> _buildMonthlySalaryPdf({
    required String staffName,
    required String staffEmail,
    required DateTime month,
    required List<Map<String, dynamic>> rows,
  }) async {
    final monthLabel = DateFormat('MMMM yyyy').format(month);
    final generatedAt = DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.now());
    double total = 0;
    for (final row in rows) {
      final fee = row['fee'];
      if (fee is num) total += fee.toDouble();
    }

    final doc = pw.Document();
    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(28),
        build: (context) => [
          pw.Container(
            padding: const pw.EdgeInsets.all(14),
            decoration: pw.BoxDecoration(
              color: PdfColors.teal50,
              borderRadius: pw.BorderRadius.circular(12),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'DELIVERY MONTHLY SALARY BILL',
                  style: pw.TextStyle(
                    fontSize: 20,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.teal900,
                  ),
                ),
                pw.SizedBox(height: 6),
                pw.Text('Month: $monthLabel'),
                pw.Text('Delivery Staff: $staffName'),
                if (staffEmail.trim().isNotEmpty) pw.Text('Email: $staffEmail'),
                pw.Text('Generated: $generatedAt'),
              ],
            ),
          ),
          pw.SizedBox(height: 14),
          pw.Row(
            children: [
              pw.Expanded(
                child: _pdfCell(
                  'Delivered Orders: ${rows.length}',
                  bold: true,
                  background: PdfColors.grey100,
                ),
              ),
              pw.SizedBox(width: 10),
              pw.Expanded(
                child: _pdfCell(
                  'Total Salary: RM ${total.toStringAsFixed(2)}',
                  bold: true,
                  background: PdfColors.grey100,
                  align: pw.TextAlign.right,
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 14),
          if (rows.isEmpty)
            pw.Text('No delivered orders for this month.')
          else
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.7),
              columnWidths: {
                0: const pw.FlexColumnWidth(2),
                1: const pw.FlexColumnWidth(2.2),
                2: const pw.FlexColumnWidth(3.8),
                3: const pw.FlexColumnWidth(1.6),
                4: const pw.FlexColumnWidth(1.8),
              },
              children: [
                pw.TableRow(
                  children: [
                    _pdfCell('Order ID', bold: true, background: PdfColors.teal100),
                    _pdfCell('Delivered Date', bold: true, background: PdfColors.teal100),
                    _pdfCell('Address', bold: true, background: PdfColors.teal100),
                    _pdfCell('Customer', bold: true, background: PdfColors.teal100),
                    _pdfCell(
                      'Fee (RM)',
                      bold: true,
                      background: PdfColors.teal100,
                      align: pw.TextAlign.right,
                    ),
                  ],
                ),
                for (final row in rows)
                  pw.TableRow(
                    children: [
                      _pdfCell((row['orderId'] ?? '-').toString()),
                      _pdfCell(
                        DateFormat('dd/MM/yyyy').format(row['deliveredAt'] as DateTime),
                      ),
                      _pdfCell((row['address'] ?? '-').toString()),
                      _pdfCell((row['customer'] ?? '-').toString()),
                      _pdfCell(
                        (row['fee'] as num).toDouble().toStringAsFixed(2),
                        align: pw.TextAlign.right,
                      ),
                    ],
                  ),
              ],
            ),
        ],
      ),
    );
    return doc.save();
  }

  Future<void> _printMonthlySalaryBill(
    BuildContext context, {
    required String uid,
    required String staffName,
    required String staffEmail,
    required bool share,
  }) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: DateTime(now.year - 5, 1, 1),
      lastDate: DateTime(now.year + 1, 12, 31),
      helpText: 'Select Salary Month',
    );
    if (picked == null) return;
    if (!context.mounted) return;

    final month = DateTime(picked.year, picked.month, 1);

    try {
      final rows = await _loadMonthlySalaryRows(uid, month);
      if (!context.mounted) return;

      if (rows.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'No delivered orders in ${DateFormat('MMMM yyyy').format(month)}.',
            ),
          ),
        );
        return;
      }

      final bytes = await _buildMonthlySalaryPdf(
        staffName: staffName,
        staffEmail: staffEmail,
        month: month,
        rows: rows,
      );
      final code = DateFormat('yyyy_MM').format(month);
      final fileName = 'delivery_salary_bill_$code.pdf';

      if (share) {
        await Printing.sharePdf(bytes: bytes, filename: fileName);
      } else {
        await Printing.layoutPdf(
          onLayout: (format) async => bytes,
          name: fileName,
        );
      }
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to generate salary bill: $e')),
      );
    }
  }

  Future<Map<String, dynamic>> _loadLiveStats(String uid) async {
    int totalAssigned = 0;
    int onTheWay = 0;
    int delivered = 0;
    double earnings = 0;

    try {
      final snap =
          await FirebaseFirestore.instance
              .collectionGroup('orders')
              .where('deliveryUid', isEqualTo: uid)
              .get();

      for (final doc in snap.docs) {
        totalAssigned += 1;
        final o = doc.data();
        final status = (o['deliveryStatus'] ?? '').toString();
        if (status == 'On The Way') onTheWay += 1;
        if (status == 'Delivered') {
          delivered += 1;
          final fee = (o['deliveryFee'] is num)
              ? (o['deliveryFee'] as num).toDouble()
              : _defaultDeliveryFee;
          if (fee > 0) earnings += fee;
        }
      }
      return {
        'totalAssigned': totalAssigned,
        'onTheWay': onTheWay,
        'delivered': delivered,
        'earnings': earnings,
      };
    } on FirebaseException catch (_) {
      // Fallback: assigned_orders + pull latest order doc by orderPath.
      final assigned =
          await FirebaseFirestore.instance
              .collection('delivery_staff')
              .doc(uid)
              .collection('assigned_orders')
              .get();

      for (final doc in assigned.docs) {
        totalAssigned += 1;
        final data = doc.data();
        var status = (data['deliveryStatus'] ?? '').toString();
        var deliveryFee =
            (data['deliveryFee'] is num)
                ? (data['deliveryFee'] as num).toDouble()
                : _defaultDeliveryFee;

        final orderPath = (data['orderPath'] ?? '').toString();
        if (orderPath.isNotEmpty) {
          try {
            final orderSnap = await FirebaseFirestore.instance.doc(orderPath).get();
            if (orderSnap.exists) {
              final o = orderSnap.data() ?? const <String, dynamic>{};
              status = (o['deliveryStatus'] ?? status).toString();
              final f = o['deliveryFee'];
              if (f is num) deliveryFee = f.toDouble();
            }
          } on FirebaseException catch (_) {}
        }

        if (status == 'On The Way') onTheWay += 1;
        if (status == 'Delivered') {
          delivered += 1;
          if (deliveryFee > 0) earnings += deliveryFee;
        }
      }
      return {
        'totalAssigned': totalAssigned,
        'onTheWay': onTheWay,
        'delivered': delivered,
        'earnings': earnings,
      };
    }
  }

  Stream<Map<String, dynamic>> _statsStream(String uid) async* {
    while (true) {
      yield await _loadLiveStats(uid);
      await Future<void>.delayed(const Duration(seconds: 3));
    }
  }

  @override
  // Builds and returns the UI for this widget.
  Widget build(BuildContext context) {
    const kOrange = Color(0xFF00695C);
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final svc = FirestoreService();

    return Scaffold(
      backgroundColor: const Color(0xFFF2F7F6),
      appBar: AppBar(
        title: const Text('Delivery Profile'),
        backgroundColor: kOrange,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              final ok = await _confirmLogout(context);
              if (!ok) return;
              if (!context.mounted) return;
              await _logout(context);
            },
          ),
        ],
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance.collection('users').doc(uid).snapshots(),
        builder: (context, userSnap) {
          if (userSnap.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'Failed to load profile.\n${userSnap.error}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            );
          }

          return StreamBuilder<Map<String, dynamic>>(
            stream: _statsStream(uid),
            builder: (context, statsSnap) {
              if (!userSnap.hasData || !statsSnap.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final data = userSnap.data?.data() ?? const <String, dynamic>{};
              final name = _pickName(data);
              final email = (data['email'] ?? '').toString();
              final phone = (data['phone'] ?? '').toString();
              final stats = statsSnap.data ?? const <String, dynamic>{};
              final totalAssigned = (stats['totalAssigned'] ?? 0) as int;
              final onTheWay = (stats['onTheWay'] ?? 0) as int;
              final delivered = (stats['delivered'] ?? 0) as int;
              final earnings = (stats['earnings'] ?? 0.0) as double;
              final onDuty = (data['deliveryOnDuty'] ?? true) == true;

              return _DeliveryProfileBody(
                name: name,
                email: email,
                phone: phone,
                totalAssigned: totalAssigned,
                onTheWay: onTheWay,
                delivered: delivered,
                earnings: earnings,
                onDuty: onDuty,
                onPrintSalary: (share) async {
                  await _printMonthlySalaryBill(
                    context,
                    uid: uid,
                    staffName: name,
                    staffEmail: email,
                    share: share,
                  );
                },
                onToggleDuty: (setOnDuty) async {
                  final title = setOnDuty ? 'Turn On Duty' : 'Turn Off Duty';
                  final msg = setOnDuty
                      ? 'Set yourself as ON DUTY now? Admin can assign orders to you.'
                      : 'Set yourself as OFF DUTY now? Admin cannot assign orders to you.';
                  final ok = await showConfirmDialog(
                    context,
                    title: title,
                    message: msg,
                    confirmText: setOnDuty ? 'On Duty' : 'Off Duty',
                  );
                  if (!ok) return;
                  await svc.setDeliveryOnDuty(userId: uid, onDuty: setOnDuty);
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        setOnDuty
                            ? 'You are now On Duty.'
                            : 'You are now Off Duty.',
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}

// This class defines _DeliveryProfileBody, used for this page/feature.
class _DeliveryProfileBody extends StatelessWidget {
  final String name;
  final String email;
  final String phone;
  final int totalAssigned;
  final int onTheWay;
  final int delivered;
  final double earnings;
  final bool onDuty;
  final Future<void> Function(bool share) onPrintSalary;
  final Future<void> Function(bool setOnDuty) onToggleDuty;

  const _DeliveryProfileBody({
    required this.name,
    required this.email,
    required this.phone,
    required this.totalAssigned,
    required this.onTheWay,
    required this.delivered,
    required this.earnings,
    required this.onDuty,
    required this.onPrintSalary,
    required this.onToggleDuty,
  });

  @override
  // Builds and returns the UI for this widget.
  Widget build(BuildContext context) {
    final nowLabel = DateFormat('MMMM yyyy').format(DateTime.now());
    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF00695C), Color(0xFF26A69A)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 20,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                email.isEmpty ? 'No email' : email,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (phone.trim().isNotEmpty)
                Text(
                  phone,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.17),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  'Monthly Salary Bill: $nowLabel',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: onDuty
                          ? const Color(0xFF1B5E20).withValues(alpha: 0.35)
                          : const Color(0xFFB71C1C).withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      onDuty ? 'Current: ON DUTY' : 'Current: OFF DUTY',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: BorderSide(
                        color: Colors.white.withValues(alpha: 0.75),
                      ),
                    ),
                    onPressed: () async {
                      await onToggleDuty(!onDuty);
                    },
                    icon: Icon(
                      onDuty
                          ? Icons.pause_circle_outline
                          : Icons.play_circle_outline,
                    ),
                    label: Text(onDuty ? 'Set Off Duty' : 'Set On Duty'),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: _StatCard(
                title: 'Assigned',
                value: totalAssigned.toString(),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _StatCard(title: 'On The Way', value: onTheWay.toString()),
            ),
          ],
        ),
        Row(
          children: [
            Expanded(
              child: _StatCard(title: 'Delivered', value: delivered.toString()),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _StatCard(
                title: 'Earnings (RM)',
                value: earnings.toStringAsFixed(2),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE2E8E7)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x11000000),
                blurRadius: 8,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Monthly Salary Bill',
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                  color: Color(0xFF00695C),
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Select a month and generate printable salary PDF from delivered orders.',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Colors.black54,
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00695C),
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () async {
                    await onPrintSalary(false);
                  },
                  icon: const Icon(Icons.picture_as_pdf_outlined),
                  label: const Text('Preview / Print Salary PDF'),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () async {
                    await onPrintSalary(true);
                  },
                  icon: const Icon(Icons.share_outlined),
                  label: const Text('Share Salary PDF'),
                ),
              ),
            ],
          ),
        ),
        Container(
          margin: const EdgeInsets.only(top: 10),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFE8F5E9),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Text(
            'Salary is calculated from delivered orders using delivery fee for the selected month.',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: Color(0xFF1B5E20),
            ),
          ),
        ),
      ],
    );
  }
}

// This class defines _StatCard, used for this page/feature.
class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  const _StatCard({required this.title, required this.value});

  @override
  // Builds and returns the UI for this widget.
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      child: AppCard(
        child: Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
            Text(
              value,
              style: const TextStyle(
                fontWeight: FontWeight.w900,
                color: Color(0xFF00695C),
              ),
            ),
          ],
        ),
      ),
    );
  }
}



