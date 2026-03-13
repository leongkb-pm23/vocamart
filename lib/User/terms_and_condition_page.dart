import 'package:flutter/material.dart';

class TermsAndConditionPage extends StatelessWidget {
  static const kOrange = Color(0xFFFF6A00);

  const TermsAndConditionPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Terms and Condition'),
        backgroundColor: kOrange,
        foregroundColor: Colors.black,
      ),
      body: const SingleChildScrollView(
        padding: EdgeInsets.all(14),
        child: Text(
          'Terms and Condition\n\n'
          '1. By using this app, you agree to use it lawfully and responsibly.\n\n'
          '2. Product information and prices may change without prior notice.\n\n'
          '3. We may update app features and policies from time to time.\n\n'
          '4. Users are responsible for account security and activity under their account.\n\n'
          '5. Orders, delivery, and payment are subject to store availability and verification.',
          style: TextStyle(fontSize: 15, height: 1.5),
        ),
      ),
    );
  }
}
