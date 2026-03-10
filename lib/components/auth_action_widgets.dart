// How this file works:
// 1) Data/models are declared first (if any).
// 2) UI widgets are built in build() methods.
// 3) Helper methods are used to keep UI code clean.

// File purpose: This file handles auth action widgets screen/logic.

import 'package:flutter/material.dart';

// This class defines AuthPrimarySignInButton, used for this page/feature.
class AuthPrimarySignInButton extends StatelessWidget {
  final bool loading;
  final VoidCallback? onPressed;

  const AuthPrimarySignInButton({
    super.key,
    required this.loading,
    required this.onPressed,
  });

  @override
  // Builds and returns the UI for this widget.
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.grey.shade200,
          foregroundColor: Colors.black,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
        ),
        onPressed: onPressed,
        child: loading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('Sign In', style: TextStyle(fontWeight: FontWeight.w700)),
                  SizedBox(width: 10),
                  Icon(Icons.arrow_forward),
                ],
              ),
      ),
    );
  }
}

// This class defines AuthOrDivider, used for this page/feature.
class AuthOrDivider extends StatelessWidget {
  const AuthOrDivider({super.key});

  @override
  // Builds and returns the UI for this widget.
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Divider(color: Colors.grey.shade300)),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 10),
          child: Text('OR'),
        ),
        Expanded(child: Divider(color: Colors.grey.shade300)),
      ],
    );
  }
}

// This class defines AuthOutlinedPillButton, used for this page/feature.
class AuthOutlinedPillButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;

  const AuthOutlinedPillButton({
    super.key,
    required this.text,
    required this.onPressed,
  });

  @override
  // Builds and returns the UI for this widget.
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
        ),
        child: Text(text),
      ),
    );
  }
}

// This class defines AuthGuestButton, used for this page/feature.
class AuthGuestButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final bool enabled;

  const AuthGuestButton({
    super.key,
    required this.onPressed,
    this.enabled = true,
  });

  @override
  // Builds and returns the UI for this widget.
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFFF6A00),
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        onPressed: enabled ? onPressed : null,
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Continue As Guest', style: TextStyle(fontWeight: FontWeight.w700)),
            SizedBox(width: 10),
            Icon(Icons.arrow_forward),
          ],
        ),
      ),
    );
  }
}

// This class defines AuthSignUpPrompt, used for this page/feature.
class AuthSignUpPrompt extends StatelessWidget {
  final VoidCallback onTap;

  const AuthSignUpPrompt({super.key, required this.onTap});

  @override
  // Builds and returns the UI for this widget.
  Widget build(BuildContext context) {
    return Center(
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          InkWell(
            onTap: onTap,
            child: const Text(
              'Sign Up',
              style: TextStyle(
                color: Color(0xFFFF6A00),
                fontWeight: FontWeight.w800,
                decoration: TextDecoration.underline,
              ),
            ),
          ),
          const Text(' here'),
        ],
      ),
    );
  }
}


