// How this file works:
// 1) Data/models are declared first (if any).
// 2) UI widgets are built in build() methods.
// 3) Helper methods are used to keep UI code clean.

// File purpose: This file handles voice command page screen/logic.

import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart';

// This class defines VoiceCommandPage, used for this page/feature.
class VoiceCommandPage extends StatefulWidget {
  const VoiceCommandPage({super.key});

  @override
  State<VoiceCommandPage> createState() => _VoiceCommandPageState();
}

// This class defines _VoiceCommandPageState, used for this page/feature.
class _VoiceCommandPageState extends State<VoiceCommandPage> {
  final _speech = SpeechToText();
  final _textCtrl = TextEditingController();
  bool _ready = false;
  bool _listening = false;

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final ok = (await _speech.initialize()) == true;
    if (!mounted) return;
    setState(() {
      _ready = ok;
    });
  }

  Future<void> _toggleListen() async {
    if (!_ready) {
      _showSnack('Voice recognition is not ready on this device.');
      return;
    }

    if (_listening) {
      await _speech.stop();
      if (!mounted) return;
      setState(() {
        _listening = false;
      });
      return;
    }

    try {
      if (_speech.isListening) {
        await _speech.stop();
        await Future<void>.delayed(const Duration(milliseconds: 100));
      }
      await _speech.listen(
        onResult: (r) {
          setState(() {
            _textCtrl.text = r.recognizedWords;
          });
        },
        listenOptions: SpeechListenOptions(cancelOnError: true),
      );
    } catch (e) {
      final code = e.toString().toLowerCase();
      if (code.contains('busy') || code.contains('error_recognizer_busy')) {
        _showSnack('Microphone is busy. Please try again.');
      } else {
        _showSnack('Failed to start microphone: $e');
      }
      return;
    }
    if (!mounted) return;
    setState(() {
      // Some plugin versions return null even when listening starts.
      // Use status callbacks/stop flow to control listening lifecycle.
      _listening = true;
    });
  }

  @override
  void dispose() {
    _textCtrl.dispose();
    _speech.cancel();
    super.dispose();
  }

  void _runCommand() {
    final cmd = _textCtrl.text.trim();
    if (cmd.isEmpty) {
      _showSnack('Please say or type a command first.');
      return;
    }
    Navigator.pop(context, cmd);
  }

  @override
  // Builds and returns the UI for this widget.
  Widget build(BuildContext context) {
    const kOrange = Color(0xFFFF6A00);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Voice Command'),
        backgroundColor: kOrange,
        foregroundColor: Colors.black,
      ),
      body: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Try: show vegetables, broccoli, add to cart, checkout',
              style: TextStyle(color: Colors.black54),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _textCtrl,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: 'Voice text will appear here',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _listening ? Colors.redAccent : kOrange,
                      foregroundColor: Colors.black,
                    ),
                    onPressed: _ready ? _toggleListen : null,
                    icon: Icon(_listening ? Icons.stop : Icons.mic_none),
                    label: Text(_listening ? 'Stop' : 'Use Microphone'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _runCommand,
                child: const Text('Run Command'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}


