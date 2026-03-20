// How this file works:
// 1) Data/models are declared first (if any).
// 2) UI widgets are built in build() methods.
// 3) Helper methods are used to keep UI code clean.
//
// File purpose: This file handles super admin screen/logic.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl_phone_field/intl_phone_field.dart';

import 'package:fyp/Admin/firestore_service.dart';
import 'package:fyp/User/login.dart';

class SuperAdminPanelPage extends StatefulWidget {
  const SuperAdminPanelPage({super.key});

  @override
  State<SuperAdminPanelPage> createState() => _SuperAdminPanelPageState();
}

class _SuperAdminPanelPageState extends State<SuperAdminPanelPage>
    with SingleTickerProviderStateMixin {
  final FirestoreService _svc = FirestoreService();

  late final TabController _tabController;

  static const Color kPrimary = Color(0xFFFFC107);
  static const Color kPrimaryLight = Color(0xFFFFF8E1);
  static const Color kPageBg = Color(0xFFFFFEF8);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 6, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _logout() async {
    await _svc.signOut();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginPage()),
      (route) => false,
    );
  }

  void _showMsg(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _svc.isSuperAdmin(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snap.data != true) {
          return Scaffold(
            backgroundColor: kPageBg,
            appBar: AppBar(
              title: const Text(
                'Access Denied',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
              backgroundColor: kPrimary,
            ),
            body: const Center(
              child: Text(
                'Only super admin can access this page.',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
          );
        }

        return Scaffold(
          backgroundColor: kPageBg,
          appBar: AppBar(
            backgroundColor: kPrimary,
            foregroundColor: Colors.black87,
            title: const Text(
              'Super Admin Panel',
              style: TextStyle(fontWeight: FontWeight.w900),
            ),
            actions: [
              IconButton(
                tooltip: 'Logout',
                onPressed: _logout,
                icon: const Icon(Icons.logout),
              ),
            ],
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(62),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.25),
                    ),
                  ),
                  child: TabBar(
                    controller: _tabController,
                    isScrollable: true,
                    dividerColor: Colors.transparent,
                    indicatorSize: TabBarIndicatorSize.tab,
                    indicator: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x22000000),
                          blurRadius: 6,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    indicatorPadding: const EdgeInsets.all(4),
                    labelPadding: const EdgeInsets.symmetric(horizontal: 12),
                    labelColor: Colors.black87,
                    unselectedLabelColor: Colors.black54,
                    labelStyle: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                    ),
                    unselectedLabelStyle: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                    tabs: const [
                      Tab(
                        icon: Icon(Icons.dashboard_outlined, size: 18),
                        text: 'Dashboard',
                      ),
                      Tab(
                        icon: Icon(Icons.storefront_outlined, size: 18),
                        text: 'Stores',
                      ),
                      Tab(
                        icon: Icon(Icons.group_outlined, size: 18),
                        text: 'Users',
                      ),
                      Tab(
                        icon: Icon(Icons.delivery_dining_outlined, size: 18),
                        text: 'Delivery Man',
                      ),
                      Tab(
                        icon: Icon(Icons.local_shipping_outlined, size: 18),
                        text: 'Orders',
                      ),
                      Tab(
                        icon: Icon(Icons.feedback_outlined, size: 18),
                        text: 'Feedback',
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          body: TabBarView(
            controller: _tabController,
            children: [
              _SuperAdminDashboard(
                svc: _svc,
                primary: kPrimary,
                light: kPrimaryLight,
                onOpenTab: (index) => _tabController.animateTo(index),
              ),
              _StoresTab(
                svc: _svc,
                primary: kPrimary,
                light: kPrimaryLight,
                onMsg: _showMsg,
              ),
              _UsersTab(
                svc: _svc,
                primary: kPrimary,
                light: kPrimaryLight,
                onMsg: _showMsg,
                rolesToShow: const {'user', 'admin', 'super_admin'},
                emptyMessage: 'No users found.',
                addButtonLabel: 'Add User',
                defaultRoleForCreate: 'user',
              ),
              _UsersTab(
                svc: _svc,
                primary: kPrimary,
                light: kPrimaryLight,
                onMsg: _showMsg,
                rolesToShow: const {'delivery'},
                emptyMessage: 'No delivery man found.',
                addButtonLabel: 'Add Delivery Man',
                defaultRoleForCreate: 'delivery',
              ),
              _OrdersAssignTab(
                svc: _svc,
                primary: kPrimary,
                light: kPrimaryLight,
                onMsg: _showMsg,
              ),
              _FeedbackTab(
                primary: kPrimary,
                light: kPrimaryLight,
                onMsg: _showMsg,
              ),
            ],
          ),
        );
      },
    );
  }
}

enum _SummaryPeriod { weekly, monthly, yearly }

class _SuperAdminDashboard extends StatefulWidget {
  final FirestoreService svc;
  final Color primary;
  final Color light;
  final void Function(int) onOpenTab;

  const _SuperAdminDashboard({
    required this.svc,
    required this.primary,
    required this.light,
    required this.onOpenTab,
  });

  @override
  State<_SuperAdminDashboard> createState() => _SuperAdminDashboardState();
}

class _SuperAdminDashboardState extends State<_SuperAdminDashboard> {
  _SummaryPeriod _selectedPeriod = _SummaryPeriod.monthly;
  late Future<List<Map<String, dynamic>>> _storeSummaryFuture;

  @override
  void initState() {
    super.initState();
    _storeSummaryFuture = _loadStoreSummary();
  }

  DateTime _startOfDay(DateTime dt) => DateTime(dt.year, dt.month, dt.day);

  ({DateTime start, DateTime end}) _periodRange(
    _SummaryPeriod period,
    DateTime now,
  ) {
    final dayStart = _startOfDay(now);
    if (period == _SummaryPeriod.weekly) {
      final weekStart = dayStart.subtract(Duration(days: dayStart.weekday - 1));
      return (start: weekStart, end: weekStart.add(const Duration(days: 7)));
    }
    if (period == _SummaryPeriod.monthly) {
      final start = DateTime(dayStart.year, dayStart.month, 1);
      final end =
          dayStart.month == 12
              ? DateTime(dayStart.year + 1, 1, 1)
              : DateTime(dayStart.year, dayStart.month + 1, 1);
      return (start: start, end: end);
    }
    return (
      start: DateTime(dayStart.year, 1, 1),
      end: DateTime(dayStart.year + 1, 1, 1),
    );
  }

  bool _inRange(DateTime dt, DateTime start, DateTime end) {
    return !dt.isBefore(start) && dt.isBefore(end);
  }

  DateTime _asDate(dynamic v) {
    if (v is Timestamp) return v.toDate();
    if (v is DateTime) return v;
    return DateTime.fromMillisecondsSinceEpoch(0);
  }

  DateTime _orderTime(Map<String, dynamic> order) {
    return _asDate(order['createdAt'] ?? order['paidAt'] ?? order['updatedAt']);
  }

  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>> _safeQueryDocs(
    Future<QuerySnapshot<Map<String, dynamic>>> Function() loader,
  ) async {
    try {
      final snap = await loader();
      return snap.docs;
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied' || e.code == 'failed-precondition') {
        return const <QueryDocumentSnapshot<Map<String, dynamic>>>[];
      }
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> _loadStoreSummary() async {
    final range = _periodRange(_selectedPeriod, DateTime.now());
    final start = range.start;
    final end = range.end;
    final db = FirebaseFirestore.instance;

    final storesDocs = await _safeQueryDocs(() => db.collection('stores').get());
    final productsDocs = await _safeQueryDocs(
      () => db.collection('products').get(),
    );
    final pricesDocs = await _safeQueryDocs(() => db.collectionGroup('prices').get());
    final ordersDocs = await widget.svc.ordersAllForAdmin();

    final storeNameById = <String, String>{};
    for (final doc in storesDocs) {
      final name = (doc.data()['name'] ?? doc.id).toString().trim();
      storeNameById[doc.id] = name.isEmpty ? doc.id : name;
    }

    final productCategoryById = <String, String>{};
    final productNameById = <String, String>{};
    final productStoreIds = <String, Set<String>>{};
    for (final doc in productsDocs) {
      final data = doc.data();
      final category = (data['category'] ?? 'Uncategorized').toString().trim();
      productCategoryById[doc.id] =
          category.isEmpty ? 'Uncategorized' : category;
      final productName = (data['name'] ?? doc.id).toString().trim();
      productNameById[doc.id] = productName.isEmpty ? doc.id : productName;

      final sid = (data['storeId'] ?? '').toString().trim();
      if (sid.isNotEmpty) {
        productStoreIds.putIfAbsent(doc.id, () => <String>{}).add(sid);
      }
    }

    for (final priceDoc in pricesDocs) {
      final sid = (priceDoc.data()['storeId'] ?? '').toString().trim();
      final pid = priceDoc.reference.parent.parent?.id ?? '';
      if (sid.isEmpty || pid.isEmpty) continue;
      productStoreIds.putIfAbsent(pid, () => <String>{}).add(sid);
    }

    final summaryByStore = <String, Map<String, dynamic>>{};
    for (final storeId in storeNameById.keys) {
      summaryByStore[storeId] = {
        'storeId': storeId,
        'storeName': storeNameById[storeId] ?? storeId,
        'orders': 0,
        'items': 0,
        'revenue': 0.0,
        'categoryItems': <String, int>{},
        'productItems': <String, int>{},
      };
    }

    for (final orderDoc in ordersDocs) {
      final order = orderDoc.data();
      if (!_inRange(_orderTime(order), start, end)) continue;

      final items = (order['items'] as List?) ?? const [];
      final total = (order['total'] is num) ? (order['total'] as num).toDouble() : 0.0;
      final orderStoreId = (order['storeId'] ?? '').toString().trim();

      final storeQty = <String, int>{};
      int totalQty = 0;

      for (final rawItem in items) {
        if (rawItem is! Map) continue;
        final item = rawItem;
        final pid = (item['productId'] ?? '').toString().trim();
        if (pid.isEmpty) continue;

        final rawQty = item['qty'];
        int qty = 0;
        if (rawQty is int) qty = rawQty;
        if (rawQty is num) qty = rawQty.toInt();
        if (qty <= 0) qty = 1;
        totalQty += qty;

        final itemStoreId = (item['storeId'] ?? '').toString().trim();
        final candidates = <String>{};
        if (itemStoreId.isNotEmpty) candidates.add(itemStoreId);
        candidates.addAll(productStoreIds[pid] ?? const <String>{});

        String targetStoreId = '';
        if (candidates.length == 1) {
          targetStoreId = candidates.first;
        } else if (orderStoreId.isNotEmpty && candidates.contains(orderStoreId)) {
          targetStoreId = orderStoreId;
        } else if (orderStoreId.isNotEmpty && candidates.isEmpty) {
          targetStoreId = orderStoreId;
        } else if (candidates.isNotEmpty) {
          final sorted = candidates.toList()..sort();
          targetStoreId = sorted.first;
        }

        if (targetStoreId.isEmpty || !summaryByStore.containsKey(targetStoreId)) {
          continue;
        }

        storeQty[targetStoreId] = (storeQty[targetStoreId] ?? 0) + qty;
        final category = (productCategoryById[pid] ?? 'Uncategorized').trim();
        final safeCategory =
            category.isEmpty ? 'Uncategorized' : category;
        final cMap =
            summaryByStore[targetStoreId]!['categoryItems'] as Map<String, int>;
        cMap[safeCategory] = (cMap[safeCategory] ?? 0) + qty;
        final productName = (productNameById[pid] ?? pid).trim();
        final safeProduct = productName.isEmpty ? pid : productName;
        final pMap =
            summaryByStore[targetStoreId]!['productItems'] as Map<String, int>;
        pMap[safeProduct] = (pMap[safeProduct] ?? 0) + qty;
      }

      if (storeQty.isEmpty) continue;

      for (final entry in storeQty.entries) {
        final sid = entry.key;
        final qty = entry.value;
        final summary = summaryByStore[sid]!;
        summary['orders'] = (summary['orders'] as int) + 1;
        summary['items'] = (summary['items'] as int) + qty;
        final share =
            (totalQty > 0) ? (total * (qty / totalQty)) : 0.0;
        summary['revenue'] = (summary['revenue'] as double) + share;
      }
    }

    final rows = <Map<String, dynamic>>[];
    for (final row in summaryByStore.values) {
      final cMap = row['categoryItems'] as Map<String, int>;
      final sortedCats =
          cMap.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
      final categoryStats =
          sortedCats
              .map((e) => <String, dynamic>{'category': e.key, 'items': e.value})
              .toList();
      final pMap = row['productItems'] as Map<String, int>;
      final sortedProducts =
          pMap.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
      row['topCategory'] =
          sortedCats.isEmpty
              ? '-'
              : '${sortedCats.first.key} (${sortedCats.first.value})';
      row['topProduct'] =
          sortedProducts.isEmpty
              ? '-'
              : '${sortedProducts.first.key} (${sortedProducts.first.value})';
      rows.add({
        'storeId': row['storeId'],
        'storeName': row['storeName'],
        'orders': row['orders'],
        'items': row['items'],
        'revenue': row['revenue'],
        'topCategory': row['topCategory'],
        'topProduct': row['topProduct'],
        'topCategoryStats': categoryStats,
      });
    }

    rows.sort(
      (a, b) => ((b['revenue'] as double?) ?? 0.0).compareTo(
        (a['revenue'] as double?) ?? 0.0,
      ),
    );

    final cacheBatch = db.batch();
    final periodCode =
        _selectedPeriod == _SummaryPeriod.weekly
            ? 'weekly'
            : _selectedPeriod == _SummaryPeriod.monthly
            ? 'monthly'
            : 'yearly';
    final nowIso = DateTime.now().toIso8601String();
    for (final row in rows) {
      final sid = (row['storeId'] ?? '').toString().trim();
      if (sid.isEmpty) continue;
      final ref = db
          .collection('stores')
          .doc(sid)
          .collection('report_cache')
          .doc(periodCode);
      cacheBatch.set(ref, {
        'periodCode': periodCode,
        'storeId': sid,
        'orders': row['orders'],
        'orderItems': row['items'],
        'revenue': row['revenue'],
        'topCategory': row['topCategory'],
        'topProduct': row['topProduct'],
        'topCategoryStats': row['topCategoryStats'],
        'updatedAt': FieldValue.serverTimestamp(),
        'updatedAtClient': nowIso,
      }, SetOptions(merge: true));
    }
    try {
      await cacheBatch.commit();
    } on FirebaseException {
      // Cache is optional; keep dashboard usable even if write is blocked.
    }

    return rows;
  }

  void _setPeriod(_SummaryPeriod period) {
    if (_selectedPeriod == period) return;
    setState(() {
      _selectedPeriod = period;
      _storeSummaryFuture = _loadStoreSummary();
    });
  }

  String _money(double value) => 'RM ${value.toStringAsFixed(2)}';

  String _periodLabel(_SummaryPeriod period) {
    if (period == _SummaryPeriod.weekly) return 'Weekly';
    if (period == _SummaryPeriod.monthly) return 'Monthly';
    return 'Yearly';
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, int>>(
      future: _loadCounts(),
      builder: (context, snap) {
        final data =
            snap.data ??
            {'stores': 0, 'users': 0, 'drivers': 0, 'orders': 0, 'feedback': 0};

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    widget.primary,
                    widget.primary.withValues(alpha: 0.92),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(18),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x22000000),
                    blurRadius: 10,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Super Admin Control Center',
                    style: TextStyle(
                      color: Colors.black87,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  SizedBox(height: 6),
                  Text(
                    'Manage stores, users, and driver assignment here.',
                    style: TextStyle(color: Colors.black54),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _statCard(
                  title: 'Total Stores',
                  value: '${data['stores']}',
                  onTap: () => widget.onOpenTab(1),
                ),
                _statCard(
                  title: 'Total Users',
                  value: '${data['users']}',
                  onTap: () => widget.onOpenTab(2),
                ),
                _statCard(
                  title: 'Total Drivers',
                  value: '${data['drivers']}',
                  onTap: () => widget.onOpenTab(3),
                ),
                _statCard(
                  title: 'Total Orders',
                  value: '${data['orders']}',
                  onTap: () => widget.onOpenTab(4),
                ),
                _statCard(
                  title: 'User Feedback',
                  value: '${data['feedback']}',
                  onTap: () => widget.onOpenTab(5),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFD7E1EE)),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x12000000),
                    blurRadius: 8,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Store Performance (${_periodLabel(_selectedPeriod)})',
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ChoiceChip(
                        label: const Text('Weekly'),
                        selected: _selectedPeriod == _SummaryPeriod.weekly,
                        onSelected: (s) {
                          if (!s) return;
                          _setPeriod(_SummaryPeriod.weekly);
                        },
                      ),
                      ChoiceChip(
                        label: const Text('Monthly'),
                        selected: _selectedPeriod == _SummaryPeriod.monthly,
                        onSelected: (s) {
                          if (!s) return;
                          _setPeriod(_SummaryPeriod.monthly);
                        },
                      ),
                      ChoiceChip(
                        label: const Text('Yearly'),
                        selected: _selectedPeriod == _SummaryPeriod.yearly,
                        onSelected: (s) {
                          if (!s) return;
                          _setPeriod(_SummaryPeriod.yearly);
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  FutureBuilder<List<Map<String, dynamic>>>(
                    future: _storeSummaryFuture,
                    builder: (context, summarySnap) {
                      if (!summarySnap.hasData) {
                        return const Padding(
                          padding: EdgeInsets.symmetric(vertical: 8),
                          child: LinearProgressIndicator(minHeight: 2),
                        );
                      }
                      final rows = summarySnap.data!;
                      if (rows.isEmpty) {
                        return const Text(
                          'No store performance data found for selected period.',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        );
                      }
                      return Column(
                        children:
                            rows.map((row) {
                              return Container(
                                width: double.infinity,
                                margin: const EdgeInsets.only(bottom: 8),
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: const Color(0xFFE6E6E6),
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      (row['storeName'] ?? '-').toString(),
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Orders: ${row['orders']} | Items: ${row['items']} | Revenue: ${_money((row['revenue'] as double?) ?? 0.0)}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    Text(
                                      'Top Category: ${(row['topCategory'] ?? '-').toString()}',
                                      style: const TextStyle(
                                        color: Colors.black54,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    Text(
                                      'Top Product: ${(row['topProduct'] ?? '-').toString()}',
                                      style: const TextStyle(
                                        color: Colors.black54,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Future<Map<String, int>> _loadCounts() async {
    final db = FirebaseFirestore.instance;
    final stores = await db.collection('stores').get();
    final users = await db.collection('users').get();
    final drivers = await db.collection('delivery_staff').get();
    final orders = await db.collectionGroup('orders').get();
    final feedback = await db.collection('user_feedback').get();

    return {
      'stores': stores.docs.length,
      'users': users.docs.length,
      'drivers': drivers.docs.length,
      'orders': orders.docs.length,
      'feedback': feedback.docs.length,
    };
  }

  Widget _statCard({
    required String title,
    required String value,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          width: 170,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFD7E1EE)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x12000000),
                blurRadius: 8,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            children: [
              Text(
                value,
                style: TextStyle(
                  color: widget.primary,
                  fontWeight: FontWeight.w800,
                  fontSize: 24,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1F2937),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StoresTab extends StatelessWidget {
  final FirestoreService svc;
  final Color primary;
  final Color light;
  final void Function(String) onMsg;

  const _StoresTab({
    required this.svc,
    required this.primary,
    required this.light,
    required this.onMsg,
  });

  bool _isHttpImageUrl(String? raw) {
    if (raw == null || raw.trim().isEmpty) return false;
    final uri = Uri.tryParse(raw.trim());
    return uri != null && (uri.scheme == 'http' || uri.scheme == 'https');
  }

  Future<void> _showStoreDialog(
    BuildContext context, {
    String? storeId,
    Map<String, dynamic>? data,
  }) async {
    final formKey = GlobalKey<FormState>();
    final nameCtrl = TextEditingController(
      text: (data?['name'] ?? '').toString(),
    );
    final locationCtrl = TextEditingController(
      text: (data?['location'] ?? '').toString(),
    );
    final logoCtrl = TextEditingController(
      text: (data?['logoUrl'] ?? '').toString(),
    );
    final adminNameCtrl = TextEditingController(
      text: (data?['adminName'] ?? '').toString(),
    );
    final adminEmailCtrl = TextEditingController(
      text: (data?['adminEmail'] ?? '').toString(),
    );
    final adminPhoneCtrl = TextEditingController(
      text: (data?['adminPhone'] ?? '').toString(),
    );
    final adminPasswordCtrl = TextEditingController();
    bool enabled = (data?['enabled'] ?? true) == true;
    bool saving = false;
    bool uploadingLogo = false;
    bool obscureAdminPassword = true;
    final picker = ImagePicker();
    final emailPattern = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text(storeId == null ? 'Add Store' : 'Edit Store'),
              content: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        controller: nameCtrl,
                        autovalidateMode: AutovalidateMode.onUserInteraction,
                        decoration: const InputDecoration(
                          labelText: 'Store Name',
                          border: OutlineInputBorder(),
                        ),
                        validator: (v) {
                          final value = (v ?? '').trim();
                          if (value.isEmpty) return 'Store name is required';
                          if (value.length < 3) {
                            return 'Store name must be at least 3 characters';
                          }
                          if (value.length > 60) {
                            return 'Store name must be 60 characters or less';
                          }
                          if (!RegExp(
                            r'^[A-Za-z0-9 &().,\-]+$',
                          ).hasMatch(value)) {
                            return 'Store name contains invalid characters';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: locationCtrl,
                        autovalidateMode: AutovalidateMode.onUserInteraction,
                        decoration: const InputDecoration(
                          labelText: 'Location',
                          border: OutlineInputBorder(),
                        ),
                        validator: (v) {
                          if ((v ?? '').trim().isEmpty) {
                            return 'Location is required';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: logoCtrl,
                        autovalidateMode: AutovalidateMode.onUserInteraction,
                        decoration: const InputDecoration(
                          labelText: 'Store Logo URL',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed:
                              saving || uploadingLogo
                                  ? null
                                  : () async {
                                    try {
                                      final file = await picker.pickImage(
                                        source: ImageSource.gallery,
                                        imageQuality: 85,
                                        maxWidth: 1800,
                                      );
                                      if (file == null) return;
                                      setState(() => uploadingLogo = true);
                                      final url = await svc.uploadImageXFile(
                                        file: file,
                                        folder: 'store_logos',
                                        fileNameHint: nameCtrl.text.trim(),
                                      );
                                      logoCtrl.text = url;
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          const SnackBar(
                                            content: Text('Logo uploaded'),
                                          ),
                                        );
                                      }
                                    } catch (e) {
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              'Logo upload failed: $e',
                                            ),
                                          ),
                                        );
                                      }
                                    } finally {
                                      if (context.mounted) {
                                        setState(() => uploadingLogo = false);
                                      }
                                    }
                                  },
                          icon: const Icon(Icons.cloud_upload_outlined),
                          label: Text(
                            uploadingLogo
                                ? 'Uploading Logo...'
                                : 'Upload Store Logo',
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Divider(height: 1),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: adminNameCtrl,
                        autovalidateMode: AutovalidateMode.onUserInteraction,
                        decoration: const InputDecoration(
                          labelText: 'Admin Name',
                          border: OutlineInputBorder(),
                        ),
                        validator: (v) {
                          if ((v ?? '').trim().isEmpty) {
                            return 'Admin name is required';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: adminEmailCtrl,
                        keyboardType: TextInputType.emailAddress,
                        autovalidateMode: AutovalidateMode.onUserInteraction,
                        decoration: const InputDecoration(
                          labelText: 'Admin Email',
                          border: OutlineInputBorder(),
                        ),
                        validator: (v) {
                          final email = (v ?? '').trim().toLowerCase();
                          if (email.isEmpty) return 'Admin email is required';
                          if (!emailPattern.hasMatch(email)) {
                            return 'Enter a valid admin email';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: adminPhoneCtrl,
                        keyboardType: TextInputType.phone,
                        autovalidateMode: AutovalidateMode.onUserInteraction,
                        decoration: const InputDecoration(
                          labelText: 'Admin Phone',
                          border: OutlineInputBorder(),
                        ),
                        validator: (v) {
                          if ((v ?? '').trim().isEmpty) {
                            return 'Admin phone is required';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: adminPasswordCtrl,
                        obscureText: obscureAdminPassword,
                        autovalidateMode: AutovalidateMode.onUserInteraction,
                        decoration: InputDecoration(
                          labelText:
                              storeId == null
                                  ? 'Admin Password'
                                  : 'Admin Password (for new admin only)',
                          border: const OutlineInputBorder(),
                          helperText:
                              storeId == null
                                  ? 'Min 8 characters'
                                  : 'Leave empty to keep existing admin account',
                          suffixIcon: IconButton(
                            tooltip:
                                obscureAdminPassword
                                    ? 'Show password'
                                    : 'Hide password',
                            onPressed:
                                saving
                                    ? null
                                    : () => setState(() {
                                      obscureAdminPassword =
                                          !obscureAdminPassword;
                                    }),
                            icon: Icon(
                              obscureAdminPassword
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                            ),
                          ),
                        ),
                        validator: (v) {
                          final value = (v ?? '').trim();
                          if (storeId == null && value.isEmpty) {
                            return 'Password is required for new admin';
                          }
                          if (value.isNotEmpty && value.length < 8) {
                            return 'Password must be at least 8 characters';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 6),
                      SwitchListTile(
                        value: enabled,
                        onChanged:
                            saving ? null : (v) => setState(() => enabled = v),
                        title: const Text('Enabled'),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: saving ? null : () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primary,
                    foregroundColor: Colors.black87,
                  ),
                  onPressed:
                      saving
                          ? null
                          : () async {
                            if (!formKey.currentState!.validate()) return;
                            final name = nameCtrl.text.trim();
                            final location = locationCtrl.text.trim();
                            final logoUrl = logoCtrl.text.trim();
                            final adminName = adminNameCtrl.text.trim();
                            final adminEmail =
                                adminEmailCtrl.text.trim().toLowerCase();
                            final adminPhone = adminPhoneCtrl.text.trim();
                            final adminPassword = adminPasswordCtrl.text.trim();
                            setState(() => saving = true);

                            final storesSnap =
                                await FirebaseFirestore.instance
                                    .collection('stores')
                                    .get();
                            final normalized = name.toLowerCase();
                            final duplicate = storesSnap.docs.any((doc) {
                              if (storeId != null && doc.id == storeId)
                                return false;
                              final existing =
                                  (doc.data()['name'] ?? '')
                                      .toString()
                                      .trim()
                                      .toLowerCase();
                              return existing == normalized;
                            });
                            if (duplicate) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Store name already exists'),
                                  ),
                                );
                              }
                              setState(() => saving = false);
                              return;
                            }

                            String adminUidToStore =
                                (data?['adminUid'] ?? '').toString().trim();

                            final usersRef = FirebaseFirestore.instance
                                .collection('users');
                            final matchedUser =
                                await usersRef
                                    .where('email', isEqualTo: adminEmail)
                                    .limit(1)
                                    .get();

                            final effectiveStoreId =
                                storeId ??
                                FirebaseFirestore.instance
                                    .collection('stores')
                                    .doc()
                                    .id;

                            if (matchedUser.docs.isNotEmpty) {
                              adminUidToStore = matchedUser.docs.first.id;
                            } else if (adminPassword.isEmpty) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Provide admin password to create new admin account',
                                    ),
                                  ),
                                );
                              }
                              setState(() => saving = false);
                              return;
                            } else {
                              FirebaseApp? secondaryApp;
                              FirebaseAuth? secondaryAuth;
                              try {
                                final appName =
                                    'super_admin_create_store_admin_${DateTime.now().millisecondsSinceEpoch}';
                                secondaryApp = await Firebase.initializeApp(
                                  name: appName,
                                  options: Firebase.app().options,
                                );
                                secondaryAuth = FirebaseAuth.instanceFor(
                                  app: secondaryApp,
                                );
                                final cred = await secondaryAuth
                                    .createUserWithEmailAndPassword(
                                      email: adminEmail,
                                      password: adminPassword,
                                    );
                                adminUidToStore = cred.user!.uid;
                              } on FirebaseAuthException catch (e) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        e.code == 'email-already-in-use'
                                            ? 'Admin email already in use'
                                            : 'Create admin failed: ${e.message ?? e.code}',
                                      ),
                                    ),
                                  );
                                }
                                setState(() => saving = false);
                                return;
                              } finally {
                                try {
                                  await secondaryAuth?.signOut();
                                } catch (_) {}
                                try {
                                  await secondaryApp?.delete();
                                } catch (_) {}
                              }
                            }

                            await FirebaseFirestore.instance
                                .collection('users')
                                .doc(adminUidToStore)
                                .set({
                                  'userId': adminUidToStore,
                                  'uid': adminUidToStore,
                                  'name': adminName,
                                  'fullName': adminName,
                                  'displayName': adminName,
                                  'email': adminEmail,
                                  'phone': adminPhone,
                                  'role': 'admin',
                                  'storeId': effectiveStoreId,
                                  'storeName': name,
                                  'blocked': false,
                                  'updatedAt': FieldValue.serverTimestamp(),
                                  'createdAt': FieldValue.serverTimestamp(),
                                }, SetOptions(merge: true));

                            await FirebaseFirestore.instance
                                .collection('admins')
                                .doc(adminUidToStore)
                                .set({
                                  'email': adminEmail,
                                  'name': adminName,
                                  'phone': adminPhone,
                                  'storeId': effectiveStoreId,
                                  'storeName': name,
                                  'updatedAt': FieldValue.serverTimestamp(),
                                  'createdAt': FieldValue.serverTimestamp(),
                                }, SetOptions(merge: true));

                            try {
                              await FirebaseFirestore.instance
                                  .collection('delivery_staff')
                                  .doc(adminUidToStore)
                                  .delete();
                            } catch (_) {}
                            try {
                              await FirebaseFirestore.instance
                                  .collection('super_admins')
                                  .doc(adminUidToStore)
                                  .delete();
                            } catch (_) {}

                            await svc.upsertStore(
                              storeId: effectiveStoreId,
                              name: name,
                              enabled: enabled,
                              location: location,
                              logoUrl: logoUrl,
                              adminUid: adminUidToStore,
                              adminEmail: adminEmail,
                              adminName: adminName,
                              adminPhone: adminPhone,
                            );

                            if (context.mounted) Navigator.pop(context);
                            onMsg(
                              storeId == null
                                  ? 'Store and admin created successfully'
                                  : 'Store updated successfully',
                            );
                            if (context.mounted) {
                              setState(() => saving = false);
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

  Future<void> _deleteStore(BuildContext context, String storeId) async {
    final ok =
        await showDialog<bool>(
          context: context,
          builder:
              (_) => AlertDialog(
                title: const Text('Delete Store'),
                content: const Text(
                  'Are you sure you want to delete this store?',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Cancel'),
                  ),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('Delete'),
                  ),
                ],
              ),
        ) ??
        false;

    if (!ok) return;

    await svc.deleteStore(storeId);
    onMsg('Store deleted');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton(
        backgroundColor: primary,
        foregroundColor: Colors.black87,
        onPressed: () => _showStoreDialog(context),
        child: const Icon(Icons.add),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: svc.storesStream(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snap.data?.docs ?? [];
          if (docs.isEmpty) {
            return const Center(child: Text('No stores found.'));
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final doc = docs[index];
              final data = doc.data();

              return Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFD7E1EE)),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x12000000),
                      blurRadius: 8,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: ListTile(
                  leading:
                      _isHttpImageUrl((data['logoUrl'] ?? '').toString())
                          ? CircleAvatar(
                            backgroundImage: NetworkImage(
                              (data['logoUrl'] ?? '').toString(),
                            ),
                            backgroundColor: Colors.white,
                          )
                          : CircleAvatar(
                            backgroundColor: primary,
                            child: const Icon(Icons.store, color: Colors.white),
                          ),
                  title: Text(
                    (data['name'] ?? 'Unnamed Store').toString(),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: Text(
                    'Location: ${(data['location'] ?? '-').toString()}\n'
                    'Admin: ${(data['adminName'] ?? '-').toString()} | ${(data['adminPhone'] ?? '-').toString()}\n'
                    '${(data['enabled'] ?? true) == true ? 'Enabled' : 'Disabled'}',
                    style: const TextStyle(
                      color: Color(0xFF334155),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  isThreeLine: true,
                  trailing: Wrap(
                    spacing: 4,
                    children: [
                      IconButton(
                        onPressed:
                            () => _showStoreDialog(
                              context,
                              storeId: doc.id,
                              data: data,
                            ),
                        icon: const Icon(Icons.edit),
                      ),
                      IconButton(
                        onPressed: () => _deleteStore(context, doc.id),
                        icon: const Icon(Icons.delete, color: Colors.red),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _UsersTab extends StatelessWidget {
  final FirestoreService svc;
  final Color primary;
  final Color light;
  final void Function(String) onMsg;
  final Set<String> rolesToShow;
  final String emptyMessage;
  final String addButtonLabel;
  final String defaultRoleForCreate;

  const _UsersTab({
    required this.svc,
    required this.primary,
    required this.light,
    required this.onMsg,
    required this.rolesToShow,
    required this.emptyMessage,
    this.addButtonLabel = 'Add User',
    this.defaultRoleForCreate = 'user',
  });

  Future<void> _setRole({
    required String userId,
    required String email,
    required String role,
  }) async {
    final db = FirebaseFirestore.instance;
    final userRef = db.collection('users').doc(userId);
    final adminRef = db.collection('admins').doc(userId);
    final deliveryRef = db.collection('delivery_staff').doc(userId);
    final superRef = db.collection('super_admins').doc(userId);

    final isDeliveryRole = role == 'delivery';

    // Always keep the main users/{uid} role source of truth updated first.
    await userRef.set({
      'role': role,
      'isDelivery': isDeliveryRole,
      'deliveryOnDuty': isDeliveryRole,
      'deliveryDutyUpdatedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    Future<void> safeDelete(DocumentReference<Map<String, dynamic>> ref) async {
      try {
        await ref.delete();
      } on FirebaseException catch (e) {
        // Some rulesets do not allow deleting role docs from client.
        // Do not block role updates in users/{uid} because of cleanup.
        if (e.code != 'permission-denied') rethrow;
      }
    }

    if (role == 'admin') {
      await adminRef.set({
        'email': email,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      await safeDelete(deliveryRef);
      await safeDelete(superRef);
    } else if (role == 'delivery') {
      await deliveryRef.set({
        'email': email,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      await safeDelete(adminRef);
      await safeDelete(superRef);
    } else if (role == 'super_admin') {
      await superRef.set({
        'email': email,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      await safeDelete(adminRef);
      await safeDelete(deliveryRef);
    } else {
      await safeDelete(adminRef);
      await safeDelete(deliveryRef);
      await safeDelete(superRef);
    }
  }

  Future<void> _toggleBlocked(String userId, bool blocked) async {
    await FirebaseFirestore.instance.collection('users').doc(userId).set({
      'blocked': blocked,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> _showAddUserDialog(BuildContext context) async {
    final formKey = GlobalKey<FormState>();
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final addressCtrl = TextEditingController();
    final blockCtrl = TextEditingController();
    final postcodeCtrl = TextEditingController();
    final passwordCtrl = TextEditingController();
    final confirmPasswordCtrl = TextEditingController();

    String phoneE164 = '';
    String? country;
    String? state;
    String? gender;
    DateTime? dob;
    String role = defaultRoleForCreate;
    bool obscurePw = true;
    bool obscureConfirm = true;
    bool saving = false;
    String? errorText;

    const countries = <String>[
      'Malaysia',
      'Singapore',
      'Indonesia',
      'Thailand',
      'Brunei',
      'United States',
      'United Kingdom',
      'China',
      'Japan',
      'India',
      'Australia',
    ];
    const malaysiaStates = <String>[
      'Johor',
      'Kedah',
      'Kelantan',
      'Melaka',
      'Negeri Sembilan',
      'Pahang',
      'Perak',
      'Perlis',
      'Pulau Pinang',
      'Sabah',
      'Sarawak',
      'Selangor',
      'Terengganu',
      'Wilayah Persekutuan Kuala Lumpur',
      'Wilayah Persekutuan Labuan',
      'Wilayah Persekutuan Putrajaya',
    ];
    const statesByCountry = <String, List<String>>{
      'Malaysia': malaysiaStates,
      'Singapore': [
        'Central Region',
        'North Region',
        'North-East Region',
        'East Region',
        'West Region',
      ],
      'Indonesia': [
        'DKI Jakarta',
        'West Java',
        'Central Java',
        'East Java',
        'Bali',
        'North Sumatra',
      ],
      'Thailand': [
        'Bangkok',
        'Chiang Mai',
        'Phuket',
        'Chonburi',
        'Nakhon Ratchasima',
        'Songkhla',
      ],
      'Brunei': ['Belait', 'Brunei-Muara', 'Temburong', 'Tutong'],
      'United States': [
        'California',
        'Texas',
        'Florida',
        'New York',
        'Illinois',
        'Washington',
      ],
      'United Kingdom': ['England', 'Scotland', 'Wales', 'Northern Ireland'],
      'China': [
        'Beijing',
        'Shanghai',
        'Guangdong',
        'Zhejiang',
        'Sichuan',
        'Jiangsu',
      ],
      'Japan': ['Tokyo', 'Osaka', 'Hokkaido', 'Aichi', 'Fukuoka', 'Kyoto'],
      'India': [
        'Maharashtra',
        'Karnataka',
        'Tamil Nadu',
        'Delhi',
        'Gujarat',
        'Kerala',
      ],
      'Australia': [
        'New South Wales',
        'Victoria',
        'Queensland',
        'Western Australia',
        'South Australia',
        'Tasmania',
      ],
    };

    String? req(String? v, String label) {
      if (v == null || v.trim().isEmpty) return '$label is required';
      return null;
    }

    String? validateEmail(String? v) {
      final value = (v ?? '').trim();
      if (value.isEmpty) return 'Email is required';
      final reg = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
      if (!reg.hasMatch(value)) return 'Enter a valid email';
      return null;
    }

    bool hasUpper(String s) => RegExp(r'[A-Z]').hasMatch(s);
    bool hasLower(String s) => RegExp(r'[a-z]').hasMatch(s);
    bool hasNumber(String s) => RegExp(r'\d').hasMatch(s);
    bool hasSymbol(String s) => RegExp(r'[@#*]').hasMatch(s);

    bool pwAllOk(String s) =>
        s.length >= 8 &&
        hasUpper(s) &&
        hasLower(s) &&
        hasNumber(s) &&
        hasSymbol(s);

    String? validatePassword(String? v) {
      final value = v ?? '';
      if (value.isEmpty) return 'Password is required';
      if (value.length < 8) return 'Password must be at least 8 characters';
      if (!hasNumber(value)) return 'Password must contain numbers';
      if (!hasUpper(value)) return 'Password must contain uppercase';
      if (!hasLower(value)) return 'Password must contain lowercase';
      if (!hasSymbol(value))
        return 'Password must have at least one @#* symbol';
      return null;
    }

    String? validateConfirm(String? v) {
      final value = v ?? '';
      if (value.isEmpty) return 'Confirm your password';
      if (value != passwordCtrl.text) return 'Passwords do not match';
      return null;
    }

    String? validatePostcode(String? v) {
      final value = (v ?? '').trim();
      if (value.isEmpty) return 'Postcode is required';
      final isMalaysia = (country ?? '').trim().toLowerCase() == 'malaysia';
      if (isMalaysia) {
        if (!RegExp(r'^\d{5}$').hasMatch(value)) {
          return 'Postcode must be 5 digits';
        }
        return null;
      }
      if (value.length < 3) return 'Postcode must be at least 3 characters';
      return null;
    }

    String? validateCountry(String? v) {
      final value = (v ?? '').trim();
      if (value.isEmpty) return 'Country is required';
      if (!countries.contains(value)) return 'Please select a valid country';
      return null;
    }

    String? validateState(String? v) {
      if (country == null || country!.trim().isEmpty)
        return 'Select country first';
      final value = (v ?? '').trim();
      if (value.isEmpty) return 'State is required';
      final allowed = statesByCountry[country!] ?? const <String>[];
      if (!allowed.contains(value)) return 'Please select a valid state';
      return null;
    }

    int ageFromDob(DateTime date) {
      final today = DateTime.now();
      int age = today.year - date.year;
      final hadBirthday =
          (today.month > date.month) ||
          (today.month == date.month && today.day >= date.day);
      if (!hadBirthday) age--;
      return age;
    }

    String? validateDob() {
      if (dob == null) return 'Date of birth is required';
      if (ageFromDob(dob!) < 18) return 'You must be at least 18 years old';
      return null;
    }

    await showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            return AlertDialog(
              title: const Text('Add User'),
              content: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        controller: nameCtrl,
                        autovalidateMode: AutovalidateMode.onUserInteraction,
                        decoration: const InputDecoration(
                          labelText: 'Full Name',
                          border: OutlineInputBorder(),
                        ),
                        validator: (v) => req(v, 'Full name'),
                      ),
                      const SizedBox(height: 12),
                      IntlPhoneField(
                        controller: phoneCtrl,
                        initialCountryCode: 'MY',
                        disableLengthCheck: true,
                        decoration: const InputDecoration(
                          labelText: 'Phone Number',
                          border: OutlineInputBorder(),
                        ),
                        validator: (phone) {
                          if (phone == null || phone.number.trim().isEmpty) {
                            return 'Phone number is required';
                          }
                          if (!RegExp(r'^\d+$').hasMatch(phone.number)) {
                            return 'Digits only';
                          }
                          return null;
                        },
                        onChanged: (phone) {
                          phoneE164 = phone.completeNumber;
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: emailCtrl,
                        keyboardType: TextInputType.emailAddress,
                        autovalidateMode: AutovalidateMode.onUserInteraction,
                        decoration: const InputDecoration(
                          labelText: 'Email',
                          border: OutlineInputBorder(),
                        ),
                        validator: validateEmail,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: addressCtrl,
                        autovalidateMode: AutovalidateMode.onUserInteraction,
                        decoration: const InputDecoration(
                          labelText: 'Address',
                          border: OutlineInputBorder(),
                        ),
                        validator: (v) => req(v, 'Address'),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: blockCtrl,
                        autovalidateMode: AutovalidateMode.onUserInteraction,
                        decoration: const InputDecoration(
                          labelText: 'Block',
                          border: OutlineInputBorder(),
                        ),
                        validator: (v) => req(v, 'Block'),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: postcodeCtrl,
                        keyboardType: TextInputType.number,
                        autovalidateMode: AutovalidateMode.onUserInteraction,
                        decoration: const InputDecoration(
                          labelText: 'Postcode',
                          border: OutlineInputBorder(),
                        ),
                        validator: validatePostcode,
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: country,
                        isExpanded: true,
                        autovalidateMode: AutovalidateMode.onUserInteraction,
                        decoration: const InputDecoration(
                          labelText: 'Country',
                          border: OutlineInputBorder(),
                        ),
                        items:
                            countries
                                .map(
                                  (c) => DropdownMenuItem<String>(
                                    value: c,
                                    child: Text(c),
                                  ),
                                )
                                .toList(),
                        onChanged:
                            saving
                                ? null
                                : (v) {
                                  setDialogState(() {
                                    country = v;
                                    state = null;
                                  });
                                },
                        validator: validateCountry,
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: state,
                        isExpanded: true,
                        autovalidateMode: AutovalidateMode.onUserInteraction,
                        decoration: const InputDecoration(
                          labelText: 'State / Province / Region',
                          border: OutlineInputBorder(),
                        ),
                        items:
                            (country == null
                                    ? const <String>[]
                                    : (statesByCountry[country!] ??
                                        const <String>[]))
                                .map(
                                  (s) => DropdownMenuItem<String>(
                                    value: s,
                                    child: Text(s),
                                  ),
                                )
                                .toList(),
                        onChanged:
                            (saving || country == null)
                                ? null
                                : (v) => setDialogState(() => state = v),
                        validator: validateState,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: passwordCtrl,
                        obscureText: obscurePw,
                        autovalidateMode: AutovalidateMode.onUserInteraction,
                        decoration: InputDecoration(
                          labelText: 'Password',
                          border: OutlineInputBorder(),
                          suffixIcon: IconButton(
                            tooltip:
                                obscurePw ? 'Show password' : 'Hide password',
                            icon: Icon(
                              obscurePw
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                            ),
                            onPressed:
                                saving
                                    ? null
                                    : () => setDialogState(
                                      () => obscurePw = !obscurePw,
                                    ),
                          ),
                        ),
                        validator: validatePassword,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: confirmPasswordCtrl,
                        obscureText: obscureConfirm,
                        autovalidateMode: AutovalidateMode.onUserInteraction,
                        decoration: InputDecoration(
                          labelText: 'Confirmed Password',
                          border: OutlineInputBorder(),
                          suffixIcon: IconButton(
                            tooltip:
                                obscureConfirm
                                    ? 'Show password'
                                    : 'Hide password',
                            icon: Icon(
                              obscureConfirm
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                            ),
                            onPressed:
                                saving
                                    ? null
                                    : () => setDialogState(
                                      () => obscureConfirm = !obscureConfirm,
                                    ),
                          ),
                        ),
                        validator: validateConfirm,
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: gender,
                        autovalidateMode: AutovalidateMode.onUserInteraction,
                        decoration: const InputDecoration(
                          labelText: 'Gender',
                          border: OutlineInputBorder(),
                        ),
                        items: const [
                          DropdownMenuItem(value: 'male', child: Text('Male')),
                          DropdownMenuItem(
                            value: 'female',
                            child: Text('Female'),
                          ),
                        ],
                        onChanged:
                            saving
                                ? null
                                : (v) => setDialogState(() => gender = v),
                        validator:
                            (v) => v == null ? 'Gender is required' : null,
                      ),
                      const SizedBox(height: 12),
                      FormField<String>(
                        autovalidateMode: AutovalidateMode.onUserInteraction,
                        validator: (_) => validateDob(),
                        builder: (field) {
                          final hasError = field.errorText != null;
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              InkWell(
                                onTap:
                                    saving
                                        ? null
                                        : () async {
                                          final now = DateTime.now();
                                          final initial =
                                              dob ??
                                              DateTime(
                                                now.year - 18,
                                                now.month,
                                                now.day,
                                              );
                                          final picked = await showDatePicker(
                                            context: dialogContext,
                                            initialDate: initial,
                                            firstDate: DateTime(1900),
                                            lastDate: now,
                                          );
                                          if (picked != null &&
                                              dialogContext.mounted) {
                                            setDialogState(() => dob = picked);
                                            field.didChange(
                                              dob!.toIso8601String(),
                                            );
                                            field.validate();
                                          }
                                        },
                                child: Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 14,
                                  ),
                                  decoration: BoxDecoration(
                                    border: Border.all(
                                      color:
                                          hasError
                                              ? Colors.red
                                              : Colors.black26,
                                    ),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    dob == null
                                        ? 'Date of Birth (DD/MM/YYYY)'
                                        : '${dob!.day.toString().padLeft(2, '0')}/${dob!.month.toString().padLeft(2, '0')}/${dob!.year}',
                                  ),
                                ),
                              ),
                              if (hasError) ...[
                                const SizedBox(height: 6),
                                Text(
                                  field.errorText!,
                                  style: const TextStyle(
                                    color: Colors.red,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: role,
                        decoration: const InputDecoration(
                          labelText: 'Role',
                          border: OutlineInputBorder(),
                        ),
                        items: const [
                          DropdownMenuItem(value: 'user', child: Text('User')),
                          DropdownMenuItem(
                            value: 'admin',
                            child: Text('Admin'),
                          ),
                          DropdownMenuItem(
                            value: 'delivery',
                            child: Text('Delivery'),
                          ),
                          DropdownMenuItem(
                            value: 'super_admin',
                            child: Text('Super Admin (Full Access)'),
                          ),
                        ],
                        onChanged:
                            saving
                                ? null
                                : (v) {
                                  setDialogState(() {
                                    role = (v ?? 'user').trim();
                                  });
                                },
                      ),
                      if (errorText != null) ...[
                        const SizedBox(height: 10),
                        Text(
                          errorText!,
                          style: const TextStyle(
                            color: Colors.redAccent,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: saving ? null : () => Navigator.pop(dialogContext),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primary,
                    foregroundColor: Colors.black87,
                  ),
                  onPressed:
                      saving
                          ? null
                          : () async {
                            if (!formKey.currentState!.validate()) return;
                            setDialogState(() {
                              saving = true;
                              errorText = null;
                            });

                            if (phoneE164.trim().isEmpty) {
                              setDialogState(() {
                                saving = false;
                                errorText = 'Phone number is required';
                              });
                              return;
                            }
                            if (gender == null) {
                              setDialogState(() {
                                saving = false;
                                errorText = 'Gender is required';
                              });
                              return;
                            }
                            if (dob == null) {
                              setDialogState(() {
                                saving = false;
                                errorText = 'Date of birth is required';
                              });
                              return;
                            }
                            if (ageFromDob(dob!) < 18) {
                              setDialogState(() {
                                saving = false;
                                errorText = 'You must be at least 18 years old';
                              });
                              return;
                            }
                            if (!pwAllOk(passwordCtrl.text)) {
                              setDialogState(() {
                                saving = false;
                                errorText =
                                    'Password does not meet the requirements.';
                              });
                              return;
                            }

                            FirebaseApp? secondaryApp;
                            FirebaseAuth? secondaryAuth;
                            try {
                              final appName =
                                  'super_admin_create_user_${DateTime.now().millisecondsSinceEpoch}';
                              secondaryApp = await Firebase.initializeApp(
                                name: appName,
                                options: Firebase.app().options,
                              );
                              secondaryAuth = FirebaseAuth.instanceFor(
                                app: secondaryApp,
                              );

                              final credential = await secondaryAuth
                                  .createUserWithEmailAndPassword(
                                    email: emailCtrl.text.trim().toLowerCase(),
                                    password: passwordCtrl.text.trim(),
                                  );
                              final uid = credential.user!.uid;

                              await FirebaseFirestore.instance
                                  .collection('users')
                                  .doc(uid)
                                  .set({
                                    'uid': uid,
                                    'userId': uid,
                                    'name': nameCtrl.text.trim(),
                                    'fullName': nameCtrl.text.trim(),
                                    'displayName': nameCtrl.text.trim(),
                                    'phone': phoneE164.trim(),
                                    'email':
                                        emailCtrl.text.trim().toLowerCase(),
                                    'address': addressCtrl.text.trim(),
                                    'block': blockCtrl.text.trim(),
                                    'postcode': postcodeCtrl.text.trim(),
                                    'state': (state ?? '').trim(),
                                    'country': (country ?? '').trim(),
                                    'gender': gender,
                                    'dob': Timestamp.fromDate(dob!),
                                    'role': role,
                                    'blocked': false,
                                    'deliveryOnDuty':
                                        role == 'delivery' ? true : false,
                                    'createdAt': FieldValue.serverTimestamp(),
                                    'updatedAt': FieldValue.serverTimestamp(),
                                  }, SetOptions(merge: true));

                              await _setRole(
                                userId: uid,
                                email: emailCtrl.text.trim().toLowerCase(),
                                role: role,
                              );

                              await secondaryAuth.signOut();
                              await secondaryApp.delete();

                              if (!dialogContext.mounted) return;
                              Navigator.pop(dialogContext);
                              onMsg('User added successfully');
                            } on FirebaseAuthException catch (e) {
                              String msg = 'Failed to create account.';
                              if (e.code == 'email-already-in-use') {
                                msg = 'This email is already registered.';
                              } else if (e.code == 'invalid-email') {
                                msg = 'Invalid email format.';
                              } else if (e.code == 'weak-password') {
                                msg = 'Password is too weak.';
                              } else if ((e.message ?? '').trim().isNotEmpty) {
                                msg = e.message!;
                              }
                              if (dialogContext.mounted) {
                                setDialogState(() {
                                  saving = false;
                                  errorText = msg;
                                });
                              }
                            } catch (e) {
                              if (dialogContext.mounted) {
                                setDialogState(() {
                                  saving = false;
                                  errorText = 'Failed: $e';
                                });
                              }
                            } finally {
                              try {
                                await secondaryAuth?.signOut();
                              } catch (_) {}
                              try {
                                await secondaryApp?.delete();
                              } catch (_) {}
                            }
                          },
                  child: Text(saving ? 'Adding...' : 'Add User'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: svc.usersStream(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snap.data?.docs ?? [];
        final filteredDocs =
            docs.where((doc) {
              final role =
                  (doc.data()['role'] ?? 'user')
                      .toString()
                      .trim()
                      .toLowerCase();
              return rolesToShow.contains(role);
            }).toList();

        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primary,
                    foregroundColor: Colors.black87,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () => _showAddUserDialog(context),
                  icon: const Icon(Icons.person_add_alt_1),
                  label: Text(
                    addButtonLabel,
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child:
                    filteredDocs.isEmpty
                        ? Center(child: Text(emptyMessage))
                        : ListView.separated(
                          itemCount: filteredDocs.length,
                          separatorBuilder:
                              (_, __) => const SizedBox(height: 10),
                          itemBuilder: (context, index) {
                            final doc = filteredDocs[index];
                            final data = doc.data();

                            final email = (data['email'] ?? '').toString();
                            final name =
                                (data['name'] ?? data['fullName'] ?? 'No Name')
                                    .toString();
                            final role = (data['role'] ?? 'user').toString();
                            final blocked = (data['blocked'] ?? false) == true;

                            return Container(
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: const Color(0xFFD7E1EE),
                                ),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Color(0x12000000),
                                    blurRadius: 8,
                                    offset: Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: primary,
                                  child: const Icon(
                                    Icons.person,
                                    color: Colors.white,
                                  ),
                                ),
                                title: Text(
                                  name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                subtitle: Text('$email\nRole: $role'),
                                isThreeLine: true,
                                trailing: PopupMenuButton<String>(
                                  onSelected: (value) async {
                                    try {
                                      if (value == 'block') {
                                        await _toggleBlocked(doc.id, true);
                                        onMsg('User blocked');
                                      } else if (value == 'unblock') {
                                        await _toggleBlocked(doc.id, false);
                                        onMsg('User unblocked');
                                      } else {
                                        await _setRole(
                                          userId: doc.id,
                                          email: email,
                                          role: value,
                                        );
                                        onMsg('Role updated to $value');
                                      }
                                    } on FirebaseException catch (e) {
                                      onMsg(
                                        'Update failed: ${e.message ?? e.code}',
                                      );
                                    } catch (e) {
                                      onMsg('Update failed: $e');
                                    }
                                  },
                                  itemBuilder:
                                      (_) => [
                                        const PopupMenuItem(
                                          value: 'user',
                                          child: Text('Set as User'),
                                        ),
                                        const PopupMenuItem(
                                          value: 'admin',
                                          child: Text('Set as Admin'),
                                        ),
                                        const PopupMenuItem(
                                          value: 'delivery',
                                          child: Text('Set as Delivery'),
                                        ),
                                        const PopupMenuItem(
                                          value: 'super_admin',
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                Icons.verified_user_outlined,
                                                size: 18,
                                                color: Color(0xFF0D47A1),
                                              ),
                                              SizedBox(width: 8),
                                              Text('Set as Super Admin'),
                                            ],
                                          ),
                                        ),
                                        PopupMenuItem(
                                          value: blocked ? 'unblock' : 'block',
                                          child: Text(
                                            blocked
                                                ? 'Unblock User'
                                                : 'Block User',
                                          ),
                                        ),
                                      ],
                                ),
                              ),
                            );
                          },
                        ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _OrdersAssignTab extends StatefulWidget {
  final FirestoreService svc;
  final Color primary;
  final Color light;
  final void Function(String) onMsg;

  const _OrdersAssignTab({
    required this.svc,
    required this.primary,
    required this.light,
    required this.onMsg,
  });

  @override
  State<_OrdersAssignTab> createState() => _OrdersAssignTabState();
}

class _OrdersAssignTabState extends State<_OrdersAssignTab> {
  bool _loading = true;
  List<QueryDocumentSnapshot<Map<String, dynamic>>> _orders = [];
  static const List<String> _statusOptions = <String>[
    'To Ship',
    'To Receive',
    'Completed',
    'Cancelled',
  ];

  @override
  void initState() {
    super.initState();
    _loadOrders();
  }

  Future<void> _loadOrders() async {
    setState(() => _loading = true);
    try {
      final loaded = await widget.svc.ordersAllForAdmin(forceRefresh: true);
      if (!mounted) return;
      setState(() {
        _orders = loaded;
      });
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  DateTime _asDate(Object? value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return DateTime.fromMillisecondsSinceEpoch(0);
  }

  List<QueryDocumentSnapshot<Map<String, dynamic>>> _sortedOrders(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> input,
  ) {
    final out = [...input];
    out.sort((a, b) {
      final ad = _asDate(a.data()['createdAt']);
      final bd = _asDate(b.data()['createdAt']);
      return bd.compareTo(ad);
    });
    return out;
  }

  Future<void> _assignDriver(BuildContext context, String orderPath) async {
    final drivers =
        await FirebaseFirestore.instance.collection('delivery_staff').get();

    if (drivers.docs.isEmpty) {
      widget.onMsg('No delivery staff found');
      return;
    }

    String? selectedUid;
    String? selectedEmail;

    await showDialog(
      context: context,
      builder:
          (_) => AlertDialog(
            title: const Text('Assign Driver'),
            content: StatefulBuilder(
              builder: (context, setState) {
                return DropdownButtonFormField<String>(
                  value: selectedUid,
                  decoration: const InputDecoration(
                    labelText: 'Choose Driver',
                    border: OutlineInputBorder(),
                  ),
                  items:
                      drivers.docs.map((d) {
                        final data = d.data();
                        final email = (data['email'] ?? '').toString();
                        return DropdownMenuItem<String>(
                          value: d.id,
                          child: Text(email.isEmpty ? d.id : email),
                          onTap: () {
                            selectedEmail = email;
                          },
                        );
                      }).toList(),
                  onChanged: (v) {
                    setState(() {
                      selectedUid = v;
                      final match = drivers.docs.where((e) => e.id == v).first;
                      selectedEmail = (match.data()['email'] ?? '').toString();
                    });
                  },
                );
              },
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: widget.primary,
                  foregroundColor: Colors.black87,
                ),
                onPressed: () async {
                  if (selectedUid == null || selectedEmail == null) return;
                  try {
                    await widget.svc.assignDelivery(
                      orderPath: orderPath,
                      deliveryUid: selectedUid!,
                      deliveryEmail: selectedEmail!,
                    );

                    if (context.mounted) Navigator.pop(context);
                    widget.onMsg('Driver assigned successfully');
                    await _loadOrders();
                  } catch (e) {
                    widget.onMsg('Assign failed: $e');
                  }
                },
                child: const Text('Assign'),
              ),
            ],
          ),
    );
  }

  Future<void> _updateOrderStatus(
    BuildContext context,
    String orderPath,
    String newStatus,
  ) async {
    final ok =
        await showDialog<bool>(
          context: context,
          builder:
              (_) => AlertDialog(
                title: const Text('Update Order Status'),
                content: Text('Change order status to "$newStatus"?'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Cancel'),
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: widget.primary,
                      foregroundColor: Colors.black87,
                    ),
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('Update'),
                  ),
                ],
              ),
        ) ??
        false;
    if (!ok) return;

    try {
      await widget.svc.updateOrderStatusByPath(
        orderPath: orderPath,
        status: newStatus,
      );
      widget.onMsg('Order status updated to $newStatus');
      await _loadOrders();
    } catch (e) {
      widget.onMsg('Update failed: $e');
    }
  }

  String _safeText(
    Map<String, dynamic> data,
    String key, [
    String fallback = '-',
  ]) {
    final v = data[key];
    if (v == null) return fallback;
    final t = v.toString().trim();
    return t.isEmpty ? fallback : t;
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: widget.svc.ordersAllStream(),
      builder: (context, snap) {
        final live = snap.data?.docs ?? const [];
        final hasLiveData = live.isNotEmpty;
        final docs = _sortedOrders(hasLiveData ? live : _orders);

        if (snap.connectionState == ConnectionState.waiting &&
            _loading &&
            docs.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }

        if (docs.isEmpty) {
          return RefreshIndicator(
            onRefresh: _loadOrders,
            child: ListView(
              children: const [
                SizedBox(height: 180),
                Center(child: Text('No orders found.')),
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: _loadOrders,
          child: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final doc = docs[index];
              final data = doc.data();

              final orderPath = doc.reference.path;
              final customer = _safeText(data, 'customerName', 'Customer');
              final status = _safeText(data, 'status');
              final deliveryStatus = _safeText(
                data,
                'deliveryStatus',
                'Assigned',
              );
              final isFinalOrder =
                  status.trim().toLowerCase() == 'completed' ||
                  status.trim().toLowerCase() == 'delivered' ||
                  status.trim().toLowerCase() == 'cancelled' ||
                  status.trim().toLowerCase() == 'canceled' ||
                  deliveryStatus.trim().toLowerCase() == 'delivered' ||
                  deliveryStatus.trim().toLowerCase() == 'cancelled' ||
                  deliveryStatus.trim().toLowerCase() == 'canceled';
              final deliveryEmail = _safeText(
                data,
                'deliveryEmail',
                'Not assigned',
              );
              final address = _safeText(
                data,
                'deliveryAddress',
                _safeText(data, 'address', '-'),
              );

              return Container(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFD7E1EE)),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x12000000),
                      blurRadius: 8,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      customer,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Status: $status\nDelivery: $deliveryStatus\nDriver: $deliveryEmail\nAddress: $address',
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: widget.primary,
                            foregroundColor: Colors.black87,
                          ),
                          onPressed:
                              isFinalOrder
                                  ? null
                                  : () => _assignDriver(context, orderPath),
                          child: const Text('Assign Driver'),
                        ),
                        PopupMenuButton<String>(
                          tooltip: 'Update status',
                          enabled: !isFinalOrder,
                          onSelected:
                              (value) =>
                                  _updateOrderStatus(context, orderPath, value),
                          itemBuilder:
                              (_) =>
                                  _statusOptions
                                      .map(
                                        (s) => PopupMenuItem<String>(
                                          value: s,
                                          child: Text('Set: $s'),
                                        ),
                                      )
                                      .toList(),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 9,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: const Color(0xFFD7E1EE),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.edit_outlined, size: 16),
                                const SizedBox(width: 6),
                                Text(
                                  isFinalOrder
                                      ? 'Status Locked'
                                      : 'Update Status',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                const Icon(Icons.arrow_drop_down, size: 18),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }
}

class _FeedbackTab extends StatelessWidget {
  final Color primary;
  final Color light;
  final void Function(String) onMsg;

  const _FeedbackTab({
    required this.primary,
    required this.light,
    required this.onMsg,
  });

  Future<void> _setStatus(String feedbackId, String status) async {
    await FirebaseFirestore.instance
        .collection('user_feedback')
        .doc(feedbackId)
        .set({
          'status': status,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
  }

  Future<void> _deleteFeedback(String feedbackId) async {
    await FirebaseFirestore.instance
        .collection('user_feedback')
        .doc(feedbackId)
        .delete();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream:
          FirebaseFirestore.instance
              .collection('user_feedback')
              .orderBy('createdAt', descending: true)
              .snapshots(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Failed to load feedback.\n${snap.error}',
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          );
        }

        final docs = snap.data?.docs ?? [];
        if (docs.isEmpty) {
          return const Center(child: Text('No feedback submitted yet.'));
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final doc = docs[index];
            final data = doc.data();
            final title = (data['title'] ?? 'Feedback').toString().trim();
            final message = (data['message'] ?? '').toString().trim();
            final email = (data['email'] ?? 'Unknown').toString().trim();
            final userName =
                (data['userName'] ?? data['name'] ?? '').toString().trim();
            final ratingRaw = data['rating'];
            final rating = ratingRaw is num ? ratingRaw.toInt() : 0;
            final status = (data['status'] ?? 'new').toString().trim();

            return Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFD7E1EE)),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x12000000),
                    blurRadius: 8,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                title: Text(
                  title.isEmpty ? 'Feedback' : title,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 4),
                    if (userName.isNotEmpty) Text('Name: $userName'),
                    Text('From: $email'),
                    Text('Rating: $rating / 5'),
                    Text('Status: $status'),
                    if (message.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(message),
                    ],
                  ],
                ),
                trailing: PopupMenuButton<String>(
                  onSelected: (value) async {
                    try {
                      if (value == 'delete') {
                        await _deleteFeedback(doc.id);
                        onMsg('Feedback deleted');
                      } else {
                        await _setStatus(doc.id, value);
                        onMsg('Feedback status set to $value');
                      }
                    } on FirebaseException catch (e) {
                      onMsg('Update failed: ${e.message ?? e.code}');
                    } catch (e) {
                      onMsg('Update failed: $e');
                    }
                  },
                  itemBuilder:
                      (_) => const [
                        PopupMenuItem(
                          value: 'new',
                          child: Text('Set status: new'),
                        ),
                        PopupMenuItem(
                          value: 'reviewed',
                          child: Text('Set status: reviewed'),
                        ),
                        PopupMenuItem(
                          value: 'resolved',
                          child: Text('Set status: resolved'),
                        ),
                        PopupMenuItem(
                          value: 'delete',
                          child: Text('Delete feedback'),
                        ),
                      ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
