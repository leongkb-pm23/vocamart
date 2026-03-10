// File purpose: Registration screen/logic with:
// ? Address fields (address, block, postcode, state dropdown, country)
// ? Live validation (auto show while typing)
// ? DOB validation shown under field
// ? Save everything to Firestore

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl_phone_field/intl_phone_field.dart';

import 'package:fyp/components/auth_form_widgets.dart';
import 'package:fyp/User/login.dart';

enum Gender { male, female }

class RegistrationPage extends StatefulWidget {
  static const routeName = '/register';
  const RegistrationPage({super.key});

  @override
  State<RegistrationPage> createState() => _RegistrationPageState();
}

class _RegistrationPageState extends State<RegistrationPage> {
  static const kOrange = Color(0xFFFF6A00);

  final _formKey = GlobalKey<FormState>();

  final _fullNameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();

  // Address fields
  final _addressCtrl = TextEditingController();
  final _blockCtrl = TextEditingController();
  final _postcodeCtrl = TextEditingController();

  final _passwordCtrl = TextEditingController();
  final _confirmPasswordCtrl = TextEditingController();

  String _phoneE164 = "";

  Gender? _gender;
  DateTime? _dob;

  // ? State dropdown value
  String? _state;
  String? _country;

  bool _loading = false;
  bool _obscurePw = true;
  bool _obscureConfirm = true;

  String _pwLive = "";
  String _confirmLive = "";

  // ? Malaysia states + federal territories
  static const List<String> _malaysiaStates = [
    "Johor",
    "Kedah",
    "Kelantan",
    "Melaka",
    "Negeri Sembilan",
    "Pahang",
    "Perak",
    "Perlis",
    "Pulau Pinang",
    "Sabah",
    "Sarawak",
    "Selangor",
    "Terengganu",
    "Wilayah Persekutuan Kuala Lumpur",
    "Wilayah Persekutuan Labuan",
    "Wilayah Persekutuan Putrajaya",
  ];

  static const List<String> _countries = [
    "Malaysia",
    "Singapore",
    "Indonesia",
    "Thailand",
    "Brunei",
    "United States",
    "United Kingdom",
    "China",
    "Japan",
    "India",
    "Australia",
  ];

  static const Map<String, List<String>> _statesByCountry = {
    "Malaysia": _malaysiaStates,
    "Singapore": ["Central Region", "North Region", "North-East Region", "East Region", "West Region"],
    "Indonesia": ["DKI Jakarta", "West Java", "Central Java", "East Java", "Bali", "North Sumatra"],
    "Thailand": ["Bangkok", "Chiang Mai", "Phuket", "Chonburi", "Nakhon Ratchasima", "Songkhla"],
    "Brunei": ["Belait", "Brunei-Muara", "Temburong", "Tutong"],
    "United States": ["California", "Texas", "Florida", "New York", "Illinois", "Washington"],
    "United Kingdom": ["England", "Scotland", "Wales", "Northern Ireland"],
    "China": ["Beijing", "Shanghai", "Guangdong", "Zhejiang", "Sichuan", "Jiangsu"],
    "Japan": ["Tokyo", "Osaka", "Hokkaido", "Aichi", "Fukuoka", "Kyoto"],
    "India": ["Maharashtra", "Karnataka", "Tamil Nadu", "Delhi", "Gujarat", "Kerala"],
    "Australia": ["New South Wales", "Victoria", "Queensland", "Western Australia", "South Australia", "Tasmania"],
  };

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  void initState() {
    super.initState();
    _passwordCtrl.addListener(() => setState(() => _pwLive = _passwordCtrl.text));
    _confirmPasswordCtrl
        .addListener(() => setState(() => _confirmLive = _confirmPasswordCtrl.text));
  }

  @override
  void dispose() {
    _fullNameCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();

    _addressCtrl.dispose();
    _blockCtrl.dispose();
    _postcodeCtrl.dispose();

    _passwordCtrl.dispose();
    _confirmPasswordCtrl.dispose();
    super.dispose();
  }

  // ---------------- Validators ----------------

  String? _req(String? v, String label) {
    if (v == null || v.trim().isEmpty) return "$label is required";
    return null;
  }

  String? _validateEmail(String? v) {
    final value = (v ?? '').trim();
    if (value.isEmpty) return "Email is required";
    final reg = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
    if (!reg.hasMatch(value)) return "Enter a valid email";
    return null;
  }

  String? _validatePostcode(String? v) {
    final value = (v ?? '').trim();
    if (value.isEmpty) return "Postcode is required";
    if (_isMalaysiaSelected()) {
      if (!RegExp(r'^\d{5}$').hasMatch(value)) {
        return "Postcode must be 5 digits";
      }
      return null;
    }
    if (value.length < 3) return "Postcode must be at least 3 characters";
    return null;
  }

  String? _validateCountry(String? v) {
    final value = (v ?? '').trim();
    if (value.isEmpty) return "Country is required";
    if (!_countries.contains(value)) return "Please select a valid country";
    return null;
  }

  String? _validateGender(Gender? v) {
    if (v == null) return "Gender is required";
    return null;
  }

  String? _validateState(String? v) {
    if (_country == null || (_country ?? '').trim().isEmpty) {
      return "Select country first";
    }
    final value = (v ?? '').trim();
    if (value.isEmpty) return "State is required";
    final allowed = _stateOptionsForSelectedCountry();
    if (!allowed.contains(value)) return "Please select a valid state";
    return null;
  }

  bool _hasUpper(String s) => RegExp(r'[A-Z]').hasMatch(s);
  bool _hasLower(String s) => RegExp(r'[a-z]').hasMatch(s);
  bool _hasNumber(String s) => RegExp(r'\d').hasMatch(s);
  bool _hasSymbol(String s) => RegExp(r'[@#*]').hasMatch(s);

  bool _pwAllOk(String s) {
    return s.length >= 8 &&
        _hasUpper(s) &&
        _hasLower(s) &&
        _hasNumber(s) &&
        _hasSymbol(s);
  }

  String? _validatePassword(String? v) {
    final value = v ?? '';
    if (value.isEmpty) return "Password is required";
    if (value.length < 8) return "Password must be at least 8 characters";
    if (!_hasNumber(value)) return "Password must contain numbers";
    if (!_hasUpper(value)) return "Password must contain uppercase";
    if (!_hasLower(value)) return "Password must contain lowercase";
    if (!_hasSymbol(value)) return "Password must have at least one @#* symbol";
    return null;
  }

  String? _validateConfirm(String? v) {
    final value = v ?? '';
    if (value.isEmpty) return "Confirm your password";
    if (value != _passwordCtrl.text) return "Passwords do not match";
    return null;
  }

  int _ageFromDob(DateTime dob) {
    final today = DateTime.now();
    int age = today.year - dob.year;
    final hadBirthday =
        (today.month > dob.month) || (today.month == dob.month && today.day >= dob.day);
    if (!hadBirthday) age--;
    return age;
  }

  String? _validateDob() {
    if (_dob == null) return "Date of birth is required";
    if (_ageFromDob(_dob!) < 18) return "You must be at least 18 years old";
    return null;
  }

  bool _isMalaysiaSelected() {
    return (_country ?? '').trim().toLowerCase() == 'malaysia';
  }

  List<String> _stateOptionsForSelectedCountry() {
    final country = (_country ?? '').trim();
    if (country.isEmpty) return const [];
    return _statesByCountry[country] ?? const [];
  }

  // ---------------- DOB picker ----------------

  Future<void> _pickDob(FormFieldState<String> field) async {
    final now = DateTime.now();
    final initial = _dob ?? DateTime(now.year - 18, now.month, now.day);

    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(1900),
      lastDate: now,
    );

    if (picked != null) {
      setState(() => _dob = picked);
      field.didChange(_formatDob(picked));
      field.validate();
    }
  }

  String _formatDob(DateTime d) {
    String two(int n) => n.toString().padLeft(2, '0');
    return "${two(d.day)}/${two(d.month)}/${d.year}";
  }

  // ---------------- Register ----------------

  Future<void> _register() async {
    final ok = _formKey.currentState?.validate() ?? false;
    if (!ok) {
      _showSnack("Please fix the errors in the form.");
      return;
    }

    if (_phoneE164.trim().isEmpty) {
      _showSnack("Phone number is required");
      return;
    }

    if (_gender == null) {
      _showSnack("Gender is required");
      return;
    }

    final dobErr = _validateDob();
    if (dobErr != null) {
      _showSnack(dobErr);
      return;
    }

    if (!_pwAllOk(_passwordCtrl.text)) {
      _showSnack("Password does not meet the requirements.");
      return;
    }

    setState(() => _loading = true);

    try {
      final cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailCtrl.text.trim(),
        password: _passwordCtrl.text,
      );

      final uid = cred.user!.uid;
      final stateValue = (_state ?? '').trim();

      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'uid': uid,
        'fullName': _fullNameCtrl.text.trim(),
        'phone': _phoneE164.trim(),
        'email': _emailCtrl.text.trim(),
        'gender': _gender!.name,
        'dob': Timestamp.fromDate(_dob!),

        'address': _addressCtrl.text.trim(),
        'block': _blockCtrl.text.trim(),
        'postcode': _postcodeCtrl.text.trim(),
        'state': stateValue,
        'country': (_country ?? '').trim(),

        'createdAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;

      _showSnack('Registration successful');
      Navigator.pushReplacementNamed(context, LoginPage.routeName);
    } on FirebaseAuthException catch (e) {
      String msg = 'Registration failed.';
      if (e.code == 'email-already-in-use') {
        msg = 'This email is already registered.';
      } else if (e.code == 'invalid-email') {
        msg = 'Invalid email format.';
      } else if (e.code == 'weak-password') {
        msg = 'Password too weak.';
      }
      if (mounted) _showSnack(msg);
    } catch (e) {
      if (mounted) _showSnack('Error: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ---------------- UI ----------------

  @override
  Widget build(BuildContext context) {
    return AuthPageShell(
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            IconButton(
              onPressed: () => Navigator.pushReplacementNamed(context, LoginPage.routeName),
              icon: const Icon(Icons.arrow_back),
            ),
            const Text(
              "Sign Up",
              style: TextStyle(
                color: kOrange,
                fontWeight: FontWeight.w800,
                fontSize: 26,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              "Sign Up to enjoy special Offer",
              style: TextStyle(color: Colors.grey.shade700),
            ),
            const SizedBox(height: 14),

            const _Label("Full Name"),
            const SizedBox(height: 6),
            _BoxField(
              controller: _fullNameCtrl,
              hint: "Enter full name",
              keyboardType: TextInputType.name,
              validator: (v) => _req(v, "Full name"),
            ),
            const SizedBox(height: 12),

            const _Label("Phone Number"),
            const SizedBox(height: 6),
            IntlPhoneField(
              controller: _phoneCtrl,
              initialCountryCode: 'MY',
              disableLengthCheck: true,
              decoration: _phoneDecoration(),
              validator: (phone) {
                if (phone == null || phone.number.trim().isEmpty) {
                  return "Phone number is required";
                }
                if (!RegExp(r'^\d+$').hasMatch(phone.number)) {
                  return "Digits only";
                }
                return null;
              },
              onChanged: (phone) => _phoneE164 = phone.completeNumber,
            ),
            const SizedBox(height: 12),

            const _Label("Email Address"),
            const SizedBox(height: 6),
            _BoxField(
              controller: _emailCtrl,
              hint: "Enter email address",
              keyboardType: TextInputType.emailAddress,
              validator: _validateEmail,
            ),
            const SizedBox(height: 12),

            const _Label("Address"),
            const SizedBox(height: 6),
            _BoxField(
              controller: _addressCtrl,
              hint: "Enter address",
              keyboardType: TextInputType.streetAddress,
              validator: (v) => _req(v, "Address"),
            ),
            const SizedBox(height: 12),

            const _Label("Block"),
            const SizedBox(height: 6),
            _BoxField(
              controller: _blockCtrl,
              hint: "Example: Block A / No. 12 / Apartment 3A",
              keyboardType: TextInputType.text,
              validator: (v) => _req(v, "Block"),
            ),
            const SizedBox(height: 12),

            const _Label("Postcode"),
            const SizedBox(height: 6),
            _BoxField(
              controller: _postcodeCtrl,
              hint: "Example: 43000",
              keyboardType: TextInputType.number,
              validator: _validatePostcode,
            ),
            const SizedBox(height: 12),

            const _Label("Country"),
            const SizedBox(height: 6),
            DropdownButtonFormField<String>(
              value: _country,
              isExpanded: true,
              autovalidateMode: AutovalidateMode.onUserInteraction,
              decoration: InputDecoration(
                hintText: "Select country",
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
              ),
              items: _countries
                  .map((c) => DropdownMenuItem<String>(value: c, child: Text(c)))
                  .toList(),
              onChanged: (v) {
                setState(() {
                  _country = v;
                  _state = null;
                });
              },
              validator: _validateCountry,
            ),
            const SizedBox(height: 12),
            _Label(_isMalaysiaSelected() ? "State (Malaysia)" : "State / Province / Region"),
            const SizedBox(height: 6),
            DropdownButtonFormField<String>(
              value: _state,
              isExpanded: true,
              autovalidateMode: AutovalidateMode.onUserInteraction,
              decoration: InputDecoration(
                hintText: _country == null
                    ? "Select country first"
                    : "Select state (optional)",
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
              ),
              items: _stateOptionsForSelectedCountry()
                  .map((s) => DropdownMenuItem<String>(value: s, child: Text(s)))
                  .toList(),
              onChanged: _country == null ? null : (v) => setState(() => _state = v),
              validator: _validateState,
            ),
            const SizedBox(height: 12),

            const _Label("Password"),
            const SizedBox(height: 6),
            _BoxField(
              controller: _passwordCtrl,
              hint: "Enter password",
              keyboardType: TextInputType.text,
              obscureText: _obscurePw,
              validator: _validatePassword,
              suffix: IconButton(
                onPressed: () => setState(() => _obscurePw = !_obscurePw),
                icon: Icon(_obscurePw ? Icons.visibility_off : Icons.visibility),
              ),
            ),
            const SizedBox(height: 8),
            PasswordRulesChecklist(password: _pwLive),
            const SizedBox(height: 12),

            const _Label("Confirmed Password"),
            const SizedBox(height: 6),
            _BoxField(
              controller: _confirmPasswordCtrl,
              hint: "Enter confirmed password",
              keyboardType: TextInputType.text,
              obscureText: _obscureConfirm,
              validator: _validateConfirm,
              suffix: IconButton(
                onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
                icon: Icon(_obscureConfirm ? Icons.visibility_off : Icons.visibility),
              ),
            ),
            const SizedBox(height: 8),
            ConfirmPasswordRule(password: _pwLive, confirm: _confirmLive),
            const SizedBox(height: 14),

            const _Label("Gender"),
            const SizedBox(height: 6),
            FormField<Gender>(
              autovalidateMode: AutovalidateMode.onUserInteraction,
              validator: _validateGender,
              builder: (field) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _RadioTile(
                            text: "Male",
                            value: Gender.male,
                            groupValue: _gender,
                            onChanged: (v) {
                              setState(() => _gender = v);
                              field.didChange(v);
                            },
                          ),
                        ),
                        Expanded(
                          child: _RadioTile(
                            text: "Female",
                            value: Gender.female,
                            groupValue: _gender,
                            onChanged: (v) {
                              setState(() => _gender = v);
                              field.didChange(v);
                            },
                          ),
                        ),
                      ],
                    ),
                    if (field.errorText != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        field.errorText!,
                        style: const TextStyle(color: Colors.red, fontSize: 12),
                      ),
                    ],
                  ],
                );
              },
            ),
            const SizedBox(height: 10),

            const _Label("Date of Birth"),
            const SizedBox(height: 6),
            FormField<String>(
              autovalidateMode: AutovalidateMode.onUserInteraction,
              validator: (_) => _validateDob(),
              builder: (field) {
                final hasError = field.errorText != null;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    InkWell(
                      onTap: () => _pickDob(field),
                      child: Container(
                        padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                        decoration: BoxDecoration(
                          border: Border.all(color: hasError ? Colors.red : Colors.black26),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(_dob == null ? "DD/MM/YYYY" : _formatDob(_dob!)),
                            ),
                            const Icon(Icons.calendar_month),
                          ],
                        ),
                      ),
                    ),
                    if (hasError) ...[
                      const SizedBox(height: 6),
                      Text(
                        field.errorText!,
                        style: const TextStyle(color: Colors.red, fontSize: 12),
                      ),
                    ],
                  ],
                );
              },
            ),
            const SizedBox(height: 20),

            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _loading ? null : _register,
                child: _loading
                    ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
                    : const Text("Sign Up"),
              ),
            ),

            const SizedBox(height: 12),

            Center(
              child: Wrap(
                children: [
                  const Text("Already have an account? "),
                  InkWell(
                    onTap: () =>
                        Navigator.pushReplacementNamed(context, LoginPage.routeName),
                    child: const Text(
                      "Sign In",
                      style: TextStyle(
                        color: kOrange,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _phoneDecoration() {
    return InputDecoration(
      hintText: "Enter phone number",
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
    );
  }
}

/* ---------------- Shared widgets ---------------- */

class _Label extends StatelessWidget {
  final String text;
  const _Label(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: Color(0xFFFF6A00),
        fontWeight: FontWeight.w700,
        fontSize: 13,
      ),
    );
  }
}

class _BoxField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final TextInputType keyboardType;
  final bool obscureText;
  final Widget? suffix;
  final String? Function(String?)? validator;

  const _BoxField({
    required this.controller,
    required this.hint,
    required this.keyboardType,
    this.obscureText = false,
    this.suffix,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscureText,
      validator: validator,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      decoration: InputDecoration(
        hintText: hint,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        suffixIcon: suffix,
      ),
    );
  }
}

class _RadioTile extends StatelessWidget {
  final String text;
  final Gender value;
  final Gender? groupValue;
  final ValueChanged<Gender?> onChanged;

  const _RadioTile({
    required this.text,
    required this.value,
    required this.groupValue,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => onChanged(value),
      child: Row(
        children: [
          Radio<Gender>(value: value, groupValue: groupValue, onChanged: onChanged),
          Text(text),
        ],
      ),
    );
  }
}

/* ---------------- Password rules checklist (red/green) ---------------- */

class PasswordRulesChecklist extends StatelessWidget {
  final String password;
  const PasswordRulesChecklist({super.key, required this.password});

  bool _hasUpper() => RegExp(r'[A-Z]').hasMatch(password);
  bool _hasLower() => RegExp(r'[a-z]').hasMatch(password);
  bool _hasNumber() => RegExp(r'\d').hasMatch(password);
  bool _hasSymbol() => RegExp(r'[@#*]').hasMatch(password);
  bool _hasLen() => password.length >= 8;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _RuleItem(ok: _hasNumber(), text: "Password must contain numbers"),
        _RuleItem(ok: _hasUpper(), text: "Password must contain uppercase"),
        _RuleItem(ok: _hasLower(), text: "Password must contain lowercase"),
        _RuleItem(ok: _hasSymbol(), text: "Password must have at least one @#* symbol"),
        _RuleItem(ok: _hasLen(), text: "Length must be >= 8 characters"),
      ],
    );
  }
}

class ConfirmPasswordRule extends StatelessWidget {
  final String password;
  final String confirm;

  const ConfirmPasswordRule({
    super.key,
    required this.password,
    required this.confirm,
  });

  @override
  Widget build(BuildContext context) {
    final ok = confirm.isNotEmpty && confirm == password;
    return _RuleItem(ok: ok, text: "Confirm password must match");
  }
}

class _RuleItem extends StatelessWidget {
  final bool ok;
  final String text;

  const _RuleItem({required this.ok, required this.text});

  @override
  Widget build(BuildContext context) {
    final color = ok ? Colors.green : Colors.red;
    final icon = ok ? Icons.check_circle : Icons.error;

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: color,
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
