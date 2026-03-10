// How this file works:
// 1) Data/models are declared first (if any).
// 2) UI widgets are built in build() methods.
// 3) Helper methods are used to keep UI code clean.


import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:fyp/components/auth_form_widgets.dart';
import 'package:fyp/User/login.dart';

// This class defines CreateNewPasswordPage, used for this page/feature.
class CreateNewPasswordPage extends StatefulWidget {
  static const routeName = '/create-new-password';
  const CreateNewPasswordPage({super.key});

  @override
  State<CreateNewPasswordPage> createState() => _CreateNewPasswordPageState();
}

// This class defines _CreateNewPasswordPageState, used for this page/feature.
class _CreateNewPasswordPageState extends State<CreateNewPasswordPage> {
  static const kOrange = Color(0xFFFF6A00);

  final _formKey = GlobalKey<FormState>();
  final _pwCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();

  bool _obscurePw = true;
  bool _obscureConfirm = true;
  bool _loading = false;

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  InputDecoration _passwordInputDecoration({
    required String hint,
    required bool obscure,
    required VoidCallback onToggle,
  }) {
    return InputDecoration(
      hintText: hint,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      suffixIcon: IconButton(
        onPressed: onToggle,
        icon: Icon(obscure ? Icons.visibility_off : Icons.visibility),
      ),
    );
  }

  @override
  void dispose() {
    _pwCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  bool _hasUpper(String s) {
    return RegExp(r'[A-Z]').hasMatch(s);
  }

  bool _hasLower(String s) {
    return RegExp(r'[a-z]').hasMatch(s);
  }

  bool _hasNumber(String s) {
    return RegExp(r'\d').hasMatch(s);
  }

  bool _hasSymbol(String s) {
    return RegExp(r'[@#*]').hasMatch(s);
  }

  String? _validatePw(String? v) {
    final value = (v ?? '');
    if (value.isEmpty) return "Password is required";
    if (value.length < 8) return "At least 8 characters";
    if (!_hasUpper(value)) return "Need uppercase";
    if (!_hasLower(value)) return "Need lowercase";
    if (!_hasNumber(value)) return "Need number";
    if (!_hasSymbol(value)) return "Need @#* symbol";
    return null;
  }

  String? _validateConfirm(String? v) {
    final value = (v ?? '');
    if (value.isEmpty) return "Confirm password is required";
    if (value != _pwCtrl.text) return "Passwords do not match";
    return null;
  }

  Future<void> _updatePassword() async {
    final ok = _formKey.currentState?.validate() ?? false;
    if (!ok) return;

    setState(() {
      _loading = true;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw FirebaseAuthException(code: 'no-user', message: 'No authenticated user.');
      }

      await user.updatePassword(_pwCtrl.text);

      if (!mounted) return;
      _showSnack("Password updated. Please login again.");

      // optional: sign out then back to login
      await FirebaseAuth.instance.signOut();

      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginPage()),
        (_) {
          return false;
        },
      );
    } on FirebaseAuthException catch (e) {
      final msg = e.message ?? "Failed to update password.";
      _showSnack(msg);
    } catch (e) {
      _showSnack("Error: $e");
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
                              onPressed: _loading
                                  ? null
                                  : () {
                                      Navigator.pop(context);
                                    },
                              icon: const Icon(Icons.arrow_back),
                            ),
                          ],
                        ),

                        const Text(
                          "Set Password",
                          style: TextStyle(
                            color: kOrange,
                            fontSize: 26,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          "Please enter your password and confirm it.",
                          style: TextStyle(color: Colors.black54),
                        ),
                        const SizedBox(height: 18),

                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _pwCtrl,
                          obscureText: _obscurePw,
                          autovalidateMode: AutovalidateMode.onUserInteraction,
                          validator: _validatePw,
                          decoration: _passwordInputDecoration(
                            hint: "Password",
                            obscure: _obscurePw,
                            onToggle: () {
                              setState(() {
                                _obscurePw = !_obscurePw;
                              });
                            },
                          ),
                        ),

                        const SizedBox(height: 14),

                        const Text("Confirm Password", style: TextStyle(color: kOrange, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _confirmCtrl,
                          obscureText: _obscureConfirm,
                          autovalidateMode: AutovalidateMode.onUserInteraction,
                          validator: _validateConfirm,
                          decoration: _passwordInputDecoration(
                            hint: "Confirm Password",
                            obscure: _obscureConfirm,
                            onToggle: () {
                              setState(() {
                                _obscureConfirm = !_obscureConfirm;
                              });
                            },
                          ),
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
                            onPressed: _loading ? null : _updatePassword,
                            child: _loading
                                ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                                : const Text("Update Password", style: TextStyle(fontWeight: FontWeight.w800)),
                          ),
                        ),
          ],
        ),
      ),
    );
  }
}




