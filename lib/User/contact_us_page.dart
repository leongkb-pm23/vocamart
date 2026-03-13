import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class ContactUsPage extends StatelessWidget {
  static const kOrange = Color(0xFFFF6A00);

  const ContactUsPage({super.key});

  Future<void> _openLink(BuildContext context, Uri uri) async {
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to open link.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final emailUri = Uri.parse('mailto:support@vocamart.com');
    final phoneUri = Uri.parse('tel:+60123456789');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Contact Us'),
        backgroundColor: kOrange,
        foregroundColor: Colors.black,
      ),
      body: ListView(
        padding: const EdgeInsets.all(14),
        children: [
          const Card(
            child: ListTile(
              leading: Icon(Icons.location_on_outlined),
              title: Text('Address'),
              subtitle: Text('VocaMart Support Center, Kuala Lumpur, Malaysia'),
            ),
          ),
          Card(
            child: ListTile(
              leading: const Icon(Icons.email_outlined),
              title: const Text('Email'),
              subtitle: const Text('support@vocamart.com'),
              trailing: const Icon(Icons.open_in_new),
              onTap: () => _openLink(context, emailUri),
            ),
          ),
          Card(
            child: ListTile(
              leading: const Icon(Icons.phone_outlined),
              title: const Text('Phone'),
              subtitle: const Text('+60 12-345 6789'),
              trailing: const Icon(Icons.open_in_new),
              onTap: () => _openLink(context, phoneUri),
            ),
          ),
        ],
      ),
    );
  }
}
