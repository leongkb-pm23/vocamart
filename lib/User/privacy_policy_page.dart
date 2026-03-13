import 'package:flutter/material.dart';

class PrivacyPolicyPage extends StatelessWidget {
  static const kOrange = Color(0xFFFF6A00);

  const PrivacyPolicyPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Privacy and Policy'),
        backgroundColor: kOrange,
        foregroundColor: Colors.black,
      ),
      body: const SingleChildScrollView(
        padding: EdgeInsets.all(14),
        child: Text(
          'Privacy and Policy\n\n'
          '1. We collect basic account and order data to provide app services.\n\n'
          '2. Your data is used for authentication, order processing, and support.\n\n'
          '3. We do not sell personal data to third parties.\n\n'
          '4. Data may be stored securely using cloud services for app functionality.\n\n'
          '5. You can contact support to request account-related data updates.',
          style: TextStyle(fontSize: 15, height: 1.5),
        ),
      ),
    );
  }
}
