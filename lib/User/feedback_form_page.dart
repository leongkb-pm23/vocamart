import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class FeedbackFormPage extends StatefulWidget {
  static const kOrange = Color(0xFFFF6A00);

  const FeedbackFormPage({super.key});

  @override
  State<FeedbackFormPage> createState() => _FeedbackFormPageState();
}

class _FeedbackFormPageState extends State<FeedbackFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _messageCtrl = TextEditingController();
  int _rating = 5;
  bool _saving = false;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _messageCtrl.dispose();
    super.dispose();
  }

  void _showMsg(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _submit() async {
    if (_saving) return;
    if (!_formKey.currentState!.validate()) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _showMsg('Please login first.');
      return;
    }

    setState(() => _saving = true);
    try {
      String userName = (user.displayName ?? '').trim();
      try {
        final profile =
            await FirebaseFirestore.instance
                .collection('users')
                .doc(user.uid)
                .get();
        final data = profile.data() ?? const <String, dynamic>{};
        final fromProfile =
            (data['name'] ?? data['displayName'] ?? '').toString().trim();
        if (fromProfile.isNotEmpty) userName = fromProfile;
      } on FirebaseException catch (_) {}

      await FirebaseFirestore.instance.collection('user_feedback').add({
        'uid': user.uid,
        'email': (user.email ?? '').trim(),
        'userName': userName,
        'name': userName,
        'title': _titleCtrl.text.trim(),
        'message': _messageCtrl.text.trim(),
        'rating': _rating,
        'status': 'new',
        'createdAt': FieldValue.serverTimestamp(),
      });

      _titleCtrl.clear();
      _messageCtrl.clear();
      setState(() => _rating = 5);
      _showMsg('Thank you! Your feedback has been submitted.');
    } on FirebaseException catch (e) {
      _showMsg('Submit failed: ${e.message ?? e.code}');
    } catch (e) {
      _showMsg('Submit failed: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Feedback Form'),
        backgroundColor: FeedbackFormPage.kOrange,
        foregroundColor: Colors.black,
      ),
      body: ListView(
        padding: const EdgeInsets.all(14),
        children: [
          const Text(
            'Share your experience with us',
            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
          ),
          const SizedBox(height: 6),
          const Text(
            'Your feedback helps us improve the app.',
            style: TextStyle(color: Colors.black54),
          ),
          const SizedBox(height: 14),
          Form(
            key: _formKey,
            child: Column(
              children: [
                TextFormField(
                  controller: _titleCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Title',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) {
                    final value = (v ?? '').trim();
                    if (value.isEmpty) return 'Title is required';
                    if (value.length < 3) return 'Title is too short';
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<int>(
                  value: _rating,
                  decoration: const InputDecoration(
                    labelText: 'Rating',
                    border: OutlineInputBorder(),
                  ),
                  items:
                      List.generate(
                        5,
                        (i) => DropdownMenuItem<int>(
                          value: i + 1,
                          child: Text('${i + 1} Star${i == 0 ? '' : 's'}'),
                        ),
                      ).toList(),
                  onChanged: _saving ? null : (v) => setState(() => _rating = v ?? 5),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _messageCtrl,
                  maxLines: 5,
                  decoration: const InputDecoration(
                    labelText: 'Feedback',
                    hintText: 'Tell us what you like or what should improve.',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) {
                    final value = (v ?? '').trim();
                    if (value.isEmpty) return 'Feedback is required';
                    if (value.length < 10) return 'Please write a bit more detail';
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: FeedbackFormPage.kOrange,
                      foregroundColor: Colors.black,
                    ),
                    onPressed: _saving ? null : _submit,
                    child: Text(
                      _saving ? 'Submitting...' : 'Submit Feedback',
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
