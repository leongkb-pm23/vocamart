// How this file works:
// 1) Data/models are declared first (if any).
// 2) UI widgets are built in build() methods.
// 3) Helper methods are used to keep UI code clean.

// File purpose: This file handles forgot password screen/logic.

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl_phone_field/intl_phone_field.dart';

import 'package:fyp/components/auth_form_widgets.dart';
import 'package:fyp/User/otp_page.dart';

// This class defines ForgotPasswordPage, used for this page/feature.
class ForgotPasswordPage extends StatefulWidget {
  static const routeName = '/forgot-password';
  const ForgotPasswordPage({super.key});

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

// This class defines _ForgotPasswordPageState, used for this page/feature.
class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  static const kOrange = Color(0xFFFF6A00);

  final _formKey = GlobalKey<FormState>();

  bool _useEmail = true; // email link OR phone otp

  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();

  String _phoneE164 = "";
  bool _loading = false;

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Colors.black26),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Colors.black87),
      ),
    );
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  bool _isEmail(String v) {
    final value = v.trim();
    final reg = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
    return reg.hasMatch(value);
  }

  Future<void> _send() async {
    _formKey.currentState?.save();
    final ok = _formKey.currentState?.validate() ?? false;
    if (!ok) return;

    setState(() {
      _loading = true;
    });

    try {
      if (_useEmail) {
        // Email reset link (recommended)
        final email = _emailCtrl.text.trim();
        await FirebaseAuth.instance.sendPasswordResetEmail(email: email);

        if (!mounted) return;
        _showSnack("Reset link sent to your email");
        Navigator.pop(context);
      } else {
        // Phone OTP via Firebase
        final phone = _phoneE164.trim();
        if (phone.isEmpty) {
          throw FirebaseAuthException(code: 'invalid-phone-number', message: 'Phone is empty');
        }

        await FirebaseAuth.instance.verifyPhoneNumber(
          phoneNumber: phone,
          timeout: const Duration(seconds: 60),
          verificationCompleted: (PhoneAuthCredential credential) async {
            // Sometimes Android auto-detects OTP and completes
            // We still go to OTP page usually, but auto sign-in could happen here if you want.
          },
          verificationFailed: (FirebaseAuthException e) {
            if (!mounted) return;
            final msg = e.message ?? "Failed to send OTP.";
            _showSnack(msg);
          },
          codeSent: (String verificationId, int? resendToken) {
            if (!mounted) return;
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => OtpPage(
                  phoneE164: phone,
                  verificationId: verificationId,
                ),
              ),
            );
          },
          codeAutoRetrievalTimeout: (String verificationId) {},
        );
      }
    } on FirebaseAuthException catch (e) {
      final msg = e.message ?? "Something went wrong.";
      if (mounted) _showSnack(msg);
    } catch (e) {
      if (mounted) _showSnack("Error: $e");
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
    return AuthPageShell(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
                        Row(
                          children: [
                            IconButton(
                              onPressed: () {
                                Navigator.pop(context);
                              },
                              icon: const Icon(Icons.arrow_back),
                            ),
                          ],
                        ),

                        const Text(
                          "Forgot password",
                          style: TextStyle(
                            color: kOrange,
                            fontSize: 26,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          _useEmail
                              ? "Enter your email. We will send a reset link."
                              : "Enter your phone number. We will send an OTP code.",
                          style: const TextStyle(color: Colors.black54, height: 1.35),
                        ),

                        const SizedBox(height: 18),

                        Row(
                          children: [
                            Expanded(
                              child: _ModeChip(
                                selected: _useEmail,
                                text: "Email",
                                onTap: () {
                                  setState(() {
                                    _useEmail = true;
                                  });
                                },
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _ModeChip(
                                selected: !_useEmail,
                                text: "Phone",
                                onTap: () {
                                  setState(() {
                                    _useEmail = false;
                                  });
                                },
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 18),

                        Text(
                          _useEmail ? "Email Address" : "Phone Number",
                          style: const TextStyle(
                            color: kOrange,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 8),

                        if (_useEmail)
                          TextFormField(
                            controller: _emailCtrl,
                            keyboardType: TextInputType.emailAddress,
                            autovalidateMode: AutovalidateMode.onUserInteraction,
                            validator: (v) {
                              final value = (v ?? '').trim();
                              if (value.isEmpty) return "Email is required";
                              if (!_isEmail(value)) return "Enter a valid email";
                              return null;
                            },
                            decoration: _inputDecoration("Enter email address"),
                          )
                        else
                          IntlPhoneField(
                            controller: _phoneCtrl,
                            initialCountryCode: 'MY',
                            disableLengthCheck: true,
                            autovalidateMode: AutovalidateMode.onUserInteraction,
                            decoration: _inputDecoration("Enter phone number"),
                            validator: (phone) {
                              if (phone == null) return "Phone number is required";
                              final n = phone.number.trim();
                              if (n.isEmpty) return "Phone number is required";
                              if (!RegExp(r'^\d+$').hasMatch(n)) return "Digits only";
                              // For MY numbers: intl_phone_field removes leading 0, so usually 9-11 digits.
                              if (n.length < 9 || n.length > 11) return "Enter a valid phone number";
                              return null;
                            },
                            onChanged: (phone) {
                              _phoneE164 = phone.completeNumber;
                            },
                            onSaved: (phone) {
                              _phoneE164 = phone?.completeNumber ?? "";
                            },
                          ),

                        const SizedBox(height: 22),

                        SizedBox(
                          width: double.infinity,
                          height: 54,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: kOrange,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                            ),
                            onPressed: _loading ? null : _send,
                            child: _loading
                                ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                                : Text(
                              _useEmail ? "Send Reset Link" : "Send OTP Code",
                              style: const TextStyle(fontWeight: FontWeight.w800),
                            ),
                          ),
                        ),
                      ],
        ),
      ),
    );
  }
}

// This class defines _ModeChip, used for this page/feature.
class _ModeChip extends StatelessWidget {
  final bool selected;
  final String text;
  final VoidCallback onTap;

  const _ModeChip({
    required this.selected,
    required this.text,
    required this.onTap,
  });

  @override
  // Builds and returns the UI for this widget.
  Widget build(BuildContext context) {
    const kOrange = Color(0xFFFF6A00);
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: selected ? kOrange : Colors.black12),
          color:
              selected
                  ? kOrange.withValues(alpha: 0.08)
                  : Colors.transparent,
        ),
        child: Center(
          child: Text(
            text,
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: selected ? kOrange : Colors.black54,
            ),
          ),
        ),
      ),
    );
  }
}



