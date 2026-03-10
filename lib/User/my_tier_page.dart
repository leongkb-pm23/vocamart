// How this file works:
// 1) Data/models are declared first (if any).
// 2) UI widgets are built in build() methods.
// 3) Helper methods are used to keep UI code clean.

// File purpose: This file handles my tier page screen/logic.

import 'package:flutter/material.dart';

import 'package:fyp/components/app_store.dart';

// This class defines MyTierPage, used for this page/feature.
class MyTierPage extends StatelessWidget {
  const MyTierPage({super.key});

  static const _orange = Color(0xFFFF6A00);
  static const _rewards = <TierVoucherReward>[
    TierVoucherReward(
      title: 'Points Voucher 5% Off',
      pointsCost: 120,
      percent: 5,
      minSpend: 30,
    ),
    TierVoucherReward(
      title: 'Points Voucher 10% Off',
      pointsCost: 250,
      percent: 10,
      minSpend: 60,
    ),
    TierVoucherReward(
      title: 'Points Voucher 15% Off',
      pointsCost: 450,
      percent: 15,
      minSpend: 100,
    ),
  ];

  void _showSnack(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  // Builds and returns the UI for this widget.
  Widget build(BuildContext context) {
    final store = AppStore.instance;

    return AnimatedBuilder(
      animation: store,
      builder: (context, _) {
        final tier = store.tier;
        final points = store.totalPoints;
        final earned = store.earnedPoints;
        final spent = store.pointsSpent;

        return Scaffold(
          appBar: AppBar(
            title: const Text('My Tier'),
            backgroundColor: _orange,
            foregroundColor: Colors.black,
          ),
          body: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFF6A00), Color(0xFFFFA05A)],
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tier,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Points: $points',
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  'Available Points: $points',
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Earned: $earned  |  Used: $spent',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: Colors.black54,
                  ),
                ),
                const SizedBox(height: 14),
                const Text(
                  'Redeem Points To Voucher',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 8),
                ..._rewards.map((reward) {
                  final enough = points >= reward.pointsCost;
                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE6E6E6)),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                reward.title,
                                style: const TextStyle(fontWeight: FontWeight.w900),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                '${reward.percent}% OFF  |  Min RM ${reward.minSpend.toStringAsFixed(2)}',
                                style: const TextStyle(
                                  color: Colors.black54,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                'Cost: ${reward.pointsCost} points',
                                style: const TextStyle(fontWeight: FontWeight.w700),
                              ),
                            ],
                          ),
                        ),
                        ElevatedButton(
                          onPressed: enough
                              ? () async {
                                  final msg = await store.redeemPointsForVoucher(reward);
                                  if (context.mounted) {
                                    _showSnack(context, msg);
                                  }
                                }
                              : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _orange,
                            foregroundColor: Colors.black,
                          ),
                          child: Text(enough ? 'Redeem' : 'Not enough'),
                        ),
                      ],
                    ),
                  );
                }),
                const SizedBox(height: 4),
                const Text(
                  'Tier Rules',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 8),
                const Text('Bronze: < 250 points'),
                const Text('Silver: 250 - 599 points'),
                const Text('Gold: 600 - 1199 points'),
                const Text('Platinum: 1200+ points'),
              ],
            ),
          ),
        );
      },
    );
  }
}



