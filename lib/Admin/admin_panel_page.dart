// How this file works:
// 1) Data/models are declared first (if any).
// 2) UI widgets are built in build() methods.
// 3) Helper methods are used to keep UI code clean.
//
// File purpose: This file handles store admin panel page screen/logic.

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';

import 'package:fyp/components/confirm_dialog.dart';
import 'package:fyp/Admin/firestore_service.dart';
import 'package:fyp/User/login.dart';
import 'package:fyp/Admin/admin_extra_tabs.dart';

class AdminPanelPage extends StatefulWidget {
  const AdminPanelPage({super.key});

  @override
  State<AdminPanelPage> createState() => _AdminPanelPageState();
}

class _AdminPanelPageState extends State<AdminPanelPage>
    with SingleTickerProviderStateMixin {
  final _svc = FirestoreService();
  late TabController _tabController;
  int _selectedTabIndex = 0;

  void _bindTabControllerListener() {
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) return;
      if (!mounted) return;
      if (_selectedTabIndex == _tabController.index) return;
      setState(() => _selectedTabIndex = _tabController.index);
    });
  }

  List<Tab> _tabs() {
    return const [
      Tab(text: "Dashboard"),
      Tab(text: "Promotions"),
      Tab(text: "Products"),
      Tab(text: "Prices"),
      Tab(text: "Reviews"),
      Tab(text: "Events"),
      Tab(text: "Reports"),
    ];
  }

  List<Widget> _tabViews({
    required String? managedStoreId,
    required String? managedStoreName,
  }) {
    return [
      _DashboardTab(
        svc: _svc,
        onOpenTab: _openTab,
        fixedStoreId: managedStoreId,
      ),
      _PromosTab(
        svc: _svc,
        fixedStoreId: managedStoreId,
        fixedStoreName: managedStoreName,
      ),
      _ProductsTab(
        svc: _svc,
        fixedStoreId: managedStoreId,
        fixedStoreName: managedStoreName,
      ),
      _PricesTab(
        svc: _svc,
        fixedStoreId: managedStoreId,
        fixedStoreName: managedStoreName,
      ),
      ReviewsAdminTab(svc: _svc, fixedStoreId: managedStoreId),
      EventsAdminTab(
        svc: _svc,
        fixedStoreId: managedStoreId,
        fixedStoreName: managedStoreName,
      ),
      ReportsAdminTab(svc: _svc, fixedStoreId: managedStoreId),
    ];
  }

  void _openTab(int index) {
    final length = _tabController.length;
    if (index < 0 || index >= length) return;
    setState(() => _selectedTabIndex = index);
    _tabController.animateTo(index);
  }

  Scaffold _loadingView() {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }

  Scaffold _deniedView() {
    return Scaffold(
      appBar: AppBar(title: const Text("Store Admin Panel")),
      body: Padding(
        padding: const EdgeInsets.all(18),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.lock_outline, size: 48),
              const SizedBox(height: 10),
              const Text(
                "Access denied",
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
              ),
              const SizedBox(height: 8),
              const Text(
                "This page is only for store admins.",
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                height: 46,
                child: ElevatedButton.icon(
                  onPressed: _logout,
                  icon: const Icon(Icons.logout),
                  label: const Text("Back to Login"),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<bool> _confirm({
    required String title,
    required String message,
    String confirmText = 'Yes',
  }) async {
    return showConfirmDialog(
      context,
      title: title,
      message: message,
      confirmText: confirmText,
    );
  }

  Future<Map<String, dynamic>> _loadAccessContext() async {
    final isAdmin = await _svc.isAdmin();
    final store = await _svc.myStoreInfo();
    String? storeLocation;
    final storeId = (store['storeId'] ?? '').toString().trim();
    if (storeId.isNotEmpty) {
      try {
        final storeDoc =
            await FirebaseFirestore.instance
                .collection('stores')
                .doc(storeId)
                .get();
        final data = storeDoc.data() ?? const <String, dynamic>{};
        storeLocation = (data['location'] ?? '').toString().trim();
      } on FirebaseException {
        storeLocation = null;
      }
    }
    return {
      'isAdmin': isAdmin,
      'storeId': store['storeId'],
      'storeName': store['storeName'],
      'storeLocation': storeLocation,
    };
  }

  Future<void> _logout() async {
    final ok = await _confirm(
      title: 'Logout',
      message: 'Are you sure you want to logout?',
      confirmText: 'Logout',
    );
    if (!ok) return;
    await FirebaseAuth.instance.signOut();
    if (!mounted) return;

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginPage()),
      (route) => false,
    );
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs().length, vsync: this);
    _bindTabControllerListener();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _loadAccessContext(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return _loadingView();
        }
        if (!snap.hasData || snap.data!['isAdmin'] != true) {
          return _deniedView();
        }

        final managedStoreId = (snap.data!['storeId'] as String?)?.trim();
        final managedStoreName = (snap.data!['storeName'] as String?)?.trim();
        final managedStoreLocation =
            (snap.data!['storeLocation'] as String?)?.trim();
        if ((managedStoreId ?? '').isEmpty) {
          return Scaffold(
            appBar: AppBar(title: const Text('Store Admin Panel')),
            body: const Center(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'No store is assigned to this admin account yet. Please ask Super Admin to assign your store first.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ),
          );
        }

        return Scaffold(
          backgroundColor: const Color(0xFFF6F7FB),
          appBar: AppBar(
            title: const Text(
              "Store Admin Panel",
              style: TextStyle(fontWeight: FontWeight.w900),
            ),
            foregroundColor: Colors.white,
            backgroundColor: Colors.transparent,
            flexibleSpace: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF1565C0), Color(0xFF42A5F5)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
            ),
            actions: [
              IconButton(
                tooltip: "Logout",
                onPressed: _logout,
                icon: const Icon(Icons.logout),
              ),
            ],
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(58),
              child: TabBar(
                controller: _tabController,
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                labelColor: Colors.black,
                unselectedLabelColor: Colors.white,
                labelStyle: const TextStyle(fontWeight: FontWeight.w900),
                indicator: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(999),
                ),
                indicatorSize: TabBarIndicatorSize.tab,
                indicatorPadding: const EdgeInsets.symmetric(
                  vertical: 4,
                  horizontal: 3,
                ),
                labelPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                tabs: _tabs(),
              ),
            ),
          ),
          body: Column(
            children: [
              Container(
                width: double.infinity,
                margin: const EdgeInsets.fromLTRB(12, 10, 12, 8),
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFDCE6F3)),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x14000000),
                      blurRadius: 10,
                      offset: Offset(0, 3),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE3F2FD),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.storefront_outlined,
                        color: Color(0xFF1565C0),
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            managedStoreName ?? '-',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 16,
                              color: Color(0xFF1F2937),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Icon(
                                Icons.location_on_outlined,
                                size: 14,
                                color: Colors.black54,
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  (managedStoreLocation ?? '').isEmpty
                                      ? 'Location not set'
                                      : managedStoreLocation!,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    color: Colors.black54,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: _tabViews(
                    managedStoreId: managedStoreId,
                    managedStoreName: managedStoreName,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/* ===================== DASHBOARD TAB ===================== */

class _DashboardTab extends StatelessWidget {
  final FirestoreService svc;
  final ValueChanged<int> onOpenTab;
  final String? fixedStoreId;

  const _DashboardTab({
    required this.svc,
    required this.onOpenTab,
    this.fixedStoreId,
  });

  Future<Map<String, dynamic>> _loadStats() async {
    final db = FirebaseFirestore.instance;
    final cleanStoreId = (fixedStoreId ?? '').trim();
    final cleanStoreIdLower = cleanStoreId.toLowerCase();
    final scoped = cleanStoreId.isNotEmpty;

    Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>> safeQueryDocs(
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

    final promosDocs = await safeQueryDocs(
      () =>
          scoped
              ? db
                  .collection('store_promotions')
                  .where('storeId', isEqualTo: cleanStoreId)
                  .get()
              : db.collection('store_promotions').get(),
    );
    final productsDocs = await safeQueryDocs(() => db.collection('products').get());
    final reviewsDocs = await safeQueryDocs(
      () => db.collection('product_reviews').get(),
    );
    final eventsDocs = await safeQueryDocs(
      () =>
          scoped
              ? db
                  .collection('events')
                  .where('storeId', isEqualTo: cleanStoreId)
                  .get()
              : db.collection('events').get(),
    );

    int totalPriceEntries = 0;
    final scopedProductIds = <String>{};
    final scopedPriceProductIds = <String>{};
    if (scoped) {
      final scopedPrices = await safeQueryDocs(
        () =>
            db
                .collectionGroup('prices')
                .where('storeId', isEqualTo: cleanStoreId)
                .get(),
      );
      for (final priceDoc in scopedPrices) {
        final pid = priceDoc.reference.parent.parent?.id ?? '';
        if (pid.isNotEmpty) {
          scopedPriceProductIds.add(pid);
        }
      }

      if (scopedPriceProductIds.isEmpty) {
        for (final product in productsDocs) {
          try {
            final snap =
                await product.reference
                    .collection('prices')
                    .where('storeId', isEqualTo: cleanStoreId)
                    .limit(1)
                    .get();
            if (snap.docs.isNotEmpty) {
              scopedPriceProductIds.add(product.id);
            }
          } on FirebaseException catch (e) {
            if (e.code == 'permission-denied' ||
                e.code == 'failed-precondition') {
              continue;
            }
            rethrow;
          }
        }
      }
    }

    int scopedProductCount = 0;
    for (final product in productsDocs) {
      final productStoreId =
          (product.data()['storeId'] ?? '').toString().trim().toLowerCase();
      final belongsByProduct = !scoped || productStoreId == cleanStoreIdLower;
      final belongsByPrice =
          scoped && scopedPriceProductIds.contains(product.id);
      final belongsToStore = belongsByProduct || belongsByPrice;
      if (!belongsToStore) continue;

      if (scoped) {
        scopedProductCount++;
      }
      scopedProductIds.add(product.id);
      QuerySnapshot<Map<String, dynamic>> pricesSnap;
      try {
        pricesSnap = await product.reference.collection('prices').get();
      } on FirebaseException catch (e) {
        if (e.code == 'permission-denied' || e.code == 'failed-precondition') {
          continue;
        }
        rethrow;
      }
      if (!scoped) {
        totalPriceEntries += pricesSnap.docs.length;
      } else {
        totalPriceEntries +=
            pricesSnap.docs.where((d) {
              final data = d.data();
              final priceStoreId =
                  (data['storeId'] ?? d.id).toString().trim().toLowerCase();
              return priceStoreId == cleanStoreIdLower;
            }).length;
      }
    }

    int reviewCount = 0;
    for (final review in reviewsDocs) {
      if (!scoped) {
        reviewCount++;
        continue;
      }
      final data = review.data();
      final reviewStoreId =
          (data['storeId'] ?? '').toString().trim().toLowerCase();
      final productId = (data['productId'] ?? '').toString().trim();
      if (reviewStoreId == cleanStoreIdLower ||
          scopedProductIds.contains(productId)) {
        reviewCount++;
      }
    }

    int orderCount = 0;
    double revenue = 0.0;
    if (!scoped) {
      final sales = await svc.salesSummary();
      orderCount = (sales['totalOrders'] ?? 0) as int;
      revenue = ((sales['totalRevenue'] ?? 0.0) as num).toDouble();
    } else {
      List<QueryDocumentSnapshot<Map<String, dynamic>>> ordersDocs;
      try {
        final ordersSnap = await db.collectionGroup('orders').get();
        ordersDocs = ordersSnap.docs;
      } on FirebaseException catch (e) {
        if (e.code == 'permission-denied' || e.code == 'failed-precondition') {
          ordersDocs = const <QueryDocumentSnapshot<Map<String, dynamic>>>[];
        } else {
          rethrow;
        }
      }
      for (final orderDoc in ordersDocs) {
        final order = orderDoc.data();
        final items = (order['items'] as List?) ?? const [];
        final orderStoreId =
            (order['storeId'] ?? '').toString().trim().toLowerCase();
        bool hasThisStoreItem = false;
        double thisStoreRevenue = 0.0;

        for (final raw in items) {
          if (raw is! Map) continue;
          final item = Map<String, dynamic>.from(raw);
          final itemStoreId =
              (item['storeId'] ?? '').toString().trim().toLowerCase();
          final itemProductId = (item['productId'] ?? '').toString().trim();
          final belongsToStore =
              itemStoreId == cleanStoreIdLower ||
              (itemStoreId.isEmpty && scopedProductIds.contains(itemProductId));
          if (!belongsToStore) continue;

          int qty = 1;
          final qtyRaw = item['qty'];
          if (qtyRaw is int) qty = qtyRaw;
          if (qtyRaw is num) qty = qtyRaw.toInt();
          if (qty <= 0) qty = 1;

          double lineTotal = 0.0;
          final lt = item['lineTotal'];
          if (lt is num) {
            lineTotal = lt.toDouble();
          } else {
            final up = item['unitPrice'];
            if (up is num) {
              lineTotal = up.toDouble() * qty;
            } else {
              final orderTotal = order['total'];
              if (orderTotal is num && items.isNotEmpty) {
                lineTotal = orderTotal.toDouble() / items.length;
              }
            }
          }

          hasThisStoreItem = true;
          thisStoreRevenue += lineTotal;
        }

        if (hasThisStoreItem) {
          orderCount++;
          revenue += thisStoreRevenue;
          continue;
        }

        if (orderStoreId == cleanStoreIdLower) {
          final total = order['total'];
          if (total is num && total.toDouble() > 0) {
            orderCount++;
            revenue += total.toDouble();
          }
        }
      }
    }

    return {
      'promotions': promosDocs.length,
      'products': scoped ? scopedProductCount : productsDocs.length,
      'prices': totalPriceEntries,
      'reviews': reviewCount,
      'events': eventsDocs.length,
      'orders': orderCount,
      'revenue': revenue,
    };
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _loadStats(),
      builder: (context, snap) {
        if (snap.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Failed to load dashboard.\n${snap.error}',
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          );
        }

        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final s = snap.data!;

        return RefreshIndicator(
          onRefresh: () async {
            await _loadStats();
          },
          child: ListView(
            padding: const EdgeInsets.all(14),
            children: [
              const Text(
                'Overview Dashboard',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 6),
              const Text(
                'Tap a card to open its related admin tab.',
                style: TextStyle(color: Colors.black54),
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  SizedBox(
                    width: 165,
                    height: 148,
                    child: _DashboardCard(
                      title: 'PROMOTIONS',
                      value: '${s['promotions']}',
                      icon: Icons.campaign_outlined,
                      iconColor: const Color(0xFFE91E63),
                      onTap: () => onOpenTab(1),
                    ),
                  ),
                  SizedBox(
                    width: 165,
                    height: 148,
                    child: _DashboardCard(
                      title: 'PRODUCTS',
                      value: '${s['products']}',
                      icon: Icons.inventory_2_outlined,
                      iconColor: const Color(0xFF2196F3),
                      onTap: () => onOpenTab(2),
                    ),
                  ),
                  SizedBox(
                    width: 165,
                    height: 148,
                    child: _DashboardCard(
                      title: 'PRICES',
                      value: '${s['prices']}',
                      icon: Icons.attach_money_outlined,
                      iconColor: const Color(0xFF4CAF50),
                      onTap: () => onOpenTab(3),
                    ),
                  ),
                  SizedBox(
                    width: 165,
                    height: 148,
                    child: _DashboardCard(
                      title: 'REVIEWS',
                      value: '${s['reviews']}',
                      icon: Icons.rate_review_outlined,
                      iconColor: const Color(0xFFFF9800),
                      onTap: () => onOpenTab(4),
                    ),
                  ),
                  SizedBox(
                    width: 165,
                    height: 148,
                    child: _DashboardCard(
                      title: 'EVENTS',
                      value: '${s['events']}',
                      icon: Icons.event_note_outlined,
                      iconColor: const Color(0xFF009688),
                      onTap: () => onOpenTab(5),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _RevenueCard(
                revenue: (s['revenue'] as double),
                onTap: () => onOpenTab(6),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _DashboardCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color iconColor;
  final VoidCallback onTap;

  const _DashboardCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.iconColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            boxShadow: const [
              BoxShadow(
                color: Color(0x14000000),
                blurRadius: 12,
                offset: Offset(0, 4),
              ),
            ],
            border: Border.all(color: const Color(0xFFE8E8E8)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: Colors.grey,
                ),
              ),
              const Spacer(),
              Icon(icon, color: iconColor, size: 30),
              const Spacer(),
              Align(
                alignment: Alignment.bottomRight,
                child: Text(
                  value,
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF5F6368),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RevenueCard extends StatelessWidget {
  final double revenue;
  final VoidCallback onTap;

  const _RevenueCard({required this.revenue, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF1565C0), Color(0xFF42A5F5)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: const [
              BoxShadow(
                color: Color(0x22000000),
                blurRadius: 10,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              const CircleAvatar(
                radius: 24,
                backgroundColor: Colors.white24,
                child: Icon(
                  Icons.monetization_on_outlined,
                  color: Colors.white,
                  size: 28,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'TOTAL REVENUE',
                      style: TextStyle(
                        color: Colors.white70,
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'RM ${revenue.toStringAsFixed(2)}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios, color: Colors.white70),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionCountHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final String countText;

  const _SectionCountHeader({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.countText,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE6E6E6)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x11000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: const Color(0xFFE3F2FD),
            foregroundColor: const Color(0xFF1565C0),
            child: Icon(icon),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: Colors.black54,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          Text(
            countText,
            style: const TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 20,
              color: Color(0xFF1565C0),
            ),
          ),
        ],
      ),
    );
  }
}

/* ===================== SHARED ADMIN HELPERS ===================== */

class _AdminColors {
  static const primary = Color(0xFF1565C0);
  static const secondary = Color(0xFF42A5F5);
  static const lightBg = Color(0xFFF6F7FB);
  static const cardBg = Colors.white;
  static const border = Color(0xFFE6E6E6);
  static const softBlue = Color(0xFFE3F2FD);
  static const textMuted = Colors.black54;
}

InputDecoration _adminInputDecoration({
  required String label,
  String? hint,
  IconData? prefixIcon,
}) {
  return InputDecoration(
    labelText: label,
    hintText: hint,
    prefixIcon: prefixIcon == null ? null : Icon(prefixIcon),
    filled: true,
    fillColor: Colors.white,
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: _AdminColors.border),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: _AdminColors.border),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: _AdminColors.primary, width: 1.5),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: Colors.red),
    ),
    focusedErrorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: Colors.red, width: 1.5),
    ),
  );
}

ButtonStyle _adminPrimaryButtonStyle() {
  return ElevatedButton.styleFrom(
    backgroundColor: _AdminColors.primary,
    foregroundColor: Colors.white,
    elevation: 0,
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
  );
}

ButtonStyle _adminSecondaryButtonStyle() {
  return OutlinedButton.styleFrom(
    foregroundColor: _AdminColors.primary,
    side: const BorderSide(color: _AdminColors.primary),
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
  );
}

BoxDecoration _adminCardDecoration() {
  return BoxDecoration(
    color: _AdminColors.cardBg,
    borderRadius: BorderRadius.circular(14),
    border: Border.all(color: _AdminColors.border),
    boxShadow: const [
      BoxShadow(color: Color(0x11000000), blurRadius: 8, offset: Offset(0, 2)),
    ],
  );
}

String? _validateRequired(String? value, String fieldName) {
  final text = (value ?? '').trim();
  if (text.isEmpty) return '$fieldName is required.';
  return null;
}

String? _validateUrlOptional(String? value) {
  final text = (value ?? '').trim();
  if (text.isEmpty) return null;
  final uri = Uri.tryParse(text);
  if (uri == null || !uri.isAbsolute) {
    return 'Please enter a valid URL.';
  }
  return null;
}

String? _validatePriceRequired(String? value, String fieldName) {
  final text = (value ?? '').trim();
  if (text.isEmpty) return '$fieldName is required.';
  final n = double.tryParse(text);
  if (n == null || n <= 0) return '$fieldName must be greater than 0.';
  return null;
}

String? _validatePriceOptional(String? value, String fieldName) {
  final text = (value ?? '').trim();
  if (text.isEmpty) return null;
  final n = double.tryParse(text);
  if (n == null || n <= 0) return '$fieldName must be greater than 0.';
  return null;
}

String? _validateNonNegativeInt(String? value, String fieldName) {
  final text = (value ?? '').trim();
  if (text.isEmpty) return '$fieldName is required.';
  final n = int.tryParse(text);
  if (n == null || n < 0) return '$fieldName must be 0 or greater.';
  return null;
}

/* ===================== STORES TAB ===================== */

class _StoresTab extends StatelessWidget {
  final FirestoreService svc;
  const _StoresTab({required this.svc});

  Future<bool> _confirm(
    BuildContext context,
    String title,
    String message, {
    String confirmText = 'Yes',
  }) async {
    return showConfirmDialog(
      context,
      title: title,
      message: message,
      confirmText: confirmText,
    );
  }

  void _showMsg(BuildContext context, String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Widget _streamError(Object? error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          'Failed to load stores.\n$error',
          textAlign: TextAlign.center,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
    );
  }

  Future<void> _addOrEdit(
    BuildContext context, {
    String? id,
    Map<String, dynamic>? data,
  }) async {
    final formKey = GlobalKey<FormState>();
    final nameCtrl = TextEditingController(
      text: (data?['name'] ?? '').toString(),
    );
    bool enabled = (data?['enabled'] ?? true) == true;
    bool saving = false;
    String selectedAdminUid = (data?['adminUid'] ?? '').toString().trim();
    String selectedAdminEmail = (data?['adminEmail'] ?? '').toString().trim();
    String selectedAdminName = (data?['adminName'] ?? '').toString().trim();

    final usersSnap =
        await FirebaseFirestore.instance
            .collection('users')
            .orderBy('email')
            .get();
    if (!context.mounted) return;

    final candidates =
        usersSnap.docs.where((d) {
          final role = (d.data()['role'] ?? 'user').toString().trim();
          return role != 'delivery';
        }).toList();

    if (candidates.isNotEmpty && selectedAdminUid.isEmpty) {
      final first = candidates.first;
      selectedAdminUid = first.id;
      selectedAdminEmail = (first.data()['email'] ?? '').toString().trim();
      selectedAdminName =
          (first.data()['name'] ?? first.data()['displayName'] ?? '')
              .toString()
              .trim();
    }

    await showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
              title: Text(id == null ? "Add Store" : "Edit Store"),
              content: SingleChildScrollView(
                child: Form(
                  key: formKey,
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        controller: nameCtrl,
                        validator: (v) => _validateRequired(v, 'Store name'),
                        decoration: _adminInputDecoration(
                          label: 'Store Name',
                          prefixIcon: Icons.storefront_outlined,
                        ),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value:
                            selectedAdminUid.isEmpty ? null : selectedAdminUid,
                        decoration: _adminInputDecoration(
                          label: 'Store Admin',
                          prefixIcon: Icons.person_outline,
                        ),
                        items:
                            candidates
                                .map(
                                  (doc) => DropdownMenuItem<String>(
                                    value: doc.id,
                                    child: Text(
                                      ((doc.data()['name'] ??
                                              doc.data()['displayName'] ??
                                              doc.data()['email'] ??
                                              doc.id))
                                          .toString(),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                )
                                .toList(),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) {
                            return 'Store admin is required.';
                          }
                          return null;
                        },
                        onChanged: (v) {
                          setDialogState(() {
                            selectedAdminUid = (v ?? '').trim();
                            final picked = candidates.firstWhere(
                              (doc) => doc.id == selectedAdminUid,
                            );
                            selectedAdminEmail =
                                (picked.data()['email'] ?? '')
                                    .toString()
                                    .trim();
                            selectedAdminName =
                                (picked.data()['name'] ??
                                        picked.data()['displayName'] ??
                                        '')
                                    .toString()
                                    .trim();
                          });
                        },
                      ),
                      const SizedBox(height: 12),
                      SwitchListTile(
                        value: enabled,
                        onChanged: (v) {
                          setDialogState(() => enabled = v);
                        },
                        title: const Text("Enabled"),
                        activeColor: _AdminColors.primary,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                OutlinedButton(
                  style: _adminSecondaryButtonStyle(),
                  onPressed: saving ? null : () => Navigator.pop(dialogContext),
                  child: const Text("Cancel"),
                ),
                ElevatedButton(
                  style: _adminPrimaryButtonStyle(),
                  onPressed:
                      saving
                          ? null
                          : () async {
                            if (!formKey.currentState!.validate()) return;

                            try {
                              setDialogState(() => saving = true);
                              await svc.upsertStore(
                                storeId: id,
                                name: nameCtrl.text.trim(),
                                enabled: enabled,
                                adminUid: selectedAdminUid,
                                adminEmail: selectedAdminEmail,
                                adminName: selectedAdminName,
                              );
                              if (context.mounted) {
                                Navigator.of(dialogContext).pop();
                                _showMsg(context, 'Store saved.');
                              }
                            } on FirebaseException catch (e) {
                              if (context.mounted) {
                                _showMsg(
                                  context,
                                  'Save failed: ${e.message ?? e.code}',
                                );
                              }
                            } catch (e) {
                              if (context.mounted) {
                                _showMsg(context, 'Save failed: $e');
                              }
                            } finally {
                              if (dialogContext.mounted) {
                                setDialogState(() => saving = false);
                              }
                            }
                          },
                  child: Text(saving ? "Saving..." : "Save"),
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
      stream: svc.storesStream(),
      builder: (context, snap) {
        if (snap.hasError) return _streamError(snap.error);
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final docs =
            snap.data!.docs.toList()..sort((a, b) {
              DateTime asDate(Object? v) {
                if (v is Timestamp) return v.toDate();
                if (v is DateTime) return v;
                return DateTime.fromMillisecondsSinceEpoch(0);
              }

              final ad = asDate(a.data()['endAt']);
              final bd = asDate(b.data()['endAt']);
              return ad.compareTo(bd);
            });

        return Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            children: [
              _SectionCountHeader(
                title: 'Stores',
                subtitle: 'Manage all store records here.',
                icon: Icons.storefront_outlined,
                countText: '${docs.length}',
              ),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: _adminPrimaryButtonStyle(),
                  onPressed: () {
                    _addOrEdit(context);
                  },
                  icon: const Icon(Icons.add),
                  label: const Text("Add Store"),
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child:
                    docs.isEmpty
                        ? const Center(
                          child: Text(
                            'No stores yet',
                            style: TextStyle(fontWeight: FontWeight.w800),
                          ),
                        )
                        : ListView.separated(
                          itemCount: docs.length,
                          separatorBuilder: (_, __) {
                            return const SizedBox(height: 10);
                          },
                          itemBuilder: (_, i) {
                            final d = docs[i];
                            final data = d.data();
                            return Container(
                              decoration: _adminCardDecoration(),
                              child: ListTile(
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 8,
                                ),
                                leading: const CircleAvatar(
                                  backgroundColor: _AdminColors.softBlue,
                                  foregroundColor: _AdminColors.primary,
                                  child: Icon(Icons.storefront_outlined),
                                ),
                                title: Text(
                                  "${data['name']} (${d.id})",
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                subtitle: Text(
                                  "Enabled: ${data['enabled'] == true}",
                                  style: const TextStyle(
                                    color: _AdminColors.textMuted,
                                  ),
                                ),
                                trailing: Wrap(
                                  spacing: 4,
                                  children: [
                                    IconButton(
                                      icon: const Icon(
                                        Icons.edit_outlined,
                                        color: _AdminColors.primary,
                                      ),
                                      onPressed:
                                          () => _addOrEdit(
                                            context,
                                            id: d.id,
                                            data: data,
                                          ),
                                    ),
                                    IconButton(
                                      icon: const Icon(
                                        Icons.delete_outline,
                                        color: Colors.redAccent,
                                      ),
                                      onPressed: () async {
                                        final ok = await _confirm(
                                          context,
                                          'Delete Store',
                                          'Delete store "${data['name']}"?',
                                          confirmText: 'Delete',
                                        );
                                        if (!ok) return;
                                        await svc.deleteStore(d.id);
                                      },
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

/* ===================== PROMOTIONS TAB ===================== */

class _PromosTab extends StatelessWidget {
  final FirestoreService svc;
  final String? fixedStoreId;
  final String? fixedStoreName;
  const _PromosTab({required this.svc, this.fixedStoreId, this.fixedStoreName});

  Future<bool> _confirm(
    BuildContext context,
    String title,
    String message, {
    String confirmText = 'Yes',
  }) async {
    return showConfirmDialog(
      context,
      title: title,
      message: message,
      confirmText: confirmText,
    );
  }

  void _showMsg(BuildContext context, String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Widget _streamError(Object? error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          'Failed to load promotions.\n$error',
          textAlign: TextAlign.center,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
    );
  }

  List<Map<String, dynamic>> _storeRows(
    QuerySnapshot<Map<String, dynamic>> snap,
  ) {
    final rows = <Map<String, dynamic>>[];
    for (final doc in snap.docs) {
      final row = <String, dynamic>{'id': doc.id};
      row.addAll(doc.data());
      rows.add(row);
    }
    return rows;
  }

  List<DropdownMenuItem<String>> _storeItems(
    List<Map<String, dynamic>> stores,
  ) {
    final items = <DropdownMenuItem<String>>[];
    for (final store in stores) {
      items.add(
        DropdownMenuItem<String>(
          value: store['id'].toString(),
          child: Text(store['name'].toString()),
        ),
      );
    }
    return items;
  }

  Map<String, dynamic> _storeById(
    List<Map<String, dynamic>> stores,
    String storeId,
  ) {
    for (final store in stores) {
      if (store['id'].toString() == storeId) {
        return store;
      }
    }
    return stores.first;
  }

  Future<void> _addOrEditPromo(
    BuildContext context, {
    String? promoId,
    Map<String, dynamic>? data,
  }) async {
    final formKey = GlobalKey<FormState>();
    final titleCtrl = TextEditingController(
      text: (data?['title'] ?? '').toString(),
    );
    final descCtrl = TextEditingController(
      text: (data?['description'] ?? '').toString(),
    );
    final codeCtrl = TextEditingController(
      text: (data?['code'] ?? '').toString(),
    );
    bool active = (data?['isActive'] ?? true) == true;
    bool saving = false;

    String storeId = (fixedStoreId ?? data?['storeId'] ?? '').toString();
    String storeName = (fixedStoreName ?? data?['storeName'] ?? '').toString();
    DateTime endAt =
        (data?['endAt'] is Timestamp)
            ? (data!['endAt'] as Timestamp).toDate()
            : DateTime.now().add(const Duration(days: 7));

    final storesSnap = await svc.storesStream().first;
    if (!context.mounted) return;
    final stores = _storeRows(storesSnap);
    if (stores.isEmpty) {
      _showMsg(context, 'Add at least one store before creating promotions.');
      return;
    }

    if (storeId.isEmpty) {
      storeId = stores.first['id'].toString();
      storeName = stores.first['name'].toString();
    }

    await showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
              title: Text(promoId == null ? "Add Promotion" : "Edit Promotion"),
              content: SingleChildScrollView(
                child: Form(
                  key: formKey,
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if ((fixedStoreId ?? '').trim().isEmpty) ...[
                        DropdownButtonFormField<String>(
                          value: storeId.isEmpty ? null : storeId,
                          decoration: _adminInputDecoration(
                            label: 'Store',
                            prefixIcon: Icons.storefront_outlined,
                          ),
                          items: _storeItems(stores),
                          validator:
                              (v) =>
                                  v == null || v.isEmpty
                                      ? 'Store is required.'
                                      : null,
                          onChanged: (v) {
                            setDialogState(() {
                              storeId = v ?? '';
                              final found = _storeById(stores, storeId);
                              storeName = found['name'].toString();
                            });
                          },
                        ),
                        const SizedBox(height: 12),
                      ] else ...[
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: _adminCardDecoration(),
                          child: Text(
                            'Store: $storeName',
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                      TextFormField(
                        controller: titleCtrl,
                        validator: (v) => _validateRequired(v, 'Title'),
                        decoration: _adminInputDecoration(
                          label: 'Title',
                          prefixIcon: Icons.campaign_outlined,
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: descCtrl,
                        maxLines: 3,
                        validator: (v) => _validateRequired(v, 'Description'),
                        decoration: _adminInputDecoration(
                          label: 'Description',
                          prefixIcon: Icons.description_outlined,
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: codeCtrl,
                        decoration: _adminInputDecoration(
                          label: 'Code (optional)',
                          prefixIcon: Icons.discount_outlined,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFD),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: _AdminColors.border),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                "End Date: ${endAt.toLocal().toString().split(' ').first}",
                              ),
                            ),
                            TextButton(
                              onPressed: () async {
                                final picked = await showDatePicker(
                                  context: context,
                                  initialDate: endAt,
                                  firstDate: DateTime.now().subtract(
                                    const Duration(days: 1),
                                  ),
                                  lastDate: DateTime.now().add(
                                    const Duration(days: 365),
                                  ),
                                );
                                if (picked != null) {
                                  setDialogState(() {
                                    endAt = DateTime(
                                      picked.year,
                                      picked.month,
                                      picked.day,
                                      23,
                                      59,
                                    );
                                  });
                                }
                              },
                              child: const Text("Pick"),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      SwitchListTile(
                        value: active,
                        onChanged: (v) => setDialogState(() => active = v),
                        title: const Text("Active"),
                        activeColor: _AdminColors.primary,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                OutlinedButton(
                  style: _adminSecondaryButtonStyle(),
                  onPressed: saving ? null : () => Navigator.pop(dialogContext),
                  child: const Text("Cancel"),
                ),
                ElevatedButton(
                  style: _adminPrimaryButtonStyle(),
                  onPressed:
                      saving
                          ? null
                          : () async {
                            if (!formKey.currentState!.validate()) return;

                            try {
                              setDialogState(() => saving = true);
                              await svc.addOrUpdatePromo(
                                promoId: promoId,
                                storeId: storeId,
                                storeName: storeName,
                                title: titleCtrl.text.trim(),
                                description: descCtrl.text.trim(),
                                code: codeCtrl.text.trim(),
                                endAt: endAt,
                                isActive: active,
                              );
                              if (context.mounted) {
                                Navigator.of(dialogContext).pop();
                                _showMsg(context, 'Promotion saved.');
                              }
                            } on FirebaseException catch (e) {
                              if (context.mounted) {
                                _showMsg(
                                  context,
                                  'Save failed: ${e.message ?? e.code}',
                                );
                              }
                            } catch (e) {
                              if (context.mounted) {
                                _showMsg(context, 'Save failed: $e');
                              }
                            } finally {
                              if (dialogContext.mounted) {
                                setDialogState(() => saving = false);
                              }
                            }
                          },
                  child: Text(saving ? "Saving..." : "Save"),
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
      stream: svc.promosStream(storeId: fixedStoreId ?? 'all'),
      builder: (context, snap) {
        if (snap.hasError) return _streamError(snap.error);
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final docs = snap.data!.docs;

        return Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            children: [
              _SectionCountHeader(
                title: 'Promotions',
                subtitle: 'Manage store promotions and coupon details.',
                icon: Icons.campaign_outlined,
                countText: '${docs.length}',
              ),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: _adminPrimaryButtonStyle(),
                  onPressed: () {
                    _addOrEditPromo(context);
                  },
                  icon: const Icon(Icons.add),
                  label: const Text("Add Promotion"),
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child:
                    docs.isEmpty
                        ? const Center(
                          child: Text(
                            'No promotions yet',
                            style: TextStyle(fontWeight: FontWeight.w800),
                          ),
                        )
                        : ListView.separated(
                          itemCount: docs.length,
                          separatorBuilder: (_, __) {
                            return const SizedBox(height: 10);
                          },
                          itemBuilder: (_, i) {
                            final d = docs[i];
                            final p = d.data();
                            return Container(
                              decoration: _adminCardDecoration(),
                              child: ListTile(
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 8,
                                ),
                                leading: const CircleAvatar(
                                  backgroundColor: _AdminColors.softBlue,
                                  foregroundColor: _AdminColors.primary,
                                  child: Icon(Icons.campaign_outlined),
                                ),
                                title: Text(
                                  "${p['storeName']}: ${p['title']}",
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                subtitle: Text(
                                  "Active: ${p['isActive'] == true} | Code: ${(p['code'] ?? '').toString()}",
                                ),
                                trailing: Wrap(
                                  spacing: 4,
                                  children: [
                                    IconButton(
                                      icon: const Icon(
                                        Icons.edit_outlined,
                                        color: _AdminColors.primary,
                                      ),
                                      onPressed:
                                          () => _addOrEditPromo(
                                            context,
                                            promoId: d.id,
                                            data: p,
                                          ),
                                    ),
                                    IconButton(
                                      icon: const Icon(
                                        Icons.delete_outline,
                                        color: Colors.redAccent,
                                      ),
                                      onPressed: () async {
                                        final ok = await _confirm(
                                          context,
                                          'Delete Promotion',
                                          'Delete promotion "${p['title']}"?',
                                          confirmText: 'Delete',
                                        );
                                        if (!ok) return;
                                        await svc.deletePromo(d.id);
                                      },
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

/* ===================== PRODUCTS TAB ===================== */

class _ProductsTab extends StatefulWidget {
  final FirestoreService svc;
  final String? fixedStoreId;
  final String? fixedStoreName;
  const _ProductsTab({
    required this.svc,
    this.fixedStoreId,
    this.fixedStoreName,
  });

  @override
  State<_ProductsTab> createState() => _ProductsTabState();
}

class _ProductsTabState extends State<_ProductsTab> {
  static const _homeCategories = <String>[
    'For baby',
    'Beverage',
    'Food',
    'Household',
    'Fresh Food',
    'Chilled & Frozen',
    'Health & Beauty',
  ];

  final _search = TextEditingController();
  String _categoryFilter = 'all';

  bool _isHttpImageUrl(String? raw) {
    if (raw == null || raw.trim().isEmpty) return false;
    final uri = Uri.tryParse(raw.trim());
    return uri != null && (uri.scheme == 'http' || uri.scheme == 'https');
  }

  Future<bool> _confirm(
    String title,
    String message, {
    String confirmText = 'Yes',
  }) async {
    return showConfirmDialog(
      context,
      title: title,
      message: message,
      confirmText: confirmText,
    );
  }

  void _showMsg(BuildContext context, String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Widget _streamError(Object? error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          'Failed to load products.\n$error',
          textAlign: TextAlign.center,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
    );
  }

  List<DropdownMenuItem<String>> _categoryItems(List<String> categories) {
    final items = <DropdownMenuItem<String>>[];
    for (final category in categories) {
      items.add(
        DropdownMenuItem<String>(value: category, child: Text(category)),
      );
    }
    return items;
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _addOrEditProduct(
    BuildContext context, {
    String? id,
    Map<String, dynamic>? data,
  }) async {
    final formKey = GlobalKey<FormState>();
    final nameCtrl = TextEditingController(
      text: (data?['name'] ?? '').toString(),
    );
    final unitCtrl = TextEditingController(
      text: (data?['unit'] ?? '').toString(),
    );
    final catCtrl = TextEditingController(
      text: (data?['category'] ?? '').toString(),
    );
    String selectedCategory = catCtrl.text.trim();
    final categoryItems = [..._homeCategories];
    if (selectedCategory.isNotEmpty &&
        !categoryItems.contains(selectedCategory)) {
      categoryItems.add(selectedCategory);
    }

    final descCtrl = TextEditingController(
      text: (data?['description'] ?? '').toString(),
    );
    final qtyCtrl = TextEditingController(
      text:
          (() {
            final raw = data?['quantity'];
            if (raw is num) return raw.toInt().toString();
            return int.tryParse(raw?.toString() ?? '')?.toString() ?? '';
          })(),
    );
    final imageCtrl = TextEditingController(
      text: (data?['imageUrl'] ?? '').toString(),
    );
    bool saving = false;
    bool uploadingImage = false;

    await showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
              title: Text(id == null ? "Add Product" : "Edit Product"),
              content: SingleChildScrollView(
                child: Form(
                  key: formKey,
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        controller: nameCtrl,
                        validator: (v) => _validateRequired(v, 'Product name'),
                        decoration: _adminInputDecoration(
                          label: 'Name',
                          prefixIcon: Icons.inventory_2_outlined,
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: unitCtrl,
                        validator: (v) => _validateRequired(v, 'Unit'),
                        decoration: _adminInputDecoration(
                          label: 'Unit',
                          hint: 'e.g. 1kg',
                          prefixIcon: Icons.scale_outlined,
                        ),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value:
                            selectedCategory.isEmpty ? null : selectedCategory,
                        decoration: _adminInputDecoration(
                          label: 'Category',
                          prefixIcon: Icons.category_outlined,
                        ),
                        items: _categoryItems(categoryItems),
                        validator:
                            (v) =>
                                (v == null || v.trim().isEmpty)
                                    ? 'Category is required.'
                                    : null,
                        onChanged: (v) {
                          setDialogState(() {
                            selectedCategory = (v ?? '').trim();
                            catCtrl.text = selectedCategory;
                          });
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: descCtrl,
                        maxLines: 3,
                        validator: (v) => _validateRequired(v, 'Description'),
                        decoration: _adminInputDecoration(
                          label: 'Description',
                          prefixIcon: Icons.description_outlined,
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: qtyCtrl,
                        keyboardType: TextInputType.number,
                        validator:
                            (v) => _validateNonNegativeInt(v, 'Quantity'),
                        decoration: _adminInputDecoration(
                          label: 'Quantity',
                          hint: 'e.g. 50',
                          prefixIcon: Icons.numbers_outlined,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          border: Border.all(color: const Color(0xFFE0E0E0)),
                          borderRadius: BorderRadius.circular(10),
                          color: const Color(0xFFF9FBFF),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Product Image',
                              style: TextStyle(fontWeight: FontWeight.w800),
                            ),
                            const SizedBox(height: 8),
                            Container(
                              width: double.infinity,
                              height: 120,
                              decoration: BoxDecoration(
                                color: const Color(0xFFEDEDED),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child:
                                  _isHttpImageUrl(imageCtrl.text)
                                      ? ClipRRect(
                                        borderRadius: BorderRadius.circular(10),
                                        child: Image.network(
                                          imageCtrl.text.trim(),
                                          fit: BoxFit.cover,
                                          errorBuilder:
                                              (_, __, ___) => const Icon(
                                                Icons.broken_image_outlined,
                                                size: 40,
                                                color: Colors.black45,
                                              ),
                                        ),
                                      )
                                      : const Icon(
                                        Icons.image_outlined,
                                        size: 40,
                                        color: Colors.black45,
                                      ),
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton.icon(
                                    style: _adminSecondaryButtonStyle(),
                                    onPressed:
                                        (saving || uploadingImage)
                                            ? null
                                            : () async {
                                              final picker = ImagePicker();
                                              final picked = await picker
                                                  .pickImage(
                                                    source: ImageSource.gallery,
                                                    imageQuality: 85,
                                                    maxWidth: 1600,
                                                  );
                                              if (picked == null) return;

                                              setDialogState(
                                                () => uploadingImage = true,
                                              );
                                              try {
                                                final hint =
                                                    (id ?? '').trim().isNotEmpty
                                                        ? id!.trim()
                                                        : (nameCtrl.text
                                                                .trim()
                                                                .isNotEmpty
                                                            ? nameCtrl.text
                                                                .trim()
                                                            : 'product');
                                                final url = await widget.svc
                                                    .uploadImageXFile(
                                                      file: picked,
                                                      folder: 'products',
                                                      fileNameHint: hint,
                                                    );
                                                if (!dialogContext.mounted)
                                                  return;
                                                setDialogState(() {
                                                  imageCtrl.text = url;
                                                });
                                                if (context.mounted) {
                                                  _showMsg(
                                                    context,
                                                    'Image uploaded.',
                                                  );
                                                }
                                              } on FirebaseException catch (e) {
                                                if (context.mounted) {
                                                  _showMsg(
                                                    context,
                                                    'Image upload failed: ${e.message ?? e.code}',
                                                  );
                                                }
                                              } catch (e) {
                                                if (context.mounted) {
                                                  _showMsg(
                                                    context,
                                                    'Image upload failed: $e',
                                                  );
                                                }
                                              } finally {
                                                if (dialogContext.mounted) {
                                                  setDialogState(
                                                    () =>
                                                        uploadingImage = false,
                                                  );
                                                }
                                              }
                                            },
                                    icon: const Icon(Icons.upload_outlined),
                                    label: Text(
                                      uploadingImage
                                          ? 'Uploading...'
                                          : 'Upload Image',
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                OutlinedButton.icon(
                                  style: _adminSecondaryButtonStyle(),
                                  onPressed:
                                      (saving || uploadingImage)
                                          ? null
                                          : () {
                                            setDialogState(() {
                                              imageCtrl.clear();
                                            });
                                          },
                                  icon: const Icon(Icons.delete_outline),
                                  label: const Text('Clear'),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            TextFormField(
                              controller: imageCtrl,
                              readOnly: true,
                              validator: _validateUrlOptional,
                              decoration: _adminInputDecoration(
                                label: 'Image URL (auto)',
                                prefixIcon: Icons.link_outlined,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                OutlinedButton(
                  style: _adminSecondaryButtonStyle(),
                  onPressed: saving ? null : () => Navigator.pop(dialogContext),
                  child: const Text("Cancel"),
                ),
                ElevatedButton(
                  style: _adminPrimaryButtonStyle(),
                  onPressed:
                      saving
                          ? null
                          : () async {
                            if (!formKey.currentState!.validate()) return;

                            try {
                              setDialogState(() => saving = true);
                              await widget.svc.upsertProduct(
                                productId: id,
                                name: nameCtrl.text.trim(),
                                unit: unitCtrl.text.trim(),
                                category: catCtrl.text.trim(),
                                quantity: int.parse(qtyCtrl.text.trim()),
                                description: descCtrl.text.trim(),
                                imageUrl: imageCtrl.text.trim(),
                                storeId: widget.fixedStoreId,
                                storeName: widget.fixedStoreName,
                              );
                              if (context.mounted) {
                                Navigator.of(dialogContext).pop();
                                _showMsg(context, 'Product saved.');
                              }
                            } on FirebaseException catch (e) {
                              if (context.mounted) {
                                _showMsg(
                                  context,
                                  'Save failed: ${e.message ?? e.code}',
                                );
                              }
                            } catch (e) {
                              if (context.mounted) {
                                _showMsg(context, 'Save failed: $e');
                              }
                            } finally {
                              if (dialogContext.mounted) {
                                setDialogState(() => saving = false);
                              }
                            }
                          },
                  child: Text(saving ? "Saving..." : "Save"),
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
    return Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        children: [
          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: widget.svc.productsStream(
              search: '',
              storeId: widget.fixedStoreId,
            ),
            builder: (context, countSnap) {
              final total = countSnap.data?.docs.length ?? 0;
              return _SectionCountHeader(
                title: 'Products',
                subtitle: 'Manage product records, images, and categories.',
                icon: Icons.inventory_2_outlined,
                countText: '$total',
              );
            },
          ),
          TextField(
            controller: _search,
            decoration: _adminInputDecoration(
              label: 'Search products',
              hint: 'Type product name...',
              prefixIcon: Icons.search,
            ),
            onChanged: (_) {
              setState(() {});
            },
          ),
          const SizedBox(height: 10),
          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: widget.svc.productsStream(
              search: '',
              storeId: widget.fixedStoreId,
            ),
            builder: (context, categorySnap) {
              final categorySet = <String>{'all'};
              final docs = categorySnap.data?.docs ?? const [];
              for (final d in docs) {
                final raw = (d.data()['category'] ?? '').toString().trim();
                categorySet.add(raw.isEmpty ? 'Uncategorized' : raw);
              }
              if (_categoryFilter.trim().isNotEmpty) {
                categorySet.add(_categoryFilter);
              }
              final categories =
                  categorySet.toList()..sort((a, b) {
                    if (a == 'all') return -1;
                    if (b == 'all') return 1;
                    return a.toLowerCase().compareTo(b.toLowerCase());
                  });

              return DropdownButtonFormField<String>(
                value: _categoryFilter,
                decoration: _adminInputDecoration(
                  label: 'Filter by Category',
                  prefixIcon: Icons.category_outlined,
                ),
                items:
                    categories
                        .map(
                          (c) => DropdownMenuItem<String>(
                            value: c,
                            child: Text(c == 'all' ? 'All Categories' : c),
                          ),
                        )
                        .toList(),
                onChanged: (v) {
                  if (v == null) return;
                  setState(() => _categoryFilter = v);
                },
              );
            },
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: _adminPrimaryButtonStyle(),
              onPressed: () {
                _addOrEditProduct(context);
              },
              icon: const Icon(Icons.add),
              label: const Text("Add Product"),
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: widget.svc.productsStream(
                search: _search.text,
                storeId: widget.fixedStoreId,
              ),
              builder: (context, snap) {
                if (snap.hasError) return _streamError(snap.error);
                if (!snap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                var docs = snap.data!.docs.toList();
                final rawSearch = _search.text.trim().toLowerCase();
                if (rawSearch.isNotEmpty) {
                  docs =
                      docs.where((d) {
                        final name =
                            (d.data()['name'] ?? '').toString().toLowerCase();
                        return name.contains(rawSearch);
                      }).toList();
                }

                if (_categoryFilter != 'all') {
                  docs =
                      docs.where((d) {
                        final raw =
                            (d.data()['category'] ?? '').toString().trim();
                        final cat = raw.isEmpty ? 'Uncategorized' : raw;
                        return cat == _categoryFilter;
                      }).toList();
                }

                if (docs.isEmpty) {
                  return Center(
                    child: Text(
                      _search.text.trim().isEmpty && _categoryFilter == 'all'
                          ? 'No products yet'
                          : 'No products found',
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  );
                }

                return ListView.separated(
                  itemCount: docs.length,
                  separatorBuilder: (_, __) {
                    return const SizedBox(height: 10);
                  },
                  itemBuilder: (_, i) {
                    final d = docs[i];
                    final p = d.data();
                    final rawQty = p['quantity'];
                    final qty =
                        rawQty is num
                            ? rawQty.toInt()
                            : int.tryParse(rawQty?.toString() ?? '') ?? 0;
                    final outOfStock = qty <= 0;
                    return Container(
                      decoration: _adminCardDecoration(),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                        leading: const CircleAvatar(
                          backgroundColor: _AdminColors.softBlue,
                          foregroundColor: _AdminColors.primary,
                          child: Icon(Icons.inventory_2_outlined),
                        ),
                        title: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              (p['name'] ?? '').toString(),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'ID: ${d.id}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 12,
                                color: _AdminColors.textMuted,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                        subtitle: Text(
                          "${p['unit'] ?? ''} - ${p['category'] ?? ''}"
                          " | Qty: $qty${outOfStock ? ' (Out of stock)' : ''}",
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: Wrap(
                          spacing: 4,
                          children: [
                            IconButton(
                              icon: const Icon(
                                Icons.edit_outlined,
                                color: _AdminColors.primary,
                              ),
                              onPressed:
                                  () => _addOrEditProduct(
                                    context,
                                    id: d.id,
                                    data: p,
                                  ),
                            ),
                            IconButton(
                              icon: const Icon(
                                Icons.delete_outline,
                                color: Colors.redAccent,
                              ),
                              onPressed: () async {
                                final ok = await _confirm(
                                  'Delete Product',
                                  'Delete product "${p['name']}"?',
                                  confirmText: 'Delete',
                                );
                                if (!ok) return;
                                await widget.svc.deleteProduct(d.id);
                              },
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/* ===================== PRICES TAB ===================== */

class _PricesTab extends StatefulWidget {
  final FirestoreService svc;
  final String? fixedStoreId;
  final String? fixedStoreName;
  const _PricesTab({required this.svc, this.fixedStoreId, this.fixedStoreName});

  @override
  State<_PricesTab> createState() => _PricesTabState();
}

class _PricesTabState extends State<_PricesTab> {
  String? _selectedProductId;
  String _selectedProductName = '';

  Future<bool> _confirm(
    String title,
    String message, {
    String confirmText = 'Yes',
  }) async {
    return showConfirmDialog(
      context,
      title: title,
      message: message,
      confirmText: confirmText,
    );
  }

  void _showMsg(BuildContext context, String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Widget _streamError(Object? error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          'Failed to load prices.\n$error',
          textAlign: TextAlign.center,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
    );
  }

  Set<String> _productIds(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> products,
  ) {
    final ids = <String>{};
    for (final product in products) {
      ids.add(product.id);
    }
    return ids;
  }

  List<DropdownMenuItem<String>> _productItems(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> products,
  ) {
    final items = <DropdownMenuItem<String>>[];
    for (final product in products) {
      final name = (product.data()['name'] ?? product.id).toString();
      items.add(
        DropdownMenuItem<String>(
          value: product.id,
          child: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
      );
    }
    return items;
  }

  QueryDocumentSnapshot<Map<String, dynamic>> _productById(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> products,
    String id,
  ) {
    for (final product in products) {
      if (product.id == id) {
        return product;
      }
    }
    return products.first;
  }

  List<Map<String, dynamic>> _storeRows(
    QuerySnapshot<Map<String, dynamic>> snap,
  ) {
    final rows = <Map<String, dynamic>>[];
    for (final doc in snap.docs) {
      final row = <String, dynamic>{'id': doc.id};
      row.addAll(doc.data());
      rows.add(row);
    }
    return rows;
  }

  List<DropdownMenuItem<String>> _storeItems(
    List<Map<String, dynamic>> stores,
  ) {
    final items = <DropdownMenuItem<String>>[];
    for (final store in stores) {
      items.add(
        DropdownMenuItem<String>(
          value: store['id'].toString(),
          child: Text(store['name'].toString()),
        ),
      );
    }
    return items;
  }

  Map<String, dynamic> _storeById(
    List<Map<String, dynamic>> stores,
    String storeId,
  ) {
    for (final store in stores) {
      if (store['id'].toString() == storeId) {
        return store;
      }
    }
    return stores.first;
  }

  Future<void> _addOrEditPrice(
    BuildContext context,
    String productId, {
    Map<String, dynamic>? data,
  }) async {
    final formKey = GlobalKey<FormState>();
    final storesSnap = await widget.svc.storesStream().first;
    if (!context.mounted) return;
    final stores = _storeRows(storesSnap);
    if (stores.isEmpty) {
      _showMsg(context, 'Add at least one store before setting prices.');
      return;
    }

    String storeId =
        (data?['storeId'] ?? (stores.isNotEmpty ? stores.first['id'] : ''))
            .toString();
    String storeName =
        (data?['storeName'] ?? (stores.isNotEmpty ? stores.first['name'] : ''))
            .toString();

    final priceCtrl = TextEditingController(
      text: (data?['price'] ?? '').toString(),
    );
    final promoCtrl = TextEditingController(
      text: (data?['promoPrice'] ?? '').toString(),
    );
    bool saving = false;

    await showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
              title: const Text("Set Store Price"),
              content: SingleChildScrollView(
                child: Form(
                  key: formKey,
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if ((widget.fixedStoreId ?? '').trim().isEmpty) ...[
                        DropdownButtonFormField<String>(
                          value: storeId.isEmpty ? null : storeId,
                          decoration: _adminInputDecoration(
                            label: 'Store',
                            prefixIcon: Icons.storefront_outlined,
                          ),
                          items: _storeItems(stores),
                          validator:
                              (v) =>
                                  v == null || v.isEmpty
                                      ? 'Store is required.'
                                      : null,
                          onChanged: (v) {
                            setDialogState(() {
                              storeId = v ?? storeId;
                              final found = _storeById(stores, storeId);
                              storeName = found['name'].toString();
                            });
                          },
                        ),
                        const SizedBox(height: 12),
                      ] else ...[
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: _adminCardDecoration(),
                          child: Text(
                            'Store: $storeName',
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                      TextFormField(
                        controller: priceCtrl,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        validator: (v) => _validatePriceRequired(v, 'Price'),
                        decoration: _adminInputDecoration(
                          label: 'Price (RM)',
                          prefixIcon: Icons.attach_money_outlined,
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: promoCtrl,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        validator:
                            (v) => _validatePriceOptional(v, 'Promo price'),
                        decoration: _adminInputDecoration(
                          label: 'Promo Price (optional)',
                          prefixIcon: Icons.local_offer_outlined,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                OutlinedButton(
                  style: _adminSecondaryButtonStyle(),
                  onPressed: saving ? null : () => Navigator.pop(dialogContext),
                  child: const Text("Cancel"),
                ),
                ElevatedButton(
                  style: _adminPrimaryButtonStyle(),
                  onPressed:
                      saving
                          ? null
                          : () async {
                            if (!formKey.currentState!.validate()) return;

                            final price = double.parse(priceCtrl.text.trim());
                            final promo =
                                promoCtrl.text.trim().isEmpty
                                    ? null
                                    : double.parse(promoCtrl.text.trim());

                            try {
                              setDialogState(() => saving = true);
                              await widget.svc.upsertPrice(
                                productId: productId,
                                storeId: storeId,
                                storeName: storeName,
                                price: price,
                                promoPrice: promo,
                              );
                              if (context.mounted) {
                                Navigator.of(dialogContext).pop();
                                _showMsg(context, 'Price saved.');
                              }
                            } on FirebaseException catch (e) {
                              if (context.mounted) {
                                _showMsg(
                                  context,
                                  'Save failed: ${e.message ?? e.code}',
                                );
                              }
                            } catch (e) {
                              if (context.mounted) {
                                _showMsg(context, 'Save failed: $e');
                              }
                            } finally {
                              if (dialogContext.mounted) {
                                setDialogState(() => saving = false);
                              }
                            }
                          },
                  child: Text(saving ? "Saving..." : "Save"),
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
    return Padding(
      padding: const EdgeInsets.all(14),
      child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: widget.svc.productsStream(
          search: '',
          storeId: widget.fixedStoreId,
        ),
        builder: (context, productSnap) {
          if (productSnap.hasError) return _streamError(productSnap.error);
          if (!productSnap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final products = productSnap.data!.docs;

          if (products.isEmpty) {
            return const Center(
              child: Text(
                'No products yet. Add products first.',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
            );
          }

          final validIds = _productIds(products);
          if (_selectedProductId == null ||
              !validIds.contains(_selectedProductId)) {
            _selectedProductId = products.first.id;
            final data = products.first.data();
            _selectedProductName =
                (data['name'] ?? products.first.id).toString();
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: widget.svc.pricesStream(
                  _selectedProductId!,
                  storeId: widget.fixedStoreId,
                ),
                builder: (context, priceSnap) {
                  final count = priceSnap.data?.docs.length ?? 0;
                  return _SectionCountHeader(
                    title: 'Prices',
                    subtitle: 'Manage store pricing for the selected product.',
                    icon: Icons.attach_money_outlined,
                    countText: '$count',
                  );
                },
              ),
              const Text(
                'Step 1: Select product',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: _selectedProductId,
                decoration: _adminInputDecoration(
                  label: 'Product',
                  prefixIcon: Icons.inventory_2_outlined,
                ),
                items: _productItems(products),
                onChanged: (v) {
                  if (v == null) return;
                  final found = _productById(products, v);
                  setState(() {
                    _selectedProductId = v;
                    _selectedProductName =
                        (found.data()['name'] ?? v).toString();
                  });
                },
              ),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: _adminCardDecoration(),
                child: Text(
                  'Step 2: Manage prices for $_selectedProductName (${_selectedProductId ?? ''})',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: _adminPrimaryButtonStyle(),
                  onPressed:
                      _selectedProductId == null
                          ? null
                          : () => _addOrEditPrice(context, _selectedProductId!),
                  icon: const Icon(Icons.add),
                  label: const Text('Add Store Price'),
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child:
                    _selectedProductId == null
                        ? const Center(
                          child: Text(
                            'Please select a product',
                            style: TextStyle(fontWeight: FontWeight.w800),
                          ),
                        )
                        : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                          stream: widget.svc.pricesStream(
                            _selectedProductId!,
                            storeId: widget.fixedStoreId,
                          ),
                          builder: (context, snap) {
                            if (snap.hasError) return _streamError(snap.error);
                            if (!snap.hasData) {
                              return const Center(
                                child: CircularProgressIndicator(),
                              );
                            }
                            final docs = snap.data!.docs;
                            if (docs.isEmpty) {
                              return const Center(
                                child: Text(
                                  'No prices set for this product',
                                  style: TextStyle(fontWeight: FontWeight.w800),
                                ),
                              );
                            }

                            return ListView.separated(
                              itemCount: docs.length,
                              separatorBuilder:
                                  (_, __) => const SizedBox(height: 10),
                              itemBuilder: (_, i) {
                                final d = docs[i];
                                final p = d.data();
                                final price = (p['price'] as num?)?.toDouble();
                                final promo =
                                    (p['promoPrice'] as num?)?.toDouble();

                                return Container(
                                  decoration: _adminCardDecoration(),
                                  child: ListTile(
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 8,
                                    ),
                                    leading: const CircleAvatar(
                                      backgroundColor: _AdminColors.softBlue,
                                      foregroundColor: _AdminColors.primary,
                                      child: Icon(Icons.attach_money_outlined),
                                    ),
                                    title: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          (p['storeName'] ?? '').toString(),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w900,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          'Store ID: ${d.id}',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: _AdminColors.textMuted,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ],
                                    ),
                                    subtitle: Text(
                                      "Normal: RM ${price?.toStringAsFixed(2) ?? '-'}"
                                      "${promo != null ? " | Promo: RM ${promo.toStringAsFixed(2)}" : ""}",
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    trailing: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          tooltip: 'Edit',
                                          visualDensity: VisualDensity.compact,
                                          constraints:
                                              const BoxConstraints.tightFor(
                                                width: 36,
                                                height: 36,
                                              ),
                                          padding: EdgeInsets.zero,
                                          icon: const Icon(
                                            Icons.edit_outlined,
                                            color: _AdminColors.primary,
                                          ),
                                          onPressed:
                                              () => _addOrEditPrice(
                                                context,
                                                _selectedProductId!,
                                                data: p,
                                              ),
                                        ),
                                        IconButton(
                                          tooltip: 'Delete',
                                          visualDensity: VisualDensity.compact,
                                          constraints:
                                              const BoxConstraints.tightFor(
                                                width: 36,
                                                height: 36,
                                              ),
                                          padding: EdgeInsets.zero,
                                          icon: const Icon(
                                            Icons.delete_outline,
                                            color: Colors.redAccent,
                                          ),
                                          onPressed: () async {
                                            final ok = await _confirm(
                                              'Delete Price',
                                              'Delete price entry for store "${p['storeName']}"?',
                                              confirmText: 'Delete',
                                            );
                                            if (!ok) return;
                                            try {
                                              await widget.svc.deletePrice(
                                                productId: _selectedProductId!,
                                                storeId: d.id,
                                              );
                                              if (context.mounted) {
                                                _showMsg(
                                                  context,
                                                  'Price deleted.',
                                                );
                                              }
                                            } on FirebaseException catch (e) {
                                              if (context.mounted) {
                                                _showMsg(
                                                  context,
                                                  'Delete failed: ${e.message ?? e.code}',
                                                );
                                              }
                                            }
                                          },
                                        ),
                                      ],
                                    ),
                                  ),
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
}
