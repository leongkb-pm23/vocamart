// How this file works:
// 1) Data/models are declared first (if any).
// 2) UI widgets are built in build() methods.
// 3) Helper methods are used to keep UI code clean.
//
// File purpose: This file handles payment verification page screen/logic.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart';

// This class defines PaymentVerificationPage, used for this page/feature.
class PaymentVerificationPage extends StatefulWidget {
  final String? paymentLabel;

  const PaymentVerificationPage({super.key, this.paymentLabel});

  @override
  State<PaymentVerificationPage> createState() =>
      _PaymentVerificationPageState();
}

// This class defines _PaymentVerificationPageState, used for this page/feature.
class _PaymentVerificationPageState extends State<PaymentVerificationPage> {
  final SpeechToText _speech = SpeechToText();
  final TextEditingController _spokenCtrl = TextEditingController();

  bool _ready = false;
  bool _phraseReady = false;
  bool _listening = false;
  bool _verifying = false;

  String _expected = 'my voice is my password';
  String _statusText = 'Tap Start Listening';

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<String> _loadExpectedPhrase() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return _expected;

    DocumentSnapshot<Map<String, dynamic>> doc;
    try {
      doc =
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .get();
    } catch (_) {
      return _expected;
    }

    final data = doc.data() ?? const <String, dynamic>{};
    // Support older keys so existing users are not locked out at checkout.
    final phrase =
        (data['paymentPhrase'] ??
                data['voicePhrase'] ??
                data['passphrase'] ??
                '')
            .toString()
            .trim();
    if (phrase.isEmpty) return _expected;
    return phrase.toLowerCase();
  }

  Future<void> _init() async {
    bool ok = false;

    try {
      ok = await _speech.initialize(
        onStatus: (status) {
          debugPrint('Speech status: $status');
          if (!mounted) return;

          setState(() {
            _statusText = status;
          });

          if (status == 'done' ||
              status == 'notListening' ||
              status == 'doneNoResult') {
            setState(() {
              _listening = false;
            });
          }
        },
        onError: (error) {
          debugPrint('Speech error: ${error.errorMsg}');
          if (!mounted) return;
          final code = error.errorMsg.toLowerCase().trim();

          setState(() {
            _listening = false;
            _statusText = 'Error: ${error.errorMsg}';
          });

          final benign =
              code == 'error_no_match' ||
              code == 'error_speech_timeout' ||
              code == 'error_recognizer_busy';
          if (!benign) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Speech error: ${error.errorMsg}')),
            );
          }
        },
      );
    } catch (e) {
      debugPrint('Speech initialize exception: $e');
      ok = false;
    }

    try {
      _expected = await _loadExpectedPhrase();
      debugPrint('Loaded payment phrase: $_expected');
    } catch (e) {
      debugPrint('Load phrase exception: $e');
    }

    if (!mounted) return;
    setState(() {
      _ready = ok;
      _phraseReady = true;
      if (!_ready) {
        _statusText = 'Speech recognition not available';
      }
    });
  }

  Future<void> _toggleMic() async {
    if (_verifying) return;

    if (!_ready) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Speech recognition is not ready on this device.'),
        ),
      );
      return;
    }

    if (_listening) {
      try {
        await _speech.stop();
      } catch (e) {
        debugPrint('Speech stop exception: $e');
      }

      if (!mounted) return;
      setState(() {
        _listening = false;
        _statusText = 'Stopped listening';
      });
      return;
    }

    try {
      // Guard against stale listening state from platform side.
      if (_speech.isListening) {
        await _speech.stop();
        await Future<void>.delayed(const Duration(milliseconds: 120));
      }

      await _speech.listen(
        onResult: (result) {
          debugPrint(
            'Recognized: ${result.recognizedWords} | final: ${result.finalResult}',
          );

          if (!mounted) return;
          setState(() {
            _spokenCtrl.text = result.recognizedWords.toLowerCase().trim();
            _statusText =
                result.finalResult ? 'Final result ready' : 'Listening...';
          });
        },
      );

      if (!mounted) return;
      setState(() {
        // Some plugin versions return null even when listening starts.
        // Trust status callbacks and mark listening true after successful call.
        _listening = true;
        _statusText = 'Listening...';
      });
    } catch (e) {
      debugPrint('Speech listen exception: $e');
      final code = e.toString().toLowerCase();
      if (code.contains('busy') || code.contains('error_recognizer_busy')) {
        try {
          await _speech.stop();
          await Future<void>.delayed(const Duration(milliseconds: 180));
          await _speech.listen(
            onResult: (result) {
              if (!mounted) return;
              setState(() {
                _spokenCtrl.text = result.recognizedWords.toLowerCase().trim();
                _statusText =
                    result.finalResult ? 'Final result ready' : 'Listening...';
              });
            },
          );
          if (!mounted) return;
          setState(() {
            _listening = true;
            _statusText = 'Listening...';
          });
          return;
        } catch (_) {}
      }
      if (!mounted) return;

      setState(() {
        _listening = false;
        _statusText = 'Failed to start listening';
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to start listening: $e')));
    }
  }

  String _normalize(String s) {
    final lower = s.toLowerCase();
    final cleaned = lower.replaceAll(RegExp(r'[^a-z0-9\s]'), ' ');
    return cleaned.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  bool _wordSimilar(String a, String b) {
    if (a == b) return true;
    if (a.contains(b) || b.contains(a)) return true;
    if ((a.length - b.length).abs() > 1) return false;
    if (a.length < 4 || b.length < 4) return false;

    int i = 0;
    int j = 0;
    int edits = 0;

    while (i < a.length && j < b.length) {
      if (a[i] == b[j]) {
        i++;
        j++;
        continue;
      }

      edits++;
      if (edits > 1) return false;

      if (a.length > b.length) {
        i++;
      } else if (b.length > a.length) {
        j++;
      } else {
        i++;
        j++;
      }
    }

    if (i < a.length || j < b.length) edits++;
    return edits <= 1;
  }

  int _levenshteinDistance(String a, String b) {
    if (a.isEmpty) return b.length;
    if (b.isEmpty) return a.length;

    final prev = List<int>.generate(b.length + 1, (i) => i);
    final curr = List<int>.filled(b.length + 1, 0);

    for (int i = 1; i <= a.length; i++) {
      curr[0] = i;
      for (int j = 1; j <= b.length; j++) {
        final cost = a[i - 1] == b[j - 1] ? 0 : 1;
        curr[j] = [
          curr[j - 1] + 1,
          prev[j] + 1,
          prev[j - 1] + cost,
        ].reduce((x, y) => x < y ? x : y);
      }
      for (int j = 0; j <= b.length; j++) {
        prev[j] = curr[j];
      }
    }

    return prev[b.length];
  }

  bool _isVerified() {
    final heard = _normalize(_spokenCtrl.text);
    final target = _normalize(_expected);

    debugPrint('Normalized heard: $heard');
    debugPrint('Normalized target: $target');

    if (heard.isEmpty || target.isEmpty) return false;

    if (heard == target || heard.contains(target) || target.contains(heard)) {
      return true;
    }

    final maxLen = heard.length > target.length ? heard.length : target.length;
    if (maxLen > 0) {
      final distance = _levenshteinDistance(heard, target);
      final phraseScore = 1 - (distance / maxLen);
      debugPrint('Phrase similarity score: $phraseScore');
      if (phraseScore >= 0.72) return true;
    }

    final heardWords = heard.split(' ').where((w) => w.isNotEmpty).toList();
    final targetWords = target.split(' ').where((w) => w.isNotEmpty).toList();

    if (heardWords.isEmpty || targetWords.isEmpty) return false;

    if (targetWords.length <= 2) {
      for (final word in targetWords) {
        final found = heardWords.any(
          (heardWord) => _wordSimilar(word, heardWord),
        );
        if (!found) return false;
      }
      return true;
    }

    int matched = 0;
    for (final targetWord in targetWords) {
      bool found = false;
      for (final heardWord in heardWords) {
        if (_wordSimilar(targetWord, heardWord)) {
          found = true;
          break;
        }
      }
      if (found) matched++;
    }

    final score = matched / targetWords.length;
    debugPrint('Match score: $score');

    return score >= 0.6;
  }

  Future<void> _verifyAndClose() async {
    if (_verifying) return;

    if (!_phraseReady) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Loading passphrase, please wait...')),
      );
      return;
    }

    setState(() {
      _verifying = true;
    });

    try {
      if (_listening) {
        try {
          await _speech.stop();
        } catch (e) {
          debugPrint('Speech stop before verify exception: $e');
        }

        if (!mounted) return;
        setState(() {
          _listening = false;
          _statusText = 'Processing speech...';
        });

        await Future<void>.delayed(const Duration(milliseconds: 1200));
        if (!mounted) return;
      }

      final spokenText = _spokenCtrl.text.trim();
      debugPrint('Expected phrase: $_expected');
      debugPrint('Recognized speech: $spokenText');

      if (spokenText.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No speech captured yet.')),
        );
        return;
      }

      final ok = _isVerified();
      debugPrint('Verification result: $ok');

      if (ok) {
        Navigator.pop(context, true);
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Passphrase not matched. Please try again.'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _verifying = false;
          if (!_listening) {
            _statusText = 'Tap Start Listening';
          }
        });
      }
    }
  }

  @override
  void dispose() {
    _spokenCtrl.dispose();
    _speech.stop();
    _speech.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const kOrange = Color(0xFFFF6A00);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Payment Voice Verification'),
        backgroundColor: kOrange,
        foregroundColor: Colors.black,
      ),
      body: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Say your payment passphrase to verify payment.',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 10),
            if ((widget.paymentLabel ?? '').trim().isNotEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                margin: const EdgeInsets.only(bottom: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF7F7F7),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFE6E6E6)),
                ),
                child: Text(
                  'Paying with ${widget.paymentLabel}',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            const Text(
              'For privacy, your expected passphrase is hidden.',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Colors.black54,
              ),
            ),
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF6EE),
                border: Border.all(color: const Color(0xFFFFD7BA)),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                'Status: $_statusText',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _spokenCtrl,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Recognized speech',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: _listening ? Colors.redAccent : kOrange,
                foregroundColor: Colors.black,
              ),
              onPressed: !_verifying ? _toggleMic : null,
              icon: Icon(_listening ? Icons.stop : Icons.mic_none),
              label: Text(_listening ? 'Stop Listening' : 'Start Listening'),
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: kOrange,
                  foregroundColor: Colors.black,
                ),
                onPressed: _phraseReady && !_verifying ? _verifyAndClose : null,
                child: Text(
                  _verifying ? 'Verifying...' : 'Verify and Continue',
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
