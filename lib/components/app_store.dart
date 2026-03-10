// How this file works:
// 1) Data/models are declared first (if any).
// 2) UI widgets are built in build() methods.
// 3) Helper methods are used to keep UI code clean.

// File purpose: This file handles app store screen/logic.

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

// This class defines ProductPrice, used for this page/feature.
class ProductPrice {
  final String store;
  final double price;

  const ProductPrice({required this.store, required this.price});
}

// This class defines ProductItem, used for this page/feature.
class ProductItem {
  final String id;
  final String name;
  final String category;
  final String description;
  final String unit;
  final int quantity;
  final String? imageUrl;
  final DateTime createdAt;
  final List<ProductPrice> prices;
  final double? oldPrice;

  const ProductItem({
    required this.id,
    required this.name,
    required this.category,
    required this.description,
    required this.unit,
    required this.quantity,
    required this.imageUrl,
    required this.createdAt,
    required this.prices,
    this.oldPrice,
  });

  bool get isOutOfStock => quantity <= 0;
  bool get isInStock => quantity > 0;

  double get lowestPrice {
    if (prices.isEmpty) return 0;
    var lowest = prices.first.price;
    for (final item in prices) {
      if (item.price < lowest) {
        lowest = item.price;
      }
    }
    return lowest;
  }

  String get cheapestStore {
    if (prices.isEmpty) return '-';
    var cheapest = prices.first;
    for (final item in prices) {
      if (item.price <= cheapest.price) {
        cheapest = item;
      }
    }
    return cheapest.store;
  }

  double? get dropPercent {
    if (oldPrice == null ||
        oldPrice! <= 0 ||
        lowestPrice <= 0 ||
        lowestPrice >= oldPrice!) {
      return null;
    }
    return ((oldPrice! - lowestPrice) / oldPrice!) * 100;
  }
}

// This class defines CartItem, used for this page/feature.
class CartItem {
  final String productId;
  int qty;

  CartItem({required this.productId, required this.qty});
}

// This class defines PaymentMethodItem, used for this page/feature.
class PaymentMethodItem {
  final String id;
  final String type;
  final String holderName;
  final String last4;
  final String expiry;

  const PaymentMethodItem({
    required this.id,
    required this.type,
    required this.holderName,
    required this.last4,
    required this.expiry,
  });
}

// This class defines VoucherItem, used for this page/feature.
class VoucherItem {
  final String id;
  final String store;
  final int percent;
  final double minSpend;
  final String code;

  const VoucherItem({
    required this.id,
    required this.store,
    required this.percent,
    required this.minSpend,
    required this.code,
  });
}

// This class defines OrderItem, used for this page/feature.
class OrderItem {
  final String id;
  final DateTime createdAt;
  final List<CartItem> items;
  final double total;
  final double subtotal;
  final double discount;
  final String customerName;
  final String customerPhone;
  final String deliveryAddress;
  final double deliveryDistanceKm;
  final double deliveryFee;
  final String paymentType;
  final String paymentLast4;
  final String voucherCode;
  String status;

  OrderItem({
    required this.id,
    required this.createdAt,
    required this.items,
    required this.total,
    required this.status,
    this.subtotal = 0,
    this.discount = 0,
    this.customerName = '',
    this.customerPhone = '',
    this.deliveryAddress = '',
    this.deliveryDistanceKm = 0,
    this.deliveryFee = 0,
    this.paymentType = '',
    this.paymentLast4 = '',
    this.voucherCode = '',
  });
}

// This class defines VoiceCommandResult, used for this page/feature.
class VoiceCommandResult {
  final bool handled;
  final String message;
  final String? categoryFilter;
  final String? searchText;
  final String? route;
  final ProductItem? product;

  const VoiceCommandResult({
    required this.handled,
    required this.message,
    this.categoryFilter,
    this.searchText,
    this.route,
    this.product,
  });
}

// This class defines TrackedItem, used for this page/feature.
class TrackedItem {
  final String productId;
  final double? targetPrice;
  final double? lastNotifiedPrice;

  const TrackedItem({
    required this.productId,
    required this.targetPrice,
    required this.lastNotifiedPrice,
  });
}

// This class defines TierVoucherReward, used for points-to-voucher redemption.
class TierVoucherReward {
  final String title;
  final int pointsCost;
  final int percent;
  final double minSpend;
  final String store;

  const TierVoucherReward({
    required this.title,
    required this.pointsCost,
    required this.percent,
    required this.minSpend,
    this.store = 'E-Commerce',
  });
}

// This class defines AppStore, used for this page/feature.
class AppStore extends ChangeNotifier {
  AppStore._() {
    // Keep product catalog listening all the time.
    _startCatalogListeners();

    // When auth user changes, reload user-specific collections.
    _authSub = _auth.authStateChanges().listen(_onAuthChanged);
    _onAuthChanged(_auth.currentUser);
  }

  static final AppStore instance = AppStore._();

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  static const int _hubPostcode = 43000;
  static const double _baseDistanceKm = 3.0;
  static const double _minDistanceKm = 1.0;
  static const double _maxDistanceKm = 40.0;
  static const double _fallbackDistanceKm = 8.0;
  static const double _baseDeliveryFee = 3.00;
  static const double _extraFeePerKm = 0.60;

  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _productsSub;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _pricesSub;
  StreamSubscription<User?>? _authSub;
  Timer? _catalogRetryTimer;

  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _likesSub;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _recentSub;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _trackedSub;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _cartSub;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _ordersSub;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _paymentsSub;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _vouchersSub;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _activitiesSub;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _profileSub;

  final List<ProductItem> _products = [];
  final List<CartItem> _cart = [];
  final List<String> _likedProductIds = [];
  final List<String> _recentlyViewed = [];
  final List<TrackedItem> _trackedItems = [];
  final List<PaymentMethodItem> _payments = [];
  final List<VoucherItem> _vouchers = [];
  final List<OrderItem> _orders = [];
  final List<String> _activityLogs = [];
  String? _appliedVoucherId;
  bool _priceDropCheckRunning = false;
  bool _priceDropCheckQueued = false;
  int _pointsSpent = 0;

  List<ProductItem> get products => List.unmodifiable(_products);
  List<CartItem> get cart => List.unmodifiable(_cart);
  List<String> get likedProductIds => List.unmodifiable(_likedProductIds);
  List<String> get recentlyViewedIds => List.unmodifiable(_recentlyViewed);
  List<String> get trackedProductIds {
    final ids = <String>[];
    for (final item in _trackedItems) {
      ids.add(item.productId);
    }
    return List.unmodifiable(ids);
  }

  List<PaymentMethodItem> get payments => List.unmodifiable(_payments);
  List<VoucherItem> get vouchers => List.unmodifiable(_vouchers);
  List<OrderItem> get orders => List.unmodifiable(_orders);
  List<String> get activityLogs => List.unmodifiable(_activityLogs);
  int get pointsSpent => _pointsSpent;

  String? get _uid => _auth.currentUser?.uid;
  bool get _isGuestUser {
    final user = _auth.currentUser;
    return user == null || user.isAnonymous;
  }

  VoucherItem? get appliedVoucher {
    final id = _appliedVoucherId;
    if (id == null) return null;
    for (final v in _vouchers) {
      if (v.id == id) return v;
    }
    return null;
  }

  DocumentReference<Map<String, dynamic>> _userDoc(String uid) {
    return _db.collection('users').doc(uid);
  }

  int _asInt(dynamic v, {int fallback = 0}) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) {
      final parsed = int.tryParse(v.trim());
      if (parsed != null) return parsed;
    }
    return fallback;
  }

  int _cartQtyFromMap(Map<String, dynamic> data, {int fallback = 0}) {
    final qty = _asInt(data['qty'], fallback: -1);
    if (qty >= 0) return qty;
    final legacyQty = _asInt(data['quantity'], fallback: -1);
    if (legacyQty >= 0) return legacyQty;
    return fallback;
  }

  double _asDouble(dynamic v, {double fallback = 0}) {
    if (v is double) return v;
    if (v is int) return v.toDouble();
    if (v is num) return v.toDouble();
    return fallback;
  }

  DateTime _asDate(dynamic v) {
    if (v is Timestamp) return v.toDate();
    if (v is DateTime) return v;
    return DateTime.fromMillisecondsSinceEpoch(0);
  }

  int? _extractPostcode(String text) {
    final match = RegExp(r'\b(\d{5})\b').firstMatch(text);
    if (match == null) return null;
    return int.tryParse(match.group(1)!);
  }

  double _round2(double value) {
    return (value * 100).roundToDouble() / 100;
  }

  double estimateDeliveryDistanceKm({
    required String deliveryAddress,
    String fallbackPostcode = '',
  }) {
    final fromAddress = _extractPostcode(deliveryAddress);
    final fromFallback = _extractPostcode(fallbackPostcode);
    final customerPostcode = fromAddress ?? fromFallback;
    if (customerPostcode == null) {
      return _fallbackDistanceKm;
    }

    final delta = (customerPostcode - _hubPostcode).abs() / 100.0;
    final km = delta.clamp(_minDistanceKm, _maxDistanceKm).toDouble();
    return _round2(km);
  }

  double estimateDeliveryFee({
    required String deliveryAddress,
    String fallbackPostcode = '',
  }) {
    final distanceKm = estimateDeliveryDistanceKm(
      deliveryAddress: deliveryAddress,
      fallbackPostcode: fallbackPostcode,
    );
    final extraDistance =
        (distanceKm - _baseDistanceKm) > 0
            ? (distanceKm - _baseDistanceKm)
            : 0.0;
    final fee = _baseDeliveryFee + (extraDistance * _extraFeePerKm);
    return _round2(fee);
  }

  Future<void> _onProductsChanged(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) async {
    // Build each product with prices from subcollection.
    final items = <ProductItem>[];
    for (final doc in docs) {
      final product = await _composeProduct(doc);
      items.add(product);
    }
    items.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

    _products
      ..clear()
      ..addAll(items);

    await _syncCartToCurrentStock();

    // Product prices changed -> tracked price checks may need to run.
    _schedulePriceDropCheck();
    notifyListeners();
  }

  int _productQuantityFromMap(Map<String, dynamic> data) {
    final primary = _asInt(data['quantity'], fallback: -1);
    if (primary >= 0) return primary;

    final qty = _asInt(data['qty'], fallback: -1);
    if (qty >= 0) return qty;

    final stock = _asInt(data['stock'], fallback: -1);
    if (stock >= 0) return stock;

    return 0;
  }

  Future<ProductItem> _composeProduct(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) async {
    final data = doc.data();

    // prices are stored under products/{productId}/prices/{storeId}
    final priceSnap =
        await _db.collection('products').doc(doc.id).collection('prices').get();
    final prices = <ProductPrice>[];
    for (final pDoc in priceSnap.docs) {
      final p = pDoc.data();
      final promo = p['promoPrice'];
      final base = p['price'];
      // promoPrice has priority when present and valid.
      final effective = (promo is num && promo > 0) ? promo : base;
      final item = ProductPrice(
        store: (p['storeName'] ?? p['storeId'] ?? pDoc.id).toString(),
        price: _asDouble(effective),
      );
      if (item.price > 0) {
        prices.add(item);
      }
    }

    return ProductItem(
      id: doc.id,
      name: (data['name'] ?? '').toString(),
      category: (data['category'] ?? '').toString(),
      description: (data['description'] ?? '').toString(),
      unit: (data['unit'] ?? '').toString(),
      quantity: _productQuantityFromMap(data),
      imageUrl: (data['imageUrl'] as String?)?.trim(),
      createdAt: _asDate(data['createdAt'] ?? data['updatedAt']),
      prices: prices,
      oldPrice: data['oldPrice'] is num ? _asDouble(data['oldPrice']) : null,
    );
  }

  Future<void> _syncCartToCurrentStock() async {
    final uid = _uid;
    if (uid == null || _cart.isEmpty) return;

    final batch = _db.batch();
    var changed = false;

    for (final item in _cart) {
      final product = productById(item.productId);
      final ref = _userDoc(uid).collection('cart').doc(item.productId);
      if (product == null || item.qty <= 0) {
        batch.delete(ref);
        changed = true;
        continue;
      }

      final allowedQty = product.quantity;

      if (allowedQty <= 0 && item.qty > 0) {
        batch.delete(ref);
        changed = true;
        continue;
      }

      if (item.qty > allowedQty && allowedQty > 0) {
        batch.set(ref, {
          'qty': allowedQty,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
        changed = true;
      }
    }

    if (changed) {
      await batch.commit();
    }
  }

  Future<void> _refreshProductsFromServer() async {
    final productsSnap = await _db.collection('products').get();
    await _onProductsChanged(productsSnap.docs);
  }

  void _scheduleCatalogRetry() {
    // Retry with delay to avoid tight reconnect loop on temporary network errors.
    if (_catalogRetryTimer?.isActive == true) return;
    _catalogRetryTimer = Timer(const Duration(seconds: 3), () {
      _startCatalogListeners();
    });
  }

  void _startCatalogListeners() {
    _catalogRetryTimer?.cancel();
    _productsSub?.cancel();
    _pricesSub?.cancel();

    _productsSub = _db
        .collection('products')
        .snapshots()
        .listen(
          (snap) {
            // Keep _products in sync with any product document changes.
            _onProductsChanged(snap.docs);
          },
          onError: (error) {
            if (_shouldRetryCatalogError(error)) {
              _scheduleCatalogRetry();
            }
          },
        );

    _pricesSub = _db
        .collectionGroup('prices')
        .snapshots()
        .listen(
          (_) async {
            // If any store price changes, recalculate product effective prices.
            await _refreshProductsFromServer();
          },
          onError: (error) {
            // If rules block collectionGroup('prices'), do not keep retrying forever.
            if (_shouldRetryCatalogError(error)) {
              _scheduleCatalogRetry();
            }
          },
        );
  }

  bool _shouldRetryCatalogError(Object error) {
    if (error is FirebaseException && error.code == 'permission-denied') {
      return false;
    }
    return true;
  }

  void _onAuthChanged(User? user) {
    // Always reset local user state when user changes.
    _startCatalogListeners();
    _likesSub?.cancel();
    _recentSub?.cancel();
    _trackedSub?.cancel();
    _cartSub?.cancel();
    _ordersSub?.cancel();
    _paymentsSub?.cancel();
    _vouchersSub?.cancel();
    _activitiesSub?.cancel();
    _profileSub?.cancel();

    // Reset all local caches before loading the new user's data.
    _likedProductIds.clear();
    _recentlyViewed.clear();
    _trackedItems.clear();
    _cart.clear();
    _orders.clear();
    _payments.clear();
    _vouchers.clear();
    _activityLogs.clear();
    _appliedVoucherId = null;
    _pointsSpent = 0;

    if (user == null) {
      notifyListeners();
      return;
    }

    final u = _userDoc(user.uid);

    _profileSub = u.snapshots().listen((snap) {
      final data = snap.data() ?? const <String, dynamic>{};
      _pointsSpent = _asInt(data['pointsSpent'], fallback: 0);
      notifyListeners();
    });

    _likesSub = u.collection('likes').snapshots().listen((snap) {
      // likes docs use productId as document id.
      _likedProductIds.clear();
      for (final d in snap.docs) {
        _likedProductIds.add(d.id);
      }
      notifyListeners();
    });

    _recentSub = u
        .collection('recently_viewed')
        .orderBy('updatedAt', descending: true)
        .limit(20)
        .snapshots()
        .listen((snap) {
          _recentlyViewed.clear();
          // Keep order as returned by query (latest viewed first).
          for (final d in snap.docs) {
            _recentlyViewed.add(d.id);
          }
          notifyListeners();
        });

    _trackedSub = u.collection('tracked_products').snapshots().listen((snap) {
      _trackedItems.clear();
      for (final d in snap.docs) {
        final data = d.data();
        final item = TrackedItem(
          productId: d.id,
          targetPrice:
              data['targetPrice'] is num
                  ? (data['targetPrice'] as num).toDouble()
                  : null,
          lastNotifiedPrice:
              data['lastNotifiedPrice'] is num
                  ? (data['lastNotifiedPrice'] as num).toDouble()
                  : null,
        );
        _trackedItems.add(item);
      }
      // Tracked list changed -> rerun trigger check.
      _schedulePriceDropCheck();
      notifyListeners();
    });

    _cartSub = u.collection('cart').snapshots().listen((snap) {
      _cart.clear();
      for (final d in snap.docs) {
        final row = CartItem(
          productId: d.id,
          qty: _cartQtyFromMap(d.data(), fallback: 0),
        );
        if (row.qty > 0) {
          _cart.add(row);
        }
      }
      _ensureAppliedVoucherStillValid();
      notifyListeners();
    });

    _ordersSub = u
        .collection('orders')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .listen((snap) {
          final rows = <OrderItem>[];
          for (final d in snap.docs) {
            final data = d.data();
            // items is stored as list of maps, convert back to CartItem model.
            final rawItems = (data['items'] as List?) ?? const [];
            final items = <CartItem>[];
            for (final entry in rawItems) {
              if (entry is! Map) continue;
              items.add(
                CartItem(
                  productId: (entry['productId'] ?? '').toString(),
                  qty: _asInt(entry['qty'], fallback: 1),
                ),
              );
            }

            rows.add(
              OrderItem(
                id: d.id,
                createdAt: _asDate(data['createdAt']),
                items: items,
                total: _asDouble(data['total']),
                status: (data['status'] ?? 'To Ship').toString(),
                subtotal: _asDouble(data['subtotal']),
                discount: _asDouble(data['discount']),
                customerName: (data['customerName'] ?? '').toString(),
                customerPhone: (data['customerPhone'] ?? '').toString(),
                deliveryAddress:
                    (data['deliveryAddress'] ?? data['address'] ?? '')
                        .toString(),
                deliveryDistanceKm: _asDouble(data['deliveryDistanceKm']),
                deliveryFee: _asDouble(data['deliveryFee']),
                paymentType: (data['paymentType'] ?? '').toString(),
                paymentLast4: (data['paymentLast4'] ?? '').toString(),
                voucherCode: (data['voucherCode'] ?? '').toString(),
              ),
            );
          }

          _orders
            ..clear()
            ..addAll(rows);
          notifyListeners();
        });

    _paymentsSub = u.collection('payment_methods').snapshots().listen((snap) {
      _payments.clear();
      for (final d in snap.docs) {
        final data = d.data();
        _payments.add(
          PaymentMethodItem(
            id: d.id,
            type: (data['type'] ?? '').toString(),
            holderName: (data['holderName'] ?? '').toString(),
            last4: (data['last4'] ?? '').toString(),
            expiry: (data['expiry'] ?? '').toString(),
          ),
        );
      }
      notifyListeners();
    });

    _vouchersSub = u
        .collection('vouchers')
        .orderBy('claimedAt', descending: true)
        .snapshots()
        .listen((snap) {
          _vouchers.clear();
          for (final d in snap.docs) {
            final data = d.data();
            _vouchers.add(
              VoucherItem(
                id: d.id,
                store: (data['store'] ?? '').toString(),
                percent: _asInt(data['percent']),
                minSpend: _asDouble(data['minSpend']),
                code: (data['code'] ?? '').toString(),
              ),
            );
          }
          _ensureAppliedVoucherStillValid();
          notifyListeners();
        });

    _activitiesSub = u
        .collection('activities')
        .orderBy('createdAt', descending: true)
        .limit(60)
        .snapshots()
        .listen((snap) {
          _activityLogs.clear();
          for (final d in snap.docs) {
            final data = d.data();
            final dt = _asDate(data['createdAt']);
            final msg = (data['message'] ?? '').toString();
            _activityLogs.add('${dt.toIso8601String()}|$msg');
          }
          notifyListeners();
        });

    notifyListeners();
  }

  ProductItem? productById(String id) {
    for (final p in _products) {
      if (p.id == id) return p;
    }
    return null;
  }

  int availableStock(String productId) {
    return productById(productId)?.quantity ?? 0;
  }

  bool canAddToCart(String productId, {int qty = 1}) {
    final p = productById(productId);
    if (p == null) return false;
    if (qty <= 0) return false;

    var inCart = 0;
    for (final item in _cart) {
      if (item.productId == productId) {
        inCart = item.qty;
        break;
      }
    }
    return (inCart + qty) <= p.quantity;
  }

  List<ProductItem> filteredProducts({String? category, String search = ''}) {
    final keyword = search.trim().toLowerCase();
    final wantedCategory = (category ?? '').trim().toLowerCase();
    final output = <ProductItem>[];

    for (final p in _products) {
      final inCategory =
          wantedCategory.isEmpty || p.category.toLowerCase() == wantedCategory;
      final matchSearch =
          keyword.isEmpty ||
          p.name.toLowerCase().contains(keyword) ||
          p.category.toLowerCase().contains(keyword);
      if (inCategory && matchSearch) {
        output.add(p);
      }
    }
    return output;
  }

  List<ProductItem> get priceDrops {
    final copy = <ProductItem>[];
    for (final product in _products) {
      if (product.dropPercent != null) {
        copy.add(product);
      }
    }
    copy.sort((a, b) => (b.dropPercent ?? 0).compareTo(a.dropPercent ?? 0));
    return copy;
  }

  List<ProductItem> get newProducts {
    final copy = <ProductItem>[];
    for (final product in _products) {
      copy.add(product);
    }
    copy.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final limited = <ProductItem>[];
    for (final product in copy) {
      if (limited.length >= 8) break;
      limited.add(product);
    }
    return limited;
  }

  List<ProductItem> get likedProducts {
    final result = <ProductItem>[];
    for (final id in _likedProductIds) {
      final product = productById(id);
      if (product != null) {
        result.add(product);
      }
    }
    return result;
  }

  List<ProductItem> get recentlyViewedProducts {
    final result = <ProductItem>[];
    for (final id in _recentlyViewed) {
      final product = productById(id);
      if (product != null) {
        result.add(product);
      }
    }
    return result;
  }

  List<ProductItem> get trackedProducts {
    final result = <ProductItem>[];
    for (final item in _trackedItems) {
      final product = productById(item.productId);
      if (product != null) {
        result.add(product);
      }
    }
    return result;
  }

  double? trackedTargetPrice(String productId) {
    for (final t in _trackedItems) {
      if (t.productId == productId) return t.targetPrice;
    }
    return null;
  }

  double get cartTotal {
    double total = 0;
    for (final item in _cart) {
      final p = productById(item.productId);
      if (p == null) continue;
      final cappedQty = item.qty > p.quantity ? p.quantity : item.qty;
      if (cappedQty <= 0) continue;
      total += p.lowestPrice * cappedQty;
    }
    return total;
  }

  double get voucherDiscountAmount {
    final voucher = appliedVoucher;
    if (voucher == null) return 0;
    final subtotal = cartTotal;
    if (subtotal <= 0 || subtotal < voucher.minSpend) return 0;
    final percent = voucher.percent.clamp(0, 100).toDouble();
    return subtotal * (percent / 100);
  }

  double get payableTotal {
    final total = cartTotal - voucherDiscountAmount;
    return total <= 0 ? 0 : total;
  }

  bool _ensureAppliedVoucherStillValid() {
    // Auto-remove selected voucher when cart is empty or below min spend.
    final voucher = appliedVoucher;
    if (voucher == null) {
      if (_appliedVoucherId != null) {
        _appliedVoucherId = null;
        return true;
      }
      return false;
    }
    if (_cart.isEmpty || cartTotal < voucher.minSpend) {
      _appliedVoucherId = null;
      return true;
    }
    return false;
  }

  Future<void> markViewed(String productId) async {
    if (_isGuestUser) return;
    final uid = _uid;
    if (uid == null) return;

    await _userDoc(uid).collection('recently_viewed').doc(productId).set({
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    await _log('Viewed ${productById(productId)?.name ?? productId}');
  }

  Future<void> recordSearch(String query) async {
    if (_isGuestUser) return;
    final uid = _uid;
    final q = query.trim();
    if (uid == null || q.isEmpty) return;

    await _userDoc(uid).collection('search_history').add({
      'query': q,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> toggleLike(String productId) async {
    if (_isGuestUser) return;
    final uid = _uid;
    if (uid == null) return;

    final ref = _userDoc(uid).collection('likes').doc(productId);
    final snap = await ref.get();
    if (snap.exists) {
      await ref.delete();
      await _log(
        'Removed from likes: ${productById(productId)?.name ?? productId}',
      );
    } else {
      await ref.set({'updatedAt': FieldValue.serverTimestamp()});
      await _log(
        'Added to likes: ${productById(productId)?.name ?? productId}',
      );
    }
  }

  Future<bool> addToCart(String productId, {int qty = 1}) async {
    if (_isGuestUser) return false;
    final uid = _uid;
    if (uid == null) return false;

    final product = productById(productId);
    if (product == null || qty <= 0) return false;
    if (product.quantity <= 0) return false;

    final ref = _userDoc(uid).collection('cart').doc(productId);
    final snap = await ref.get();
    final current = _cartQtyFromMap(
      snap.data() ?? const <String, dynamic>{},
      fallback: 0,
    );
    final next = current + qty;
    if (next > product.quantity) return false;
    await ref.set({
      'qty': next,
      'quantity': next,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    await _log('Added to cart: ${productById(productId)?.name ?? productId}');
    return true;
  }

  Future<bool> updateCartQty(String productId, int qty) async {
    final uid = _uid;
    if (uid == null) return false;

    final ref = _userDoc(uid).collection('cart').doc(productId);
    if (qty <= 0) {
      await ref.delete();
      return true;
    }

    final product = productById(productId);
    if (product == null || qty > product.quantity) {
      return false;
    }

    await ref.set({
      'qty': qty,
      'quantity': qty,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    return true;
  }

  Future<void> clearCart() async {
    final uid = _uid;
    if (uid == null) return;

    // Batch delete is faster and safer than deleting one-by-one.
    final snap = await _userDoc(uid).collection('cart').get();
    final batch = _db.batch();
    for (final d in snap.docs) {
      batch.delete(d.reference);
    }
    await batch.commit();
  }

  Future<void> toggleTrackProduct(
    String productId, {
    double? targetPrice,
  }) async {
    if (_isGuestUser) return;
    final uid = _uid;
    if (uid == null) return;

    final ref = _userDoc(uid).collection('tracked_products').doc(productId);
    final snap = await ref.get();
    if (snap.exists) {
      await ref.delete();
      await _log(
        'Stopped tracking ${productById(productId)?.name ?? productId}',
      );
    } else {
      await ref.set({
        'targetPrice': targetPrice,
        'lastNotifiedPrice': null,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      await _log(
        'Started tracking ${productById(productId)?.name ?? productId}',
      );
    }
  }

  Future<void> setTrackTargetPrice(
    String productId,
    double? targetPrice,
  ) async {
    if (_isGuestUser) return;
    final uid = _uid;
    if (uid == null) return;

    await _userDoc(uid).collection('tracked_products').doc(productId).set({
      'targetPrice': targetPrice,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> addPaymentMethod(PaymentMethodItem method) async {
    final uid = _uid;
    if (uid == null) return;

    await _userDoc(uid).collection('payment_methods').doc(method.id).set({
      'type': method.type,
      'holderName': method.holderName,
      'last4': method.last4,
      'expiry': method.expiry,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deletePaymentMethod(String id) async {
    final uid = _uid;
    if (uid == null) return;

    await _userDoc(uid).collection('payment_methods').doc(id).delete();
  }

  Future<void> setPaymentPhrase(String phrase) async {
    final uid = _uid;
    if (uid == null) return;
    await _userDoc(uid).set({
      'paymentPhrase': phrase.trim(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> deleteVoucher(String id) async {
    final uid = _uid;
    if (uid == null) return;

    await _userDoc(uid).collection('vouchers').doc(id).delete();
    if (_appliedVoucherId == id) {
      _appliedVoucherId = null;
      notifyListeners();
    }
  }

  Future<String> applyVoucher(String voucherId) async {
    if (_isGuestUser) return 'Please login to apply voucher.';
    VoucherItem? voucher;
    for (final v in _vouchers) {
      if (v.id == voucherId) {
        voucher = v;
        break;
      }
    }
    if (voucher == null) return 'Voucher not found.';
    if (cartTotal < voucher.minSpend) {
      return 'Minimum spend RM ${voucher.minSpend.toStringAsFixed(2)} required.';
    }
    _appliedVoucherId = voucher.id;
    notifyListeners();
    await _log('Applied voucher ${voucher.code}');
    return 'Applied voucher ${voucher.code}.';
  }

  Future<String> applyVoucherCode(String code) async {
    final c = code.trim().toLowerCase();
    if (c.isEmpty) return 'Please enter voucher code.';
    VoucherItem? voucher;
    for (final v in _vouchers) {
      if (v.code.trim().toLowerCase() == c) {
        voucher = v;
        break;
      }
    }
    if (voucher == null) return 'Voucher code not found in your vouchers.';
    return applyVoucher(voucher.id);
  }

  Future<void> clearAppliedVoucher() async {
    final voucher = appliedVoucher;
    if (_appliedVoucherId == null) return;
    _appliedVoucherId = null;
    notifyListeners();
    if (voucher != null && !_isGuestUser) {
      await _log('Removed voucher ${voucher.code}');
    }
  }

  List<CartItem> _copyCartItems() {
    final result = <CartItem>[];
    for (final item in _cart) {
      result.add(CartItem(productId: item.productId, qty: item.qty));
    }
    return result;
  }

  double _subtotalForItems(List<CartItem> items) {
    double total = 0;
    for (final item in items) {
      final p = productById(item.productId);
      if (p == null || item.qty <= 0) continue;
      total += p.lowestPrice * item.qty;
    }
    return total;
  }

  List<Map<String, dynamic>> _orderItemsToMap(List<CartItem> items) {
    final rows = <Map<String, dynamic>>[];
    for (final item in items) {
      rows.add({'productId': item.productId, 'qty': item.qty});
    }
    return rows;
  }

  Future<OrderItem?> checkout({
    PaymentMethodItem? paymentMethod,
    String? deliveryAddressOverride,
  }) async {
    final uid = _uid;
    if (uid == null || _cart.isEmpty) return null;

    final items = _copyCartItems();
    if (items.isEmpty) return null;

    final now = DateTime.now();
    // Create order id first so we can store a stable reference.
    final ref = _userDoc(uid).collection('orders').doc();
    final profileSnap = await _userDoc(uid).get();
    final profile = profileSnap.data() ?? const <String, dynamic>{};
    final overrideAddress = (deliveryAddressOverride ?? '').trim();
    final deliveryAddress =
        overrideAddress.isNotEmpty
            ? overrideAddress
            : (profile['address'] ?? profile['location'] ?? '')
                .toString()
                .trim();
    final customerPhone = (profile['phone'] ?? '').toString().trim();
    final customerName =
        (profile['name'] ?? profile['fullName'] ?? '').toString().trim();
    final profilePostcode = (profile['postcode'] ?? '').toString().trim();
    // Snapshot values now to avoid UI changes during async write.
    final voucher = appliedVoucher;
    final subtotal = _subtotalForItems(items);
    final discount =
        (() {
          if (voucher == null) return 0.0;
          if (subtotal <= 0 || subtotal < voucher.minSpend) return 0.0;
          final percent = voucher.percent.clamp(0, 100).toDouble();
          return subtotal * (percent / 100);
        })();
    final deliveryDistanceKm = estimateDeliveryDistanceKm(
      deliveryAddress: deliveryAddress,
      fallbackPostcode: profilePostcode,
    );
    final deliveryFee = estimateDeliveryFee(
      deliveryAddress: deliveryAddress,
      fallbackPostcode: profilePostcode,
    );
    final finalTotal =
        (subtotal - discount + deliveryFee) <= 0
            ? 0.0
            : (subtotal - discount + deliveryFee);

    final order = OrderItem(
      id: ref.id,
      createdAt: now,
      items: items,
      total: finalTotal,
      status: 'To Ship',
      subtotal: subtotal,
      discount: discount,
      customerName: customerName,
      customerPhone: customerPhone,
      deliveryAddress: deliveryAddress,
      deliveryDistanceKm: deliveryDistanceKm,
      deliveryFee: deliveryFee,
      paymentType: paymentMethod?.type ?? '',
      paymentLast4: paymentMethod?.last4 ?? '',
      voucherCode: voucher?.code ?? '',
    );

    // Validate stock first (read-only). Product writes are admin-only by rules.
    for (final item in items) {
      final productRef = _db.collection('products').doc(item.productId);
      final productSnap = await productRef.get();
      if (!productSnap.exists) {
        throw StateError('Product not found: ${item.productId}');
      }
      final data = productSnap.data() ?? const <String, dynamic>{};
      final productName = (data['name'] ?? item.productId).toString();
      final available = _asInt(data['quantity'], fallback: 0);
      if (available <= 0) {
        throw StateError('$productName is out of stock.');
      }
      if (available < item.qty) {
        throw StateError(
          '$productName has only $available item(s) left in stock.',
        );
      }
    }

    final batch = _db.batch();

    batch.set(ref, {
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'userId': uid,
      'customerName': customerName,
      'customerPhone': customerPhone,
      'address': deliveryAddress,
      'deliveryAddress': deliveryAddress,
      'deliveryDistanceKm': deliveryDistanceKm,
      'deliveryFee': deliveryFee,
      // Main user/admin status and delivery status are tracked separately.
      'status': order.status,
      'total': order.total,
      'subtotal': subtotal,
      'discount': discount,
      'voucherId': voucher?.id,
      'voucherCode': voucher?.code,
      'voucherPercent': voucher?.percent,
      'paymentMethodId': paymentMethod?.id,
      'paymentType': paymentMethod?.type,
      'paymentLast4': paymentMethod?.last4,
      'items': _orderItemsToMap(order.items),
    });

    for (final item in items) {
      final cartRef = _userDoc(uid).collection('cart').doc(item.productId);
      batch.delete(cartRef);
    }

    if (voucher != null) {
      final voucherRef = _userDoc(uid).collection('vouchers').doc(voucher.id);
      batch.delete(voucherRef);
    }

    await batch.commit();

    _appliedVoucherId = null;
    await _log('Created order ${order.id}');
    return order;
  }

  Future<void> updateOrderStatus(String orderId, String status) async {
    final uid = _uid;
    if (uid == null) return;

    await _userDoc(uid).collection('orders').doc(orderId).set({
      'status': status,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    await _log('Order $orderId -> $status');
  }

  List<OrderItem> ordersByStatus(String status) {
    final result = <OrderItem>[];
    for (final order in _orders) {
      if (order.status == status) {
        result.add(order);
      }
    }
    return result;
  }

  int get earnedPoints {
    double totalSpend = 0;
    for (final order in _orders) {
      totalSpend += order.total;
    }
    return totalSpend.floor();
  }

  int get pointsBalance {
    final remaining = earnedPoints - _pointsSpent;
    return remaining > 0 ? remaining : 0;
  }

  int get totalPoints => pointsBalance;

  String get tier {
    final pts = earnedPoints;
    if (pts >= 1200) return 'Platinum';
    if (pts >= 600) return 'Gold';
    if (pts >= 250) return 'Silver';
    return 'Bronze';
  }

  Future<String> redeemPointsForVoucher(TierVoucherReward reward) async {
    if (_isGuestUser) return 'Please login to redeem points.';
    final uid = _uid;
    if (uid == null) return 'Please login to redeem points.';

    if (reward.pointsCost <= 0) return 'Invalid points cost.';
    if (reward.percent <= 0 || reward.percent > 100) {
      return 'Invalid voucher percent.';
    }
    if (reward.minSpend < 0) return 'Invalid minimum spend.';

    if (pointsBalance < reward.pointsCost) {
      return 'Not enough points. Need ${reward.pointsCost} points.';
    }

    final userRef = _userDoc(uid);
    final voucherRef = userRef.collection('vouchers').doc();
    final codeSuffix = DateTime.now().millisecondsSinceEpoch
        .toString()
        .substring(7);
    final code = 'TIER${reward.percent}-$codeSuffix';

    try {
      await _db.runTransaction((txn) async {
        final userSnap = await txn.get(userRef);
        final data = userSnap.data() ?? const <String, dynamic>{};
        final spent = _asInt(data['pointsSpent'], fallback: 0);
        final available = earnedPoints - spent;
        if (available < reward.pointsCost) {
          throw StateError('Not enough points');
        }

        txn.set(userRef, {
          'pointsSpent': spent + reward.pointsCost,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        txn.set(voucherRef, {
          'store': reward.store,
          'percent': reward.percent,
          'minSpend': reward.minSpend,
          'code': code,
          'title': reward.title,
          'description': '${reward.percent}% off (Points Redeem)',
          'source': 'tier_points',
          'pointsCost': reward.pointsCost,
          'updatedAt': FieldValue.serverTimestamp(),
          'claimedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      });

      await _log(
        'Redeemed ${reward.pointsCost} points for voucher $code (${reward.percent}% off)',
      );
      return 'Redeemed successfully: $code';
    } on StateError {
      return 'Not enough points.';
    } on FirebaseException catch (e) {
      return 'Redeem failed: ${e.message ?? e.code}';
    } catch (_) {
      return 'Redeem failed. Please try again.';
    }
  }

  Future<VoiceCommandResult> handleVoiceCommand(String rawCommand) async {
    // Normalize input once to make matching consistent.
    final cmd = rawCommand.trim().toLowerCase();
    if (cmd.isEmpty) {
      return const VoiceCommandResult(
        handled: false,
        message: 'Please say a command.',
      );
    }

    if (cmd.contains('show vegetable') || cmd.contains('show vegetables')) {
      return const VoiceCommandResult(
        handled: true,
        message: 'Showing vegetables category.',
        categoryFilter: 'Fresh Food',
      );
    }

    if (cmd.startsWith('show ')) {
      // Generic "show ..." maps to search text.
      final text = cmd.replaceFirst('show ', '').trim();
      if (text.isNotEmpty) {
        return VoiceCommandResult(
          handled: true,
          message: 'Showing results for "$text".',
          searchText: text,
        );
      }
    }

    if (cmd.startsWith('search ')) {
      final text = cmd.replaceFirst('search ', '').trim();
      if (text.isNotEmpty) {
        return VoiceCommandResult(
          handled: true,
          message: 'Searching "$text".',
          searchText: text,
        );
      }
    }

    if (cmd == 'checkout') {
      return VoiceCommandResult(
        handled: true,
        message:
            cart.isEmpty
                ? 'Cart is empty, cannot checkout yet.'
                : 'Opening checkout.',
        route: cart.isEmpty ? null : '/cart',
      );
    }

    if (cmd == 'open cart' || cmd == 'show cart') {
      return const VoiceCommandResult(
        handled: true,
        message: 'Opening cart.',
        route: '/cart',
      );
    }

    if (cmd == 'show likes' || cmd == 'open likes') {
      return const VoiceCommandResult(
        handled: true,
        message: 'Opening likes.',
        route: '/likes',
      );
    }

    if (cmd == 'show vouchers' || cmd == 'open vouchers') {
      return const VoiceCommandResult(
        handled: true,
        message: 'Opening vouchers.',
        route: '/wallet-voucher-discount',
      );
    }

    if (cmd == 'open account') {
      return const VoiceCommandResult(
        handled: true,
        message: 'Opening account.',
        route: '/account',
      );
    }

    if (cmd == 'open price tracker' || cmd == 'show price tracker') {
      return const VoiceCommandResult(
        handled: true,
        message: 'Opening price tracker.',
        route: '/price-tracker',
      );
    }

    if (cmd == 'open help center') {
      return const VoiceCommandResult(
        handled: true,
        message: 'Opening help center.',
        route: '/help-center',
      );
    }

    if (cmd == 'open recently viewed') {
      return const VoiceCommandResult(
        handled: true,
        message: 'Opening recently viewed.',
        route: '/recently-viewed',
      );
    }

    if (cmd == 'open search history') {
      return const VoiceCommandResult(
        handled: true,
        message: 'Opening search history.',
        route: '/search-history',
      );
    }

    if (cmd == 'open notifications') {
      return const VoiceCommandResult(
        handled: true,
        message: 'Opening notifications.',
        route: '/notifications',
      );
    }

    if (cmd.startsWith('add to cart')) {
      if (_isGuestUser) {
        return const VoiceCommandResult(
          handled: true,
          message: 'Please login to add items to cart.',
        );
      }
      // Support both "add to cart broccoli" and plain "add to cart".
      final productText = cmd.replaceFirst('add to cart', '').trim();
      ProductItem? p;

      if (productText.isNotEmpty) {
        // Find first partial-name match.
        for (final item in _products) {
          if (item.name.toLowerCase().contains(productText)) {
            p = item;
            break;
          }
        }
      } else if (_recentlyViewed.isNotEmpty) {
        // If product name not spoken, fallback to most recently viewed product.
        p = productById(_recentlyViewed.first);
      }

      if (p == null) {
        return const VoiceCommandResult(
          handled: true,
          message: 'No product found for add to cart command.',
        );
      }

      final ok = await addToCart(p.id);
      if (!ok) {
        return VoiceCommandResult(
          handled: true,
          message: '${p.name} is out of stock.',
          product: p,
        );
      }
      return VoiceCommandResult(
        handled: true,
        message: '${p.name} added to cart.',
        product: p,
      );
    }

    ProductItem? exact;
    for (final item in _products) {
      if (item.name.toLowerCase() == cmd) {
        exact = item;
        break;
      }
    }
    if (exact != null) {
      return VoiceCommandResult(
        handled: true,
        message: 'Opening ${exact.name}.',
        product: exact,
      );
    }

    return const VoiceCommandResult(
      handled: false,
      message:
          'Command not recognized. Try: show vegetables, broccoli, add to cart, checkout.',
    );
  }

  Future<void> _log(String message) async {
    final uid = _uid;
    if (uid == null) return;

    await _userDoc(uid).collection('activities').add({
      'message': message,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  void _schedulePriceDropCheck() {
    // Simple lock+queue: do not run multiple checks at the same time.
    if (_priceDropCheckRunning) {
      _priceDropCheckQueued = true;
      return;
    }
    _checkPriceDropNotifications();
  }

  String _priceDropNotificationId(String productId, double price) {
    final cents = (price * 100).round();
    return 'price_drop_${productId}_$cents';
  }

  Future<void> _checkPriceDropNotifications() async {
    final uid = _uid;
    if (uid == null) return;
    if (_isGuestUser) return;

    _priceDropCheckRunning = true;

    try {
      // For each tracked product, notify only when current price hits target.
      for (final t in _trackedItems) {
        final product = productById(t.productId);
        if (product == null || product.lowestPrice <= 0) continue;

        final target = t.targetPrice;
        if (target == null || target <= 0) continue;

        if (product.lowestPrice <= target) {
          // Skip duplicate notification when same notified price already saved.
          final already = t.lastNotifiedPrice;
          if (already != null &&
              (already - product.lowestPrice).abs() < 0.0001) {
            continue;
          }

          final notificationId = _priceDropNotificationId(
            product.id,
            product.lowestPrice,
          );
          // Deterministic doc id keeps alert idempotent for same product+price.
          await _userDoc(
            uid,
          ).collection('notifications').doc(notificationId).set({
            'type': 'price_drop',
            'productId': product.id,
            'title': 'Price Drop Alert',
            'message':
                '${product.name} is now RM ${product.lowestPrice.toStringAsFixed(2)} (target RM ${target.toStringAsFixed(2)})',
            'createdAt': FieldValue.serverTimestamp(),
            'read': false,
          }, SetOptions(merge: true));

          // Persist last notified price to avoid repeated same-price alerts.
          await _userDoc(
            uid,
          ).collection('tracked_products').doc(product.id).set({
            'lastNotifiedPrice': product.lowestPrice,
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
        }
      }
    } finally {
      _priceDropCheckRunning = false;
      if (_priceDropCheckQueued) {
        _priceDropCheckQueued = false;
        _schedulePriceDropCheck();
      }
    }
  }

  Future<void> disposeStore() async {
    _catalogRetryTimer?.cancel();
    await _productsSub?.cancel();
    await _pricesSub?.cancel();
    await _authSub?.cancel();
    await _likesSub?.cancel();
    await _recentSub?.cancel();
    await _trackedSub?.cancel();
    await _cartSub?.cancel();
    await _ordersSub?.cancel();
    await _paymentsSub?.cancel();
    await _vouchersSub?.cancel();
    await _activitiesSub?.cancel();
    await _profileSub?.cancel();
  }
}
