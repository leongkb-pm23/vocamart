// How this file works:
// 1) Data/models are declared first (if any).
// 2) UI widgets are built in build() methods.
// 3) Helper methods are used to keep UI code clean.

// File purpose: This file handles auth form widgets screen/logic.

import 'package:flutter/material.dart';

// This class defines AuthPageShell, used for this page/feature.
class AuthPageShell extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;

  const AuthPageShell({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
  });

  @override
  // Builds and returns the UI for this widget.
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, c) {
            final width = c.maxWidth > 520 ? 520.0 : c.maxWidth;
            return Center(
              child: SizedBox(
                width: width,
                child: SingleChildScrollView(
                  padding: padding,
                  child: child,
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

// This class defines AuthFieldLabel, used for this page/feature.
class AuthFieldLabel extends StatelessWidget {
  static const kOrange = Color(0xFFFF6A00);
  final String text;

  const AuthFieldLabel(this.text, {super.key});

  @override
  // Builds and returns the UI for this widget.
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: kOrange,
        fontWeight: FontWeight.w700,
        fontSize: 13,
      ),
    );
  }
}

// This class defines AuthBoxField, used for this page/feature.
class AuthBoxField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final TextInputType keyboardType;
  final bool obscureText;
  final Widget? suffix;
  final String? Function(String?)? validator;
  final InputDecoration? decoration;

  const AuthBoxField({
    super.key,
    required this.controller,
    required this.hint,
    required this.keyboardType,
    this.obscureText = false,
    this.suffix,
    this.validator,
    this.decoration,
  });

  static InputDecoration defaultDecoration(String hint, {Widget? suffix}) {
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
      suffixIcon: suffix,
    );
  }

  @override
  // Builds and returns the UI for this widget.
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscureText,
      validator: validator,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      decoration: decoration ?? defaultDecoration(hint, suffix: suffix),
    );
  }
}


