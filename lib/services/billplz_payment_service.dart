import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';

import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

class BillplzCreateResult {
  final bool success;
  final String? billId;
  final String? billUrl;
  final String? state;
  final bool? paid;
  final String? message;
  final String? error;

  const BillplzCreateResult({
    required this.success,
    this.billId,
    this.billUrl,
    this.state,
    this.paid,
    this.message,
    this.error,
  });

  factory BillplzCreateResult.fromJson(Map<String, dynamic> json) {
    return BillplzCreateResult(
      success: json['success'] == true,
      billId: (json['bill_id'] ?? '').toString().trim().isEmpty
          ? null
          : (json['bill_id']).toString(),
      billUrl: (json['bill_url'] ?? '').toString().trim().isEmpty
          ? null
          : (json['bill_url']).toString(),
      state: (json['state'] ?? '').toString().trim().isEmpty
          ? null
          : (json['state']).toString(),
      paid: json['paid'] is bool ? json['paid'] as bool : null,
      message: (json['message'] ?? '').toString().trim().isEmpty
          ? null
          : (json['message']).toString(),
      error: (json['error'] ?? '').toString().trim().isEmpty
          ? null
          : (json['error']).toString(),
    );
  }
}

class BillplzPaymentService {
  static const Duration _requestTimeout = Duration(seconds: 12);

  static String get _configuredBaseUrl {
    return const String.fromEnvironment(
      'PAYMENT_API_BASE_URL',
      defaultValue: '',
    ).trim();
  }

  static List<String> get _candidateBaseUrls {
    final urls = <String>[];
    if (_configuredBaseUrl.isNotEmpty) urls.add(_configuredBaseUrl);
    // Real device with `adb reverse tcp:8000 tcp:8000`.
    urls.add('http://127.0.0.1:8000');
    // Android emulator host alias.
    urls.add('http://10.0.2.2:8000');
    return urls.toSet().toList();
  }

  Uri _uri(String baseUrl, String path) {
    final base =
        baseUrl.endsWith('/') ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl;
    return Uri.parse('$base$path');
  }

  Future<bool> healthCheck() async {
    for (final baseUrl in _candidateBaseUrls) {
      try {
        final res = await http
            .get(_uri(baseUrl, '/api/payments/health'))
            .timeout(_requestTimeout);
        if (res.statusCode != 200) continue;
        final map = jsonDecode(res.body) as Map<String, dynamic>;
        if ((map['status'] ?? '').toString().toLowerCase() == 'ok') {
          return true;
        }
      } on TimeoutException {
        continue;
      } catch (_) {
        continue;
      }
    }
    return false;
  }

  Future<BillplzCreateResult> createBill({
    required String orderId,
    required String name,
    required double amountRm,
    String? email,
    String? mobile,
    String? description,
  }) async {
    String? lastError;

    for (final baseUrl in _candidateBaseUrls) {
      try {
        final payload = <String, dynamic>{
          'order_id': orderId,
          'name': name,
          'amount_rm': amountRm,
          'email': (email ?? '').trim(),
          'mobile': (mobile ?? '').trim(),
          'description': (description ?? '').trim(),
        };

        final res = await http
            .post(
              _uri(baseUrl, '/api/payments/billplz/create'),
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode(payload),
            )
            .timeout(_requestTimeout);

        if (res.statusCode >= 400) {
          return BillplzCreateResult(
            success: false,
            error:
                'Create bill failed (${res.statusCode}) on $baseUrl: ${res.body}',
          );
        }

        final map = jsonDecode(res.body) as Map<String, dynamic>;
        return BillplzCreateResult.fromJson(map);
      } on TimeoutException {
        lastError =
            'Create bill timeout after ${_requestTimeout.inSeconds}s on $baseUrl.';
        continue;
      } catch (e) {
        lastError = 'Create bill request error on $baseUrl: $e';
        continue;
      }
    }

    return BillplzCreateResult(
      success: false,
      error: lastError ??
          'Create bill request failed on all configured payment backend URLs.',
    );
  }

  Future<BillplzCreateResult> fetchBill(String billId) async {
    String? lastError;

    for (final baseUrl in _candidateBaseUrls) {
      try {
        final res = await http
            .get(_uri(baseUrl, '/api/payments/billplz/bill/$billId'))
            .timeout(_requestTimeout);
        if (res.statusCode >= 400) {
          return BillplzCreateResult(
            success: false,
            error:
                'Fetch bill failed (${res.statusCode}) on $baseUrl: ${res.body}',
          );
        }
        final map = jsonDecode(res.body) as Map<String, dynamic>;
        return BillplzCreateResult.fromJson(map);
      } on TimeoutException {
        lastError =
            'Fetch bill timeout after ${_requestTimeout.inSeconds}s on $baseUrl.';
        continue;
      } catch (e) {
        lastError = 'Fetch bill request error on $baseUrl: $e';
        continue;
      }
    }

    return BillplzCreateResult(
      success: false,
      error: lastError ??
          'Fetch bill request failed on all configured payment backend URLs.',
    );
  }

  Future<bool> openBillUrl(String billUrl) async {
    Uri uri;
    try {
      uri = Uri.parse(billUrl.trim());
    } catch (_) {
      return false;
    }

    if (uri.scheme != 'https') {
      return false;
    }

    final modes = <LaunchMode>[
      // Prefer in-app so user clearly sees payment flow from current app.
      LaunchMode.inAppBrowserView,
      LaunchMode.externalApplication,
      LaunchMode.platformDefault,
    ];

    for (final mode in modes) {
      try {
        debugPrint('Billplz launch attempt: mode=$mode url=$uri');
        final ok = await launchUrl(uri, mode: mode);
        debugPrint('Billplz launch result: mode=$mode ok=$ok');
        if (ok) return true;
      } catch (_) {
        // Try next mode.
      }
    }
    return false;
  }
}
