// How this file works:
// 1) Validates email/password login.
// 2) Signs in the user.
// 3) Sends the user back to the central auth router.
//
// File purpose: Login screen/logic.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'package:fyp/components/auth_action_widgets.dart';
import 'package:fyp/components/auth_form_widgets.dart';
import 'package:fyp/components/auth_router.dart';
import 'package:fyp/User/forgot_password.dart';
import 'package:fyp/User/login_phone.dart';
import 'package:fyp/User/register.dart';

class LoginPage extends StatefulWidget {
  static const routeName = '/login';
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  static const kOrange = Color(0xFFFF6A00);

  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();

  bool _obscurePw = true;
  bool _loading = false;

  Future<void> _openNamed(String routeName, {bool replace = false}) async {
    if (replace) {
      await Navigator.pushReplacementNamed(context, routeName);
      return;
    }
    await Navigator.pushNamed(context, routeName);
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  String? _validateEmail(String? v) {
    final value = (v ?? '').trim();
    if (value.isEmpty) return 'Email is required';
    final reg = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
    if (!reg.hasMatch(value)) return 'Enter a valid email';
    return null;
  }

  String? _validatePassword(String? v) {
    final value = v ?? '';
    if (value.isEmpty) return 'Password is required';
    return null;
  }

  Future<void> _login() async {
    final ok = _formKey.currentState?.validate() ?? false;
    if (!ok) {
      _showSnack('Please enter email and password');
      return;
    }

    setState(() => _loading = true);

    try {
      final email = _emailCtrl.text.trim();
      final password = _passwordCtrl.text;

      final cred = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (cred.user?.uid == null) {
        throw Exception('Login failed: UID is null');
      }

      if (!mounted) return;
      _showSnack('Login successful');
      await AuthRouterGate.goAfterLogin(context);
    } on FirebaseAuthException catch (e) {
      String msg = 'Login failed.';
      if (e.code == 'user-not-found') msg = 'No user found for this email.';
      if (e.code == 'wrong-password') msg = 'Wrong password.';
      if (e.code == 'invalid-email') msg = 'Invalid email format.';
      if (e.code == 'invalid-credential') msg = 'Invalid email or password.';
      if (e.code == 'too-many-requests') {
        msg = 'Too many attempts. Try again later.';
      }
      _showSnack(msg);
    } catch (e) {
      _showSnack('Error: $e');
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _loginWithGoogle() async {
    if (_loading) return;
    setState(() => _loading = true);

    try {
      final googleUser = await GoogleSignIn(scopes: ['email']).signIn();
      if (googleUser == null) {
        _showSnack('Google sign-in cancelled.');
        return;
      }

      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final userCred =
      await FirebaseAuth.instance.signInWithCredential(credential);
      final user = userCred.user;
      if (user == null) throw Exception('Google login failed.');

      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'uid': user.uid,
        'email': user.email ?? '',
        'name': user.displayName ?? '',
        'photoUrl': user.photoURL ?? '',
        'updatedAt': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (!mounted) return;
      _showSnack('Google sign-in successful');
      await AuthRouterGate.goAfterLogin(context);
    } on FirebaseAuthException catch (e) {
      _showSnack(e.message ?? 'Google sign-in failed');
    } catch (e) {
      _showSnack('Google sign-in error: $e');
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
      _showSnack('Guest login failed: $e');
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
              'Welcome',
              style: TextStyle(
                color: kOrange,
                fontWeight: FontWeight.w800,
                fontSize: 26,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Sign in to your account',
              style: TextStyle(color: Colors.grey.shade700),
            ),
            const SizedBox(height: 14),
            const AuthFieldLabel('Email Address'),
            const SizedBox(height: 6),
            AuthBoxField(
              controller: _emailCtrl,
              hint: 'Enter email address',
              keyboardType: TextInputType.emailAddress,
              validator: _validateEmail,
            ),
            const SizedBox(height: 12),
            const AuthFieldLabel('Password'),
            const SizedBox(height: 6),
            AuthBoxField(
              controller: _passwordCtrl,
              hint: 'Enter password',
              keyboardType: TextInputType.text,
              obscureText: _obscurePw,
              validator: _validatePassword,
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
                  _openNamed(ForgotPasswordPage.routeName);
                },
                child: const Text(
                  'Forgot Password?',
                  style: TextStyle(color: Colors.black87),
                ),
              ),
            ),
            const SizedBox(height: 4),
            AuthPrimarySignInButton(
              loading: _loading,
              onPressed: _loading ? null : _login,
            ),
            const SizedBox(height: 18),
            const AuthOrDivider(),
            const SizedBox(height: 12),
            AuthOutlinedPillButton(
              text: 'Sign In with Google',
              onPressed: _loading ? null : _loginWithGoogle,
            ),
            const SizedBox(height: 10),
            AuthOutlinedPillButton(
              text: 'Sign In with Phone Number',
              onPressed: _loading
                  ? null
                  : () {
                _openNamed(
                  LoginPhonePage.routeName,
                  replace: true,
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
                _openNamed(
                  RegistrationPage.routeName,
                  replace: true,
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}