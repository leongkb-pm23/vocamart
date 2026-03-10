// How this file works:
// 1) Data/models are declared first (if any).
// 2) UI widgets are built in build() methods.
// 3) Helper methods are used to keep UI code clean.

// File purpose: This file handles edit profile page screen/logic.

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:fyp/User/login.dart';

// This class defines EditProfilePage, used for this page/feature.
class EditProfilePage extends StatefulWidget {
  static const routeName = '/edit-profile';
  const EditProfilePage({super.key});

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

// This class defines _EditProfilePageState, used for this page/feature.
class _EditProfilePageState extends State<EditProfilePage> {
  static const kOrange = Color(0xFFFF6A00);

  final _formKey = GlobalKey<FormState>();

  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();

  bool _loading = true;
  bool _saving = false;

  DocumentReference<Map<String, dynamic>>? _docRef;

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  String _readText(
    Map<String, dynamic>? data,
    List<String> keys, {
    String fallback = '',
  }) {
    if (data != null) {
      for (final key in keys) {
        final raw = data[key];
        if (raw == null) continue;
        final text = raw.toString().trim();
        if (text.isNotEmpty) return text;
      }
    }
    return fallback;
  }

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _addressCtrl.dispose();
    super.dispose();
  }

  Future<void> _ensureUserDocExists(User user) async {
    final ref = FirebaseFirestore.instance.collection('users').doc(user.uid);
    final snap = await ref.get();
    if (!snap.exists) {
      await ref.set({
        "name": user.displayName ?? "",
        "email": user.email ?? "",
        "phone": user.phoneNumber ?? "",
        "address": "",
        "createdAt": FieldValue.serverTimestamp(),
        "updatedAt": FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }
  }

  Future<void> _loadProfile() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, LoginPage.routeName);
      return;
    }

    setState(() {
      _loading = true;
    });

    _docRef = FirebaseFirestore.instance.collection('users').doc(user.uid);

    try {
      await _ensureUserDocExists(user);

      final snap = await _docRef!.get();
      final data = snap.data();

      _nameCtrl.text = _readText(
        data,
        const ['name', 'fullName', 'displayName', 'username'],
        fallback: (user.displayName ?? '').trim(),
      );
      _phoneCtrl.text = _readText(
        data,
        const ['phone', 'phoneNumber'],
        fallback: (user.phoneNumber ?? '').trim(),
      );
      _addressCtrl.text = _readText(
        data,
        const ['address', 'location'],
      );
    } on FirebaseException catch (e) {
      _showSnack("Firestore: ${e.code} - ${e.message}");
    } catch (e) {
      _showSnack("Failed to load profile: $e");
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> _saveProfile() async {
    if (_docRef == null) return;
    if (!_formKey.currentState!.validate()) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, LoginPage.routeName);
      return;
    }

    setState(() {
      _saving = true;
    });

    final payload = <String, dynamic>{
      "name": _nameCtrl.text.trim(),
      "phone": _phoneCtrl.text.trim(),
      "address": _addressCtrl.text.trim(),
      "email": user.email ?? "",
      "updatedAt": FieldValue.serverTimestamp(),
    };

    try {
      await _docRef!.set(payload, SetOptions(merge: true));

      final newName = _nameCtrl.text.trim();
      if (newName.isNotEmpty && newName != user.displayName) {
        await user.updateDisplayName(newName);
      }

      if (!mounted) return;
      _showSnack("Profile updated.");
      Navigator.pop(context);
    } on FirebaseException catch (e) {
      _showSnack("Save failed: ${e.code} - ${e.message}");
    } catch (e) {
      _showSnack("Save failed: $e");
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  @override
  // Builds and returns the UI for this widget.
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Edit Profile"),
        backgroundColor: kOrange,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: SafeArea(
        child: user == null
            ? _GuestLocked(
          onLogin: () {
            Navigator.pushReplacementNamed(context, LoginPage.routeName);
          },
        )
            : (_loading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 20),
          children: [
            const Text(
              "Update your information",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 12),

            Form(
              key: _formKey,
              child: Column(
                children: [
                  _Input(
                    label: "Name",
                    controller: _nameCtrl,
                    validator: (v) {
                      final t = (v ?? "").trim();
                      if (t.isEmpty) return "Name is required";
                      if (t.length < 2) return "Name is too short";
                      return null;
                    },
                  ),
                  const SizedBox(height: 10),

                  _Input(
                    label: "Phone",
                    controller: _phoneCtrl,
                    keyboardType: TextInputType.phone,
                    hint: "+60xxxxxxxxx",
                    validator: (v) {
                      final t = (v ?? "").trim();
                      if (t.isEmpty) return null; // optional
                      if (t.length < 8) return "Phone seems too short";
                      return null;
                    },
                  ),
                  const SizedBox(height: 10),

                  _Input(
                    label: "Address",
                    controller: _addressCtrl,
                    maxLines: 3,
                    hint: "Enter your address",
                  ),

                  const SizedBox(height: 14),

                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kOrange,
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: _saving ? null : _saveProfile,
                      child: _saving
                          ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                          : const Text(
                        "Save Changes",
                        style: TextStyle(fontWeight: FontWeight.w900),
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  Text(
                    "Email: ${user.email ?? "-"}",
                    style: const TextStyle(
                      color: Colors.black54,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        )),
      ),
    );
  }
}

/* ================== UI Helpers ================== */

// This class defines _GuestLocked, used for this page/feature.
class _GuestLocked extends StatelessWidget {
  static const kOrange = Color(0xFFFF6A00);
  final VoidCallback onLogin;

  const _GuestLocked({required this.onLogin});

  @override
  // Builds and returns the UI for this widget.
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.lock_outline, color: kOrange, size: 44),
            const SizedBox(height: 10),
            const Text(
              "Login required",
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
            ),
            const SizedBox(height: 6),
            const Text(
              "Please login to edit your profile.",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.black54, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: kOrange,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: onLogin,
                child: const Text(
                  "Login to continue",
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// This class defines _Input, used for this page/feature.
class _Input extends StatelessWidget {
  static const kOrange = Color(0xFFFF6A00);

  final String label;
  final TextEditingController controller;
  final String? hint;
  final int maxLines;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;

  const _Input({
    required this.label,
    required this.controller,
    this.hint,
    this.maxLines = 1,
    this.keyboardType,
    this.validator,
  });

  @override
  // Builds and returns the UI for this widget.
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      validator: validator,
      keyboardType: keyboardType,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: kOrange, width: 1.6),
        ),
      ),
    );
  }
}



