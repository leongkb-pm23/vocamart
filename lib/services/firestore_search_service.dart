import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class FirestoreProduct {
  final String id;
  final String name;
  final String category;
  final String description;
  final String imageUrl;
  final num quantity;
  final String unit;
  final List<String> searchKeywords;

  const FirestoreProduct({
    required this.id,
    required this.name,
    required this.category,
    required this.description,
    required this.imageUrl,
    required this.quantity,
    required this.unit,
    required this.searchKeywords,
  });

  factory FirestoreProduct.fromDoc(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final d = doc.data() ?? <String, dynamic>{};

    return FirestoreProduct(
      id: doc.id,
      name: (d['name'] ?? '').toString(),
      category: (d['category'] ?? '').toString(),
      description: (d['description'] ?? '').toString(),
      imageUrl: (d['imageUrl'] ?? '').toString(),
      quantity: d['quantity'] is num ? d['quantity'] as num : 0,
      unit: (d['unit'] ?? '').toString(),
      searchKeywords: (d['searchKeywords'] as List?)
              ?.map((e) => e.toString().toLowerCase())
              .toList() ??
          <String>[],
    );
  }
}

class FirestoreSearchService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Set<String> _tokenize(String text) {
    return text
        .toLowerCase()
        .split(RegExp(r'[^a-z0-9]+'))
        .map((e) => e.trim())
        .where((e) => e.length >= 2)
        .toSet();
  }

  Future<List<FirestoreProduct>> searchByLabels(List<String> labels) async {
    if (labels.isEmpty) return <FirestoreProduct>[];

    final keywords = <String>{};
    for (final raw in labels) {
      final normalized = raw.trim().toLowerCase();
      if (normalized.isEmpty) continue;
      keywords.add(normalized);
      keywords.addAll(
        normalized
            .split(RegExp(r'[^a-z0-9]+'))
            .map((e) => e.trim())
            .where((e) => e.length >= 2),
      );
    }
    if (keywords.isEmpty) return <FirestoreProduct>[];

    final results = <FirestoreProduct>[];
    final seen = <String>{};

    for (final keyword in keywords) {
      final found = await _searchByKeyword(keyword);
      for (final product in found) {
        if (seen.add(product.id)) {
          results.add(product);
        }
      }
    }

    if (results.isNotEmpty) return results;
    return _fallbackScanSearch(keywords);
  }

  Future<List<FirestoreProduct>> searchByKeyword(String keyword) async {
    final clean = keyword.trim().toLowerCase();
    if (clean.isEmpty) return <FirestoreProduct>[];
    return _searchByKeyword(clean);
  }

  Future<List<FirestoreProduct>> _searchByKeyword(String keyword) async {
    final results = <FirestoreProduct>[];
    final seen = <String>{};

    try {
      debugPrint('Searching Firestore keyword: $keyword');

      final productsRef =
          _db.collection('products').withConverter<Map<String, dynamic>>(
                fromFirestore: (snapshot, _) => snapshot.data() ?? {},
                toFirestore: (value, _) => value,
              );

      final nameQuery = await productsRef
          .where('nameLower', isGreaterThanOrEqualTo: keyword)
          .where('nameLower', isLessThanOrEqualTo: '$keyword\uf8ff')
          .limit(10)
          .get();

      for (final doc in nameQuery.docs) {
        if (seen.add(doc.id)) {
          results.add(FirestoreProduct.fromDoc(doc));
        }
      }

      final categoryQuery = await productsRef
          .where('categoryLower', isGreaterThanOrEqualTo: keyword)
          .where('categoryLower', isLessThanOrEqualTo: '$keyword\uf8ff')
          .limit(10)
          .get();

      for (final doc in categoryQuery.docs) {
        if (seen.add(doc.id)) {
          results.add(FirestoreProduct.fromDoc(doc));
        }
      }

      final keywordQuery = await productsRef
          .where('searchKeywords', arrayContains: keyword)
          .limit(10)
          .get();

      for (final doc in keywordQuery.docs) {
        if (seen.add(doc.id)) {
          results.add(FirestoreProduct.fromDoc(doc));
        }
      }
    } catch (e, st) {
      debugPrint('Firestore search error: $e');
      debugPrintStack(stackTrace: st);
    }

    return results;
  }

  Future<List<FirestoreProduct>> _fallbackScanSearch(
    Set<String> keywords,
  ) async {
    final results = <FirestoreProduct>[];
    final seen = <String>{};

    try {
      final snap = await _db.collection('products').limit(300).get();
      for (final doc in snap.docs) {
        final data = doc.data();
        final name = (data['name'] ?? '').toString().toLowerCase();
        final category = (data['category'] ?? '').toString().toLowerCase();
        final description = (data['description'] ?? '').toString().toLowerCase();
        final unit = (data['unit'] ?? '').toString().toLowerCase();
        final legacyKeywords = (data['searchKeywords'] as List?)
                ?.map((e) => e.toString().toLowerCase())
                .toSet() ??
            <String>{};
        final productTokens = <String>{
          ..._tokenize(name),
          ..._tokenize(category),
          ..._tokenize(description),
          ..._tokenize(unit),
          ...legacyKeywords,
        };

        bool matched = false;
        for (final keyword in keywords) {
          final kw = keyword.trim().toLowerCase();
          if (kw.length < 3) continue;

          if (name.contains(keyword) ||
              category.contains(keyword) ||
              description.contains(keyword) ||
              unit.contains(keyword) ||
              legacyKeywords.contains(keyword)) {
            matched = true;
            break;
          }

          for (final token in productTokens) {
            if (token.length < 3) continue;
            if (token.contains(kw) ||
                kw.contains(token) ||
                token.startsWith(kw) ||
                kw.startsWith(token)) {
              matched = true;
              break;
            }
          }
          if (matched) break;
        }
        if (!matched) continue;

        if (seen.add(doc.id)) {
          results.add(
            FirestoreProduct(
              id: doc.id,
              name: (data['name'] ?? '').toString(),
              category: (data['category'] ?? '').toString(),
              description: (data['description'] ?? '').toString(),
              imageUrl: (data['imageUrl'] ?? '').toString(),
              quantity: data['quantity'] is num ? data['quantity'] as num : 0,
              unit: (data['unit'] ?? '').toString(),
              searchKeywords: legacyKeywords.toList()..sort(),
            ),
          );
        }
      }
    } catch (e, st) {
      debugPrint('Fallback Firestore scan error: $e');
      debugPrintStack(stackTrace: st);
    }

    return results;
  }
}

final firestoreSearchService = FirestoreSearchService();
