// How this file works:
// 1) Data/models are declared first (if any).
// 2) UI widgets are built in build() methods.
// 3) Helper methods are used to keep UI code clean.
//
// File purpose: This file handles firestore service screen/logic.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

// This class defines FirestoreService, used for this page/feature.
class FirestoreService {
  final _db = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  static const double _defaultDeliveryFee = 5.0;

  DateTime? _adminOrdersCacheAt;
  List<QueryDocumentSnapshot<Map<String, dynamic>>>? _adminOrdersCache;

  DateTime? _salesSummaryCacheAt;
  Map<String, dynamic>? _salesSummaryCache;

  User? get _currentUser => _auth.currentUser;
  String get uid => _auth.currentUser!.uid;

  DocumentReference<Map<String, dynamic>> _userDoc(String userId) {
    return _db.collection('users').doc(userId);
  }

  String _orderKeyFromPath(String orderPath) {
    return orderPath.replaceAll('/', '_');
  }

  double _asDouble(Object? value, {double fallback = 0.0}) {
    if (value is num) return value.toDouble();
    return fallback;
  }

  String _asText(Object? value, {String fallback = ''}) {
    if (value == null) return fallback;
    final text = value.toString();
    if (text.trim().isEmpty) return fallback;
    return text;
  }

  Future<bool> _safeDocExists(
      DocumentReference<Map<String, dynamic>> ref,
      ) async {
    try {
      final snap = await ref.get();
      return snap.exists;
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') return false;
      rethrow;
    }
  }

  Future<String> currentRole() async {
    final user = _currentUser;
    if (user == null) return 'guest';
    if (user.isAnonymous) return 'guest';

    final isAdmin = await _safeDocExists(
      _db.collection('admins').doc(user.uid),
    );
    if (isAdmin) return 'admin';

    final isDelivery = await _safeDocExists(
      _db.collection('delivery_staff').doc(user.uid),
    );
    if (isDelivery) return 'delivery';

    try {
      final userDoc = await _db.collection('users').doc(user.uid).get();
      final data = userDoc.data() ?? const {};
      if ((data['role'] ?? '').toString().toLowerCase() == 'delivery' ||
          data['isDelivery'] == true) {
        return 'delivery';
      }
    } on FirebaseException catch (_) {}

    return 'user';
  }

  Future<bool> isAdmin() async {
    final doc = await _db.collection('admins').doc(uid).get();
    return doc.exists;
  }

  Future<void> adminSignInEmail(String email, String password) async {
    await _auth.signInWithEmailAndPassword(email: email, password: password);
  }

  Future<void> signOut() async {
    await _auth.signOut();
  }

  String _safeToken(String input, {String fallback = 'file'}) {
    final raw = input.trim().toLowerCase();
    if (raw.isEmpty) return fallback;
    final cleaned = raw.replaceAll(RegExp(r'[^a-z0-9_-]'), '_');
    final squashed = cleaned.replaceAll(RegExp(r'_+'), '_');
    return squashed.isEmpty ? fallback : squashed;
  }

  String _fileExtFrom(XFile file) {
    final name = file.name.trim();
    final dot = name.lastIndexOf('.');
    if (dot > -1 && dot < name.length - 1) {
      final ext = name.substring(dot + 1).toLowerCase();
      if (RegExp(r'^[a-z0-9]+$').hasMatch(ext)) return ext;
    }
    return 'jpg';
  }

  String _contentTypeForExt(String ext) {
    if (ext == 'png') return 'image/png';
    if (ext == 'webp') return 'image/webp';
    if (ext == 'gif') return 'image/gif';
    return 'image/jpeg';
  }

  Future<String> uploadImageXFile({
    required XFile file,
    required String folder,
    String? fileNameHint,
  }) async {
    final bytes = await file.readAsBytes();
    final ext = _fileExtFrom(file);
    final contentType = _contentTypeForExt(ext);
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final safeFolder = _safeToken(folder, fallback: 'uploads');
    final safeName = _safeToken(fileNameHint ?? 'image');

    final ref = FirebaseStorage.instance
        .ref()
        .child('$safeFolder/${safeName}_$timestamp.$ext');

    await ref.putData(
      bytes,
      SettableMetadata(contentType: contentType),
    );
    return ref.getDownloadURL();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> storesStream() {
    return _db.collection('stores').orderBy('name').snapshots();
  }

  Future<void> upsertStore({
    String? storeId,
    required String name,
    required bool enabled,
  }) async {
    final trimmedId = (storeId ?? '').trim();
    final ref = trimmedId.isEmpty
        ? _db.collection('stores').doc()
        : _db.collection('stores').doc(trimmedId);

    await ref.set({
      'name': name,
      'enabled': enabled,
      'updatedAt': FieldValue.serverTimestamp(),
      if (trimmedId.isEmpty) 'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> deleteStore(String storeId) async {
    await _db.collection('stores').doc(storeId).delete();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> promosStream({String? storeId}) {
    Query<Map<String, dynamic>> q = _db
        .collection('store_promotions')
        .orderBy('endAt', descending: false);

    if (storeId != null && storeId != 'all') {
      q = q.where('storeId', isEqualTo: storeId);
    }
    return q.snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> publicPromosStream() {
    return _db
        .collection('store_promotions')
        .orderBy('endAt', descending: false)
        .snapshots();
  }

  int _extractPercent(Map<String, dynamic> data) {
    final p = data['percent'];
    if (p is num && p > 0) return p.toInt();

    final text = '${data['title'] ?? ''} ${data['description'] ?? ''}';
    final m = RegExp(r'(\d{1,2})\s*%').firstMatch(text);
    if (m != null) {
      final parsed = int.tryParse(m.group(1)!);
      if (parsed != null && parsed > 0) return parsed;
    }
    return 10;
  }

  double _extractMinSpend(Map<String, dynamic> data) {
    final m = data['minSpend'];
    if (m is num && m >= 0) return m.toDouble();

    final text =
    '${data['title'] ?? ''} ${data['description'] ?? ''}'.toLowerCase();
    final match = RegExp(
      r'(?:min(?:imum)?\s*spend|min)\s*(?:rm)?\s*([0-9]+(?:\.[0-9]+)?)',
    ).firstMatch(text);

    if (match == null) return 0;
    return double.tryParse(match.group(1) ?? '') ?? 0;
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> claimedPromosStream() {
    return _userDoc(uid).collection('claimed_promotions').snapshots();
  }

  Future<bool> claimPromoAsVoucher({
    required String promoId,
    required Map<String, dynamic> promoData,
  }) async {
    final user = _currentUser;
    if (user == null || user.isAnonymous) return false;

    final claimedRef = _db
        .collection('users')
        .doc(user.uid)
        .collection('claimed_promotions')
        .doc(promoId);

    final claimedSnap = await claimedRef.get();
    if (claimedSnap.exists) return false;

    final storeName = (promoData['storeName'] ?? '').toString().trim();
    final code = (promoData['code'] ?? '').toString().trim();
    final percent = _extractPercent(promoData);
    final minSpend = _extractMinSpend(promoData);

    await _db
        .collection('users')
        .doc(user.uid)
        .collection('vouchers')
        .doc(promoId)
        .set({
      'store': storeName,
      'percent': percent,
      'minSpend': minSpend,
      'code': code,
      'promoId': promoId,
      'title': (promoData['title'] ?? '').toString(),
      'description': (promoData['description'] ?? '').toString(),
      'updatedAt': FieldValue.serverTimestamp(),
      'claimedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    await claimedRef.set({
      'promoId': promoId,
      'title': (promoData['title'] ?? '').toString(),
      'code': code,
      'claimedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    return true;
  }

  Future<void> addOrUpdatePromo({
    String? promoId,
    required String storeId,
    required String storeName,
    required String title,
    required String description,
    String? code,
    required DateTime endAt,
    bool isActive = true,
  }) async {
    final data = {
      'storeId': storeId,
      'storeName': storeName,
      'title': title,
      'description': description,
      'code': (code ?? '').trim(),
      'isActive': isActive,
      'endAt': Timestamp.fromDate(endAt),
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if (promoId == null) {
      await _db.collection('store_promotions').add({
        ...data,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } else {
      await _db.collection('store_promotions').doc(promoId).update(data);
    }
  }

  Future<void> deletePromo(String promoId) async {
    await _db.collection('store_promotions').doc(promoId).delete();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> productsStream({
    required String search,
  }) {
    final s = search.trim().toLowerCase();

    if (s.isEmpty) {
      return _db
          .collection('products')
          .orderBy('nameLower')
          .limit(100)
          .snapshots();
    }

    return _db
        .collection('products')
        .orderBy('nameLower')
        .startAt([s])
        .endAt(['$s\uf8ff'])
        .limit(100)
        .snapshots();
  }

  Future<void> upsertProduct({
    String? productId,
    required String name,
    required String unit,
    required String category,
    required int quantity,
    String? description,
    String? imageUrl,
  }) async {
    final trimmedId = (productId ?? '').trim();
    final ref = trimmedId.isEmpty
        ? _db.collection('products').doc()
        : _db.collection('products').doc(trimmedId);

    await ref.set({
      'name': name,
      'nameLower': name.toLowerCase(),
      'unit': unit,
      'category': category,
      'quantity': quantity,
      'description': (description ?? '').trim(),
      'imageUrl': (imageUrl ?? '').trim(),
      'updatedAt': FieldValue.serverTimestamp(),
      if (trimmedId.isEmpty) 'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> deleteProduct(String productId) async {
    await _db.collection('products').doc(productId).delete();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> pricesStream(String productId) {
    return _db
        .collection('products')
        .doc(productId)
        .collection('prices')
        .snapshots();
  }

  Future<void> upsertPrice({
    required String productId,
    required String storeId,
    required String storeName,
    required double price,
    double? promoPrice,
  }) async {
    await _db
        .collection('products')
        .doc(productId)
        .collection('prices')
        .doc(storeId)
        .set({
      'storeId': storeId,
      'storeName': storeName,
      'price': price,
      'promoPrice': promoPrice,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> deletePrice({
    required String productId,
    required String storeId,
  }) async {
    await _db
        .collection('products')
        .doc(productId)
        .collection('prices')
        .doc(storeId)
        .delete();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> usersStream() {
    return _db.collection('users').orderBy('email').snapshots();
  }

  Future<void> deleteUserDoc(String userId) async {
    await _db.collection('users').doc(userId).delete();
  }

  Future<void> setDeliveryStaff({
    required String userId,
    required String email,
    required bool enabled,
  }) async {
    final ref = _db.collection('delivery_staff').doc(userId);
    final userRef = _db.collection('users').doc(userId);
    final batch = _db.batch();

    if (!enabled) {
      batch.delete(ref);
      batch.set(userRef, {
        'role': 'user',
        'isDelivery': false,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      await batch.commit();
      return;
    }

    batch.set(ref, {
      'email': email,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    batch.set(userRef, {
      'role': 'delivery',
      'isDelivery': true,
      'deliveryOnDuty': true,
      'deliveryDutyUpdatedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    await batch.commit();
  }

  Future<void> setDeliveryOnDuty({
    required String userId,
    required bool onDuty,
  }) async {
    final userRef = _db.collection('users').doc(userId);
    final dutyData = {
      'deliveryOnDuty': onDuty,
      'deliveryDutyUpdatedAt': FieldValue.serverTimestamp(),
      if (!onDuty) 'deliveryOffAt': FieldValue.serverTimestamp(),
      if (onDuty) 'deliveryOnAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };

    await userRef.set(dutyData, SetOptions(merge: true));
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> deliveryStaffStream() {
    return _db.collection('delivery_staff').snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> reviewsStream() {
    return _db
        .collection('product_reviews')
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  Future<void> upsertReview({
    String? reviewId,
    required String productId,
    required String productName,
    required int rating,
    required String comment,
  }) async {
    final user = _currentUser;
    if (user == null || user.isAnonymous) return;

    final data = {
      'productId': productId,
      'productName': productName,
      'userId': user.uid,
      'userEmail': user.email ?? '',
      'rating': rating,
      'comment': comment.trim(),
      'status': 'published',
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if (reviewId == null) {
      await _db.collection('product_reviews').add({
        ...data,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } else {
      await _db
          .collection('product_reviews')
          .doc(reviewId)
          .set(data, SetOptions(merge: true));
    }
  }

  Future<void> updateReviewStatus({
    required String reviewId,
    required String status,
  }) async {
    await _db.collection('product_reviews').doc(reviewId).set({
      'status': status,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> deleteReview(String reviewId) async {
    await _db.collection('product_reviews').doc(reviewId).delete();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> eventsStream() {
    return _db
        .collection('events')
        .orderBy('updatedAt', descending: true)
        .snapshots();
  }

  Future<void> upsertEvent({
    String? eventId,
    required String title,
    required String message,
    String? imageUrl,
    bool active = true,
  }) async {
    final data = {
      'title': title.trim(),
      'message': message.trim(),
      'imageUrl': (imageUrl ?? '').trim(),
      'active': active,
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if (eventId == null) {
      await _db.collection('events').add({
        ...data,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } else {
      await _db
          .collection('events')
          .doc(eventId)
          .set(data, SetOptions(merge: true));
    }
  }

  Future<void> deleteEvent(String eventId) async {
    await _db.collection('events').doc(eventId).delete();
  }

  // IMPORTANT:
  // Do not order collectionGroup('orders') by createdAt descending here,
  // because that requires a special Firestore composite index.
  // This safer stream avoids the sudden crash.
  Stream<QuerySnapshot<Map<String, dynamic>>> ordersAllStream() {
    return _db.collectionGroup('orders').snapshots();
  }

  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>> _loadOrdersByUsers({
    int perUserLimit = 50,
    int maxUsers = 200,
    int batchSize = 12,
  }) async {
    final users = await _db.collection('users').limit(maxUsers).get();
    final result = <QueryDocumentSnapshot<Map<String, dynamic>>>[];

    for (int i = 0; i < users.docs.length; i += batchSize) {
      final end =
      (i + batchSize > users.docs.length)
          ? users.docs.length
          : i + batchSize;
      final batch = users.docs.sublist(i, end);

      for (final userDoc in batch) {
        final snap = await userDoc.reference
            .collection('orders')
            .orderBy('createdAt', descending: true)
            .limit(perUserLimit)
            .get();

        result.addAll(snap.docs);
      }
    }

    DateTime asDate(Object? v) {
      if (v is Timestamp) return v.toDate();
      return DateTime.fromMillisecondsSinceEpoch(0);
    }

    result.sort((a, b) {
      final ad = asDate(a.data()['createdAt']);
      final bd = asDate(b.data()['createdAt']);
      return bd.compareTo(ad);
    });

    return result;
  }

  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>> ordersAllForAdmin({
    bool forceRefresh = false,
  }) async {
    final now = DateTime.now();
    final cached = _adminOrdersCache;
    final cacheAt = _adminOrdersCacheAt;

    if (!forceRefresh &&
        cached != null &&
        cacheAt != null &&
        now.difference(cacheAt).inSeconds < 20) {
      return cached;
    }

    final loaded = await _loadOrdersByUsers();
    _adminOrdersCache = loaded;
    _adminOrdersCacheAt = now;
    return loaded;
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> myAssignedDeliveriesStream() {
    return _db
        .collection('delivery_staff')
        .doc(uid)
        .collection('assigned_orders')
        .snapshots();
  }

  Future<void> updateOrderByPath({
    required String orderPath,
    required Map<String, dynamic> data,
  }) async {
    final orderRef = _db.doc(orderPath);
    final snap = await orderRef.get();
    final existing = snap.data() ?? const <String, dynamic>{};

    final batch = _db.batch();
    batch.set(orderRef, {
      ...data,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    final deliveryUid =
    (data['deliveryUid'] ?? existing['deliveryUid'] ?? '').toString();

    if (deliveryUid.isNotEmpty) {
      final deliveryEmail =
      _asText(data['deliveryEmail'] ?? existing['deliveryEmail']);
      final deliveryStatus = _asText(
        data['deliveryStatus'] ?? existing['deliveryStatus'],
        fallback: 'Assigned',
      );
      final status = _asText(data['status'] ?? existing['status']);
      final total = _asDouble(existing['total']);
      final deliveryFee = _asDouble(
        data['deliveryFee'],
        fallback: _asDouble(
          existing['deliveryFee'],
          fallback: _defaultDeliveryFee,
        ),
      );
      final address =
      _asText(existing['deliveryAddress'] ?? existing['address']);
      final customerPhone = _asText(existing['customerPhone']);

      final assignedRef = _db
          .collection('delivery_staff')
          .doc(deliveryUid)
          .collection('assigned_orders')
          .doc(_orderKeyFromPath(orderPath));

      batch.set(assignedRef, {
        'orderPath': orderPath,
        'deliveryUid': deliveryUid,
        'deliveryEmail': deliveryEmail,
        'deliveryStatus': deliveryStatus,
        'status': status,
        'total': total,
        'deliveryFee': deliveryFee,
        'deliveryAddress': address,
        'customerPhone': customerPhone,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }

    try {
      await batch.commit();
    } on FirebaseException catch (e) {
      if (e.code != 'permission-denied') rethrow;

      await orderRef.set({
        ...data,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }
  }

  Future<void> assignDelivery({
    required String orderPath,
    required String deliveryUid,
    required String deliveryEmail,
  }) async {
    final orderRef = _db.doc(orderPath);
    final orderSnap = await orderRef.get();
    final oldDeliveryUid = _asText(orderSnap.data()?['deliveryUid']);

    final existingFee = _asDouble(
      orderSnap.data()?['deliveryFee'],
      fallback: _defaultDeliveryFee,
    );

    final batch = _db.batch();
    batch.set(orderRef, {
      'deliveryUid': deliveryUid,
      'deliveryEmail': deliveryEmail,
      'deliveryStatus': 'Assigned',
      'status': 'To Ship',
      'deliveryFee': existingFee,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    final assignedRef = _db
        .collection('delivery_staff')
        .doc(deliveryUid)
        .collection('assigned_orders')
        .doc(_orderKeyFromPath(orderPath));

    final total = _asDouble(orderSnap.data()?['total']);
    final status = 'To Ship';
    final deliveryStatus = _asText(
      orderSnap.data()?['deliveryStatus'],
      fallback: 'Assigned',
    );
    final address = _asText(
      orderSnap.data()?['deliveryAddress'] ?? orderSnap.data()?['address'],
    );
    final customerPhone = _asText(orderSnap.data()?['customerPhone']);

    batch.set(assignedRef, {
      'orderPath': orderPath,
      'deliveryUid': deliveryUid,
      'deliveryEmail': deliveryEmail,
      'deliveryStatus': deliveryStatus,
      'status': status,
      'total': total,
      'deliveryFee': existingFee,
      'deliveryAddress': address,
      'customerPhone': customerPhone,
      'updatedAt': FieldValue.serverTimestamp(),
      'assignedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    if (oldDeliveryUid.isNotEmpty && oldDeliveryUid != deliveryUid) {
      final oldAssignedRef = _db
          .collection('delivery_staff')
          .doc(oldDeliveryUid)
          .collection('assigned_orders')
          .doc(_orderKeyFromPath(orderPath));
      batch.delete(oldAssignedRef);
    }

    await batch.commit();
  }

  Future<Map<String, dynamic>> salesSummary({bool forceRefresh = false}) async {
    final now = DateTime.now();

    if (!forceRefresh &&
        _salesSummaryCache != null &&
        _salesSummaryCacheAt != null &&
        now.difference(_salesSummaryCacheAt!).inSeconds < 20) {
      return _salesSummaryCache!;
    }

    QuerySnapshot<Map<String, dynamic>> snap;
    try {
      snap = await _db.collectionGroup('orders').get();
    } on FirebaseException catch (e) {
      if (e.code != 'permission-denied') rethrow;

      final docs = await _loadOrdersByUsers(perUserLimit: 200, maxUsers: 400);

      double totalRevenue = 0;
      int totalOrders = 0;
      final categoryCount = <String, int>{};

      for (final doc in docs) {
        final data = doc.data();
        totalOrders += 1;

        final total = data['total'];
        if (total is num) totalRevenue += total.toDouble();

        final items = (data['items'] as List?) ?? const [];
        for (final item in items) {
          if (item is! Map) continue;
          final category = (item['category'] ?? 'Unknown').toString();
          categoryCount[category] = (categoryCount[category] ?? 0) + 1;
        }
      }

      final out = {
        'totalRevenue': totalRevenue,
        'totalOrders': totalOrders,
        'categoryCount': categoryCount,
      };

      _salesSummaryCache = out;
      _salesSummaryCacheAt = now;
      return out;
    }

    double totalRevenue = 0;
    int totalOrders = 0;
    final categoryCount = <String, int>{};

    for (final doc in snap.docs) {
      final data = doc.data();
      totalOrders += 1;

      final total = data['total'];
      if (total is num) totalRevenue += total.toDouble();

      final items = (data['items'] as List?) ?? const [];
      for (final item in items) {
        if (item is! Map) continue;
        final category = (item['category'] ?? 'Unknown').toString();
        categoryCount[category] = (categoryCount[category] ?? 0) + 1;
      }
    }

    final out = {
      'totalRevenue': totalRevenue,
      'totalOrders': totalOrders,
      'categoryCount': categoryCount,
    };

    _salesSummaryCache = out;
    _salesSummaryCacheAt = now;
    return out;
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> favouritesStream() {
    return _userDoc(uid)
        .collection('favourites')
        .orderBy('updatedAt', descending: true)
        .snapshots();
  }

  Future<void> addFavourite({
    required String productId,
    double? targetPrice,
    String? preferredStoreId,
    String? note,
  }) async {
    final now = FieldValue.serverTimestamp();

    await _userDoc(uid).collection('favourites').add({
      'productId': productId,
      'targetPrice': targetPrice,
      'preferredStoreId': preferredStoreId,
      'note': note ?? '',
      'createdAt': now,
      'updatedAt': now,
    });
  }

  Future<void> updateFavourite({
    required String favId,
    double? targetPrice,
    String? preferredStoreId,
    String? note,
  }) async {
    await _userDoc(uid).collection('favourites').doc(favId).update({
      'targetPrice': targetPrice,
      'preferredStoreId': preferredStoreId,
      'note': note ?? '',
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteFavourite(String favId) async {
    await _userDoc(uid).collection('favourites').doc(favId).delete();
  }

  Future<DocumentSnapshot<Map<String, dynamic>>> getProduct(String productId) {
    return _db.collection('products').doc(productId).get();
  }
}
