import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class EventDetailPage extends StatelessWidget {
  final String eventId;
  final Map<String, dynamic> data;

  const EventDetailPage({super.key, required this.eventId, required this.data});

  bool _isHttpImageUrl(String? raw) {
    if (raw == null || raw.trim().isEmpty) return false;
    final uri = Uri.tryParse(raw.trim());
    return uri != null && (uri.scheme == 'http' || uri.scheme == 'https');
  }

  String _eventDateText(dynamic rawDate) {
    if (rawDate is! Timestamp) return 'Date not set';
    return DateFormat('dd MMM yyyy').format(rawDate.toDate());
  }

  @override
  Widget build(BuildContext context) {
    final title =
        (data['title'] ?? data['name'] ?? 'Event Details').toString().trim();
    final description =
        (data['description'] ?? data['message'] ?? '').toString().trim();
    final imageUrl = (data['imageUrl'] ?? '').toString().trim();
    final eventDateText = _eventDateText(data['date']);

    return Scaffold(
      appBar: AppBar(title: Text(title.isEmpty ? 'Event Details' : title)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: AspectRatio(
              aspectRatio: 16 / 9,
              child:
                  _isHttpImageUrl(imageUrl)
                      ? Image.network(
                        imageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) {
                          return const ColoredBox(
                            color: Color(0xFFEDEDED),
                            child: Center(
                              child: Text(
                                'Unable to load event image',
                                style: TextStyle(fontWeight: FontWeight.w700),
                              ),
                            ),
                          );
                        },
                      )
                      : const ColoredBox(
                        color: Color(0xFFEDEDED),
                        child: Center(
                          child: Text(
                            'No image for this event',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                      ),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            title.isEmpty ? 'Event Details' : title,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF3E0),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              'Date: $eventDateText',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            description.isEmpty
                ? 'No event description provided.'
                : description,
            style: const TextStyle(fontSize: 15, height: 1.45),
          ),
          const SizedBox(height: 10),
          Text(
            'Event ID: $eventId',
            style: const TextStyle(
              fontSize: 12,
              color: Colors.black54,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
