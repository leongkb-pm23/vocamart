// How this file works:
// 1) Data/models are declared first (if any).
// 2) UI widgets are built in build() methods.
// 3) Helper methods are used to keep UI code clean.

// File purpose: This file handles cart page screen/logic.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:fyp/components/app_store.dart';
import 'package:fyp/User/detail_ui.dart';
import 'package:fyp/User/payment_verification_page.dart';
import 'package:fyp/services/billplz_payment_service.dart';

class _CheckoutAddress {
  final String id;
  final String label;
  final String address;
  final String block;
  final String postcode;
  final String state;
  final String country;
  final String fullAddress;

  const _CheckoutAddress({
    required this.id,
    required this.label,
    required this.address,
    required this.block,
    required this.postcode,
    required this.state,
    required this.country,
    required this.fullAddress,
  });
}

enum _CheckoutPaymentMode { card, wallet, billplz }

// This class defines CartPage, used for this page/feature.
class CartPage extends StatefulWidget {
  static const kOrange = Color(0xFFFF6A00);

  const CartPage({super.key});

  @override
  State<CartPage> createState() => _CartPageState();
}

class _CartPageState extends State<CartPage> {
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
    "Malaysia": [
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
    ],
    "Singapore": [
      "Central Region",
      "North Region",
      "North-East Region",
      "East Region",
      "West Region",
    ],
    "Indonesia": [
      "DKI Jakarta",
      "West Java",
      "Central Java",
      "East Java",
      "Bali",
      "North Sumatra",
    ],
    "Thailand": [
      "Bangkok",
      "Chiang Mai",
      "Phuket",
      "Chonburi",
      "Nakhon Ratchasima",
      "Songkhla",
    ],
    "Brunei": ["Belait", "Brunei-Muara", "Temburong", "Tutong"],
    "United States": [
      "California",
      "Texas",
      "Florida",
      "New York",
      "Illinois",
      "Washington",
    ],
    "United Kingdom": ["England", "Scotland", "Wales", "Northern Ireland"],
    "China": [
      "Beijing",
      "Shanghai",
      "Guangdong",
      "Zhejiang",
      "Sichuan",
      "Jiangsu",
    ],
    "Japan": ["Tokyo", "Osaka", "Hokkaido", "Aichi", "Fukuoka", "Kyoto"],
    "India": [
      "Maharashtra",
      "Karnataka",
      "Tamil Nadu",
      "Delhi",
      "Gujarat",
      "Kerala",
    ],
    "Australia": [
      "New South Wales",
      "Victoria",
      "Queensland",
      "Western Australia",
      "South Australia",
      "Tasmania",
    ],
  };

  String? _selectedAddressId;
  String? _selectedPaymentId;
  _CheckoutPaymentMode _selectedPaymentMode = _CheckoutPaymentMode.card;
  String _selectedAddressPreview = '';
  final BillplzPaymentService _billplz = BillplzPaymentService();

  bool _isGuestUser() {
    final user = FirebaseAuth.instance.currentUser;
    return user == null || user.isAnonymous;
  }

  BoxDecoration _surfaceCardDecoration({bool highlighted = false}) {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(
        color: highlighted ? const Color(0xFFFFC9A6) : const Color(0xFFE8E8E8),
      ),
      boxShadow: const [
        BoxShadow(
          color: Color(0x12000000),
          blurRadius: 14,
          offset: Offset(0, 6),
        ),
      ],
    );
  }

  Widget _qtyButton({
    required IconData icon,
    required Future<void> Function() onTap,
  }) {
    return Material(
      color: const Color(0xFFFFF4EC),
      borderRadius: BorderRadius.circular(9),
      child: InkWell(
        borderRadius: BorderRadius.circular(9),
        onTap: () async => onTap(),
        child: SizedBox(
          width: 32,
          height: 32,
          child: Icon(icon, size: 18, color: Colors.black87),
        ),
      ),
    );
  }

  void _showSnack(BuildContext context, String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  CollectionReference<Map<String, dynamic>>? _addressCollection() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.isAnonymous) return null;
    return FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('addresses');
  }

  Stream<QuerySnapshot<Map<String, dynamic>>>? _addressBookStream() {
    final col = _addressCollection();
    if (col == null) return null;
    return col.orderBy('updatedAt', descending: true).snapshots();
  }

  List<_CheckoutAddress> _addressRows(
    QuerySnapshot<Map<String, dynamic>>? snap,
  ) {
    final rows = <_CheckoutAddress>[];
    final docs = snap?.docs ?? const [];
    for (final doc in docs) {
      final data = doc.data();
      final address = (data['address'] ?? '').toString().trim();
      if (address.isEmpty) continue;
      final label = (data['label'] ?? 'Address').toString().trim();
      final block = (data['block'] ?? '').toString().trim();
      final postcode = (data['postcode'] ?? '').toString().trim();
      final state = (data['state'] ?? '').toString().trim();
      final country = (data['country'] ?? '').toString().trim();
      rows.add(
        _CheckoutAddress(
          id: doc.id,
          label: label,
          address: address,
          block: block,
          postcode: postcode,
          state: state,
          country: country,
          fullAddress: _composeAddress(
            address: address,
            block: block,
            postcode: postcode,
            state: state,
            country: country,
          ),
        ),
      );
    }
    return rows;
  }

  _CheckoutAddress? _selectedAddress(List<_CheckoutAddress> rows) {
    if (rows.isEmpty) return null;
    if (_selectedAddressId == null) return rows.first;
    for (final row in rows) {
      if (row.id == _selectedAddressId) return row;
    }
    return rows.first;
  }

  String _composeAddress({
    required String address,
    required String block,
    required String postcode,
    required String state,
    required String country,
  }) {
    final lines =
        <String>[
          address.trim(),
          block.trim(),
          [postcode.trim(), state.trim()].where((e) => e.isNotEmpty).join(' '),
          country.trim(),
        ].where((e) => e.isNotEmpty).toList();
    return lines.join('\n');
  }

  String _readAddress(Map<String, dynamic>? data) {
    final map = data ?? const <String, dynamic>{};
    final address = (map['address'] ?? map['location'] ?? '').toString().trim();
    final block = (map['block'] ?? '').toString().trim();
    final postcode = (map['postcode'] ?? '').toString().trim();
    final state = (map['state'] ?? '').toString().trim();
    final country = (map['country'] ?? '').toString().trim();
    if (block.isNotEmpty ||
        postcode.isNotEmpty ||
        state.isNotEmpty ||
        country.isNotEmpty) {
      return _composeAddress(
        address: address,
        block: block,
        postcode: postcode,
        state: state,
        country: country,
      );
    }
    return address;
  }

  Future<String> _currentAddress() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.isAnonymous) return '';
    final doc =
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();
    return _readAddress(doc.data());
  }

  Future<void> _saveAddress(Map<String, String> value) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.isAnonymous) return;
    final address = (value['address'] ?? '').trim();
    final block = (value['block'] ?? '').trim();
    final postcode = (value['postcode'] ?? '').trim();
    final state = (value['state'] ?? '').trim();
    final country = (value['country'] ?? '').trim();
    await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
      'address': address,
      'block': block,
      'postcode': postcode,
      'state': state,
      'country': country,
      'fullAddress': _composeAddress(
        address: address,
        block: block,
        postcode: postcode,
        state: state,
        country: country,
      ),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<Map<String, String>?> _editAddressDialog(
    BuildContext context, {
    String initialAddress = '',
    String initialBlock = '',
    String initialPostcode = '',
    String initialState = '',
    String initialCountry = '',
    String initialLabel = 'Home',
  }) async {
    const labels = ['Home', 'Work', 'Office', 'Other'];
    final formKey = GlobalKey<FormState>();
    final addressCtrl = TextEditingController(text: initialAddress);
    final blockCtrl = TextEditingController(text: initialBlock);
    final postcodeCtrl = TextEditingController(text: initialPostcode);
    String selectedLabel =
        labels.contains(initialLabel) ? initialLabel : 'Other';
    String? selectedCountry =
        _countries.contains(initialCountry) ? initialCountry : null;
    String? selectedState =
        initialState.trim().isEmpty ? null : initialState.trim();
    final customLabelCtrl = TextEditingController(
      text: labels.contains(initialLabel) ? '' : initialLabel,
    );
    bool saving = false;

    return showDialog<Map<String, String>>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            return AlertDialog(
              title: const Text('Delivery Address'),
              content: SizedBox(
                width: 420,
                child: SingleChildScrollView(
                  child: Form(
                    key: formKey,
                    autovalidateMode: AutovalidateMode.onUserInteraction,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        DropdownButtonFormField<String>(
                          value: selectedLabel,
                          decoration: const InputDecoration(
                            labelText: 'Label',
                            border: OutlineInputBorder(),
                          ),
                          items:
                              labels
                                  .map(
                                    (label) => DropdownMenuItem<String>(
                                      value: label,
                                      child: Text(label),
                                    ),
                                  )
                                  .toList(),
                          onChanged: (v) {
                            setDialogState(() {
                              selectedLabel = v ?? selectedLabel;
                            });
                          },
                        ),
                        const SizedBox(height: 10),
                        if (selectedLabel == 'Other') ...[
                          TextFormField(
                            controller: customLabelCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Custom Label',
                              border: OutlineInputBorder(),
                            ),
                            validator: (v) {
                              if (selectedLabel != 'Other') return null;
                              if (v == null || v.trim().isEmpty) {
                                return 'Custom label is required.';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 10),
                        ],
                        TextFormField(
                          controller: addressCtrl,
                          maxLines: 3,
                          decoration: const InputDecoration(
                            hintText: 'Enter delivery address',
                            border: OutlineInputBorder(),
                          ),
                          validator:
                              (v) =>
                                  (v == null || v.trim().isEmpty)
                                      ? 'Address is required.'
                                      : null,
                        ),
                        const SizedBox(height: 10),
                        TextFormField(
                          controller: blockCtrl,
                          decoration: const InputDecoration(
                            hintText:
                                'Example: Block A / No. 12 / Apartment 3A',
                            border: OutlineInputBorder(),
                          ),
                          validator:
                              (v) =>
                                  (v == null || v.trim().isEmpty)
                                      ? 'Block is required.'
                                      : null,
                        ),
                        const SizedBox(height: 10),
                        TextFormField(
                          controller: postcodeCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            hintText: 'Example: 43000',
                            border: OutlineInputBorder(),
                          ),
                          validator: (v) {
                            final value = (v ?? '').trim();
                            if (value.isEmpty) return 'Postcode is required.';
                            if ((selectedCountry ?? '').toLowerCase() ==
                                'malaysia') {
                              if (!RegExp(r'^\d{5}$').hasMatch(value)) {
                                return 'Postcode must be 5 digits.';
                              }
                            } else if (value.length < 3) {
                              return 'Postcode must be at least 3 characters.';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 10),
                        DropdownButtonFormField<String>(
                          value: selectedCountry,
                          decoration: const InputDecoration(
                            hintText: 'Select country',
                            border: OutlineInputBorder(),
                          ),
                          items:
                              _countries
                                  .map(
                                    (country) => DropdownMenuItem<String>(
                                      value: country,
                                      child: Text(country),
                                    ),
                                  )
                                  .toList(),
                          onChanged: (value) {
                            setDialogState(() {
                              selectedCountry = value;
                              selectedState = null;
                            });
                          },
                          validator: (v) {
                            final value = (v ?? '').trim();
                            if (value.isEmpty) return 'Country is required.';
                            if (!_countries.contains(value)) {
                              return 'Please select a valid country.';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 10),
                        DropdownButtonFormField<String>(
                          value: selectedState,
                          decoration: InputDecoration(
                            hintText:
                                selectedCountry == null
                                    ? 'Select country first'
                                    : 'Select state',
                            border: const OutlineInputBorder(),
                          ),
                          items:
                              (selectedCountry == null
                                      ? const <String>[]
                                      : (_statesByCountry[selectedCountry!] ??
                                          const <String>[]))
                                  .map(
                                    (state) => DropdownMenuItem<String>(
                                      value: state,
                                      child: Text(state),
                                    ),
                                  )
                                  .toList(),
                          onChanged:
                              selectedCountry == null
                                  ? null
                                  : (value) {
                                    setDialogState(() => selectedState = value);
                                  },
                          validator: (v) {
                            if (selectedCountry == null ||
                                selectedCountry!.trim().isEmpty) {
                              return 'Select country first.';
                            }
                            final value = (v ?? '').trim();
                            if (value.isEmpty) return 'State is required.';
                            final allowed =
                                _statesByCountry[selectedCountry!] ??
                                const <String>[];
                            if (!allowed.contains(value)) {
                              return 'Please select a valid state.';
                            }
                            return null;
                          },
                        ),
                      ],
                    ),
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
                      saving
                          ? null
                          : () {
                            if (!formKey.currentState!.validate()) return;
                            setDialogState(() => saving = true);
                            final label =
                                selectedLabel == 'Other'
                                    ? customLabelCtrl.text.trim()
                                    : selectedLabel;
                            Navigator.pop(dialogContext, {
                              'label': label,
                              'address': addressCtrl.text.trim(),
                              'block': blockCtrl.text.trim(),
                              'postcode': postcodeCtrl.text.trim(),
                              'state': (selectedState ?? '').trim(),
                              'country': (selectedCountry ?? '').trim(),
                            });
                          },
                  child: Text(saving ? 'Saving...' : 'Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<String?> _upsertAddress({
    String? id,
    required String label,
    required String address,
    required String block,
    required String postcode,
    required String state,
    required String country,
  }) async {
    final col = _addressCollection();
    if (col == null) return null;

    final doc = id == null ? col.doc() : col.doc(id);
    await doc.set({
      'label': label.trim(),
      'address': address.trim(),
      'block': block.trim(),
      'postcode': postcode.trim(),
      'state': state.trim(),
      'country': country.trim(),
      'fullAddress': _composeAddress(
        address: address,
        block: block,
        postcode: postcode,
        state: state,
        country: country,
      ),
      'updatedAt': FieldValue.serverTimestamp(),
      if (id == null) 'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    return doc.id;
  }

  Future<void> _deleteAddress(String id) async {
    final col = _addressCollection();
    if (col == null) return;
    await col.doc(id).delete();
    if (_selectedAddressId == id && mounted) {
      setState(() {
        _selectedAddressId = null;
      });
    }
  }

  Future<String> _selectedAddressFromBook() async {
    if (_selectedAddressId == null || _selectedAddressId!.isEmpty) return '';
    final col = _addressCollection();
    if (col == null) return '';
    final doc = await col.doc(_selectedAddressId!).get();
    return _readAddress(doc.data());
  }

  PaymentMethodItem? _selectedPaymentMethod(AppStore store) {
    if (store.payments.isEmpty) return null;
    if (_selectedPaymentId == null) return store.payments.first;
    for (final card in store.payments) {
      if (card.id == _selectedPaymentId) return card;
    }
    return store.payments.first;
  }

  Future<void> _openCardDetail(BuildContext context) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) {
          return const CardDetailPage();
        },
      ),
    );
  }

  Future<bool> _verifyPayment(
    BuildContext context,
    PaymentMethodItem method,
  ) async {
    try {
      final verified = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (_) {
            return PaymentVerificationPage(
              paymentLabel: '${method.type} **** ${method.last4}',
            );
          },
        ),
      );
      return verified == true;
    } catch (e) {
      if (context.mounted) {
        _showSnack(context, 'Payment verification failed: $e');
      }
      return false;
    }
  }

  Future<void> _checkout(BuildContext context, AppStore store) async {
    if (_isGuestUser()) {
      _showSnack(context, 'Please login to checkout.');
      return;
    }

    var deliveryAddress = await _selectedAddressFromBook();
    if (deliveryAddress.isEmpty) deliveryAddress = await _currentAddress();
    if (!context.mounted) return;
    if (deliveryAddress.isEmpty) {
      _showSnack(context, 'Please add a delivery address first.');
      final added = await _editAddressDialog(context);
      if (!context.mounted) return;
      if (added == null) return;
      final label = (added['label'] ?? '').trim();
      final address = (added['address'] ?? '').trim();
      final block = (added['block'] ?? '').trim();
      final postcode = (added['postcode'] ?? '').trim();
      final state = (added['state'] ?? '').trim();
      final country = (added['country'] ?? '').trim();
      if (label.isEmpty ||
          address.isEmpty ||
          block.isEmpty ||
          postcode.isEmpty ||
          state.isEmpty ||
          country.isEmpty) {
        return;
      }

      await _upsertAddress(
        label: label,
        address: address,
        block: block,
        postcode: postcode,
        state: state,
        country: country,
      );
      await _saveAddress({
        'address': address,
        'block': block,
        'postcode': postcode,
        'state': state,
        'country': country,
      });
      if (!context.mounted) return;
      deliveryAddress = _composeAddress(
        address: address,
        block: block,
        postcode: postcode,
        state: state,
        country: country,
      );
    }

    final user = FirebaseAuth.instance.currentUser;
    final email = (user?.email ?? '').trim();
    final mobile = (user?.phoneNumber ?? '').trim();
    final preOrderId = 'PRE-${DateTime.now().millisecondsSinceEpoch}';
    final fallbackEmail = 'order-${preOrderId.toLowerCase()}@vocamart.local';
    final contactEmail =
        email.isNotEmpty ? email : (mobile.isEmpty ? fallbackEmail : '');
    final customerName =
        user?.displayName?.trim().isNotEmpty == true
            ? user!.displayName!.trim()
            : 'Customer';
    final amountToPay =
        store.payableTotal +
        store.estimateDeliveryFee(deliveryAddress: deliveryAddress);
    if (amountToPay <= 0) {
      _showSnack(context, 'Invalid checkout total.');
      return;
    }

    if (_selectedPaymentMode == _CheckoutPaymentMode.card) {
      if (store.payments.isEmpty) {
        _showSnack(context, 'Please add a payment card before checkout.');
        await _openCardDetail(context);
        return;
      }

      final method = _selectedPaymentMethod(store);
      if (method == null) {
        _showSnack(context, 'Please select a payment card.');
        return;
      }

      final ok = await _verifyPayment(context, method);
      if (!context.mounted) return;
      if (!ok) {
        _showSnack(context, 'Payment verification failed');
        return;
      }

      OrderItem? finalOrder;
      try {
        finalOrder = await store.checkout(
          paymentMethod: method,
          deliveryAddressOverride: deliveryAddress,
        );
      } on StateError catch (e) {
        if (!context.mounted) return;
        _showSnack(context, e.message);
        return;
      } on FirebaseException catch (e) {
        if (!context.mounted) return;
        _showSnack(context, 'Checkout failed: ${e.message ?? e.code}');
        return;
      } catch (e) {
        if (!context.mounted) return;
        _showSnack(context, 'Checkout failed: $e');
        return;
      }
      if (finalOrder == null || !context.mounted) return;

      await store.updateOrderPayment(
        orderId: finalOrder.id,
        paymentStatus: 'paid',
        paymentGateway: 'card',
      );
      await store.updateOrderStatus(finalOrder.id, 'To Ship');
      if (!context.mounted) return;
      _showSnack(
        context,
        'Card payment successful for order ${finalOrder.id}.',
      );
      Navigator.pushNamedAndRemoveUntil(context, '/home', (route) => false);
      return;
    }

    if (_selectedPaymentMode == _CheckoutPaymentMode.wallet) {
      if (store.walletBalance + 0.0001 < amountToPay) {
        _showSnack(
          context,
          'Insufficient wallet balance. Current RM ${store.walletBalance.toStringAsFixed(2)}, need RM ${amountToPay.toStringAsFixed(2)}.',
        );
        return;
      }

      OrderItem? finalOrder;
      try {
        finalOrder = await store.checkoutWithWallet(
          deliveryAddressOverride: deliveryAddress,
        );
      } on StateError catch (e) {
        if (!context.mounted) return;
        _showSnack(context, e.message);
        return;
      } on FirebaseException catch (e) {
        if (!context.mounted) return;
        _showSnack(context, 'Checkout failed: ${e.message ?? e.code}');
        return;
      } catch (e) {
        if (!context.mounted) return;
        _showSnack(context, 'Checkout failed: $e');
        return;
      }
      if (finalOrder == null || !context.mounted) return;

      await store.updateOrderStatus(finalOrder.id, 'To Ship');
      if (!context.mounted) return;
      _showSnack(
        context,
        'Digital wallet payment successful for order ${finalOrder.id}.',
      );
      Navigator.pushNamedAndRemoveUntil(context, '/home', (route) => false);
      return;
    }

    _showSnack(context, 'Creating Billplz payment...');

    final backendOk = await _billplz.healthCheck();
    if (!context.mounted) return;
    if (!backendOk) {
      await showDialog<void>(
        context: context,
        builder: (dCtx) {
          return AlertDialog(
            title: const Text('Payment Backend Unreachable'),
            content: const Text(
              'Cannot reach payment backend from this device. Check PAYMENT_API_BASE_URL, backend server, and Wi-Fi/firewall.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dCtx),
                child: const Text('OK'),
              ),
            ],
          );
        },
      );
      return;
    }

    final created = await _billplz.createBill(
      orderId: preOrderId,
      name: customerName,
      email: contactEmail,
      mobile: mobile,
      amountRm: amountToPay,
      description: 'Order $preOrderId',
    );
    debugPrint(
      'Billplz create result: success=${created.success}, billId=${created.billId}, billUrl=${created.billUrl}, error=${created.error}',
    );

    if (!context.mounted) return;
    if (!created.success || created.billId == null || created.billUrl == null) {
      await showDialog<void>(
        context: context,
        builder: (dCtx) {
          return AlertDialog(
            title: const Text('Billplz Create Bill Failed'),
            content: Text(
              created.error ??
                  'Billplz bill creation failed. Check backend URL/env configuration.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dCtx),
                child: const Text('OK'),
              ),
            ],
          );
        },
      );
      return;
    }

    final opened = await _billplz.openBillUrl(created.billUrl!);
    if (!context.mounted) return;
    if (!opened) {
      await showDialog<void>(
        context: context,
        builder: (dCtx) {
          return AlertDialog(
            title: const Text('Unable To Open Billplz'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Automatic open failed. Copy the Billplz URL and open it in your browser.',
                ),
                const SizedBox(height: 8),
                SelectableText(created.billUrl!),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () async {
                  await Clipboard.setData(
                    ClipboardData(text: created.billUrl!),
                  );
                  if (!dCtx.mounted) return;
                  ScaffoldMessenger.of(dCtx).showSnackBar(
                    const SnackBar(content: Text('Billplz link copied.')),
                  );
                },
                child: const Text('Copy Link'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(dCtx),
                child: const Text('Close'),
              ),
            ],
          );
        },
      );
    }

    if (!context.mounted) return;
    final checkNow = await showDialog<bool>(
      context: context,
      builder: (dCtx) {
        return AlertDialog(
          title: const Text('Billplz Payment Opened'),
          content: const Text(
            'Complete payment in Billplz page, then press "Check Payment Status".',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dCtx, false),
              child: const Text('Later'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(dCtx, true),
              child: const Text('Check Payment Status'),
            ),
          ],
        );
      },
    );

    if (checkNow == true) {
      final latest = await _billplz.fetchBill(created.billId!);
      if (!context.mounted) return;

      final paid = latest.paid == true;
      final state = (latest.state ?? '').toLowerCase();
      final paymentStatus =
          paid
              ? 'paid'
              : (state == 'expired' ||
                  state == 'cancelled' ||
                  state == 'failed')
              ? 'failed'
              : 'pending';

      if (paymentStatus == 'paid') {
        OrderItem? finalOrder;
        try {
          finalOrder = await store.checkout(
            paymentMethod: null,
            deliveryAddressOverride: deliveryAddress,
          );
        } on StateError catch (e) {
          if (!context.mounted) return;
          _showSnack(context, e.message);
          return;
        } on FirebaseException catch (e) {
          if (!context.mounted) return;
          _showSnack(context, 'Checkout failed: ${e.message ?? e.code}');
          return;
        } catch (e) {
          if (!context.mounted) return;
          _showSnack(context, 'Checkout failed: $e');
          return;
        }
        if (finalOrder == null || !context.mounted) return;

        await store.updateOrderPayment(
          orderId: finalOrder.id,
          paymentStatus: 'paid',
          paymentGateway: 'billplz',
          billId: created.billId,
          billUrl: created.billUrl,
          billState: latest.state ?? created.state,
        );
        await store.updateOrderStatus(finalOrder.id, 'To Ship');
        if (!context.mounted) return;
        _showSnack(context, 'Payment successful for order ${finalOrder.id}.');
        if (!context.mounted) return;
        Navigator.pushNamedAndRemoveUntil(context, '/home', (route) => false);
        return;
      } else if (paymentStatus == 'failed') {
        _showSnack(context, 'Payment failed/expired.');
      } else {
        _showSnack(context, 'Payment still pending.');
      }
    } else {
      if (!context.mounted) return;
      _showSnack(context, 'Payment link is ready. Complete payment later.');
    }

    // Keep user in cart when payment is pending/failed.
  }

  @override
  // Builds and returns the UI for this widget.
  Widget build(BuildContext context) {
    final store = AppStore.instance;

    return AnimatedBuilder(
      animation: store,
      builder: (context, _) {
        final isGuestUser = _isGuestUser();
        final hasAddressForEstimate = _selectedAddressPreview.trim().isNotEmpty;
        final estimatedDistanceKm =
            hasAddressForEstimate
                ? store.estimateDeliveryDistanceKm(
                  deliveryAddress: _selectedAddressPreview,
                )
                : 0.0;
        final estimatedDeliveryFee =
            hasAddressForEstimate
                ? store.estimateDeliveryFee(
                  deliveryAddress: _selectedAddressPreview,
                )
                : 0.0;
        final estimatedPayableTotal = store.payableTotal + estimatedDeliveryFee;

        var hasUnavailableItems = false;
        for (final item in store.cart) {
          final product = store.productById(item.productId);
          if (product == null || product.quantity < item.qty) {
            hasUnavailableItems = true;
            break;
          }
        }

        if (store.payments.isNotEmpty && _selectedPaymentId == null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted || store.payments.isEmpty) return;
            setState(() {
              _selectedPaymentId = store.payments.first.id;
            });
          });
        }

        return Scaffold(
          backgroundColor: const Color(0xFFFFFBF8),
          appBar: AppBar(
            title: Row(
              children: [
                const Text('My Cart'),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '${store.cart.length} item${store.cart.length == 1 ? '' : 's'}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            flexibleSpace: const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFFFF8A3D), CartPage.kOrange],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
            ),
            foregroundColor: Colors.black,
          ),
          body: SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final panelMaxHeight = constraints.maxHeight * 0.55;
                return Column(
                  children: [
                    Expanded(
                      child:
                          store.cart.isEmpty
                              ? const Center(
                                child: Text(
                                  'Your cart is empty',
                                  style: TextStyle(fontWeight: FontWeight.w800),
                                ),
                              )
                              : ListView.separated(
                                padding: const EdgeInsets.all(14),
                                itemCount: store.cart.length,
                                separatorBuilder: (_, __) {
                                  return const SizedBox(height: 10);
                                },
                                itemBuilder: (_, i) {
                                  final item = store.cart[i];
                                  final product = store.productById(
                                    item.productId,
                                  );
                                  if (product == null) {
                                    return const SizedBox.shrink();
                                  }
                                  final outOfStock = product.isOutOfStock;
                                  final exceedsStock =
                                      item.qty > product.quantity;

                                  return Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: _surfaceCardDecoration(),
                                    child: Row(
                                      children: [
                                        Container(
                                          width: 38,
                                          height: 38,
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFFFF2E8),
                                            borderRadius: BorderRadius.circular(
                                              10,
                                            ),
                                          ),
                                          child: const Icon(
                                            Icons.shopping_bag_outlined,
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                product.name,
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.w900,
                                                ),
                                              ),
                                              Text(
                                                'RM ${product.lowestPrice.toStringAsFixed(2)} each',
                                                style: const TextStyle(
                                                  color: CartPage.kOrange,
                                                  fontWeight: FontWeight.w700,
                                                ),
                                              ),
                                              if (outOfStock)
                                                const Text(
                                                  'Out of stock',
                                                  style: TextStyle(
                                                    color: Colors.redAccent,
                                                    fontWeight: FontWeight.w800,
                                                  ),
                                                )
                                              else if (exceedsStock)
                                                Text(
                                                  'Only ${product.quantity} left in stock',
                                                  style: const TextStyle(
                                                    color: Colors.redAccent,
                                                    fontWeight: FontWeight.w800,
                                                  ),
                                                ),
                                            ],
                                          ),
                                        ),
                                        _qtyButton(
                                          icon: Icons.remove,
                                          onTap: () async {
                                            await store.updateCartQty(
                                              product.id,
                                              item.qty - 1,
                                            );
                                          },
                                        ),
                                        Container(
                                          width: 38,
                                          alignment: Alignment.center,
                                          child: Text(
                                            '${item.qty}',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w900,
                                            ),
                                          ),
                                        ),
                                        _qtyButton(
                                          icon: Icons.add,
                                          onTap: () async {
                                            final ok = await store
                                                .updateCartQty(
                                                  product.id,
                                                  item.qty + 1,
                                                );
                                            if (!ok && context.mounted) {
                                              _showSnack(
                                                context,
                                                '${product.name} stock limit reached.',
                                              );
                                            }
                                          },
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                    ),
                    ConstrainedBox(
                      constraints: BoxConstraints(maxHeight: panelMaxHeight),
                      child: Container(
                        padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.only(
                            topLeft: Radius.circular(22),
                            topRight: Radius.circular(22),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Color(0x17000000),
                              blurRadius: 16,
                              offset: Offset(0, -4),
                            ),
                          ],
                        ),
                        child: SingleChildScrollView(
                          child: Column(
                            children: [
                              StreamBuilder<
                                QuerySnapshot<Map<String, dynamic>>
                              >(
                                stream: _addressBookStream(),
                                builder: (context, snap) {
                                  final rows = _addressRows(snap.data);
                                  final selected = _selectedAddress(rows);
                                  final selectedAddressText =
                                      (selected?.fullAddress ?? '').trim();
                                  if (_selectedAddressPreview !=
                                      selectedAddressText) {
                                    WidgetsBinding.instance
                                        .addPostFrameCallback((_) {
                                          if (!mounted) return;
                                          setState(() {
                                            _selectedAddressPreview =
                                                selectedAddressText;
                                          });
                                        });
                                  }
                                  if (rows.isNotEmpty &&
                                      _selectedAddressId == null) {
                                    WidgetsBinding.instance
                                        .addPostFrameCallback((_) {
                                          if (!mounted) return;
                                          setState(() {
                                            _selectedAddressId = rows.first.id;
                                          });
                                        });
                                  }

                                  return Container(
                                    width: double.infinity,
                                    margin: const EdgeInsets.only(bottom: 10),
                                    padding: const EdgeInsets.all(10),
                                    decoration: _surfaceCardDecoration(),
                                    // Show profile address fallback when no address book rows yet.
                                    // Checkout will still use this if no row is selected.
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            const Icon(
                                              Icons.location_on_outlined,
                                              color: CartPage.kOrange,
                                            ),
                                            const SizedBox(width: 8),
                                            const Expanded(
                                              child: Text(
                                                'Delivery Addresses',
                                                style: TextStyle(
                                                  fontWeight: FontWeight.w900,
                                                  color: CartPage.kOrange,
                                                ),
                                              ),
                                            ),
                                            TextButton(
                                              onPressed:
                                                  isGuestUser
                                                      ? null
                                                      : () async {
                                                        final value =
                                                            await _editAddressDialog(
                                                              context,
                                                            );
                                                        if (value == null) {
                                                          return;
                                                        }
                                                        final label =
                                                            (value['label'] ??
                                                                    '')
                                                                .trim();
                                                        final address =
                                                            (value['address'] ??
                                                                    '')
                                                                .trim();
                                                        final block =
                                                            (value['block'] ??
                                                                    '')
                                                                .trim();
                                                        final postcode =
                                                            (value['postcode'] ??
                                                                    '')
                                                                .trim();
                                                        final state =
                                                            (value['state'] ??
                                                                    '')
                                                                .trim();
                                                        final country =
                                                            (value['country'] ??
                                                                    '')
                                                                .trim();
                                                        if (label.isEmpty ||
                                                            address.isEmpty ||
                                                            block.isEmpty ||
                                                            postcode.isEmpty ||
                                                            state.isEmpty ||
                                                            country.isEmpty) {
                                                          return;
                                                        }
                                                        final id =
                                                            await _upsertAddress(
                                                              label: label,
                                                              address: address,
                                                              block: block,
                                                              postcode:
                                                                  postcode,
                                                              state: state,
                                                              country: country,
                                                            );
                                                        if (id != null &&
                                                            context.mounted) {
                                                          setState(
                                                            () =>
                                                                _selectedAddressId =
                                                                    id,
                                                          );
                                                          _showSnack(
                                                            context,
                                                            'Address added.',
                                                          );
                                                        }
                                                      },
                                              child: const Text('Add'),
                                            ),
                                          ],
                                        ),
                                        if (isGuestUser)
                                          const Padding(
                                            padding: EdgeInsets.only(top: 2),
                                            child: Text(
                                              'Guest mode: login required to add delivery addresses.',
                                              style: TextStyle(
                                                fontWeight: FontWeight.w700,
                                                color: Colors.redAccent,
                                              ),
                                            ),
                                          )
                                        else if (rows.isEmpty)
                                          const Padding(
                                            padding: EdgeInsets.only(top: 2),
                                            child: Text(
                                              'No saved addresses yet. Add Home / Work / Office address.',
                                              style: TextStyle(
                                                fontWeight: FontWeight.w700,
                                                color: Colors.redAccent,
                                              ),
                                            ),
                                          )
                                        else
                                          ...rows.map((row) {
                                            final isSelected =
                                                selected?.id == row.id;
                                            return Container(
                                              margin: const EdgeInsets.only(
                                                top: 8,
                                              ),
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 10,
                                                    vertical: 8,
                                                  ),
                                              decoration:
                                                  _surfaceCardDecoration(
                                                    highlighted: isSelected,
                                                  ).copyWith(
                                                    color:
                                                        isSelected
                                                            ? const Color(
                                                              0xFFFFF7F1,
                                                            )
                                                            : Colors.white,
                                                  ),
                                              child: Row(
                                                children: [
                                                  Radio<String>(
                                                    value: row.id,
                                                    groupValue: selected?.id,
                                                    activeColor:
                                                        CartPage.kOrange,
                                                    onChanged: (v) {
                                                      setState(
                                                        () =>
                                                            _selectedAddressId =
                                                                v,
                                                      );
                                                    },
                                                  ),
                                                  Expanded(
                                                    child: Column(
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment
                                                              .start,
                                                      children: [
                                                        Text(
                                                          row.label,
                                                          style:
                                                              const TextStyle(
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w900,
                                                              ),
                                                        ),
                                                        const SizedBox(
                                                          height: 2,
                                                        ),
                                                        Text(
                                                          row.fullAddress,
                                                          style: const TextStyle(
                                                            fontWeight:
                                                                FontWeight.w700,
                                                            color:
                                                                Colors.black87,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                  IconButton(
                                                    tooltip: 'Edit',
                                                    onPressed: () async {
                                                      final value =
                                                          await _editAddressDialog(
                                                            context,
                                                            initialAddress:
                                                                row.address,
                                                            initialBlock:
                                                                row.block,
                                                            initialPostcode:
                                                                row.postcode,
                                                            initialState:
                                                                row.state,
                                                            initialCountry:
                                                                row.country,
                                                            initialLabel:
                                                                row.label,
                                                          );
                                                      if (value == null) return;
                                                      final label =
                                                          (value['label'] ?? '')
                                                              .trim();
                                                      final address =
                                                          (value['address'] ??
                                                                  '')
                                                              .trim();
                                                      final block =
                                                          (value['block'] ?? '')
                                                              .trim();
                                                      final postcode =
                                                          (value['postcode'] ??
                                                                  '')
                                                              .trim();
                                                      final state =
                                                          (value['state'] ?? '')
                                                              .trim();
                                                      final country =
                                                          (value['country'] ??
                                                                  '')
                                                              .trim();
                                                      if (label.isEmpty ||
                                                          address.isEmpty ||
                                                          block.isEmpty ||
                                                          postcode.isEmpty ||
                                                          state.isEmpty ||
                                                          country.isEmpty) {
                                                        return;
                                                      }
                                                      await _upsertAddress(
                                                        id: row.id,
                                                        label: label,
                                                        address: address,
                                                        block: block,
                                                        postcode: postcode,
                                                        state: state,
                                                        country: country,
                                                      );
                                                      if (context.mounted) {
                                                        _showSnack(
                                                          context,
                                                          'Address updated.',
                                                        );
                                                      }
                                                    },
                                                    icon: const Icon(
                                                      Icons.edit_outlined,
                                                      size: 18,
                                                    ),
                                                  ),
                                                  IconButton(
                                                    tooltip: 'Delete',
                                                    onPressed: () async {
                                                      await _deleteAddress(
                                                        row.id,
                                                      );
                                                      if (context.mounted) {
                                                        _showSnack(
                                                          context,
                                                          'Address deleted.',
                                                        );
                                                      }
                                                    },
                                                    icon: const Icon(
                                                      Icons.delete_outline,
                                                      size: 18,
                                                      color: Colors.redAccent,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            );
                                          }),
                                      ],
                                    ),
                                  );
                                },
                              ),
                              Container(
                                width: double.infinity,
                                margin: const EdgeInsets.only(bottom: 10),
                                padding: const EdgeInsets.all(10),
                                decoration: _surfaceCardDecoration(),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        const Icon(
                                          Icons.credit_card_outlined,
                                          color: CartPage.kOrange,
                                        ),
                                        const SizedBox(width: 8),
                                        const Expanded(
                                          child: Text(
                                            'Payment Method',
                                            style: TextStyle(
                                              fontWeight: FontWeight.w900,
                                              color: CartPage.kOrange,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        TextButton(
                                          onPressed:
                                              isGuestUser
                                                  ? null
                                                  : () async {
                                                    await _openCardDetail(
                                                      context,
                                                    );
                                                  },
                                          child: const Text('Manage Cards'),
                                        ),
                                      ],
                                    ),
                                    const Text(
                                      'Choose one method: Card, Digital Wallet, or Billplz sandbox.',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.black54,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Wrap(
                                      spacing: 12,
                                      runSpacing: 8,
                                      children: [
                                        ChoiceChip(
                                          label: const Text('Card'),
                                          selected:
                                              _selectedPaymentMode ==
                                              _CheckoutPaymentMode.card,
                                          onSelected: (_) {
                                            setState(() {
                                              _selectedPaymentMode =
                                                  _CheckoutPaymentMode.card;
                                            });
                                          },
                                        ),
                                        ChoiceChip(
                                          label: const Text('Billplz'),
                                          selected:
                                              _selectedPaymentMode ==
                                              _CheckoutPaymentMode.billplz,
                                          onSelected: (_) {
                                            setState(() {
                                              _selectedPaymentMode =
                                                  _CheckoutPaymentMode.billplz;
                                            });
                                          },
                                        ),
                                        ChoiceChip(
                                          label: const Text('Digital Wallet'),
                                          selected:
                                              _selectedPaymentMode ==
                                              _CheckoutPaymentMode.wallet,
                                          onSelected: (_) {
                                            setState(() {
                                              _selectedPaymentMode =
                                                  _CheckoutPaymentMode.wallet;
                                            });
                                          },
                                        ),
                                      ],
                                    ),
                                    if (isGuestUser)
                                      const Text(
                                        'Guest mode: login required to add payment method.',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w700,
                                          color: Colors.redAccent,
                                        ),
                                      )
                                    else if (_selectedPaymentMode ==
                                            _CheckoutPaymentMode.card &&
                                        store.payments.isEmpty)
                                      const Text(
                                        'No payment card yet. Add one from Card Detail.',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w700,
                                          color: Colors.redAccent,
                                        ),
                                      )
                                    else if (_selectedPaymentMode ==
                                        _CheckoutPaymentMode.card)
                                      ...store.payments.map((card) {
                                        final selected =
                                            _selectedPaymentMethod(store)?.id ==
                                            card.id;
                                        return Container(
                                          margin: const EdgeInsets.only(top: 8),
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 8,
                                          ),
                                          decoration: _surfaceCardDecoration(
                                            highlighted: selected,
                                          ).copyWith(
                                            color:
                                                selected
                                                    ? const Color(0xFFFFF7F1)
                                                    : Colors.white,
                                          ),
                                          child: Row(
                                            children: [
                                              Radio<String>(
                                                value: card.id,
                                                groupValue:
                                                    _selectedPaymentMethod(
                                                      store,
                                                    )?.id,
                                                activeColor: CartPage.kOrange,
                                                onChanged: (v) {
                                                  setState(
                                                    () =>
                                                        _selectedPaymentId = v,
                                                  );
                                                },
                                              ),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      '${card.type} **** ${card.last4}',
                                                      style: const TextStyle(
                                                        fontWeight:
                                                            FontWeight.w900,
                                                      ),
                                                    ),
                                                    const SizedBox(height: 2),
                                                    Text(
                                                      '${card.holderName} - ${card.expiry}',
                                                      style: const TextStyle(
                                                        fontWeight:
                                                            FontWeight.w700,
                                                        color: Colors.black87,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                        );
                                      })
                                    else if (_selectedPaymentMode ==
                                        _CheckoutPaymentMode.wallet)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 8),
                                        child: Text(
                                          'Wallet Balance: RM ${store.walletBalance.toStringAsFixed(2)}'
                                          '${store.walletBalance + 0.0001 < estimatedPayableTotal ? '\nNot enough balance for current total.' : ''}',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w700,
                                            color:
                                                store.walletBalance + 0.0001 <
                                                        estimatedPayableTotal
                                                    ? Colors.redAccent
                                                    : Colors.black87,
                                          ),
                                        ),
                                      )
                                    else
                                      const Padding(
                                        padding: EdgeInsets.only(top: 8),
                                        child: Text(
                                          'Billplz selected. You will be redirected to Billplz payment page during checkout.',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w700,
                                            color: Colors.black87,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              Container(
                                decoration: _surfaceCardDecoration(),
                                padding: const EdgeInsets.all(10),
                                child: _VoucherCodeInput(store: store),
                              ),
                              const SizedBox(height: 8),
                              if (store.vouchers.isNotEmpty) ...[
                                const Align(
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    'My Vouchers',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                SizedBox(
                                  height: 74,
                                  child: ListView.separated(
                                    scrollDirection: Axis.horizontal,
                                    itemCount: store.vouchers.length,
                                    separatorBuilder: (_, __) {
                                      return const SizedBox(width: 8);
                                    },
                                    itemBuilder: (_, i) {
                                      final v = store.vouchers[i];
                                      final applied =
                                          store.appliedVoucher?.id == v.id;
                                      return Container(
                                        width: 235,
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFFFF8F2),
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                          border: Border.all(
                                            color: const Color(0xFFFFE0CA),
                                          ),
                                        ),
                                        child: Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                '${v.code} (${v.percent}% off)',
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w800,
                                                ),
                                              ),
                                            ),
                                            ElevatedButton(
                                              onPressed:
                                                  applied
                                                      ? null
                                                      : () async {
                                                        final msg = await store
                                                            .applyVoucher(v.id);
                                                        if (!context.mounted) {
                                                          return;
                                                        }
                                                        _showSnack(
                                                          context,
                                                          msg,
                                                        );
                                                      },
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor:
                                                    CartPage.kOrange,
                                                foregroundColor: Colors.black,
                                                minimumSize: const Size(56, 32),
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 10,
                                                    ),
                                              ),
                                              child: Text(
                                                applied ? 'Applied' : 'Apply',
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    },
                                  ),
                                ),
                                const SizedBox(height: 8),
                              ],
                              if (store.appliedVoucher != null)
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        'Voucher: ${store.appliedVoucher!.code}',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w800,
                                          color: CartPage.kOrange,
                                        ),
                                      ),
                                    ),
                                    TextButton(
                                      onPressed: () {
                                        store.clearAppliedVoucher();
                                      },
                                      child: const Text('Remove'),
                                    ),
                                  ],
                                ),
                              const SizedBox(height: 2),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.fromLTRB(
                                  12,
                                  12,
                                  12,
                                  10,
                                ),
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [
                                      Color(0xFFFFF6EE),
                                      Color(0xFFFFFDFB),
                                    ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: const Color(0xFFFFE3CF),
                                  ),
                                ),
                                child: Column(
                                  children: [
                                    Row(
                                      children: [
                                        const Expanded(
                                          child: Text(
                                            'Subtotal',
                                            style: TextStyle(
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ),
                                        Text(
                                          'RM ${store.cartTotal.toStringAsFixed(2)}',
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        const Expanded(
                                          child: Text(
                                            'Discount',
                                            style: TextStyle(
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ),
                                        Text(
                                          '- RM ${store.voucherDiscountAmount.toStringAsFixed(2)}',
                                          style: const TextStyle(
                                            color: CartPage.kOrange,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        const Expanded(
                                          child: Text(
                                            'Delivery Fee',
                                            style: TextStyle(
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ),
                                        Text(
                                          hasAddressForEstimate
                                              ? 'RM ${estimatedDeliveryFee.toStringAsFixed(2)}'
                                              : (isGuestUser
                                                  ? 'Login required'
                                                  : 'Add address'),
                                          style: const TextStyle(
                                            color: CartPage.kOrange,
                                          ),
                                        ),
                                      ],
                                    ),
                                    if (hasAddressForEstimate)
                                      Align(
                                        alignment: Alignment.centerLeft,
                                        child: Padding(
                                          padding: const EdgeInsets.only(
                                            top: 2,
                                          ),
                                          child: Text(
                                            'Estimated distance: ${estimatedDistanceKm.toStringAsFixed(1)} km',
                                            style: const TextStyle(
                                              fontSize: 12,
                                              color: Colors.black54,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                      ),
                                    const Padding(
                                      padding: EdgeInsets.symmetric(
                                        vertical: 8,
                                      ),
                                      child: Divider(height: 1),
                                    ),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            'Total: RM ${estimatedPayableTotal.toStringAsFixed(2)}',
                                            style: const TextStyle(
                                              fontSize: 17,
                                              fontWeight: FontWeight.w900,
                                            ),
                                          ),
                                        ),
                                        ElevatedButton.icon(
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: CartPage.kOrange,
                                            foregroundColor: Colors.black,
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 14,
                                              vertical: 12,
                                            ),
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                            ),
                                          ),
                                          onPressed:
                                              store.cart.isEmpty ||
                                                      hasUnavailableItems ||
                                                      isGuestUser
                                                  ? null
                                                  : () {
                                                    _checkout(context, store);
                                                  },
                                          icon: const Icon(
                                            Icons.lock_outline,
                                            size: 18,
                                          ),
                                          label: const Text(
                                            'Checkout',
                                            style: TextStyle(
                                              fontWeight: FontWeight.w900,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        );
      },
    );
  }
}

// This class defines _VoucherCodeInput, used for this page/feature.
class _VoucherCodeInput extends StatefulWidget {
  final AppStore store;
  const _VoucherCodeInput({required this.store});

  @override
  State<_VoucherCodeInput> createState() => _VoucherCodeInputState();
}

// This class defines _VoucherCodeInputState, used for this page/feature.
class _VoucherCodeInputState extends State<_VoucherCodeInput> {
  final _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  // Builds and returns the UI for this widget.
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _ctrl,
            textCapitalization: TextCapitalization.characters,
            decoration: const InputDecoration(
              isDense: true,
              hintText: 'Enter voucher code',
              border: OutlineInputBorder(),
            ),
          ),
        ),
        const SizedBox(width: 8),
        ElevatedButton(
          onPressed: () async {
            final msg = await widget.store.applyVoucherCode(_ctrl.text);
            if (!context.mounted) return;
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text(msg)));
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: CartPage.kOrange,
            foregroundColor: Colors.black,
          ),
          child: const Text('Apply Code'),
        ),
      ],
    );
  }
}
