import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:google_mlkit_image_labeling/google_mlkit_image_labeling.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:http/http.dart' as http;

class ImageSearchService {
  // Set with --dart-define=IMAGE_SEARCH_ENDPOINT=https://your-api/path
  static const String _endpoint = String.fromEnvironment('IMAGE_SEARCH_ENDPOINT');

  Future<Map<String, dynamic>> searchByImage(File imageFile) async {
    final labels = <String>{};

    labels.addAll(await _detectLabelsOnDevice(imageFile));
    labels.addAll(await _detectTextOnDevice(imageFile));

    final endpoint = _endpoint.trim();
    if (endpoint.isNotEmpty) {
      labels.addAll(await _detectLabelsFromEndpoint(imageFile, endpoint));
    }

    if (labels.isEmpty) {
      labels.addAll(_labelsFromFileName(imageFile.path));
    }

    return <String, dynamic>{'labels': labels.toList()};
  }

  Future<List<String>> _detectLabelsOnDevice(File imageFile) async {
    ImageLabeler? labeler;
    try {
      final options = ImageLabelerOptions(confidenceThreshold: 0.45);
      labeler = ImageLabeler(options: options);
      final input = InputImage.fromFilePath(imageFile.path);
      final labels = await labeler.processImage(input);

      return _normalizeKeywords(labels.map((l) => l.label).toList());
    } catch (e, st) {
      debugPrint('On-device image labeling failed: $e');
      debugPrintStack(stackTrace: st);
      return <String>[];
    } finally {
      await labeler?.close();
    }
  }

  Future<List<String>> _detectTextOnDevice(File imageFile) async {
    TextRecognizer? recognizer;
    try {
      recognizer = TextRecognizer(script: TextRecognitionScript.latin);
      final input = InputImage.fromFilePath(imageFile.path);
      final recognized = await recognizer.processImage(input);

      final raw = <String>[];
      for (final block in recognized.blocks) {
        raw.add(block.text);
      }
      return _normalizeKeywords(raw);
    } catch (e, st) {
      debugPrint('On-device text recognition failed: $e');
      debugPrintStack(stackTrace: st);
      return <String>[];
    } finally {
      await recognizer?.close();
    }
  }

  Future<List<String>> _detectLabelsFromEndpoint(
    File imageFile,
    String endpoint,
  ) async {
    try {
      final uri = Uri.parse(endpoint);
      final req = http.MultipartRequest('POST', uri)
        ..files.add(
          await http.MultipartFile.fromPath('image', imageFile.path),
        );

      final streamed = await req.send();
      final body = await streamed.stream.bytesToString();
      if (streamed.statusCode < 200 || streamed.statusCode >= 300) {
        debugPrint('Image search HTTP error ${streamed.statusCode}: $body');
        return <String>[];
      }

      final decoded = jsonDecode(body);
      return _extractLabels(decoded);
    } catch (e, st) {
      debugPrint('Image search endpoint failed: $e');
      debugPrintStack(stackTrace: st);
      return <String>[];
    }
  }

  List<String> _extractLabels(dynamic payload) {
    if (payload is Map<String, dynamic>) {
      final labels = payload['labels'];
      if (labels is List) {
        return _normalizeKeywords(labels.map((e) => e.toString()).toList());
      }
      if (labels is String) {
        return _normalizeKeywords(<String>[labels]);
      }
    }
    return <String>[];
  }

  List<String> _normalizeKeywords(List<String> source) {
    const stopWords = <String>{
      'and',
      'with',
      'from',
      'this',
      'that',
      'have',
      'your',
      'item',
      'food',
      'product',
      'text',
      'label',
      'brand',
      'logo',
      'font',
      'material',
      'paper',
      'plastic',
      'container',
    };

    final out = <String>{};
    for (final s in source) {
      final lower = s.toLowerCase().trim();
      if (lower.isEmpty) continue;

      out.add(lower);

      final parts = lower
          .split(RegExp(r'[^a-z0-9]+'))
          .map((e) => e.trim())
          .where((e) => e.length >= 2 && !stopWords.contains(e));

      for (final p in parts) {
        out.add(p);
      }
    }
    return out.toList();
  }

  List<String> _labelsFromFileName(String path) {
    final fileName = path.split(Platform.pathSeparator).last;
    final base = fileName.replaceFirst(RegExp(r'\.[^.]+$'), '');
    return base
        .toLowerCase()
        .split(RegExp(r'[^a-z0-9]+'))
        .where((e) => e.length >= 2)
        .toSet()
        .toList();
  }
}

final searchService = ImageSearchService();
