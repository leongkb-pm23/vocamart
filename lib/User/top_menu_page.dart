import 'package:flutter/material.dart';

import 'package:fyp/User/contact_us_page.dart';
import 'package:fyp/User/privacy_policy_page.dart';
import 'package:fyp/User/terms_and_condition_page.dart';

class TopMenuPage extends StatelessWidget {
  static const kOrange = Color(0xFFFF6A00);

  const TopMenuPage({super.key});

  Future<void> _open(BuildContext context, Widget page) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => page),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Menu'),
        backgroundColor: kOrange,
        foregroundColor: Colors.black,
      ),
      body: ListView(
        padding: const EdgeInsets.all(14),
        children: [
          Card(
            child: ListTile(
              leading: const Icon(Icons.description_outlined),
              title: const Text('Terms and Condition'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _open(context, const TermsAndConditionPage()),
            ),
          ),
          Card(
            child: ListTile(
              leading: const Icon(Icons.privacy_tip_outlined),
              title: const Text('Privacy and Policy'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _open(context, const PrivacyPolicyPage()),
            ),
          ),
          Card(
            child: ListTile(
              leading: const Icon(Icons.support_agent_outlined),
              title: const Text('Contact Us'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _open(context, const ContactUsPage()),
            ),
          ),
        ],
      ),
    );
  }
}
