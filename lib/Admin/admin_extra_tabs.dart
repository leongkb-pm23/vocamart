// How this file works:
// 1) Data/models are declared first (if any).
// 2) UI widgets are built in build() methods.
// 3) Helper methods are used to keep UI code clean.
//
// File purpose: This file handles admin extra tabs screen/logic.

import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:intl_phone_field/intl_phone_field.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import 'package:fyp/components/confirm_dialog.dart';
import 'package:fyp/Admin/firestore_service.dart';

class UsersAdminTab extends StatelessWidget {
  final FirestoreService svc;
  const UsersAdminTab({super.key, required this.svc});

  void _showMsg(BuildContext context, String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<bool> _confirm(
      BuildContext context,
      String title,
      String message, {
        String confirmText = 'Yes',
      }) async {
    return showConfirmDialog(
      context,
      title: title,
      message: message,
      confirmText: confirmText,
    );
  }

  Widget _streamError(Object? error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          'Failed to load users.\n$error',
          textAlign: TextAlign.center,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
    );
  }

  Future<void> _setRole(
      BuildContext context,
      String userId,
      Map<String, dynamic> data,
      String newRole,
      ) async {
    final name =
    (data['name'] ?? data['displayName'] ?? data['email'] ?? userId)
        .toString();

    final ok = await _confirm(
      context,
      'Change Role',
      'Change role for "$name" to "$newRole"?',
      confirmText: 'Update',
    );
    if (!ok) return;

    try {
      final db = FirebaseFirestore.instance;
      final batch = db.batch();
      final userRef = db.collection('users').doc(userId);
      final adminRef = db.collection('admins').doc(userId);
      final superRef = db.collection('super_admins').doc(userId);
      final deliveryRef = db.collection('delivery_staff').doc(userId);

      final payload = {
        'role': newRole,
        'updatedAt': FieldValue.serverTimestamp(),
      };
      if (newRole != 'admin') {
        payload['storeId'] = FieldValue.delete();
        payload['storeName'] = FieldValue.delete();
      }
      batch.set(userRef, payload, SetOptions(merge: true));

      if (newRole == 'super_admin') {
        batch.set(superRef, {
          'email': (data['email'] ?? '').toString(),
          'name': (data['name'] ?? data['displayName'] ?? '').toString(),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
        batch.delete(adminRef);
        batch.delete(deliveryRef);
      } else if (newRole == 'admin') {
        batch.set(adminRef, {
          'email': (data['email'] ?? '').toString(),
          'name': (data['name'] ?? data['displayName'] ?? '').toString(),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
        batch.delete(superRef);
        batch.delete(deliveryRef);
      } else if (newRole == 'delivery') {
        batch.set(deliveryRef, {
          'email': (data['email'] ?? '').toString(),
          'name': (data['name'] ?? data['displayName'] ?? '').toString(),
          'enabled': true,
          'deliveryOnDuty': (data['deliveryOnDuty'] ?? true) == true,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
        batch.delete(superRef);
        batch.delete(adminRef);
      } else {
        batch.delete(superRef);
        batch.delete(adminRef);
        batch.delete(deliveryRef);
      }

      await batch.commit();

      if (context.mounted) {
        _showMsg(context, 'Role updated to $newRole.');
      }
    } on FirebaseException catch (e) {
      if (context.mounted) {
        _showMsg(context, 'Update failed: ${e.message ?? e.code}');
      }
    } catch (e) {
      if (context.mounted) _showMsg(context, 'Update failed: $e');
    }
  }

  Future<void> _toggleBlocked(
      BuildContext context,
      String userId,
      Map<String, dynamic> data,
      ) async {
    final blocked = (data['blocked'] ?? false) == true;
    final name =
    (data['name'] ?? data['displayName'] ?? data['email'] ?? userId)
        .toString();

    final ok = await _confirm(
      context,
      blocked ? 'Unblock User' : 'Block User',
      blocked
          ? 'Unblock "$name"?'
          : 'Block "$name"? The user may be restricted from using the app.',
      confirmText: blocked ? 'Unblock' : 'Block',
    );
    if (!ok) return;

    try {
      await FirebaseFirestore.instance.collection('users').doc(userId).set({
        'blocked': !blocked,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (context.mounted) {
        _showMsg(context, blocked ? 'User unblocked.' : 'User blocked.');
      }
    } on FirebaseException catch (e) {
      if (context.mounted) {
        _showMsg(context, 'Update failed: ${e.message ?? e.code}');
      }
    } catch (e) {
      if (context.mounted) _showMsg(context, 'Update failed: $e');
    }
  }

  String _nameOf(Map<String, dynamic> d, String id) {
    return (d['name'] ?? d['displayName'] ?? d['email'] ?? id).toString();
  }

  String _emailOf(Map<String, dynamic> d) {
    return (d['email'] ?? '').toString();
  }

  Future<void> _addOrEditUser(
      BuildContext context, {
        String? userId,
        Map<String, dynamic>? data,
      }) async {
    final formKey = GlobalKey<FormState>();
    final isAddMode = userId == null;
    final nameCtrl = TextEditingController(
      text: (data?['name'] ?? data?['displayName'] ?? '').toString(),
    );
    final emailCtrl = TextEditingController(
      text: (data?['email'] ?? '').toString(),
    );
    final phoneCtrl = TextEditingController();
    final addressCtrl = TextEditingController(
      text: (data?['address'] ?? '').toString(),
    );
    final passwordCtrl = TextEditingController();
    final confirmPasswordCtrl = TextEditingController();

    var role = (data?['role'] ?? 'user').toString().trim();
    if (role.isEmpty) role = 'user';
    var blocked = (data?['blocked'] ?? false) == true;
    var onDuty = (data?['deliveryOnDuty'] ?? true) == true;
    var gender = (data?['gender'] ?? '').toString().trim().toLowerCase();
    if (gender != 'male' && gender != 'female') gender = '';
    DateTime? dob;
    final rawDob = data?['dob'];
    if (rawDob is Timestamp) {
      dob = rawDob.toDate();
    } else if (rawDob is DateTime) {
      dob = rawDob;
    }
    var saving = false;
    var obscurePw = true;
    var obscureConfirm = true;
    var phoneE164 = (data?['phone'] ?? '').toString().trim();
    String? errorText;
    final emailPattern = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');

    bool hasUpper(String s) => RegExp(r'[A-Z]').hasMatch(s);
    bool hasLower(String s) => RegExp(r'[a-z]').hasMatch(s);
    bool hasNumber(String s) => RegExp(r'\d').hasMatch(s);
    bool hasSymbol(String s) => RegExp(r'[@#*]').hasMatch(s);

    bool pwAllOk(String s) {
      return s.length >= 8 &&
          hasUpper(s) &&
          hasLower(s) &&
          hasNumber(s) &&
          hasSymbol(s);
    }

    Widget ruleItem(bool ok, String text) {
      return Row(
        children: [
          Icon(
            ok ? Icons.check_circle : Icons.cancel,
            size: 16,
            color: ok ? Colors.green : Colors.red,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: ok ? Colors.green : Colors.red,
                fontSize: 12,
              ),
            ),
          ),
        ],
      );
    }

    int ageFromDob(DateTime value) {
      final today = DateTime.now();
      int age = today.year - value.year;
      final hadBirthday =
          (today.month > value.month) ||
              (today.month == value.month && today.day >= value.day);
      if (!hadBirthday) age--;
      return age;
    }

    String formatDob(DateTime value) {
      String two(int n) => n.toString().padLeft(2, '0');
      return '${two(value.day)}/${two(value.month)}/${value.year}';
    }

    await showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            return AlertDialog(
              title: Text(userId == null ? 'Add User' : 'Edit User'),
              content: SingleChildScrollView(
                child: Form(
                  key: formKey,
                  autovalidateMode: AutovalidateMode.always,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        controller: nameCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Name',
                          border: OutlineInputBorder(),
                        ),
                        validator: (v) {
                          final value = (v ?? '').trim();
                          if (value.isEmpty) return 'Name is required';
                          return null;
                        },
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: emailCtrl,
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(
                          labelText: 'Email',
                          border: OutlineInputBorder(),
                        ),
                        validator: (v) {
                          final value = (v ?? '').trim();
                          if (value.isEmpty) return 'Email is required';
                          if (!emailPattern.hasMatch(value)) {
                            return 'Enter a valid email';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 10),
                      IntlPhoneField(
                        controller: phoneCtrl,
                        initialCountryCode: 'MY',
                        disableLengthCheck: true,
                        decoration: const InputDecoration(
                          labelText: 'Phone',
                          border: OutlineInputBorder(),
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 14,
                          ),
                        ),
                        validator: (phone) {
                          if (phone == null || phone.number.trim().isEmpty) {
                            return 'Phone number is required';
                          }
                          if (!RegExp(r'^\d+$').hasMatch(phone.number)) {
                            return 'Digits only';
                          }
                          return null;
                        },
                        onChanged: (phone) {
                          phoneE164 = phone.completeNumber;
                        },
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: addressCtrl,
                        maxLines: 2,
                        decoration: const InputDecoration(
                          labelText: 'Address',
                          border: OutlineInputBorder(),
                        ),
                        validator: (v) {
                          final value = (v ?? '').trim();
                          if (value.isEmpty) return 'Address is required';
                          return null;
                        },
                      ),
                      const SizedBox(height: 10),
                      DropdownButtonFormField<String>(
                        value: gender.isEmpty ? null : gender,
                        decoration: const InputDecoration(
                          labelText: 'Gender',
                          border: OutlineInputBorder(),
                        ),
                        items: const [
                          DropdownMenuItem(value: 'male', child: Text('Male')),
                          DropdownMenuItem(
                            value: 'female',
                            child: Text('Female'),
                          ),
                        ],
                        onChanged: (v) {
                          setDialogState(() => gender = (v ?? '').trim());
                        },
                        validator: (v) {
                          final value = (v ?? '').trim();
                          if (value.isEmpty) return 'Gender is required';
                          return null;
                        },
                      ),
                      const SizedBox(height: 10),
                      FormField<String>(
                        initialValue: dob == null ? '' : formatDob(dob!),
                        autovalidateMode: AutovalidateMode.onUserInteraction,
                        validator: (_) {
                          if (dob == null) return 'Date of birth is required';
                          if (ageFromDob(dob!) < 18) {
                            return 'You must be at least 18 years old';
                          }
                          return null;
                        },
                        builder: (field) {
                          final hasError = field.errorText != null;
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              InkWell(
                                onTap: () async {
                                  final now = DateTime.now();
                                  final initial =
                                      dob ??
                                          DateTime(
                                            now.year - 18,
                                            now.month,
                                            now.day,
                                          );
                                  final picked = await showDatePicker(
                                    context: dialogContext,
                                    initialDate: initial,
                                    firstDate: DateTime(1900),
                                    lastDate: now,
                                  );
                                  if (picked == null) return;
                                  setDialogState(() => dob = picked);
                                  field.didChange(formatDob(picked));
                                  field.validate();
                                },
                                child: InputDecorator(
                                  decoration: InputDecoration(
                                    labelText: 'Date of Birth',
                                    border: const OutlineInputBorder(),
                                    errorText:
                                    hasError ? field.errorText : null,
                                  ),
                                  child: Text(
                                    dob == null
                                        ? 'DD/MM/YYYY'
                                        : formatDob(dob!),
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                      if (isAddMode) ...[
                        const SizedBox(height: 10),
                        TextFormField(
                          controller: passwordCtrl,
                          obscureText: obscurePw,
                          onChanged: (_) => setDialogState(() {}),
                          decoration: InputDecoration(
                            labelText: 'Password',
                            border: const OutlineInputBorder(),
                            suffixIcon: IconButton(
                              onPressed: () {
                                setDialogState(() => obscurePw = !obscurePw);
                              },
                              icon: Icon(
                                obscurePw
                                    ? Icons.visibility_off
                                    : Icons.visibility,
                              ),
                            ),
                          ),
                          validator: (v) {
                            final value = v ?? '';
                            if (value.isEmpty) return 'Password is required';
                            if (value.length < 8) {
                              return 'Password must be at least 8 characters';
                            }
                            if (!hasNumber(value)) {
                              return 'Password must contain numbers';
                            }
                            if (!hasUpper(value)) {
                              return 'Password must contain uppercase';
                            }
                            if (!hasLower(value)) {
                              return 'Password must contain lowercase';
                            }
                            if (!hasSymbol(value)) {
                              return 'Password must have at least one @#* symbol';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 8),
                        ruleItem(
                          hasNumber(passwordCtrl.text),
                          'Password must contain numbers',
                        ),
                        ruleItem(
                          hasUpper(passwordCtrl.text),
                          'Password must contain uppercase',
                        ),
                        ruleItem(
                          hasLower(passwordCtrl.text),
                          'Password must contain lowercase',
                        ),
                        ruleItem(
                          hasSymbol(passwordCtrl.text),
                          'Password must have at least one @#* symbol',
                        ),
                        ruleItem(
                          passwordCtrl.text.length >= 8,
                          'Password length min 8',
                        ),
                        const SizedBox(height: 10),
                        TextFormField(
                          controller: confirmPasswordCtrl,
                          obscureText: obscureConfirm,
                          onChanged: (_) => setDialogState(() {}),
                          decoration: InputDecoration(
                            labelText: 'Confirm Password',
                            border: const OutlineInputBorder(),
                            suffixIcon: IconButton(
                              onPressed: () {
                                setDialogState(
                                      () => obscureConfirm = !obscureConfirm,
                                );
                              },
                              icon: Icon(
                                obscureConfirm
                                    ? Icons.visibility_off
                                    : Icons.visibility,
                              ),
                            ),
                          ),
                          validator: (v) {
                            final value = v ?? '';
                            if (value.isEmpty) return 'Confirm your password';
                            if (value != passwordCtrl.text) {
                              return 'Passwords do not match';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 8),
                        ruleItem(
                          confirmPasswordCtrl.text.isNotEmpty &&
                              confirmPasswordCtrl.text == passwordCtrl.text,
                          'Confirm password must match',
                        ),
                      ],
                      const SizedBox(height: 10),
                      DropdownButtonFormField<String>(
                        value: role,
                        decoration: const InputDecoration(
                          labelText: 'Role',
                          border: OutlineInputBorder(),
                        ),
                        items: const [
                          DropdownMenuItem(value: 'user', child: Text('User')),
                          DropdownMenuItem(
                            value: 'admin',
                            child: Text('Store Admin'),
                          ),
                          DropdownMenuItem(
                            value: 'super_admin',
                            child: Text('Super Admin'),
                          ),
                          DropdownMenuItem(
                            value: 'delivery',
                            child: Text('Delivery'),
                          ),
                        ],
                        onChanged: (v) {
                          setDialogState(() {
                            role = (v ?? 'user').trim();
                          });
                        },
                        validator: (v) {
                          final value = (v ?? '').trim();
                          if (value.isEmpty) return 'Role is required';
                          return null;
                        },
                      ),
                      const SizedBox(height: 6),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Blocked'),
                        value: blocked,
                        onChanged: (v) {
                          setDialogState(() => blocked = v);
                        },
                      ),
                      if (role == 'delivery')
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Delivery On Duty'),
                          value: onDuty,
                          onChanged: (v) {
                            setDialogState(() => onDuty = v);
                          },
                        ),
                      if (errorText != null)
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            errorText!,
                            style: const TextStyle(
                              color: Colors.red,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: saving ? null : () => Navigator.pop(dialogContext),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed:
                  !saving
                      ? () async {
                    if (!formKey.currentState!.validate()) return;
                    if ((phoneE164).trim().isEmpty) {
                      setDialogState(() {
                        errorText = 'Phone number is required';
                      });
                      return;
                    }
                    if (isAddMode && !pwAllOk(passwordCtrl.text)) {
                      setDialogState(() {
                        errorText =
                        'Password does not meet the requirements.';
                      });
                      return;
                    }
                    if (gender.isEmpty) {
                      setDialogState(() {
                        errorText = 'Gender is required';
                      });
                      return;
                    }
                    if (dob == null) {
                      setDialogState(() {
                        errorText = 'Date of birth is required';
                      });
                      return;
                    }
                    if (ageFromDob(dob!) < 18) {
                      setDialogState(() {
                        errorText = 'You must be at least 18 years old';
                      });
                      return;
                    }

                    setDialogState(() {
                      saving = true;
                      errorText = null;
                    });

                    FirebaseApp? secondaryApp;
                    FirebaseAuth? secondaryAuth;
                    User? createdAuthUser;
                    try {
                      final users = FirebaseFirestore.instance
                          .collection('users');
                      late final DocumentReference<Map<String, dynamic>>
                      docRef;

                      if (isAddMode) {
                        final appName =
                            'admin_create_user_${DateTime.now().millisecondsSinceEpoch}';
                        secondaryApp = await Firebase.initializeApp(
                          name: appName,
                          options: Firebase.app().options,
                        );
                        secondaryAuth = FirebaseAuth.instanceFor(
                          app: secondaryApp,
                        );
                        final cred = await secondaryAuth
                            .createUserWithEmailAndPassword(
                          email:
                          emailCtrl.text.trim().toLowerCase(),
                          password: passwordCtrl.text,
                        );
                        createdAuthUser = cred.user;
                        docRef = users.doc(cred.user!.uid);
                      } else {
                        docRef = users.doc(userId);
                      }

                      final payload = <String, dynamic>{
                        'uid': docRef.id,
                        'userId': docRef.id,
                        'name': nameCtrl.text.trim(),
                        'fullName': nameCtrl.text.trim(),
                        'displayName': nameCtrl.text.trim(),
                        'email': emailCtrl.text.trim().toLowerCase(),
                        'phone': phoneE164.trim(),
                        'address': addressCtrl.text.trim(),
                        'gender': gender,
                        'dob': Timestamp.fromDate(dob!),
                        'role': role,
                        'blocked': blocked,
                        'deliveryOnDuty':
                        role == 'delivery' ? onDuty : false,
                        'updatedAt': FieldValue.serverTimestamp(),
                        if (isAddMode)
                          'createdAt': FieldValue.serverTimestamp(),
                      };

                      await docRef.set(
                        payload,
                        SetOptions(merge: true),
                      );

                      final db = FirebaseFirestore.instance;
                      final adminRef = db
                          .collection('admins')
                          .doc(docRef.id);
                      final superRef = db
                          .collection('super_admins')
                          .doc(docRef.id);
                      final deliveryRef = db
                          .collection('delivery_staff')
                          .doc(docRef.id);

                      if (role == 'super_admin') {
                        await superRef.set({
                          'email': emailCtrl.text.trim().toLowerCase(),
                          'name': nameCtrl.text.trim(),
                          'updatedAt': FieldValue.serverTimestamp(),
                        }, SetOptions(merge: true));
                        try {
                          await adminRef.delete();
                        } catch (_) {}
                        try {
                          await deliveryRef.delete();
                        } catch (_) {}
                      } else if (role == 'admin') {
                        await adminRef.set({
                          'email': emailCtrl.text.trim().toLowerCase(),
                          'name': nameCtrl.text.trim(),
                          'updatedAt': FieldValue.serverTimestamp(),
                        }, SetOptions(merge: true));
                        try {
                          await superRef.delete();
                        } catch (_) {}
                        try {
                          await deliveryRef.delete();
                        } catch (_) {}
                      } else if (role == 'delivery') {
                        await deliveryRef.set({
                          'email': emailCtrl.text.trim().toLowerCase(),
                          'name': nameCtrl.text.trim(),
                          'enabled': true,
                          'deliveryOnDuty': onDuty,
                          'updatedAt': FieldValue.serverTimestamp(),
                        }, SetOptions(merge: true));
                        try {
                          await superRef.delete();
                        } catch (_) {}
                        try {
                          await adminRef.delete();
                        } catch (_) {}
                      } else {
                        try {
                          await superRef.delete();
                        } catch (_) {}
                        try {
                          await adminRef.delete();
                        } catch (_) {}
                        try {
                          await deliveryRef.delete();
                        } catch (_) {}
                      }

                      if (isAddMode) {
                        await secondaryAuth?.signOut();
                        await secondaryApp?.delete();
                      }
                      if (!context.mounted) return;
                      Navigator.pop(dialogContext);
                      _showMsg(
                        context,
                        userId == null
                            ? 'User added successfully.'
                            : 'User updated successfully.',
                      );
                    } on FirebaseAuthException catch (e) {
                      if (isAddMode) {
                        try {
                          await secondaryAuth?.signOut();
                        } catch (_) {}
                        try {
                          await secondaryApp?.delete();
                        } catch (_) {}
                      }
                      String msg = 'Registration failed.';
                      if (e.code == 'email-already-in-use') {
                        msg = 'This email is already registered.';
                      } else if (e.code == 'invalid-email') {
                        msg = 'Invalid email format.';
                      } else if (e.code == 'weak-password') {
                        msg = 'Password too weak.';
                      } else if (e.message != null &&
                          e.message!.trim().isNotEmpty) {
                        msg = e.message!;
                      }
                      setDialogState(() {
                        saving = false;
                        errorText = msg;
                      });
                    } on FirebaseException catch (e) {
                      if (isAddMode && e.code == 'permission-denied') {
                        try {
                          await createdAuthUser?.delete();
                        } catch (_) {}
                      }
                      if (isAddMode) {
                        try {
                          await secondaryAuth?.signOut();
                        } catch (_) {}
                        try {
                          await secondaryApp?.delete();
                        } catch (_) {}
                      }
                      setDialogState(() {
                        saving = false;
                        if (e.code == 'permission-denied') {
                          errorText =
                          'Save blocked by Firestore rules. '
                              'Your admin account is missing write permission for users/{uid}.';
                        } else {
                          errorText =
                          'Save failed: ${e.message ?? e.code}';
                        }
                      });
                    } catch (e) {
                      if (isAddMode) {
                        try {
                          await secondaryAuth?.signOut();
                        } catch (_) {}
                        try {
                          await secondaryApp?.delete();
                        } catch (_) {}
                      }
                      setDialogState(() {
                        saving = false;
                        errorText = 'Save failed: $e';
                      });
                    }
                  }
                      : null,
                  child: Text(userId == null ? 'Add' : 'Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream:
      FirebaseFirestore.instance
          .collection('users')
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snap) {
        if (snap.hasError) return _streamError(snap.error);
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snap.data!.docs;

        return Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            children: [
              _SectionCountHeader(
                title: 'Users',
                subtitle: 'Manage user accounts, roles, and access.',
                icon: Icons.people_alt_outlined,
                countText: '${docs.length}',
              ),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _addOrEditUser(context),
                  icon: const Icon(Icons.person_add_alt_1_outlined),
                  label: const Text('Add User'),
                ),
              ),
              const SizedBox(height: 10),
              Expanded(
                child:
                docs.isEmpty
                    ? const Center(
                  child: Text(
                    'No users yet',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                )
                    : ListView.separated(
                  itemCount: docs.length,
                  separatorBuilder:
                      (_, __) => const SizedBox(height: 10),
                  itemBuilder: (_, i) {
                    final d = docs[i];
                    final data = d.data();
                    final role =
                    (data['role'] ?? 'user').toString().trim();
                    final blocked = (data['blocked'] ?? false) == true;
                    final onDuty =
                        (data['deliveryOnDuty'] ?? true) == true;

                    return Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFFF7FAFF),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: const Color(0xFFE6E6E6),
                        ),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                        leading: CircleAvatar(
                          backgroundColor:
                          blocked
                              ? const Color(0xFFFFEBEE)
                              : const Color(0xFFE3F2FD),
                          foregroundColor:
                          blocked
                              ? const Color(0xFFD32F2F)
                              : const Color(0xFF1565C0),
                          child: Icon(
                            blocked
                                ? Icons.block_outlined
                                : Icons.person_outline,
                          ),
                        ),
                        title: Text(
                          _nameOf(data, d.id),
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (_emailOf(data).isNotEmpty)
                              Text(_emailOf(data)),
                            const SizedBox(height: 4),
                            Wrap(
                              spacing: 8,
                              runSpacing: 6,
                              children: [
                                _chip('Role: $role'),
                                if (role == 'delivery')
                                  _chip(
                                    onDuty ? 'On Duty' : 'Off Duty',
                                  ),
                                _chip(blocked ? 'Blocked' : 'Active'),
                              ],
                            ),
                          ],
                        ),
                        trailing: PopupMenuButton<String>(
                          onSelected: (value) async {
                            if (value == 'edit') {
                              await _addOrEditUser(
                                context,
                                userId: d.id,
                                data: data,
                              );
                            } else if (value == 'user' ||
                                value == 'admin' ||
                                value == 'super_admin' ||
                                value == 'delivery') {
                              await _setRole(
                                context,
                                d.id,
                                data,
                                value,
                              );
                            } else if (value == 'block') {
                              await _toggleBlocked(context, d.id, data);
                            }
                          },
                          itemBuilder:
                              (_) => [
                            const PopupMenuItem(
                              value: 'edit',
                              child: Text('Edit User'),
                            ),
                            const PopupMenuItem(
                              value: 'user',
                              child: Text('Set as User'),
                            ),
                            const PopupMenuItem(
                              value: 'admin',
                              child: Text('Set as Store Admin'),
                            ),
                            const PopupMenuItem(
                              value: 'super_admin',
                              child: Text('Set as Super Admin'),
                            ),
                            const PopupMenuItem(
                              value: 'delivery',
                              child: Text('Set as Delivery'),
                            ),
                            PopupMenuItem(
                              value: 'block',
                              child: Text(
                                blocked
                                    ? 'Unblock User'
                                    : 'Block User',
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class OrdersAdminTab extends StatefulWidget {
  final FirestoreService svc;
  final bool canAssignDelivery;
  const OrdersAdminTab({
    super.key,
    required this.svc,
    this.canAssignDelivery = true,
  });

  @override
  State<OrdersAdminTab> createState() => _OrdersAdminTabState();
}

class _OrdersAdminTabState extends State<OrdersAdminTab> {
  String _statusFilter = 'all';

  Future<bool> _confirm(
      BuildContext context,
      String title,
      String message, {
        String confirmText = 'Yes',
      }) async {
    return showConfirmDialog(
      context,
      title: title,
      message: message,
      confirmText: confirmText,
    );
  }

  void _showMsg(BuildContext context, String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Widget _streamError(Object? error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          'Failed to load orders.\n$error',
          textAlign: TextAlign.center,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
    );
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _ordersStream() {
    return FirebaseFirestore.instance.collectionGroup('orders').snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _deliveryUsersStream() {
    return FirebaseFirestore.instance
        .collection('users')
        .where('role', isEqualTo: 'delivery')
        .snapshots();
  }

  Future<void> _updateStatus(
      BuildContext context,
      DocumentReference<Map<String, dynamic>> ref,
      String newStatus,
      ) async {
    final ok = await _confirm(
      context,
      'Update Order Status',
      'Change order status to "$newStatus"?',
      confirmText: 'Update',
    );
    if (!ok) return;

    try {
      await widget.svc.updateOrderStatusByPath(
        orderPath: ref.path,
        status: newStatus,
      );

      if (context.mounted) {
        _showMsg(context, 'Order status updated.');
      }
    } on FirebaseException catch (e) {
      if (context.mounted) {
        _showMsg(context, 'Update failed: ${e.message ?? e.code}');
      }
    } catch (e) {
      if (context.mounted) _showMsg(context, 'Update failed: $e');
    }
  }

  Future<void> _assignDelivery(
      BuildContext context,
      DocumentReference<Map<String, dynamic>> orderRef,
      String? currentDeliveryId,
      ) async {
    final deliverySnap = await _deliveryUsersStream().first;
    if (!context.mounted) return;

    final docs = deliverySnap.docs;
    final available =
    docs
        .where((e) => (e.data()['deliveryOnDuty'] ?? true) == true)
        .toList();

    if (available.isEmpty) {
      _showMsg(
        context,
        'No delivery staff available now. Delivery staff may be off duty.',
      );
      return;
    }

    String? selectedId = currentDeliveryId;
    if (selectedId == null || selectedId.isEmpty) {
      selectedId = available.first.id;
    } else {
      final stillAvailable = available.any((e) => e.id == selectedId);
      if (!stillAvailable) selectedId = available.first.id;
    }

    await showDialog(
      context: context,
      builder: (dialogContext) {
        String? errorText;
        return StatefulBuilder(
          builder: (_, setDialogState) {
            return AlertDialog(
              title: const Text('Assign Delivery Staff'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<String>(
                      value: selectedId,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        labelText: 'Delivery Staff',
                      ),
                      items:
                      available
                          .map(
                            (e) => DropdownMenuItem<String>(
                          value: e.id,
                          child: Text(
                            ((e.data()['name'] ??
                                e.data()['displayName'] ??
                                e.data()['email'] ??
                                e.id))
                                .toString(),
                          ),
                        ),
                      )
                          .toList(),
                      onChanged: (v) {
                        setDialogState(() {
                          selectedId = v;
                        });
                      },
                    ),
                    if (errorText != null) ...[
                      const SizedBox(height: 10),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          errorText!,
                          style: const TextStyle(
                            color: Colors.red,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (selectedId == null || selectedId!.isEmpty) {
                      setDialogState(() {
                        errorText = 'Please select delivery staff.';
                      });
                      return;
                    }

                    final picked = available.firstWhere(
                          (e) => e.id == selectedId,
                    );
                    final staffName =
                    (picked.data()['name'] ??
                        picked.data()['displayName'] ??
                        picked.data()['email'] ??
                        picked.id)
                        .toString();
                    final staffEmail =
                    (picked.data()['email'] ?? '').toString().trim();

                    try {
                      // Use service flow so writes go to allowed path:
                      // delivery_staff/{uid}/assigned_orders/{orderKey}.
                      await widget.svc.assignDelivery(
                        orderPath: orderRef.path,
                        deliveryUid: selectedId!,
                        deliveryEmail: staffEmail,
                      );

                      // Keep legacy fields for existing admin/user UI labels.
                      await orderRef.set({
                        'deliveryId': selectedId,
                        'deliveryName': staffName,
                        'updatedAt': FieldValue.serverTimestamp(),
                      }, SetOptions(merge: true));

                      if (context.mounted) {
                        Navigator.pop(dialogContext);
                        _showMsg(context, 'Delivery staff assigned.');
                      }
                    } on FirebaseException catch (e) {
                      if (context.mounted) {
                        _showMsg(
                          context,
                          'Assign failed: ${e.message ?? e.code}',
                        );
                      }
                    } catch (e) {
                      if (context.mounted) {
                        _showMsg(context, 'Assign failed: $e');
                      }
                    }
                  },
                  child: const Text('Assign'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  String _priceText(dynamic v) {
    if (v == null) return 'RM 0.00';
    final n = (v as num).toDouble();
    return 'RM ${n.toStringAsFixed(2)}';
  }

  DateTime _asDate(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return DateTime.fromMillisecondsSinceEpoch(0);
  }

  @override
  Widget build(BuildContext context) {
    const statuses = [
      'all',
      'pending',
      'processing',
      'assigned',
      'shipping',
      'delivered',
      'cancelled',
    ];

    return Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        children: [
          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: _ordersStream(),
            builder: (context, snap) {
              final total = snap.data?.docs.length ?? 0;
              return _SectionCountHeader(
                title: 'Orders',
                subtitle: 'Manage order status and delivery assignment.',
                icon: Icons.receipt_long_outlined,
                countText: '$total',
              );
            },
          ),
          DropdownButtonFormField<String>(
            value: _statusFilter,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              labelText: 'Filter by Status',
            ),
            items:
            statuses
                .map(
                  (e) => DropdownMenuItem<String>(
                value: e,
                child: Text(e.toUpperCase()),
              ),
            )
                .toList(),
            onChanged: (v) {
              if (v == null) return;
              setState(() => _statusFilter = v);
            },
          ),
          const SizedBox(height: 12),
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _ordersStream(),
              builder: (context, snap) {
                if (snap.hasError) return _streamError(snap.error);
                if (!snap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                var docs = snap.data!.docs.toList();
                docs.sort((a, b) {
                  final ad = _asDate(a.data()['createdAt']);
                  final bd = _asDate(b.data()['createdAt']);
                  final c = bd.compareTo(ad);
                  if (c != 0) return c;
                  return b.id.compareTo(a.id);
                });
                if (_statusFilter != 'all') {
                  docs =
                      docs
                          .where(
                            (e) =>
                        (e.data()['status'] ?? '').toString() ==
                            _statusFilter,
                      )
                          .toList();
                }

                if (docs.isEmpty) {
                  return const Center(
                    child: Text(
                      'No orders found',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                  );
                }

                return ListView.separated(
                  itemCount: docs.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (_, i) {
                    final d = docs[i];
                    final o = d.data();

                    final status = (o['status'] ?? 'pending').toString();
                    final statusLower = status.trim().toLowerCase();
                    final deliveryStatusLower =
                    (o['deliveryStatus'] ?? '')
                        .toString()
                        .trim()
                        .toLowerCase();
                    final isFinalOrder =
                        statusLower == 'completed' ||
                            statusLower == 'delivered' ||
                            deliveryStatusLower == 'delivered';
                    final total = o['total'] ?? o['totalAmount'] ?? 0;
                    final customer =
                    (o['userName'] ??
                        o['customerName'] ??
                        o['email'] ??
                        'Unknown Customer')
                        .toString();
                    final deliveryName =
                    (o['deliveryName'] ?? '').toString().trim();
                    final ts = o['createdAt'];

                    String dateText = '-';
                    if (ts is Timestamp) {
                      dateText = DateFormat(
                        'dd MMM yyyy, hh:mm a',
                      ).format(ts.toDate());
                    }

                    return Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFFF7FAFF),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE6E6E6)),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const CircleAvatar(
                                  backgroundColor: Color(0xFFE3F2FD),
                                  foregroundColor: Color(0xFF1565C0),
                                  child: Icon(Icons.receipt_long_outlined),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Order ${d.id}',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w900,
                                          fontSize: 16,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(customer),
                                    ],
                                  ),
                                ),
                                _chip(status.toUpperCase()),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Text('Date: $dateText'),
                            Text('Total: ${_priceText(total)}'),
                            if (deliveryName.isNotEmpty)
                              Text('Delivery Staff: $deliveryName'),
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                OutlinedButton(
                                  onPressed:
                                  isFinalOrder
                                      ? null
                                      : () => _updateStatus(
                                    context,
                                    d.reference,
                                    'processing',
                                  ),
                                  child: const Text('Processing'),
                                ),
                                OutlinedButton(
                                  onPressed:
                                  isFinalOrder
                                      ? null
                                      : () => _updateStatus(
                                    context,
                                    d.reference,
                                    'shipping',
                                  ),
                                  child: const Text('Shipping'),
                                ),
                                OutlinedButton(
                                  onPressed:
                                  isFinalOrder
                                      ? null
                                      : () => _updateStatus(
                                    context,
                                    d.reference,
                                    'delivered',
                                  ),
                                  child: const Text('Delivered'),
                                ),
                                OutlinedButton(
                                  onPressed:
                                  isFinalOrder
                                      ? null
                                      : () => _updateStatus(
                                    context,
                                    d.reference,
                                    'cancelled',
                                  ),
                                  child: const Text('Cancelled'),
                                ),
                                if (widget.canAssignDelivery)
                                  ElevatedButton.icon(
                                    onPressed:
                                        () => _assignDelivery(
                                      context,
                                      d.reference,
                                      (o['deliveryId'] ?? '').toString(),
                                    ),
                                    icon: const Icon(
                                      Icons.local_shipping_outlined,
                                    ),
                                    label: const Text('Assign Delivery'),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class ReviewsAdminTab extends StatefulWidget {
  final FirestoreService svc;
  final String? fixedStoreId;
  const ReviewsAdminTab({super.key, required this.svc, this.fixedStoreId});

  @override
  State<ReviewsAdminTab> createState() => _ReviewsAdminTabState();
}

class _ReviewsAdminTabState extends State<ReviewsAdminTab> {
  String _categoryFilter = 'all';

  Future<bool> _confirm(
      BuildContext context,
      String title,
      String message, {
        String confirmText = 'Yes',
      }) async {
    return showConfirmDialog(
      context,
      title: title,
      message: message,
      confirmText: confirmText,
    );
  }

  void _showMsg(BuildContext context, String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Widget _streamError(Object? error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          'Failed to load reviews.\n$error',
          textAlign: TextAlign.center,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
    );
  }

  Future<void> _deleteReview(
      BuildContext context,
      DocumentReference<Map<String, dynamic>> ref,
      String title,
      ) async {
    final ok = await _confirm(
      context,
      'Delete Review',
      'Delete this review for "$title"?',
      confirmText: 'Delete',
    );
    if (!ok) return;

    try {
      await ref.delete();
      if (context.mounted) _showMsg(context, 'Review deleted.');
    } on FirebaseException catch (e) {
      if (context.mounted) {
        _showMsg(context, 'Delete failed: ${e.message ?? e.code}');
      }
    } catch (e) {
      if (context.mounted) _showMsg(context, 'Delete failed: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final reviewsStream =
    FirebaseFirestore.instance
        .collection('product_reviews')
        .orderBy('createdAt', descending: true)
        .snapshots();
    final productsStream =
    FirebaseFirestore.instance.collection('products').snapshots();

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: reviewsStream,
      builder: (context, reviewSnap) {
        if (reviewSnap.hasError) return _streamError(reviewSnap.error);
        if (!reviewSnap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: productsStream,
          builder: (context, productSnap) {
            if (!productSnap.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final productCategoryById = <String, String>{};
            final productStoreIdById = <String, String>{};
            for (final p in productSnap.data!.docs) {
              final pdata = p.data();
              final raw = (pdata['category'] ?? '').toString().trim();
              productCategoryById[p.id] = raw.isEmpty ? 'Uncategorized' : raw;
              productStoreIdById[p.id] =
                  (pdata['storeId'] ?? '').toString().trim();
            }

            String categoryOfReview(Map<String, dynamic> review) {
              final direct =
              (review['category'] ?? review['productCategory'] ?? '')
                  .toString()
                  .trim();
              if (direct.isNotEmpty) return direct;

              final productId = (review['productId'] ?? '').toString().trim();
              if (productId.isNotEmpty) {
                final mapped = productCategoryById[productId];
                if (mapped != null && mapped.trim().isNotEmpty) {
                  return mapped;
                }
              }
              return 'Uncategorized';
            }

            final cleanStoreId = (widget.fixedStoreId ?? '').trim();
            final allDocs =
            reviewSnap.data!.docs.where((d) {
              if (cleanStoreId.isEmpty) return true;
              final review = d.data();
              final reviewStoreId =
              (review['storeId'] ?? '').toString().trim();
              if (reviewStoreId == cleanStoreId) return true;
              final productId =
              (review['productId'] ?? '').toString().trim();
              final productStoreId = productStoreIdById[productId] ?? '';
              return productStoreId == cleanStoreId;
            }).toList();
            final categorySet = <String>{'all'};
            for (final d in allDocs) {
              categorySet.add(categoryOfReview(d.data()));
            }
            if (_categoryFilter.trim().isNotEmpty) {
              categorySet.add(_categoryFilter);
            }
            final categories =
            categorySet.toList()..sort((a, b) {
              if (a == 'all') return -1;
              if (b == 'all') return 1;
              return a.toLowerCase().compareTo(b.toLowerCase());
            });

            final docs =
            _categoryFilter == 'all'
                ? allDocs
                : allDocs
                .where(
                  (d) => categoryOfReview(d.data()) == _categoryFilter,
            )
                .toList();

            return Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                children: [
                  _SectionCountHeader(
                    title: 'Reviews',
                    subtitle: 'Moderate customer reviews and feedback.',
                    icon: Icons.rate_review_outlined,
                    countText: '${docs.length}',
                  ),
                  DropdownButtonFormField<String>(
                    value: _categoryFilter,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      labelText: 'Filter by Category',
                    ),
                    items:
                    categories
                        .map(
                          (c) => DropdownMenuItem<String>(
                        value: c,
                        child: Text(c == 'all' ? 'All Categories' : c),
                      ),
                    )
                        .toList(),
                    onChanged: (v) {
                      if (v == null) return;
                      setState(() => _categoryFilter = v);
                    },
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child:
                    docs.isEmpty
                        ? const Center(
                      child: Text(
                        'No reviews found',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                    )
                        : ListView.separated(
                      itemCount: docs.length,
                      separatorBuilder:
                          (_, __) => const SizedBox(height: 10),
                      itemBuilder: (_, i) {
                        final d = docs[i];
                        final r = d.data();

                        final product =
                        (r['productName'] ??
                            r['title'] ??
                            'Product')
                            .toString();
                        final user =
                        (r['userName'] ??
                            r['name'] ??
                            r['email'] ??
                            'Anonymous')
                            .toString();
                        final rating =
                        ((r['rating'] ?? 0) as num).toDouble();
                        final comment = (r['comment'] ?? '').toString();
                        final category = categoryOfReview(r);

                        return Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFFF7FAFF),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: const Color(0xFFE6E6E6),
                            ),
                          ),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 8,
                            ),
                            leading: const CircleAvatar(
                              backgroundColor: Color(0xFFE3F2FD),
                              foregroundColor: Color(0xFF1565C0),
                              child: Icon(Icons.rate_review_outlined),
                            ),
                            title: Text(
                              product,
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            subtitle: Column(
                              crossAxisAlignment:
                              CrossAxisAlignment.start,
                              children: [
                                Text('By: $user'),
                                const SizedBox(height: 4),
                                Text('Category: $category'),
                                const SizedBox(height: 4),
                                Text(
                                  'Rating: ${rating.toStringAsFixed(1)} / 5',
                                ),
                                if (comment.isNotEmpty) ...[
                                  const SizedBox(height: 6),
                                  Text(comment),
                                ],
                              ],
                            ),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete_outline),
                              onPressed:
                                  () => _deleteReview(
                                context,
                                d.reference,
                                product,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class EventsAdminTab extends StatelessWidget {
  final FirestoreService svc;
  final String? fixedStoreId;
  final String? fixedStoreName;
  const EventsAdminTab({
    super.key,
    required this.svc,
    this.fixedStoreId,
    this.fixedStoreName,
  });

  Future<bool> _confirm(
      BuildContext context,
      String title,
      String message, {
        String confirmText = 'Yes',
      }) async {
    return showConfirmDialog(
      context,
      title: title,
      message: message,
      confirmText: confirmText,
    );
  }

  void _showMsg(BuildContext context, String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Widget _streamError(Object? error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          'Failed to load events.\n$error',
          textAlign: TextAlign.center,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
    );
  }

  bool _isHttpImageUrl(String? raw) {
    if (raw == null || raw.trim().isEmpty) return false;
    final uri = Uri.tryParse(raw.trim());
    return uri != null && (uri.scheme == 'http' || uri.scheme == 'https');
  }

  String _eventDateText(Map<String, dynamic> eventData) {
    final rawDate = eventData['date'];
    if (rawDate is! Timestamp) return 'Date not set';
    return DateFormat('dd MMM yyyy').format(rawDate.toDate());
  }

  Future<void> _previewEvent(
      BuildContext context,
      String eventId,
      Map<String, dynamic> data,
      ) async {
    final title = (data['title'] ?? 'Untitled Event').toString();
    final description =
    (data['description'] ?? data['message'] ?? '').toString().trim();
    final imageUrl = (data['imageUrl'] ?? '').toString().trim();
    final dateText = _eventDateText(data);

    await showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(title),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: SizedBox(
                    width: double.infinity,
                    height: 180,
                    child:
                    _isHttpImageUrl(imageUrl)
                        ? Image.network(
                      imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) {
                        return const ColoredBox(
                          color: Color(0xFFF1F3F4),
                          child: Center(
                            child: Text('Unable to load image'),
                          ),
                        );
                      },
                    )
                        : const ColoredBox(
                      color: Color(0xFFF1F3F4),
                      child: Center(child: Text('No image')),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Text('Date: $dateText'),
                const SizedBox(height: 8),
                Text(
                  description.isEmpty
                      ? 'No description provided.'
                      : description,
                ),
                const SizedBox(height: 8),
                Text(
                  'Event ID: $eventId',
                  style: const TextStyle(
                    color: Colors.black54,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _toggleEventActive(
      BuildContext context,
      String eventId,
      bool currentValue,
      ) async {
    try {
      await FirebaseFirestore.instance.collection('events').doc(eventId).set({
        'active': !currentValue,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      if (context.mounted) {
        _showMsg(
          context,
          !currentValue ? 'Event activated.' : 'Event disabled.',
        );
      }
    } on FirebaseException catch (e) {
      if (context.mounted) {
        _showMsg(context, 'Update failed: ${e.message ?? e.code}');
      }
    } catch (e) {
      if (context.mounted) _showMsg(context, 'Update failed: $e');
    }
  }

  Future<void> _addOrEditEvent(
      BuildContext context, {
        String? eventId,
        Map<String, dynamic>? data,
      }) async {
    final titleCtrl = TextEditingController(
      text: (data?['title'] ?? '').toString(),
    );
    final descCtrl = TextEditingController(
      text: (data?['description'] ?? '').toString(),
    );
    final imageCtrl = TextEditingController(
      text: (data?['imageUrl'] ?? '').toString(),
    );
    bool active = (data?['active'] ?? true) == true;
    bool uploadingImage = false;
    final picker = ImagePicker();

    DateTime eventDate =
    (data?['date'] is Timestamp)
        ? (data!['date'] as Timestamp).toDate()
        : DateTime.now().add(const Duration(days: 7));

    Future<void> pickDate(StateSetter setDialogState) async {
      final picked = await showDatePicker(
        context: context,
        initialDate: eventDate,
        firstDate: DateTime.now().subtract(const Duration(days: 365)),
        lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
      );
      if (picked != null) {
        eventDate = DateTime(picked.year, picked.month, picked.day, 12, 0);
        setDialogState(() {});
      }
    }

    await showDialog(
      context: context,
      builder: (dialogContext) {
        String? errorText;

        return StatefulBuilder(
          builder: (_, setDialogState) {
            return AlertDialog(
              title: Text(eventId == null ? 'Add Event' : 'Edit Event'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: titleCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Title',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: descCtrl,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        labelText: 'Description',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Event Image',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: SizedBox(
                        width: double.infinity,
                        height: 220,
                        child:
                        imageCtrl.text.trim().isEmpty
                            ? Container(
                          color: const Color(0xFFF1F3F4),
                          alignment: Alignment.center,
                          child: const Text(
                            'No image selected',
                            style: TextStyle(
                              color: Colors.black54,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        )
                            : Container(
                          color: const Color(0xFFF1F3F4),
                          child: Image.network(
                            imageCtrl.text.trim(),
                            fit: BoxFit.contain,
                            errorBuilder: (_, __, ___) {
                              return Container(
                                color: const Color(0xFFF1F3F4),
                                alignment: Alignment.center,
                                child: const Text(
                                  'Unable to load image',
                                  style: TextStyle(
                                    color: Colors.black54,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed:
                        uploadingImage
                            ? null
                            : () async {
                          try {
                            final file = await picker.pickImage(
                              source: ImageSource.gallery,
                              imageQuality: 85,
                              maxWidth: 1800,
                            );
                            if (file == null) return;

                            setDialogState(() {
                              errorText = null;
                              uploadingImage = true;
                            });

                            final url = await svc.uploadImageXFile(
                              file: file,
                              folder: 'events',
                              fileNameHint: titleCtrl.text.trim(),
                            );
                            imageCtrl.text = url;
                            setDialogState(
                                  () => uploadingImage = false,
                            );
                            if (context.mounted) {
                              _showMsg(context, 'Image uploaded.');
                            }
                          } on FirebaseException catch (e) {
                            setDialogState(() {
                              uploadingImage = false;
                              errorText =
                              'Upload failed: ${e.message ?? e.code}';
                            });
                          } catch (e) {
                            setDialogState(() {
                              uploadingImage = false;
                              errorText = 'Upload failed: $e';
                            });
                          }
                        },
                        icon: const Icon(Icons.cloud_upload_outlined),
                        label: Text(
                          uploadingImage
                              ? 'Uploading image...'
                              : 'Upload Image to Storage',
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerRight,
                      child: OutlinedButton.icon(
                        onPressed:
                        uploadingImage
                            ? null
                            : () {
                          setDialogState(() => imageCtrl.clear());
                        },
                        icon: const Icon(Icons.delete_outline),
                        label: const Text('Remove Image'),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Event Date: ${DateFormat('dd MMM yyyy').format(eventDate)}',
                          ),
                        ),
                        TextButton(
                          onPressed: () => pickDate(setDialogState),
                          child: const Text('Pick'),
                        ),
                      ],
                    ),
                    SwitchListTile(
                      value: active,
                      onChanged: (v) => setDialogState(() => active = v),
                      title: const Text('Active'),
                    ),
                    if (errorText != null)
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          errorText!,
                          style: const TextStyle(
                            color: Colors.red,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (uploadingImage) {
                      setDialogState(() {
                        errorText =
                        'Please wait until image upload is complete.';
                      });
                      return;
                    }
                    final title = titleCtrl.text.trim();
                    final desc = descCtrl.text.trim();
                    final imageUrl = imageCtrl.text.trim();

                    if (title.isEmpty || desc.isEmpty) {
                      setDialogState(() {
                        errorText = 'Title and description are required.';
                      });
                      return;
                    }

                    try {
                      final ref =
                      eventId == null
                          ? FirebaseFirestore.instance
                          .collection('events')
                          .doc()
                          : FirebaseFirestore.instance
                          .collection('events')
                          .doc(eventId);

                      await ref.set({
                        'title': title,
                        'description': desc,
                        'message': desc,
                        'imageUrl': imageUrl,
                        'storeId': (fixedStoreId ?? '').trim(),
                        'storeName': (fixedStoreName ?? '').trim(),
                        'date': Timestamp.fromDate(eventDate),
                        'active': active,
                        'updatedAt': FieldValue.serverTimestamp(),
                        if (eventId == null)
                          'createdAt': FieldValue.serverTimestamp(),
                      }, SetOptions(merge: true));

                      if (context.mounted) {
                        Navigator.pop(dialogContext);
                        _showMsg(context, 'Event saved.');
                      }
                    } on FirebaseException catch (e) {
                      if (context.mounted) {
                        _showMsg(
                          context,
                          'Save failed: ${e.message ?? e.code}',
                        );
                      }
                    } catch (e) {
                      if (context.mounted) _showMsg(context, 'Save failed: $e');
                    }
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _deleteEvent(
      BuildContext context,
      String eventId,
      String title,
      ) async {
    final ok = await _confirm(
      context,
      'Delete Event',
      'Delete event "$title"?',
      confirmText: 'Delete',
    );
    if (!ok) return;

    try {
      await FirebaseFirestore.instance
          .collection('events')
          .doc(eventId)
          .delete();
      if (context.mounted) _showMsg(context, 'Event deleted.');
    } on FirebaseException catch (e) {
      if (context.mounted) {
        _showMsg(context, 'Delete failed: ${e.message ?? e.code}');
      }
    } catch (e) {
      if (context.mounted) _showMsg(context, 'Delete failed: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final cleanStoreId = (fixedStoreId ?? '').trim();
    final eventsQuery =
    cleanStoreId.isEmpty
        ? FirebaseFirestore.instance.collection('events')
        : FirebaseFirestore.instance
        .collection('events')
        .where('storeId', isEqualTo: cleanStoreId);

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: eventsQuery.snapshots(),
      builder: (context, snap) {
        if (snap.hasError) return _streamError(snap.error);
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs =
        snap.data!.docs.toList()..sort((a, b) {
          DateTime asDate(Object? v) {
            if (v is Timestamp) return v.toDate();
            if (v is DateTime) return v;
            return DateTime.fromMillisecondsSinceEpoch(0);
          }

          final ad = asDate(a.data()['date']);
          final bd = asDate(b.data()['date']);
          return bd.compareTo(ad);
        });

        return Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            children: [
              _SectionCountHeader(
                title: 'Events',
                subtitle: 'Create, update, and manage events.',
                icon: Icons.event_note_outlined,
                countText: '${docs.length}',
              ),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _addOrEditEvent(context),
                  icon: const Icon(Icons.add),
                  label: const Text('Add Event'),
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child:
                docs.isEmpty
                    ? const Center(
                  child: Text(
                    'No events yet',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                )
                    : ListView.separated(
                  itemCount: docs.length,
                  separatorBuilder:
                      (_, __) => const SizedBox(height: 10),
                  itemBuilder: (_, i) {
                    final d = docs[i];
                    final e = d.data();
                    final title =
                    (e['title'] ?? 'Untitled Event').toString();
                    final active = (e['active'] ?? false) == true;
                    final date = _eventDateText(e);
                    final imageUrl =
                    (e['imageUrl'] ?? '').toString().trim();

                    return Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFFF7FAFF),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: const Color(0xFFE6E6E6),
                        ),
                      ),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () => _previewEvent(context, d.id, e),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment:
                            CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment:
                                CrossAxisAlignment.start,
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(
                                      8,
                                    ),
                                    child: SizedBox(
                                      width: 52,
                                      height: 52,
                                      child:
                                      _isHttpImageUrl(imageUrl)
                                          ? Image.network(
                                        imageUrl,
                                        fit: BoxFit.cover,
                                        errorBuilder: (
                                            _,
                                            __,
                                            ___,
                                            ) {
                                          return const ColoredBox(
                                            color: Color(
                                              0xFFE3F2FD,
                                            ),
                                            child: Icon(
                                              Icons
                                                  .broken_image_outlined,
                                              color: Color(
                                                0xFF1565C0,
                                              ),
                                            ),
                                          );
                                        },
                                      )
                                          : const ColoredBox(
                                        color: Color(
                                          0xFFE3F2FD,
                                        ),
                                        child: Icon(
                                          Icons
                                              .event_note_outlined,
                                          color: Color(
                                            0xFF1565C0,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          title,
                                          maxLines: 1,
                                          overflow:
                                          TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w900,
                                            fontSize: 16,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          'Date: $date',
                                          style: const TextStyle(
                                            color: Colors.black54,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 8,
                                runSpacing: 4,
                                children: [
                                  Chip(
                                    label: Text(
                                      active ? 'Active' : 'Inactive',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    padding: EdgeInsets.zero,
                                    backgroundColor:
                                    active
                                        ? const Color(0xFFE8F5E9)
                                        : const Color(0xFFFFEBEE),
                                  ),
                                  Chip(
                                    label: Text(
                                      _isHttpImageUrl(imageUrl)
                                          ? 'Image ready'
                                          : 'No image',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    padding: EdgeInsets.zero,
                                    backgroundColor: const Color(
                                      0xFFE3F2FD,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                (e['description'] ?? e['message'] ?? '')
                                    .toString(),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 8),
                              Row(
                                mainAxisAlignment:
                                MainAxisAlignment.end,
                                children: [
                                  IconButton(
                                    tooltip: 'Preview',
                                    icon: const Icon(
                                      Icons.visibility_outlined,
                                    ),
                                    onPressed:
                                        () => _previewEvent(
                                      context,
                                      d.id,
                                      e,
                                    ),
                                  ),
                                  IconButton(
                                    tooltip:
                                    active
                                        ? 'Set inactive'
                                        : 'Set active',
                                    icon: Icon(
                                      active
                                          ? Icons.toggle_on_outlined
                                          : Icons.toggle_off_outlined,
                                    ),
                                    onPressed:
                                        () => _toggleEventActive(
                                      context,
                                      d.id,
                                      active,
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(
                                      Icons.edit_outlined,
                                    ),
                                    onPressed:
                                        () => _addOrEditEvent(
                                      context,
                                      eventId: d.id,
                                      data: e,
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(
                                      Icons.delete_outline,
                                    ),
                                    onPressed:
                                        () => _deleteEvent(
                                      context,
                                      d.id,
                                      title,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class ReportsAdminTab extends StatefulWidget {
  final FirestoreService svc;
  final String? fixedStoreId;
  const ReportsAdminTab({super.key, required this.svc, this.fixedStoreId});

  @override
  State<ReportsAdminTab> createState() => _ReportsAdminTabState();
}

enum _ReportPeriod { weekly, monthly, yearly }

class _ReportsAdminTabState extends State<ReportsAdminTab> {
  bool _loading = false;
  _ReportPeriod _selectedPeriod = _ReportPeriod.yearly;
  Future<Map<String, dynamic>>? _reportFuture;
  Map<String, dynamic>? _lastReportData;

  @override
  void initState() {
    super.initState();
    _refreshReport();
  }

  void _refreshReport() {
    _reportFuture = _loadReportData().then((data) {
      _lastReportData = data;
      return data;
    });
  }

  void _setPeriod(_ReportPeriod period) {
    if (_selectedPeriod == period) return;
    setState(() {
      _selectedPeriod = period;
      _refreshReport();
    });
  }

  void _showMsg(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  String _money(num value) {
    return 'RM ${value.toStringAsFixed(2)}';
  }

  String _dateTime(DateTime dt) {
    return DateFormat('dd MMM yyyy, hh:mm a').format(dt);
  }

  DateTime _atStartOfDay(DateTime dt) {
    return DateTime(dt.year, dt.month, dt.day);
  }

  DateTime _asDate(dynamic v) {
    if (v is Timestamp) return v.toDate();
    if (v is DateTime) return v;
    return DateTime.fromMillisecondsSinceEpoch(0);
  }

  int _asInt(dynamic v, {int fallback = 0}) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) {
      final parsed = int.tryParse(v.trim());
      if (parsed != null) return parsed;
    }
    return fallback;
  }

  double _asDouble(dynamic v, {double fallback = 0.0}) {
    if (v is num) return v.toDouble();
    if (v is String) {
      final parsed = double.tryParse(v.trim());
      if (parsed != null) return parsed;
    }
    return fallback;
  }

  DateTime _docTime(Map<String, dynamic> data) {
    return _asDate(
      data['createdAt'] ??
          data['paidAt'] ??
          data['updatedAt'] ??
          data['claimedAt'] ??
          data['endAt'],
    );
  }

  ({DateTime start, DateTime end}) _periodRange(
      _ReportPeriod period,
      DateTime now,
      ) {
    final dayStart = _atStartOfDay(now);
    if (period == _ReportPeriod.weekly) {
      final weekStart = dayStart.subtract(Duration(days: dayStart.weekday - 1));
      return (start: weekStart, end: weekStart.add(const Duration(days: 7)));
    }
    if (period == _ReportPeriod.monthly) {
      final monthStart = DateTime(dayStart.year, dayStart.month, 1);
      final monthEnd =
      (dayStart.month == 12)
          ? DateTime(dayStart.year + 1, 1, 1)
          : DateTime(dayStart.year, dayStart.month + 1, 1);
      return (start: monthStart, end: monthEnd);
    }
    final yearStart = DateTime(dayStart.year, 1, 1);
    final yearEnd = DateTime(dayStart.year + 1, 1, 1);
    return (start: yearStart, end: yearEnd);
  }

  bool _inRange(DateTime dt, DateTime start, DateTime end) {
    return !dt.isBefore(start) && dt.isBefore(end);
  }

  String _periodLabel(_ReportPeriod period) {
    if (period == _ReportPeriod.weekly) return 'Weekly';
    if (period == _ReportPeriod.monthly) return 'Monthly';
    return 'Yearly';
  }

  String _periodCode(_ReportPeriod period) {
    if (period == _ReportPeriod.weekly) return 'weekly';
    if (period == _ReportPeriod.monthly) return 'monthly';
    return 'yearly';
  }

  String _periodText(DateTime start, DateTime endExclusive) {
    final endInclusive = endExclusive.subtract(const Duration(milliseconds: 1));
    final f = DateFormat('dd MMM yyyy');
    return '${f.format(start)} - ${f.format(endInclusive)}';
  }

  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>> _safeQueryDocs(
      Future<QuerySnapshot<Map<String, dynamic>>> Function() loader,
      ) async {
    try {
      final snap = await loader();
      return snap.docs;
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied' || e.code == 'failed-precondition') {
        return const <QueryDocumentSnapshot<Map<String, dynamic>>>[];
      }
      rethrow;
    }
  }

  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>>
  _safeOrdersDocs() async {
    try {
      return await widget.svc.ordersAllForAdmin();
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied' || e.code == 'failed-precondition') {
        return const <QueryDocumentSnapshot<Map<String, dynamic>>>[];
      }
      rethrow;
    }
  }

  Future<Map<String, dynamic>> _loadReportData() async {
    final now = DateTime.now();
    final range = _periodRange(_selectedPeriod, now);
    final start = range.start;
    final end = range.end;
    final cleanStoreId = (widget.fixedStoreId ?? '').trim();
    final cleanStoreIdLower = cleanStoreId.toLowerCase();
    final scoped = cleanStoreId.isNotEmpty;
    final periodCode = _periodCode(_selectedPeriod);

    final db = FirebaseFirestore.instance;

    final results = await Future.wait<dynamic>([
      _safeQueryDocs(() => db.collection('stores').get()),
      _safeQueryDocs(() => db.collection('store_promotions').get()),
      _safeQueryDocs(() => db.collection('products').get()),
      _safeQueryDocs(() => db.collection('users').get()),
      _safeQueryDocs(() => db.collection('product_reviews').get()),
      _safeQueryDocs(() => db.collection('events').get()),
      _safeQueryDocs(() => db.collectionGroup('prices').get()),
      _safeOrdersDocs(),
    ]);

    final storesDocs =
    results[0] as List<QueryDocumentSnapshot<Map<String, dynamic>>>;
    final promosDocs =
    results[1] as List<QueryDocumentSnapshot<Map<String, dynamic>>>;
    final productsDocs =
    results[2] as List<QueryDocumentSnapshot<Map<String, dynamic>>>;
    final usersDocs =
    results[3] as List<QueryDocumentSnapshot<Map<String, dynamic>>>;
    final reviewsDocs =
    results[4] as List<QueryDocumentSnapshot<Map<String, dynamic>>>;
    final eventsDocs =
    results[5] as List<QueryDocumentSnapshot<Map<String, dynamic>>>;
    final pricesDocs =
    results[6] as List<QueryDocumentSnapshot<Map<String, dynamic>>>;
    final ordersDocs =
    results[7] as List<QueryDocumentSnapshot<Map<String, dynamic>>>;

    final stores =
    storesDocs
        .where((d) {
      if (!scoped) return true;
      return d.id.toLowerCase() == cleanStoreIdLower;
    })
        .where((d) => _inRange(_docTime(d.data()), start, end))
        .toList();

    final promotions =
    promosDocs
        .where((d) {
      if (!scoped) return true;
      final sid = (d.data()['storeId'] ?? '').toString().trim().toLowerCase();
      return sid == cleanStoreIdLower;
    })
        .where((d) => _inRange(_docTime(d.data()), start, end))
        .toList();

    final scopedProducts =
    productsDocs.where((d) {
      if (!scoped) return true;
      final sid = (d.data()['storeId'] ?? '').toString().trim().toLowerCase();
      return sid == cleanStoreIdLower;
    }).toList();

    final scopedProductIds = <String>{};
    for (final p in scopedProducts) {
      scopedProductIds.add(p.id);
    }

    if (scoped) {
      for (final priceDoc in pricesDocs) {
        final priceStoreId =
            (priceDoc.data()['storeId'] ?? priceDoc.id)
                .toString()
                .trim()
                .toLowerCase();
        if (priceStoreId != cleanStoreIdLower) continue;

        final pid = priceDoc.reference.parent.parent?.id ?? '';
        if (pid.isNotEmpty) {
          scopedProductIds.add(pid);
        }
      }

      if (scopedProductIds.isEmpty) {
        for (final productDoc in productsDocs) {
          try {
            final snap = await productDoc.reference
                .collection('prices')
                .where('storeId', isEqualTo: cleanStoreId)
                .limit(1)
                .get();

            if (snap.docs.isNotEmpty) {
              scopedProductIds.add(productDoc.id);
            }
          } on FirebaseException catch (e) {
            if (e.code == 'permission-denied' ||
                e.code == 'failed-precondition') {
              continue;
            }
            rethrow;
          }
        }
      }
    }

    final allStoreProducts =
    scoped
        ? productsDocs.where((d) => scopedProductIds.contains(d.id)).toList()
        : productsDocs;

    final products =
    allStoreProducts
        .where((d) => _inRange(_docTime(d.data()), start, end))
        .toList();

    final users =
    usersDocs
        .where((d) {
      if (!scoped) return true;
      final sid = (d.data()['storeId'] ?? '').toString().trim().toLowerCase();
      return sid == cleanStoreIdLower;
    })
        .where((d) => _inRange(_docTime(d.data()), start, end))
        .toList();

    final reviews =
    reviewsDocs
        .where((d) {
      if (!scoped) return true;
      final review = d.data();
      final sid = (review['storeId'] ?? '').toString().trim().toLowerCase();
      if (sid == cleanStoreIdLower) return true;

      final pid = (review['productId'] ?? '').toString().trim();
      return scopedProductIds.contains(pid);
    })
        .where((d) => _inRange(_docTime(d.data()), start, end))
        .toList();

    final events =
    eventsDocs
        .where((d) {
      if (!scoped) return true;
      final sid = (d.data()['storeId'] ?? '').toString().trim().toLowerCase();
      return sid == cleanStoreIdLower;
    })
        .where((d) => _inRange(_docTime(d.data()), start, end))
        .toList();

    final productIds = <String>{};
    final productCategoryById = <String, String>{};
    int totalPriceEntries = 0;

    for (final product in products) {
      final data = product.data();
      productIds.add(product.id);

      final category = (data['category'] ?? 'Uncategorized').toString().trim();
      productCategoryById[product.id] =
      category.isEmpty ? 'Uncategorized' : category;
    }

    for (final priceDoc in pricesDocs) {
      final productId = priceDoc.reference.parent.parent?.id ?? '';
      if (productId.isEmpty || !productIds.contains(productId)) continue;

      if (_inRange(_docTime(priceDoc.data()), start, end)) {
        totalPriceEntries++;
      }
    }

    int activePromotions = 0;
    for (final doc in promotions) {
      if (doc.data()['isActive'] == true) {
        activePromotions++;
      }
    }

    int activeEvents = 0;
    for (final doc in events) {
      if (doc.data()['active'] == true) {
        activeEvents++;
      }
    }

    int totalOrders = 0;
    int totalOrderItems = 0;
    double totalRevenue = 0.0;
    int ordersInPeriod = 0;

    final categoryItemCount = <String, int>{};
    final categoryOrderCount = <String, int>{};

    for (final orderDoc in ordersDocs) {
      final order = orderDoc.data();

      if (!_inRange(_docTime(order), start, end)) continue;
      ordersInPeriod++;

      final items = (order['items'] as List?) ?? const [];

      if (!scoped) {
        double orderRevenue = 0.0;
        final categoriesInOrder = <String>{};
        int orderItemQty = 0;
        bool hasAnyValidItem = false;

        for (final raw in items) {
          if (raw is! Map) continue;

          final item = Map<String, dynamic>.from(raw);
          final pid = (item['productId'] ?? '').toString().trim();

          int qty = 1;
          final qtyRaw = item['qty'];
          if (qtyRaw is int) qty = qtyRaw;
          if (qtyRaw is num) qty = qtyRaw.toInt();
          if (qty <= 0) qty = 1;

          double lineTotal = 0.0;
          final lt = item['lineTotal'];
          if (lt is num) {
            lineTotal = lt.toDouble();
          } else {
            final up = item['unitPrice'];
            if (up is num) {
              lineTotal = up.toDouble() * qty;
            }
          }

          hasAnyValidItem = true;
          orderRevenue += lineTotal;
          orderItemQty += qty;

          final category = (productCategoryById[pid] ?? 'Uncategorized').trim();
          final safeCategory = category.isEmpty ? 'Uncategorized' : category;

          categoryItemCount[safeCategory] =
              (categoryItemCount[safeCategory] ?? 0) + qty;
          categoriesInOrder.add(safeCategory);
        }

        if (!hasAnyValidItem) {
          final total = order['total'];
          if (total is num && total.toDouble() > 0) {
            totalOrders++;
            totalRevenue += total.toDouble();
          }
        } else {
          totalOrders++;
          totalOrderItems += orderItemQty;
          totalRevenue += orderRevenue;
        }

        for (final category in categoriesInOrder) {
          categoryOrderCount[category] =
              (categoryOrderCount[category] ?? 0) + 1;
        }

        continue;
      }

      bool hasThisStoreItem = false;
      double thisStoreRevenue = 0.0;
      int thisStoreItemQty = 0;
      final categoriesInOrder = <String>{};
      final orderStoreId =
          (order['storeId'] ?? '').toString().trim().toLowerCase();

      for (final raw in items) {
        if (raw is! Map) continue;

        final item = Map<String, dynamic>.from(raw);

        final itemStoreId =
            (item['storeId'] ?? '').toString().trim().toLowerCase();
        final itemProductId = (item['productId'] ?? '').toString().trim();

        final belongsToThisStore =
            itemStoreId == cleanStoreIdLower ||
                (itemStoreId.isEmpty && scopedProductIds.contains(itemProductId));

        if (!belongsToThisStore) continue;

        int qty = 1;
        final qtyRaw = item['qty'];
        if (qtyRaw is int) qty = qtyRaw;
        if (qtyRaw is num) qty = qtyRaw.toInt();
        if (qty <= 0) qty = 1;

        double lineTotal = 0.0;
        final lt = item['lineTotal'];
        if (lt is num) {
          lineTotal = lt.toDouble();
        } else {
          final up = item['unitPrice'];
          if (up is num) {
            lineTotal = up.toDouble() * qty;
          } else {
            final orderTotal = order['total'];
            if (orderTotal is num && qty > 0 && items.isNotEmpty) {
              lineTotal = orderTotal.toDouble() / items.length;
            }
          }
        }

        hasThisStoreItem = true;
        thisStoreRevenue += lineTotal;
        thisStoreItemQty += qty;

        final category =
        (productCategoryById[itemProductId] ?? 'Uncategorized').trim();
        final safeCategory = category.isEmpty ? 'Uncategorized' : category;

        categoryItemCount[safeCategory] =
            (categoryItemCount[safeCategory] ?? 0) + qty;
        categoriesInOrder.add(safeCategory);
      }

      if (hasThisStoreItem) {
        totalOrders++;
        totalOrderItems += thisStoreItemQty;
        totalRevenue += thisStoreRevenue;

        for (final category in categoriesInOrder) {
          categoryOrderCount[category] =
              (categoryOrderCount[category] ?? 0) + 1;
        }
      } else if (orderStoreId == cleanStoreIdLower) {
        // Legacy fallback for old orders missing per-item storeId.
        final total = order['total'];
        if (total is num && total.toDouble() > 0) {
          totalOrders++;
          totalRevenue += total.toDouble();
          totalOrderItems += items.length;

          for (final raw in items) {
            if (raw is! Map) continue;
            final item = Map<String, dynamic>.from(raw);
            final pid = (item['productId'] ?? '').toString().trim();
            int qty = 1;
            final qtyRaw = item['qty'];
            if (qtyRaw is int) qty = qtyRaw;
            if (qtyRaw is num) qty = qtyRaw.toInt();
            if (qty <= 0) qty = 1;

            final category =
                (productCategoryById[pid] ?? 'Uncategorized').trim();
            final safeCategory =
                category.isEmpty ? 'Uncategorized' : category;
            categoryItemCount[safeCategory] =
                (categoryItemCount[safeCategory] ?? 0) + qty;
            categoriesInOrder.add(safeCategory);
          }
          for (final category in categoriesInOrder) {
            categoryOrderCount[category] =
                (categoryOrderCount[category] ?? 0) + 1;
          }
        }
      }
    }

    final topCategoryStats = <Map<String, dynamic>>[];
    for (final entry in categoryItemCount.entries) {
      final category = entry.key;
      final items = entry.value;
      final orders = categoryOrderCount[category] ?? 0;
      topCategoryStats.add({
        'category': category,
        'items': items,
        'orders': orders,
      });
    }
    topCategoryStats.sort((a, b) {
      final byItems =
          ((b['items'] as int?) ?? 0).compareTo((a['items'] as int?) ?? 0);
      if (byItems != 0) return byItems;
      return ((b['orders'] as int?) ?? 0).compareTo(
        (a['orders'] as int?) ?? 0,
      );
    });

    bool usedCache = false;
    if (scoped && totalOrders == 0) {
      try {
        final cacheSnap =
            await db
                .collection('stores')
                .doc(cleanStoreId)
                .collection('report_cache')
                .doc(periodCode)
                .get();
        final cache = cacheSnap.data() ?? const <String, dynamic>{};
        final cacheOrders = _asInt(cache['orders'], fallback: 0);
        final cacheItems = _asInt(cache['orderItems'], fallback: 0);
        final cacheRevenue = _asDouble(cache['revenue'], fallback: 0.0);
        final cacheCatsRaw = cache['topCategoryStats'];
        final cacheCats = <Map<String, dynamic>>[];
        if (cacheCatsRaw is List) {
          for (final row in cacheCatsRaw) {
            if (row is Map) {
              cacheCats.add(Map<String, dynamic>.from(row));
            }
          }
        }
        if (cacheOrders > 0 || cacheItems > 0 || cacheRevenue > 0) {
          totalOrders = cacheOrders;
          totalOrderItems = cacheItems;
          totalRevenue = cacheRevenue;
          if (cacheCats.isNotEmpty) {
            topCategoryStats
              ..clear()
              ..addAll(cacheCats);
          }
          usedCache = true;
        }
      } on FirebaseException {
        // Ignore cache read issues.
      }
    }

    return {
      'generatedAt': now,
      'periodLabel': _periodLabel(_selectedPeriod),
      'periodCode': periodCode,
      'periodText': _periodText(start, end),
      'stores': stores.length,
      'promotions': promotions.length,
      'activePromotions': activePromotions,
      'products': products.length,
      'prices': totalPriceEntries,
      'users': users.length,
      'orders': totalOrders,
      'ordersInPeriod': ordersInPeriod,
      'orderItems': totalOrderItems,
      'reviews': reviews.length,
      'events': events.length,
      'activeEvents': activeEvents,
      'revenue': totalRevenue,
      'topCategoryStats': topCategoryStats,
      'usedCache': usedCache,
    };
  }

  Future<Uint8List> _buildPdf(Map<String, dynamic> data) async {
    final pdf = pw.Document();

    final generatedAt = data['generatedAt'] as DateTime;
    final periodLabel = (data['periodLabel'] ?? 'Period').toString();
    final periodText = (data['periodText'] ?? '-').toString();
    final products = data['products'] as int;
    final orders = data['orders'] as int;
    final orderItems = data['orderItems'] as int;
    final reviews = data['reviews'] as int;
    final revenue = (data['revenue'] as num).toDouble();
    final topCategoryStats =
    (data['topCategoryStats'] as List? ?? const [])
        .cast<Map<String, dynamic>>();
    final avgRevenuePerOrder = orders > 0 ? revenue / orders : 0.0;

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(26),
        build:
            (context) => [
          pw.Container(
            padding: const pw.EdgeInsets.all(14),
            decoration: pw.BoxDecoration(
              color: PdfColors.grey100,
              borderRadius: pw.BorderRadius.circular(12),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'VOCAMART ADMIN REPORT',
                  style: pw.TextStyle(
                    fontSize: 20,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.black,
                  ),
                ),
                pw.SizedBox(height: 8),
                pw.Text(
                  'Period: $periodLabel ($periodText)',
                  style: pw.TextStyle(
                    fontSize: 11,
                    color: PdfColors.grey700,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 4),
                pw.Text(
                  'Generated on: ${_dateTime(generatedAt)}',
                  style: pw.TextStyle(
                    fontSize: 10,
                    color: PdfColors.grey700,
                  ),
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 18),
          pw.Text(
            'Key Metrics',
            style: pw.TextStyle(
              fontSize: 15,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 10),
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey300),
            columnWidths: {
              0: const pw.FlexColumnWidth(3),
              1: const pw.FlexColumnWidth(2),
            },
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(
                  color: PdfColors.blue100,
                ),
                children: [
                  _pdfCell('Metric', bold: true),
                  _pdfCell('Value', bold: true),
                ],
              ),
              _pdfRow('Revenue', _money(revenue)),
              _pdfRow('Orders', '$orders'),
              _pdfRow('Order items', '$orderItems'),
              _pdfRow('Average order value', _money(avgRevenuePerOrder)),
              _pdfRow('Products', '$products'),
              _pdfRow('Reviews', '$reviews'),
            ],
          ),
          pw.SizedBox(height: 14),
          pw.Text(
            'Top Categories (By Ordered Items)',
            style: pw.TextStyle(
              fontSize: 13,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 8),
          if (topCategoryStats.isEmpty)
            pw.Text('No category order data in selected period.')
          else
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey300),
              columnWidths: {
                0: const pw.FlexColumnWidth(3),
                1: const pw.FlexColumnWidth(2),
                2: const pw.FlexColumnWidth(2),
              },
              children: [
                pw.TableRow(
                  decoration: const pw.BoxDecoration(
                    color: PdfColors.blue100,
                  ),
                  children: [
                    _pdfCell('Category', bold: true),
                    _pdfCell('Orders', bold: true),
                    _pdfCell('Items', bold: true),
                  ],
                ),
                for (final row in topCategoryStats)
                  pw.TableRow(
                    children: [
                      _pdfCell((row['category'] ?? '-').toString()),
                      _pdfCell('${row['orders'] ?? 0}'),
                      _pdfCell('${row['items'] ?? 0}'),
                    ],
                  ),
              ],
            ),
          pw.SizedBox(height: 14),
          pw.Text(
            'This report intentionally shows only essential numbers for quick decision making.',
            style: const pw.TextStyle(fontSize: 10, lineSpacing: 2),
          ),
        ],
      ),
    );

    return pdf.save();
  }

  Future<void> _previewPdf() async {
    try {
      setState(() => _loading = true);
      final data = _lastReportData ?? await _loadReportData();
      final bytes = await _buildPdf(data);
      final periodCode = (data['periodCode'] ?? 'report').toString();

      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => bytes,
        name: 'vocamart_admin_report_$periodCode.pdf',
      );
    } catch (e) {
      _showMsg('Failed to generate PDF: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _sharePdf() async {
    try {
      setState(() => _loading = true);
      final data = _lastReportData ?? await _loadReportData();
      final bytes = await _buildPdf(data);
      final periodCode = (data['periodCode'] ?? 'report').toString();

      await Printing.sharePdf(
        bytes: bytes,
        filename: 'vocamart_admin_report_$periodCode.pdf',
      );
    } catch (e) {
      _showMsg('Failed to share PDF: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _reportFuture,
      builder: (context, snap) {
        if (snap.hasError && _lastReportData == null) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Failed to load reports.\n${snap.error}',
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          );
        }

        final data = snap.data ?? _lastReportData;
        if (data == null) {
          return const Center(child: CircularProgressIndicator());
        }
        final revenue = ((data['revenue'] ?? 0.0) as num).toDouble();
        final orders = (data['orders'] ?? 0) as int;
        final ordersInPeriod = (data['ordersInPeriod'] ?? 0) as int;
        final orderItems = (data['orderItems'] ?? 0) as int;
        final topCategoryStats =
        (data['topCategoryStats'] as List? ?? const [])
            .cast<Map<String, dynamic>>();
        final avgOrderValue = orders > 0 ? revenue / orders : 0.0;
        final periodLabel = (data['periodLabel'] ?? 'Period').toString();
        final periodText = (data['periodText'] ?? '-').toString();
        final generatedAt =
            (data['generatedAt'] as DateTime?) ?? DateTime.now();
        final scoped = (widget.fixedStoreId ?? '').trim().isNotEmpty;
        final usedCache = data['usedCache'] == true;

        return ListView(
          padding: const EdgeInsets.all(14),
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE6E6E6)),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x11000000),
                    blurRadius: 8,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Store Performance ($periodLabel)',
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ChoiceChip(
                        label: const Text('Weekly'),
                        selected: _selectedPeriod == _ReportPeriod.weekly,
                        onSelected: (selected) {
                          if (!selected) return;
                          _setPeriod(_ReportPeriod.weekly);
                        },
                      ),
                      ChoiceChip(
                        label: const Text('Monthly'),
                        selected: _selectedPeriod == _ReportPeriod.monthly,
                        onSelected: (selected) {
                          if (!selected) return;
                          _setPeriod(_ReportPeriod.monthly);
                        },
                      ),
                      ChoiceChip(
                        label: const Text('Yearly'),
                        selected: _selectedPeriod == _ReportPeriod.yearly,
                        onSelected: (selected) {
                          if (!selected) return;
                          _setPeriod(_ReportPeriod.yearly);
                        },
                      ),
                    ],
                  ),
                  if (snap.connectionState == ConnectionState.waiting) ...[
                    const SizedBox(height: 10),
                    const LinearProgressIndicator(minHeight: 2),
                  ],
                  const SizedBox(height: 8),
                  Text(
                    'Period: $periodText',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: Colors.black54,
                    ),
                  ),
                  if (usedCache) ...[
                    const SizedBox(height: 8),
                    const Text(
                      'Using cached store report data from Super Admin snapshot.',
                      style: TextStyle(
                        color: Colors.black54,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                  if (scoped && orders == 0 && ordersInPeriod > 0) ...[
                    const SizedBox(height: 8),
                    const Text(
                      'Warning: Orders exist in this period, but none could be linked to this store. Check order item storeId mapping for old data.',
                      style: TextStyle(
                        color: Colors.redAccent,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFE6E6E6)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Orders: $orders | Items: $orderItems | Revenue: RM ${revenue.toStringAsFixed(2)}',
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Average Order Value: RM ${avgOrderValue.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            color: Colors.black54,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Top Categories (Ordered)',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 6),
                  if (topCategoryStats.isEmpty)
                    const Text('No category order data in this period.')
                  else
                    ...topCategoryStats.map((row) {
                      final category = (row['category'] ?? '-').toString();
                      final cOrders = (row['orders'] ?? 0).toString();
                      final cItems = (row['items'] ?? 0).toString();
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Text(
                          '$category: $cOrders orders, $cItems items',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      );
                    }),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE6E6E6)),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x11000000),
                    blurRadius: 8,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'PDF Report Preview',
                    style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
                  ),
                  const SizedBox(height: 10),
                  Text('- Period: $periodLabel ($periodText)'),
                  Text('- Generated: ${_dateTime(generatedAt)}'),
                  Text('- Total Revenue: RM ${revenue.toStringAsFixed(2)}'),
                  Text('- Total Orders: $orders'),
                  Text('- Total Order Items: $orderItems'),
                  Text(
                    '- Average Order Value: RM ${avgOrderValue.toStringAsFixed(2)}',
                  ),
                  Text('- Total Products: ${data['products']}'),
                  Text('- Total Reviews: ${data['reviews']}'),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _loading ? null : _previewPdf,
                      icon: const Icon(Icons.picture_as_pdf),
                      label: Text(
                        _loading ? 'Generating...' : 'Preview / Print PDF',
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _loading ? null : _sharePdf,
                      icon: const Icon(Icons.share),
                      label: const Text('Share PDF'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _SectionCountHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final String countText;

  const _SectionCountHeader({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.countText,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE6E6E6)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x11000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: const Color(0xFFE3F2FD),
            foregroundColor: const Color(0xFF1565C0),
            child: Icon(icon),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: Colors.black54,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          Text(
            countText,
            style: const TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 20,
              color: Color(0xFF1565C0),
            ),
          ),
        ],
      ),
    );
  }
}

Widget _chip(String label) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: const Color(0xFFE3F2FD),
      borderRadius: BorderRadius.circular(999),
    ),
    child: Text(
      label,
      style: const TextStyle(
        fontWeight: FontWeight.w800,
        fontSize: 11,
        color: Color(0xFF1565C0),
      ),
    ),
  );
}

pw.TableRow _pdfRow(String left, String right) {
  return pw.TableRow(children: [_pdfCell(left), _pdfCell(right)]);
}

pw.Widget _pdfCell(String text, {bool bold = false}) {
  return pw.Padding(
    padding: const pw.EdgeInsets.all(8),
    child: pw.Text(
      text,
      style: pw.TextStyle(
        fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
      ),
    ),
  );
}
