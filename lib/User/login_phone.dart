// How this file works:
// 1) Finds the user's email by phone number.
// 2) Signs in with email/password.
// 3) Sends the user to the central auth router.
//
// File purpose: Login with phone number + password.

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl_phone_field/intl_phone_field.dart';

import 'package:fyp/components/auth_action_widgets.dart';
import 'package:fyp/components/auth_form_widgets.dart';
import 'package:fyp/components/auth_router.dart';
import 'package:fyp/User/login.dart';
import 'package:fyp/User/register.dart';
import 'package:fyp/User/forgot_password.dart';

class LoginPhonePage extends StatefulWidget {
  static const routeName = '/login-phone';
  const LoginPhonePage({super.key});

  @override
  State<LoginPhonePage> createState() => _LoginPhonePageState();
}

class _LoginPhonePageState extends State<LoginPhonePage> {
  static const kOrange = Color(0xFFFF6A00);

  final _formKey = GlobalKey<FormState>();
  final _phoneCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();

  String _phoneE164 = "";
  bool _obscurePw = true;
  bool _loading = false;

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  void dispose() {
    _phoneCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _loginWithPhoneAndPassword() async {
    _formKey.currentState?.save();

    final ok = _formKey.currentState?.validate() ?? false;
    if (!ok) {
      _showSnack("Please enter phone number and password.");
      return;
    }

    final phone = _phoneE164.trim();
    final password = _passwordCtrl.text;

    if (phone.isEmpty) {
      _showSnack("Phone number is required");
      return;
    }

    setState(() => _loading = true);

    try {
      final snap = await FirebaseFirestore.instance
          .collection('users')
          .where('phone', isEqualTo: phone)
          .limit(1)
          .get();

      if (snap.docs.isEmpty) {
        throw FirebaseAuthException(
          code: 'user-not-found',
          message: 'No account found for this phone number.',
        );
      }

      final data = snap.docs.first.data();
      final email = (data['email'] ?? '').toString().trim();

      if (email.isEmpty) {
        throw FirebaseAuthException(
          code: 'invalid-email',
          message: 'Email not found for this phone number.',
        );
      }

      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (!mounted) return;
      _showSnack("Login successful");
      await AuthRouterGate.goAfterLogin(context);
    } on FirebaseAuthException catch (e) {
      String msg = e.message ?? "Login failed.";
      if (e.code == 'user-not-found') {
        msg = "No account found for this phone number.";
      }
      if (e.code == 'wrong-password') {
        msg = "Wrong password.";
      }
      if (e.code == 'invalid-credential') {
        msg = "Invalid phone number or password.";
      }
      if (e.code == 'too-many-requests') {
        msg = "Too many attempts. Try again later.";
      }

      _showSnack(msg);
    } on FirebaseException catch (e) {
      _showSnack("Firestore error: ${e.message ?? e.code}");
    } catch (e) {
      _showSnack("Error: $e");
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _continueAsGuest() async {
    if (_loading) return;

    setState(() => _loading = true);

    try {
      await FirebaseAuth.instance.signInAnonymously();
      if (!mounted) return;
      await AuthRouterGate.goAfterLogin(context);
    } catch (e) {
      _showSnack("Guest login failed: $e");
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthPageShell(
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 10),
            const Text(
              "Welcome",
              style: TextStyle(
                color: kOrange,
                fontWeight: FontWeight.w800,
                fontSize: 26,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              "Sign in to your account",
              style: TextStyle(color: Colors.black54),
            ),
            const SizedBox(height: 14),
            const AuthFieldLabel("Phone Number"),
            const SizedBox(height: 6),
            IntlPhoneField(
              controller: _phoneCtrl,
              initialCountryCode: 'MY',
              disableLengthCheck: true,
              autovalidateMode: AutovalidateMode.onUserInteraction,
              decoration: AuthBoxField.defaultDecoration("Enter phone number"),
              validator: (phone) {
                if (phone == null) return "Phone number is required";
                final number = phone.number.trim();
                if (number.isEmpty) return "Phone number is required";
                if (!RegExp(r'^\d+$').hasMatch(number)) return "Digits only";
                if (number.length < 9 || number.length > 11) {
                  return "Enter a valid phone number";
                }
                return null;
              },
              onChanged: (phone) {
                _phoneE164 = phone.completeNumber;
              },
              onSaved: (phone) {
                _phoneE164 = phone?.completeNumber ?? "";
              },
            ),
            const SizedBox(height: 12),
            const AuthFieldLabel("Password"),
            const SizedBox(height: 6),
            AuthBoxField(
              controller: _passwordCtrl,
              hint: "Enter password",
              keyboardType: TextInputType.text,
              obscureText: _obscurePw,
              validator: (v) {
                final value = v ?? '';
                if (value.isEmpty) return "Password is required";
                return null;
              },
              suffix: IconButton(
                onPressed: () {
                  setState(() => _obscurePw = !_obscurePw);
                },
                icon: Icon(
                  _obscurePw ? Icons.visibility_off : Icons.visibility,
                  color: Colors.grey.shade700,
                ),
              ),
            ),
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: _loading
                    ? null
                    : () {
                  Navigator.pushNamed(
                    context,
                    ForgotPasswordPage.routeName,
                  );
                },
                child: const Text(
                  "Forgot Password?",
                  style: TextStyle(color: Colors.black87),
                ),
              ),
            ),
            const SizedBox(height: 4),
            AuthPrimarySignInButton(
              loading: _loading,
              onPressed: _loading ? null : _loginWithPhoneAndPassword,
            ),
            const SizedBox(height: 18),
            const AuthOrDivider(),
            const SizedBox(height: 12),
            AuthOutlinedPillButton(
              text: "Sign In with Google",
              onPressed: _loading
                  ? null
                  : () {
                _showSnack("Google Sign-In not added yet.");
              },
            ),
            const SizedBox(height: 10),
            AuthOutlinedPillButton(
              text: "Sign In with Email Address",
              onPressed: _loading
                  ? null
                  : () {
                Navigator.pushReplacementNamed(
                  context,
                  LoginPage.routeName,
                );
              },
            ),
            const SizedBox(height: 14),
            AuthGuestButton(
              enabled: !_loading,
              onPressed: _continueAsGuest,
            ),
            const SizedBox(height: 18),
            AuthSignUpPrompt(
              onTap: () {
                Navigator.pushReplacementNamed(
                  context,
                  RegistrationPage.routeName,
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}