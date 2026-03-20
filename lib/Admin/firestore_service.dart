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

  int _asInt(Object? value, {int fallback = 0}) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) {
      final parsed = int.tryParse(value.trim());
      if (parsed != null) return parsed;
    }
    return fallback;
  }

  String _asText(Object? value, {String fallback = ''}) {
    if (value == null) return fallback;
    final text = value.toString();
    if (text.trim().isEmpty) return fallback;
    return text;
  }

  bool _isFinalOrderState({
    required String status,
    required String deliveryStatus,
  }) {
    final s = status.trim().toLowerCase();
    final d = deliveryStatus.trim().toLowerCase();
    return s == 'completed' ||
        s == 'delivered' ||
        s == 'cancelled' ||
        s == 'canceled' ||
        d == 'delivered' ||
        d == 'cancelled' ||
        d == 'canceled';
  }

  String _userIdFromOrderPath(String orderPath) {
    final parts = orderPath.split('/');
    if (parts.length >= 4 && parts[0] == 'users' && parts[2] == 'orders') {
      return parts[1];
    }
    return '';
  }

  double _round2(double value) {
    return (value * 100).roundToDouble() / 100;
  }

  void _invalidateOrderCaches() {
    _adminOrdersCache = null;
    _adminOrdersCacheAt = null;
    _salesSummaryCache = null;
    _salesSummaryCacheAt = null;
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

  Future<bool> currentUserIsGuest() async {
    final user = _currentUser;
    return user == null || user.isAnonymous;
  }

  Future<String> currentRole() async {
    final user = _currentUser;
    if (user == null || user.isAnonymous) return 'guest';

    final isSuperAdmin = await _safeDocExists(
      _db.collection('super_admins').doc(user.uid),
    );
    if (isSuperAdmin) return 'super_admin';

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

      final role = (data['role'] ?? '').toString().toLowerCase().trim();

      if (role == 'super_admin') return 'super_admin';
      if (role == 'admin') return 'admin';
      if (role == 'delivery' || data['isDelivery'] == true) {
        return 'delivery';
      }
    } on FirebaseException catch (_) {}

    return 'user';
  }

  Future<bool> isSuperAdmin() async {
    final user = _currentUser;
    if (user == null || user.isAnonymous) return false;
    return _safeDocExists(_db.collection('super_admins').doc(user.uid));
  }

  Future<bool> isAdmin() async {
    final user = _currentUser;
    if (user == null || user.isAnonymous) return false;
    final adminDocExists = await _safeDocExists(
      _db.collection('admins').doc(user.uid),
    );
    if (adminDocExists) return true;
    try {
      final userDoc = await _db.collection('users').doc(user.uid).get();
      final role =
          (userDoc.data()?['role'] ?? '').toString().trim().toLowerCase();
      return role == 'admin';
    } on FirebaseException {
      return false;
    }
  }

  Future<String> adminOrSuperAdminRole() async {
    final user = _currentUser;
    if (user == null || user.isAnonymous) return 'none';

    final isSuperAdmin = await _safeDocExists(
      _db.collection('super_admins').doc(user.uid),
    );
    if (isSuperAdmin) return 'super_admin';

    final isAdmin = await _safeDocExists(
      _db.collection('admins').doc(user.uid),
    );
    if (isAdmin) return 'admin';

    return 'none';
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

  List<String> _buildSearchKeywords({
    required String name,
    required String category,
    required String description,
    required String unit,
  }) {
    final keywords = <String>{};

    void addWords(String text) {
      final clean = text.trim().toLowerCase();
      if (clean.isEmpty) return;

      keywords.add(clean);

      final parts = clean
          .split(RegExp(r'[^a-z0-9]+'))
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty);

      for (final p in parts) {
        keywords.add(p);
      }
    }

    addWords(name);
    addWords(category);
    addWords(description);
    addWords(unit);

    return keywords.toList()..sort();
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

    final ref = FirebaseStorage.instance.ref().child(
      '$safeFolder/${safeName}_$timestamp.$ext',
    );

    await ref.putData(bytes, SettableMetadata(contentType: contentType));
    return ref.getDownloadURL();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> storesStream() {
    return _db.collection('stores').orderBy('name').snapshots();
  }

  Future<void> upsertStore({
    String? storeId,
    required String name,
    required bool enabled,
    String? location,
    String? logoUrl,
    String? adminUid,
    String? adminEmail,
    String? adminName,
    String? adminPhone,
  }) async {
    final trimmedId = (storeId ?? '').trim();
    final ref =
        trimmedId.isEmpty
            ? _db.collection('stores').doc()
            : _db.collection('stores').doc(trimmedId);

    final cleanAdminUid = (adminUid ?? '').trim();
    final cleanAdminEmail = (adminEmail ?? '').trim();
    final cleanAdminName = (adminName ?? '').trim();
    final cleanAdminPhone = (adminPhone ?? '').trim();
    final cleanLocation = (location ?? '').trim();
    final cleanLogoUrl = (logoUrl ?? '').trim();

    await ref.set({
      'name': name.trim(),
      'enabled': enabled,
      'location': cleanLocation,
      'logoUrl': cleanLogoUrl,
      'adminUid': cleanAdminUid,
      'adminEmail': cleanAdminEmail,
      'adminName': cleanAdminName,
      'adminPhone': cleanAdminPhone,
      'updatedAt': FieldValue.serverTimestamp(),
      if (trimmedId.isEmpty) 'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> upsertStoreWithAdmin({
    String? storeId,
    required String name,
    required bool enabled,
    String? location,
    String? logoUrl,
    String? adminUid,
    String? adminEmail,
    String? adminName,
    String? adminPhone,
  }) async {
    final trimmedId = (storeId ?? '').trim();
    final ref =
        trimmedId.isEmpty
            ? _db.collection('stores').doc()
            : _db.collection('stores').doc(trimmedId);

    final cleanLocation = (location ?? '').trim();
    final cleanLogoUrl = (logoUrl ?? '').trim();
    final cleanAdminPhone = (adminPhone ?? '').trim();

    await ref.set({
      'name': name.trim(),
      'enabled': enabled,
      'location': cleanLocation,
      'logoUrl': cleanLogoUrl,
      'adminUid': (adminUid ?? '').trim(),
      'adminEmail': (adminEmail ?? '').trim(),
      'adminName': (adminName ?? '').trim(),
      'adminPhone': cleanAdminPhone,
      'updatedAt': FieldValue.serverTimestamp(),
      if (trimmedId.isEmpty) 'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> deleteStore(String storeId) async {
    await _db.collection('stores').doc(storeId).delete();
  }

  Future<Map<String, String?>> myStoreInfo() async {
    final user = _currentUser;
    if (user == null || user.isAnonymous) {
      return {'storeId': null, 'storeName': null};
    }

    try {
      final adminDoc = await _db.collection('admins').doc(user.uid).get();
      final adminData = adminDoc.data() ?? const <String, dynamic>{};

      final adminStoreId = (adminData['storeId'] ?? '').toString().trim();
      final adminStoreName = (adminData['storeName'] ?? '').toString().trim();
      if (adminStoreId.isNotEmpty || adminStoreName.isNotEmpty) {
        return {
          'storeId': adminStoreId.isEmpty ? null : adminStoreId,
          'storeName': adminStoreName.isEmpty ? null : adminStoreName,
        };
      }

      final userDoc = await _db.collection('users').doc(user.uid).get();
      final userData = userDoc.data() ?? const <String, dynamic>{};

      final userStoreId = (userData['storeId'] ?? '').toString().trim();
      final userStoreName = (userData['storeName'] ?? '').toString().trim();
      if (userStoreId.isNotEmpty || userStoreName.isNotEmpty) {
        return {
          'storeId': userStoreId.isEmpty ? null : userStoreId,
          'storeName': userStoreName.isEmpty ? null : userStoreName,
        };
      }

      final byAdminUid =
          await _db
              .collection('stores')
              .where('adminUid', isEqualTo: user.uid)
              .limit(1)
              .get();
      if (byAdminUid.docs.isNotEmpty) {
        final d = byAdminUid.docs.first;
        final data = d.data();
        final storeName = (data['name'] ?? '').toString().trim();
        return {
          'storeId': d.id,
          'storeName': storeName.isEmpty ? null : storeName,
        };
      }

      return {'storeId': null, 'storeName': null};
    } on FirebaseException {
      return {'storeId': null, 'storeName': null};
    }
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> promosStream({String? storeId}) {
    if (storeId != null && storeId != 'all') {
      // Avoid composite-index dependency on where(storeId)+orderBy(endAt).
      return _db
          .collection('store_promotions')
          .where('storeId', isEqualTo: storeId)
          .snapshots();
    }
    return _db
        .collection('store_promotions')
        .orderBy('endAt', descending: false)
        .snapshots();
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
    String? storeId,
  }) {
    final s = search.trim().toLowerCase();
    final cleanStoreId = (storeId ?? '').trim();
    if (cleanStoreId.isNotEmpty && cleanStoreId != 'all') {
      // Avoid composite-index dependency on where(storeId)+orderBy(nameLower).
      return _db
          .collection('products')
          .where('storeId', isEqualTo: cleanStoreId)
          .limit(300)
          .snapshots();
    }

    final query = _db.collection('products');
    if (s.isEmpty) {
      return query.orderBy('nameLower').limit(100).snapshots();
    }
    return query
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
    String? storeId,
    String? storeName,
  }) async {
    final trimmedId = (productId ?? '').trim();
    final ref =
        trimmedId.isEmpty
            ? _db.collection('products').doc()
            : _db.collection('products').doc(trimmedId);

    final cleanName = name.trim();
    final cleanUnit = unit.trim();
    final cleanCategory = category.trim();
    final cleanDescription = (description ?? '').trim();
    final cleanImageUrl = (imageUrl ?? '').trim();

    final searchKeywords = _buildSearchKeywords(
      name: cleanName,
      category: cleanCategory,
      description: cleanDescription,
      unit: cleanUnit,
    );

    await ref.set({
      'name': cleanName,
      'nameLower': cleanName.toLowerCase(),
      'unit': cleanUnit,
      'category': cleanCategory,
      'categoryLower': cleanCategory.toLowerCase(),
      'quantity': quantity,
      'description': cleanDescription,
      'imageUrl': cleanImageUrl,
      'searchKeywords': searchKeywords,
      if ((storeId ?? '').trim().isNotEmpty) 'storeId': storeId!.trim(),
      if ((storeName ?? '').trim().isNotEmpty) 'storeName': storeName!.trim(),
      'updatedAt': FieldValue.serverTimestamp(),
      if (trimmedId.isEmpty) 'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> deleteProduct(String productId) async {
    await _db.collection('products').doc(productId).delete();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> pricesStream(
    String productId, {
    String? storeId,
  }) {
    final cleanStoreId = (storeId ?? '').trim();
    Query<Map<String, dynamic>> query = _db
        .collection('products')
        .doc(productId)
        .collection('prices');
    if (cleanStoreId.isNotEmpty && cleanStoreId != 'all') {
      query = query.where('storeId', isEqualTo: cleanStoreId);
    }
    return query.snapshots();
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

  bool _isDeliveredForReview(Map<String, dynamic> order) {
    final status = _asText(order['status']).toLowerCase().trim();
    final deliveryStatus = _asText(order['deliveryStatus']).toLowerCase().trim();

    return status == 'completed' ||
        status == 'delivered' ||
        deliveryStatus == 'delivered';
  }

  bool _orderContainsProduct({
    required Map<String, dynamic> order,
    required String productId,
  }) {
    final cleanProductId = productId.trim();
    if (cleanProductId.isEmpty) return false;

    final rawItems = order['items'];
    if (rawItems is! List) return false;

    for (final item in rawItems) {
      if (item is! Map) continue;
      final itemProductId = _asText(item['productId']).trim();
      final qty = _asInt(item['qty'], fallback: 0);
      if (itemProductId == cleanProductId && qty > 0) {
        return true;
      }
    }

    return false;
  }

  Future<bool> currentUserCanReviewProduct(String productId) async {
    final user = _currentUser;
    final cleanProductId = productId.trim();
    if (user == null || user.isAnonymous || cleanProductId.isEmpty) {
      return false;
    }

    final ordersSnap =
        await _db.collection('users').doc(user.uid).collection('orders').get();

    for (final doc in ordersSnap.docs) {
      final order = doc.data();
      if (!_isDeliveredForReview(order)) continue;
      if (_orderContainsProduct(order: order, productId: cleanProductId)) {
        return true;
      }
    }

    return false;
  }

  Future<String?> _currentUserReviewDocIdForProduct(String productId) async {
    final user = _currentUser;
    final cleanProductId = productId.trim();
    if (user == null || user.isAnonymous || cleanProductId.isEmpty) {
      return null;
    }

    final myReviewsSnap =
        await _db
            .collection('product_reviews')
            .where('userId', isEqualTo: user.uid)
            .get();

    for (final doc in myReviewsSnap.docs) {
      final data = doc.data();
      final reviewedProductId = _asText(data['productId']).trim();
      if (reviewedProductId == cleanProductId) {
        return doc.id;
      }
    }

    return null;
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
    final cleanProductId = productId.trim();
    if (cleanProductId.isEmpty) {
      throw StateError('Invalid product id for review.');
    }
    final canReview = await currentUserCanReviewProduct(productId);
    if (!canReview) {
      throw StateError(
        'Only users who purchased and received this product can submit a review.',
      );
    }

    final existingReviewId = await _currentUserReviewDocIdForProduct(
      cleanProductId,
    );
    if (reviewId == null && existingReviewId != null) {
      throw StateError('You already reviewed this product.');
    }

    final data = {
      'productId': cleanProductId,
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

  Stream<QuerySnapshot<Map<String, dynamic>>> ordersAllStream() {
    return _db.collectionGroup('orders').snapshots();
  }

  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>> _loadOrdersByUsers({
    int perUserLimit = 200,
    int maxUsers = 1200,
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
        final snap =
            await userDoc.reference
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

    List<QueryDocumentSnapshot<Map<String, dynamic>>> loaded;
    try {
      final groupSnap = await _db.collectionGroup('orders').get();
      loaded = groupSnap.docs;
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied' || e.code == 'failed-precondition') {
        loaded = await _loadOrdersByUsers(batchSize: 20);
      } else {
        rethrow;
      }
    }

    DateTime asDate(Object? v) {
      if (v is Timestamp) return v.toDate();
      return DateTime.fromMillisecondsSinceEpoch(0);
    }

    loaded.sort((a, b) {
      final ad = asDate(a.data()['createdAt']);
      final bd = asDate(b.data()['createdAt']);
      return bd.compareTo(ad);
    });

    _adminOrdersCache = loaded;
    _adminOrdersCacheAt = now;
    return loaded;
  }

  double _effectivePriceFromRow(Map<String, dynamic> row) {
    final promo = row['promoPrice'];
    if (promo is num && promo > 0) return promo.toDouble();
    final base = row['price'];
    if (base is num && base > 0) return base.toDouble();
    return 0.0;
  }

  Future<Map<String, int>> backfillLegacyOrderItems({
    int maxOrders = 0,
  }) async {
    Query<Map<String, dynamic>> query = _db.collectionGroup('orders');
    if (maxOrders > 0) {
      query = query.limit(maxOrders);
    }
    final ordersSnap = await query.get();

    final productCache = <String, Map<String, dynamic>>{};
    final priceCache = <String, Map<String, Map<String, dynamic>>>{};

    Future<Map<String, dynamic>> productData(String productId) async {
      final cached = productCache[productId];
      if (cached != null) return cached;
      try {
        final snap = await _db.collection('products').doc(productId).get();
        final data = snap.data() ?? const <String, dynamic>{};
        productCache[productId] = data;
        return data;
      } on FirebaseException {
        productCache[productId] = const <String, dynamic>{};
        return const <String, dynamic>{};
      }
    }

    Future<Map<String, Map<String, dynamic>>> priceMap(String productId) async {
      final cached = priceCache[productId];
      if (cached != null) return cached;
      final map = <String, Map<String, dynamic>>{};
      try {
        final snap =
            await _db.collection('products').doc(productId).collection('prices').get();
        for (final doc in snap.docs) {
          final sid = (doc.data()['storeId'] ?? doc.id).toString().trim();
          if (sid.isEmpty) continue;
          map[sid] = doc.data();
        }
      } on FirebaseException {
        // Ignore and leave map empty; backfill will use other fallbacks.
      }
      priceCache[productId] = map;
      return map;
    }

    int scanned = 0;
    int updated = 0;
    int failed = 0;
    int skipped = 0;
    int writesInBatch = 0;
    WriteBatch batch = _db.batch();

    Future<void> flushBatch() async {
      if (writesInBatch == 0) return;
      await batch.commit();
      batch = _db.batch();
      writesInBatch = 0;
    }

    for (final orderDoc in ordersSnap.docs) {
      scanned++;
      try {
        final order = orderDoc.data();
        final rawItems = order['items'];
        if (rawItems is! List) {
          skipped++;
          continue;
        }

        bool changed = false;
        final rebuilt = <Map<String, dynamic>>[];

        for (final rawItem in rawItems) {
          if (rawItem is! Map) continue;
          final item = Map<String, dynamic>.from(rawItem);

          final productId = _asText(item['productId']).trim();
          int qty = _asInt(item['qty'], fallback: 1);
          if (qty <= 0) qty = 1;

          String storeId = _asText(item['storeId']).trim();
          String storeName = _asText(item['storeName']).trim();
          String category = _asText(item['category']).trim();
          double unitPrice = _asDouble(item['unitPrice']);
          double lineTotal = _asDouble(item['lineTotal']);

          if (productId.isNotEmpty) {
            final product = await productData(productId);
            final prices = await priceMap(productId);

            if (storeId.isEmpty) {
              if (prices.length == 1) {
                storeId = prices.keys.first;
              } else {
                final fromProduct = _asText(product['storeId']).trim();
                if (fromProduct.isNotEmpty) {
                  storeId = fromProduct;
                }
              }
            }

            if (storeName.isEmpty && storeId.isNotEmpty) {
              final priceRow = prices[storeId];
              if (priceRow != null) {
                storeName = _asText(priceRow['storeName']).trim();
              }
            }

            if (category.isEmpty) {
              category = _asText(product['category']).trim();
            }

            if (unitPrice <= 0) {
              if (storeId.isNotEmpty && prices.containsKey(storeId)) {
                unitPrice = _effectivePriceFromRow(prices[storeId]!);
              }
              if (unitPrice <= 0 && prices.isNotEmpty) {
                var best = 0.0;
                for (final row in prices.values) {
                  final p = _effectivePriceFromRow(row);
                  if (p <= 0) continue;
                  if (best == 0 || p < best) best = p;
                }
                unitPrice = best;
              }
              if (unitPrice <= 0 && lineTotal > 0 && qty > 0) {
                unitPrice = lineTotal / qty;
              }
            }
          }

          if (lineTotal <= 0 && unitPrice > 0) {
            lineTotal = _round2(unitPrice * qty);
          }

          final patched = <String, dynamic>{
            ...item,
            'qty': qty,
            if (storeId.isNotEmpty) 'storeId': storeId,
            if (storeName.isNotEmpty) 'storeName': storeName,
            if (category.isNotEmpty) 'category': category,
            if (unitPrice > 0) 'unitPrice': _round2(unitPrice),
            if (lineTotal > 0) 'lineTotal': _round2(lineTotal),
          };

          if (_asInt(item['qty'], fallback: 1) != qty) changed = true;
          if (_asText(item['storeId']).trim() != storeId && storeId.isNotEmpty) {
            changed = true;
          }
          if (_asText(item['storeName']).trim() != storeName &&
              storeName.isNotEmpty) {
            changed = true;
          }
          if (_asText(item['category']).trim() != category && category.isNotEmpty) {
            changed = true;
          }
          if (_asDouble(item['unitPrice']) != 0 &&
              unitPrice > 0 &&
              (_asDouble(item['unitPrice']) - _round2(unitPrice)).abs() > 0.009) {
            changed = true;
          }
          if (_asDouble(item['unitPrice']) == 0 && unitPrice > 0) changed = true;
          if (_asDouble(item['lineTotal']) == 0 && lineTotal > 0) changed = true;

          rebuilt.add(patched);
        }

        if (!changed) {
          skipped++;
          continue;
        }

        batch.set(orderDoc.reference, {
          'items': rebuilt,
          'backfilledAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
        writesInBatch++;
        updated++;

        if (writesInBatch >= 300) {
          await flushBatch();
        }
      } catch (_) {
        failed++;
      }
    }

    await flushBatch();
    _invalidateOrderCaches();
    return {
      'scanned': scanned,
      'updated': updated,
      'skipped': skipped,
      'failed': failed,
    };
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
      final deliveryEmail = _asText(
        data['deliveryEmail'] ?? existing['deliveryEmail'],
      );
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
      final address = _asText(
        existing['deliveryAddress'] ?? existing['address'],
      );
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
      _invalidateOrderCaches();
    } on FirebaseException catch (e) {
      if (e.code != 'permission-denied') rethrow;

      await orderRef.set({
        ...data,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      _invalidateOrderCaches();
    }
  }

  Future<void> updateOrderStatusByPath({
    required String orderPath,
    required String status,
  }) async {
    final raw = status.trim();
    if (raw.isEmpty) return;

    final orderRef = _db.doc(orderPath);
    final snap = await orderRef.get();
    final data = snap.data() ?? const <String, dynamic>{};
    final currentStatus = _asText(data['status']);
    final currentDeliveryStatus = _asText(data['deliveryStatus']);
    if (_isFinalOrderState(
      status: currentStatus,
      deliveryStatus: currentDeliveryStatus,
    )) {
      throw StateError('Delivered orders cannot change status.');
    }

    final normalized = raw.toLowerCase();
    String nextStatus = raw;
    String? nextDeliveryStatus;

    if (normalized == 'cancelled' || normalized == 'canceled') {
      await _cancelOrderWithWalletRefund(
        orderPath: orderPath,
        cancelledBy: 'super_admin',
      );
      return;
    }

    if (normalized == 'to ship' || normalized == 'assigned') {
      nextStatus = 'To Ship';
      nextDeliveryStatus = 'Assigned';
    } else if (normalized == 'processing') {
      nextStatus = 'Processing';
      nextDeliveryStatus = 'Assigned';
    } else if (normalized == 'shipping') {
      nextStatus = 'Shipping';
      nextDeliveryStatus = 'On The Way';
    } else if (normalized == 'to receive' || normalized == 'on the way') {
      nextStatus = 'To Receive';
      nextDeliveryStatus = 'On The Way';
    } else if (normalized == 'delivered' || normalized == 'completed') {
      nextStatus = 'Completed';
      nextDeliveryStatus = 'Delivered';
    }

    final payload = <String, dynamic>{'status': nextStatus};
    if (nextDeliveryStatus != null) {
      payload['deliveryStatus'] = nextDeliveryStatus;
    }

    await updateOrderByPath(orderPath: orderPath, data: payload);
  }

  Future<void> updateDeliveryProgressByPath({
    required String orderPath,
    required String deliveryStatus,
  }) async {
    final raw = deliveryStatus.trim();
    if (raw.isEmpty) return;

    final orderRef = _db.doc(orderPath);
    final snap = await orderRef.get();
    final data = snap.data() ?? const <String, dynamic>{};
    final currentStatus = _asText(data['status']);
    final currentDeliveryStatus = _asText(data['deliveryStatus']);
    if (_isFinalOrderState(
      status: currentStatus,
      deliveryStatus: currentDeliveryStatus,
    )) {
      throw StateError('Delivered orders cannot change status.');
    }

    String nextDeliveryStatus = raw;
    String nextStatus = 'To Ship';
    final normalized = raw.toLowerCase();

    if (normalized == 'cancelled' || normalized == 'canceled') {
      await _cancelOrderWithWalletRefund(
        orderPath: orderPath,
        cancelledBy: 'delivery',
      );
      return;
    }

    if (normalized == 'on the way') {
      nextDeliveryStatus = 'On The Way';
      nextStatus = 'To Receive';
    } else if (normalized == 'delivered') {
      nextDeliveryStatus = 'Delivered';
      nextStatus = 'Completed';
    } else {
      nextDeliveryStatus = 'Assigned';
      nextStatus = 'To Ship';
    }

    await updateOrderByPath(
      orderPath: orderPath,
      data: {'deliveryStatus': nextDeliveryStatus, 'status': nextStatus},
    );
  }

  Future<void> assignDelivery({
    required String orderPath,
    required String deliveryUid,
    required String deliveryEmail,
  }) async {
    final orderRef = _db.doc(orderPath);
    final orderSnap = await orderRef.get();
    final currentStatus = _asText(orderSnap.data()?['status']);
    final currentDeliveryStatus = _asText(orderSnap.data()?['deliveryStatus']);
    if (_isFinalOrderState(
      status: currentStatus,
      deliveryStatus: currentDeliveryStatus,
    )) {
      throw StateError('Delivered orders cannot be reassigned.');
    }
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
    _invalidateOrderCaches();
  }

  Future<void> _cancelOrderWithWalletRefund({
    required String orderPath,
    required String cancelledBy,
  }) async {
    final orderRef = _db.doc(orderPath);
    final orderId = orderRef.id;

    await _db.runTransaction((txn) async {
      final orderSnap = await txn.get(orderRef);
      final data = orderSnap.data() ?? const <String, dynamic>{};
      if (data.isEmpty) {
        throw StateError('Order not found.');
      }

      final status = _asText(data['status']).toLowerCase();
      final deliveryStatus = _asText(data['deliveryStatus']).toLowerCase();
      final paymentStatus = _asText(data['paymentStatus']).toLowerCase();
      final refundStatus = _asText(data['refundStatus']).toLowerCase();
      final total = _round2(_asDouble(data['total']));
      final userIdFromDoc = _asText(data['userId']);
      final userId =
          userIdFromDoc.isNotEmpty
              ? userIdFromDoc
              : _userIdFromOrderPath(orderPath);

      final alreadyCancelled =
          status == 'cancelled' || deliveryStatus == 'cancelled';
      final shouldRefund =
          !alreadyCancelled &&
          paymentStatus == 'paid' &&
          refundStatus != 'refunded' &&
          userId.isNotEmpty &&
          total > 0;

      final payload = <String, dynamic>{
        'status': 'Cancelled',
        'deliveryStatus': 'Cancelled',
        'cancelledBy': cancelledBy,
        'cancelledAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (shouldRefund) {
        final userRef = _userDoc(userId);
        final userSnap = await txn.get(userRef);
        final userData = userSnap.data() ?? const <String, dynamic>{};
        final currentWallet = _round2(_asDouble(userData['walletBalance']));
        final nextWallet = _round2(currentWallet + total);

        payload.addAll({
          'refundStatus': 'refunded',
          'refundAmount': total,
          'refundTarget': 'wallet',
          'refundReason': 'order_cancelled_by_admin',
          'refundedBy': cancelledBy,
          'refundedAt': FieldValue.serverTimestamp(),
        });

        txn.set(userRef, {
          'walletBalance': nextWallet,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        final walletTxRef = userRef
            .collection('wallet_transactions')
            .doc('refund_$orderId');
        txn.set(walletTxRef, {
          'type': 'refund',
          'source': 'order_cancelled_by_admin',
          'orderId': orderId,
          'amount': total,
          'currency': 'MYR',
          'createdAt': FieldValue.serverTimestamp(),
          'createdBy': cancelledBy,
        }, SetOptions(merge: true));
      } else if (refundStatus.isEmpty) {
        payload['refundStatus'] = 'not_required';
      }

      txn.set(orderRef, payload, SetOptions(merge: true));
    });

    await updateOrderByPath(
      orderPath: orderPath,
      data: {'status': 'Cancelled', 'deliveryStatus': 'Cancelled'},
    );
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
