// How this file works:
// 1) Data/models are declared first (if any).
// 2) UI widgets are built in build() methods.
// 3) Helper methods are used to keep UI code clean.

// File purpose: This file handles wallet voucher discount page screen/logic.

import 'package:flutter/material.dart';

import 'package:fyp/components/app_store.dart';
import 'package:fyp/User/detail_ui.dart';

// This class defines WalletVoucherDiscountPage, used for this page/feature.
class WalletVoucherDiscountPage extends StatelessWidget {
  const WalletVoucherDiscountPage({super.key});
  static const _orange = Color(0xFFFF6A00);

  void _showMsg(BuildContext context, String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _showTopUpDialog(BuildContext context, AppStore store) async {
    if (store.payments.isEmpty) {
      _showMsg(context, 'No card found. Please add card details first.');
      return;
    }

    final formKey = GlobalKey<FormState>();
    final amountCtrl = TextEditingController();
    String selectedId = store.payments.first.id;
    bool saving = false;
    String? errorText;

    await showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            PaymentMethodItem? selected;
            for (final m in store.payments) {
              if (m.id == selectedId) {
                selected = m;
                break;
              }
            }

            return AlertDialog(
              title: const Text('Top Up E-Wallet'),
              content: SingleChildScrollView(
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      DropdownButtonFormField<String>(
                        value: selectedId,
                        decoration: const InputDecoration(
                          labelText: 'Select Card',
                          border: OutlineInputBorder(),
                        ),
                        items:
                            store.payments
                                .map(
                                  (m) => DropdownMenuItem<String>(
                                    value: m.id,
                                    child: Text('${m.type} **** ${m.last4}'),
                                  ),
                                )
                                .toList(),
                        onChanged: (v) {
                          if (v == null) {
                            return;
                          }
                          setDialogState(() => selectedId = v);
                        },
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: amountCtrl,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Top Up Amount (RM)',
                          border: OutlineInputBorder(),
                        ),
                        validator: (v) {
                          final raw = (v ?? '').trim();
                          if (raw.isEmpty) return 'Amount is required';
                          final amount = double.tryParse(raw);
                          if (amount == null) return 'Enter a valid amount';
                          if (amount <= 0) return 'Amount must be more than 0';
                          if (amount > 5000) {
                            return 'Max top up per transaction is RM 5000';
                          }
                          return null;
                        },
                      ),
                      if (selected != null) ...[
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'Card holder: ${selected.holderName}',
                            style: const TextStyle(
                              color: Colors.black54,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                      if (errorText != null) ...[
                        const SizedBox(height: 8),
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
                          : () async {
                            if (!formKey.currentState!.validate()) return;
                            final amount = double.parse(amountCtrl.text.trim());
                            PaymentMethodItem? selectedPayment;
                            for (final m in store.payments) {
                              if (m.id == selectedId) {
                                selectedPayment = m;
                                break;
                              }
                            }
                            if (selectedPayment == null) {
                              setDialogState(
                                () => errorText = 'Please select a valid card.',
                              );
                              return;
                            }

                            setDialogState(() {
                              saving = true;
                              errorText = null;
                            });

                            final msg = await store.topUpWallet(
                              amount: amount,
                              paymentMethod: selectedPayment,
                            );

                            if (!dialogContext.mounted) return;
                            final ok = msg.toLowerCase().startsWith(
                              'top up successful',
                            );
                            if (ok) {
                              Navigator.pop(dialogContext);
                              if (context.mounted) _showMsg(context, msg);
                            } else {
                              setDialogState(() {
                                errorText = msg;
                                saving = false;
                              });
                            }
                          },
                  child: Text(saving ? 'Processing...' : 'Top Up'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _walletBalanceCard(
    BuildContext context,
    AppStore store, {
    required double balance,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF2E8),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFFD7BA)),
      ),
      child: Row(
        children: [
          const CircleAvatar(
            backgroundColor: _orange,
            foregroundColor: Colors.black,
            child: Icon(Icons.account_balance_wallet_outlined),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Wallet Balance',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
                Text(
                  'RM ${balance.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 20,
                    color: _orange,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _orange,
                          foregroundColor: Colors.black,
                        ),
                        onPressed: () => _showTopUpDialog(context, store),
                        icon: const Icon(Icons.add_circle_outline),
                        label: const Text(
                          'Top Up',
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed:
                            () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const CardDetailPage(),
                              ),
                            ),
                        icon: const Icon(Icons.credit_card_outlined),
                        label: const Text('Card Detail'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  // Builds and returns the UI for this widget.
  Widget build(BuildContext context) {
    final store = AppStore.instance;

    return AnimatedBuilder(
      animation: store,
      builder: (context, _) {
        final walletBalance = store.walletBalance;

        return Scaffold(
          appBar: AppBar(
            title: const Text('E-Wallet'),
            backgroundColor: _orange,
            foregroundColor: Colors.black,
          ),
          body: ListView(
            padding: const EdgeInsets.all(14),
            children: [
              _walletBalanceCard(context, store, balance: walletBalance),
              const SizedBox(height: 12),
              Text(
                'Saved cards: ${store.payments.length}',
                style: const TextStyle(
                  color: Colors.black54,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
