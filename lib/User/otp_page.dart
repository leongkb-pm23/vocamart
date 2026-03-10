// How this file works:
// 1) Data/models are declared first (if any).
// 2) UI widgets are built in build() methods.
// 3) Helper methods are used to keep UI code clean.

// File purpose: This file handles otp page screen/logic.

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:fyp/components/auth_router.dart';

// This class defines OtpPage, used for this page/feature.
class OtpPage extends StatefulWidget {
  final String phoneE164;
  final String verificationId;

  const OtpPage({
    super.key,
    required this.phoneE164,
    required this.verificationId,
  });

  @override
  State<OtpPage> createState() => _OtpPageState();
}

// This class defines _OtpPageState, used for this page/feature.
class _OtpPageState extends State<OtpPage> {
  static const kOrange = Color(0xFFFF6A00);

  final _codeCtrl = TextEditingController();
  bool _loading = false;

  InputDecoration _otpInputDecoration() {
    return const InputDecoration(
      labelText: 'Enter OTP (6 digits)',
      border: OutlineInputBorder(),
    );
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  void dispose() {
    _codeCtrl.dispose();
    super.dispose();
  }

  Future<void> _verifyOtp() async {
    final code = _codeCtrl.text.trim();
    if (code.length != 6) {
      _showSnack('Enter 6-digit OTP');
      return;
    }

    setState(() {
      _loading = true;
    });

    try {
      final cred = PhoneAuthProvider.credential(
        verificationId: widget.verificationId,
        smsCode: code,
      );

      final userCred = await FirebaseAuth.instance.signInWithCredential(cred);
      final uid = userCred.user?.uid;
      if (uid == null) throw Exception('OTP verified but UID is null');

      if (!mounted) return;
      _showSnack('OTP verified');

      await AuthRouter.goAfterLogin(context);
    } on FirebaseAuthException catch (e) {
      final msg = e.message ?? 'OTP verification failed.';
      _showSnack(msg);
    } catch (e) {
      _showSnack('Error: $e');
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  @override
  // Builds and returns the UI for this widget.
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Verify OTP')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'OTP sent to: ${widget.phoneE164}',
              style: const TextStyle(color: Colors.black54),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _codeCtrl,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(6),
              ],
              decoration: _otpInputDecoration(),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: kOrange),
                onPressed: _loading ? null : _verifyOtp,
                child:
                    _loading
                        ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                        : const Text('Verify'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}


