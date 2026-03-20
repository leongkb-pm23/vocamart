// How this file works:
// 1) Data/models are declared first (if any).
// 2) UI widgets are built in build() methods.
// 3) Helper methods are used to keep UI code clean.

// File purpose: This file handles account page screen/logic.

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:fyp/components/confirm_dialog.dart';
import 'package:fyp/User/login.dart';
import 'package:fyp/User/edit_profile_page.dart';

import 'package:fyp/User/my_tier_page.dart';
import 'package:fyp/User/purchase_status_page.dart';
import 'package:fyp/User/purchase_history_page.dart';
import 'package:fyp/User/detail_ui.dart';
import 'package:fyp/User/wallet_voucher_discount_page.dart';
import 'package:fyp/User/voucher_page.dart';
import 'package:fyp/User/activities_page.dart';
import 'package:fyp/User/likes_page.dart';
import 'package:fyp/User/recently_viewed_page.dart';
import 'package:fyp/User/help_center_page.dart';
import 'package:fyp/User/search_history_page.dart';
import 'package:fyp/components/app_store.dart';

import 'package:fyp/Admin/admin_panel_page.dart';

// This class defines AccountPage, used for this page/feature.
class AccountPage extends StatefulWidget {
  static const kOrange = Color(0xFFFF6A00);
  const AccountPage({super.key});

  @override
  State<AccountPage> createState() => _AccountPageState();
}

// This class defines _AccountPageState, used for this page/feature.
class _AccountPageState extends State<AccountPage> {
  StreamSubscription<User?>? _authSub;
  User? _user;

  //  Admin state
  bool _adminLoading = true;
  bool _isAdmin = false;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _adminSub;

  @override
  void initState() {
    super.initState();
    _user = FirebaseAuth.instance.currentUser;

    // Listen login/logout changes.
    _authSub = FirebaseAuth.instance.authStateChanges().listen((u) {
      if (!mounted) return;
      setState(() {
        _user = u;
      });

      // When user changes, refresh admin check.
      _adminSub?.cancel();
      _adminLoading = true;
      _isAdmin = false;

      if (u != null) {
        _listenAdmin(u.uid);
      } else {
        if (mounted) {
          setState(() {
            _adminLoading = false;
          });
        }
      }
    });

    // initial admin listen
    if (_user != null) {
      _listenAdmin(_user!.uid);
    } else {
      _adminLoading = false;
    }
  }

  void _listenAdmin(String uid) {
    // Live admin role check. If admin doc changes, section updates instantly.
    final ref = FirebaseFirestore.instance.collection('admins').doc(uid);

    _adminSub = ref.snapshots().listen(
      (snap) {
        if (!mounted) return;
        setState(() {
          _isAdmin = snap.exists;
          _adminLoading = false;
        });
      },
      onError: (e) {
        // If rules block it or error, just treat as not admin
        if (!mounted) return;
        setState(() {
          _isAdmin = false;
          _adminLoading = false;
        });
      },
    );
  }

  @override
  void dispose() {
    _authSub?.cancel();
    _adminSub?.cancel();
    super.dispose();
  }

  void _open(BuildContext context, Widget page) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => page));
  }

  Future<void> _logout() async {
    // Keep navigator before await to avoid using stale BuildContext.
    final navigator = Navigator.of(context);
    final ok = await showConfirmDialog(
      context,
      title: 'Logout',
      message: 'Are you sure you want to logout?',
      confirmText: 'Logout',
    );
    if (!ok) return;

    await FirebaseAuth.instance.signOut();
    if (!mounted) return;

    navigator.pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginPage()),
      (route) {
        return false;
      },
    );
  }

  String _emailName(String? email) {
    if (email == null || email.trim().isEmpty) return "";
    final parts = email.split('@');
    if (parts.isEmpty) return email;
    return parts.first;
  }

  String _bestName({required User user, Map<String, dynamic>? data}) {
    // Name priority: Firestore profile > Firebase auth display name > email prefix.
    final fromDb = (data?['name'] as String?)?.trim();
    if (fromDb != null && fromDb.isNotEmpty) return fromDb;

    final fromAuth = user.displayName?.trim();
    if (fromAuth != null && fromAuth.isNotEmpty) return fromAuth;

    final fromEmail = _emailName(user.email).trim();
    if (fromEmail.isNotEmpty) return fromEmail;

    return "Account";
  }

  @override
  // Builds and returns the UI for this widget.
  Widget build(BuildContext context) {
    final user = _user;

    // Guest view does not read Firestore.
    if (user == null) {
      return _GuestLockedView(
        onLogin: () {
          Navigator.pushNamed(context, LoginPage.routeName);
        },
      );
    }

    // users/{uid} may not exist for some older accounts; fallback values are used below.
    final docRef = FirebaseFirestore.instance.collection('users').doc(user.uid);

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: docRef.snapshots(),
      builder: (context, snap) {
        // If logout happens while stream is active, return safely.
        if (_user == null) return const SizedBox.shrink();

        if (snap.hasError) {
          final msg = snap.error.toString();
          // Ignore brief permission flash during logout.
          if (msg.contains('permission-denied')) {
            return const SizedBox.shrink();
          }
          return _ErrorView(message: "Failed to load profile: $msg");
        }

        if (snap.connectionState == ConnectionState.waiting) {
          return const _LoadingView();
        }

        final data = snap.data?.data();
        final name = _bestName(user: user, data: data);
        final email = user.email ?? (data?['email'] as String? ?? "");
        final photoUrl = (data?['photoUrl'] as String?) ?? user.photoURL;

        return ListView(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 20),
          children: [
            _ProfileHeader(
              name: name,
              email: email,
              photoUrl: photoUrl,
              onEdit: () {
                _open(context, const EditProfilePage());
              },
            ),
            const SizedBox(height: 12),

            // Admin section (visible only for admin).
            if (_adminLoading) ...[
              const SizedBox(height: 4),
              const Center(
                child: SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
              const SizedBox(height: 8),
            ] else if (_isAdmin) ...[
              _SectionCard(
                title: "Admin",
                child: Column(
                  children: [
                    _RowTile(
                      icon: Icons.admin_panel_settings_outlined,
                      label: "Admin Panel",
                      subtitle: "Manage stores, promotions, products & prices",
                      onTap: () {
                        _open(context, const AdminPanelPage());
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],

            _SectionCard(
              title: "Account",
              child: Column(
                children: [
                  _RowTile(
                    icon: Icons.edit_outlined,
                    label: "Edit Profile",
                    subtitle: "Update your personal info",
                    onTap: () {
                      _open(context, const EditProfilePage());
                    },
                  ),
                  const Divider(height: 1),
                  _RowTile(
                    icon: Icons.card_membership_outlined,
                    label: "My Tier",
                    subtitle: "Membership & benefits",
                    onTap: () {
                      _open(context, const MyTierPage());
                    },
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            AnimatedBuilder(
              animation: AppStore.instance,
              builder: (context, _) {
                final toShipOrders = AppStore.instance.ordersByStatus(
                  "To Ship",
                );
                var toShipCount = 0;
                for (final order in toShipOrders) {
                  for (final item in order.items) {
                    toShipCount += item.qty > 0 ? item.qty : 1;
                  }
                }

                return _SectionCard(
                  title: "My Purchase",
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _IconLabel(
                        icon: Icons.local_shipping_outlined,
                        label: "To Ship",
                        badgeCount: toShipCount,
                        onTap: () {
                          _open(
                            context,
                            const PurchaseStatusPage(status: "To Ship"),
                          );
                        },
                      ),
                      _IconLabel(
                        icon: Icons.inventory_2_outlined,
                        label: "To Receive",
                        onTap: () {
                          _open(
                            context,
                            const PurchaseStatusPage(status: "To Receive"),
                          );
                        },
                      ),
                      _IconLabel(
                        icon: Icons.history,
                        label: "History",
                        onTap: () {
                          _open(context, const PurchaseHistoryPage());
                        },
                      ),
                    ],
                  ),
                );
              },
            ),

            const SizedBox(height: 12),

            AnimatedBuilder(
              animation: AppStore.instance,
              builder: (context, _) {
                final walletBalance = AppStore.instance.walletBalance;
                return _SectionCard(
                  title: "My Wallet",
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _IconLabel(
                            icon: Icons.wallet_outlined,
                            label: "Card Detail",
                            onTap: () {
                              _open(context, const CardDetailPage());
                            },
                          ),
                          _IconLabel(
                            icon: Icons.account_balance_wallet_outlined,
                            label: "E-Wallet",
                            onTap: () {
                              _open(context, const WalletVoucherDiscountPage());
                            },
                          ),
                          _IconLabel(
                            icon: Icons.discount_outlined,
                            label: "Voucher",
                            onTap: () {
                              _open(context, const VoucherStandalonePage());
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Balance: RM ${walletBalance.toStringAsFixed(2)}',
                        style: const TextStyle(
                          color: AccountPage.kOrange,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),

            const SizedBox(height: 12),

            _SectionCard(
              title: "More Activities",
              trailing: TextButton(
                onPressed: () {
                  _open(context, const ActivitiesPage());
                },
                child: const Text(
                  "See All",
                  style: TextStyle(
                    color: AccountPage.kOrange,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _SmallChip(
                      icon: Icons.thumb_up_alt_outlined,
                      label: "My Likes",
                      onTap: () {
                        _open(context, const LikesPage());
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _SmallChip(
                      icon: Icons.history_toggle_off,
                      label: "Recently Viewed",
                      onTap: () {
                        _open(context, const RecentlyViewedPage());
                      },
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),

            _SectionCard(
              title: "History",
              child: _RowTile(
                icon: Icons.search,
                label: "Search History",
                subtitle: "Your previous searches",
                onTap: () {
                  _open(context, const SearchHistoryPage());
                },
              ),
            ),

            const SizedBox(height: 12),

            _SectionCard(
              title: "Support",
              child: _RowTile(
                icon: Icons.help_outline,
                label: "Help Center",
                subtitle: "FAQs & support",
                onTap: () {
                  _open(context, const HelpCenterPage());
                },
              ),
            ),

            const SizedBox(height: 14),

            SizedBox(
              height: 50,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AccountPage.kOrange,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                onPressed: () async {
                  await _logout();
                },
                icon: const Icon(Icons.logout),
                label: const Text(
                  "Logout",
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/* ================== UI BELOW (same as before) ================== */

// This class defines _ProfileHeader, used for this page/feature.
class _ProfileHeader extends StatelessWidget {
  final String name;
  final String email;
  final String? photoUrl;
  final VoidCallback onEdit;

  const _ProfileHeader({
    required this.name,
    required this.email,
    required this.photoUrl,
    required this.onEdit,
  });

  @override
  // Builds and returns the UI for this widget.
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: const LinearGradient(
          colors: [Color(0xFFFF6A00), Color(0xFFFF8A3D)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          _ProfileAvatar(photoUrl: photoUrl, ringColor: Colors.white),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 2),
                if (email.isNotEmpty)
                  Text(
                    email,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.92),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                const SizedBox(height: 10),
                SizedBox(
                  height: 36,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: BorderSide(
                        color: Colors.white.withValues(alpha: 0.95),
                        width: 1.2,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: onEdit,
                    icon: const Icon(Icons.edit, size: 18),
                    label: const Text(
                      "Edit Profile",
                      style: TextStyle(fontWeight: FontWeight.w900),
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

// This class defines _GuestLockedView, used for this page/feature.
class _GuestLockedView extends StatelessWidget {
  final VoidCallback onLogin;
  const _GuestLockedView({required this.onLogin});

  @override
  // Builds and returns the UI for this widget.
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFF3F4F6),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.lock_outline,
                size: 46,
                color: AccountPage.kOrange,
              ),
              const SizedBox(height: 10),
              const Text(
                "Login required",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 6),
              const Text(
                "Please login to continue so you can view your profile.",
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.black54,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AccountPage.kOrange,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  onPressed: onLogin,
                  child: const Text(
                    "Login to continue",
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// This class defines _LoadingView, used for this page/feature.
class _LoadingView extends StatelessWidget {
  const _LoadingView();
  @override
  // Builds and returns the UI for this widget.
  Widget build(BuildContext context) {
    return const Center(child: CircularProgressIndicator());
  }
}

// This class defines _ErrorView, used for this page/feature.
class _ErrorView extends StatelessWidget {
  final String message;
  const _ErrorView({required this.message});

  @override
  // Builds and returns the UI for this widget.
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.red,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

// This class defines _ProfileAvatar, used for this page/feature.
class _ProfileAvatar extends StatelessWidget {
  final String? photoUrl;
  final Color ringColor;

  const _ProfileAvatar({
    required this.photoUrl,
    this.ringColor = AccountPage.kOrange,
  });

  @override
  // Builds and returns the UI for this widget.
  Widget build(BuildContext context) {
    final hasPhoto = photoUrl != null && photoUrl!.trim().isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(2.2),
      decoration: BoxDecoration(shape: BoxShape.circle, color: ringColor),
      child: CircleAvatar(
        radius: 28,
        backgroundColor: Colors.white,
        child:
            hasPhoto
                ? ClipOval(
                  child: Image.network(
                    photoUrl!,
                    width: 56,
                    height: 56,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) {
                      return const Icon(
                        Icons.person,
                        color: AccountPage.kOrange,
                        size: 32,
                      );
                    },
                  ),
                )
                : const Icon(
                  Icons.person,
                  color: AccountPage.kOrange,
                  size: 32,
                ),
      ),
    );
  }
}

// This class defines _SectionCard, used for this page/feature.
class _SectionCard extends StatelessWidget {
  final String title;
  final Widget child;
  final Widget? trailing;

  const _SectionCard({required this.title, required this.child, this.trailing});

  @override
  // Builds and returns the UI for this widget.
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 14,
            offset: const Offset(0, 8),
          ),
        ],
        border: Border.all(color: const Color(0xFFF1F1F1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: AccountPage.kOrange,
                  fontWeight: FontWeight.w900,
                  fontSize: 13,
                ),
              ),
              const Spacer(),
              if (trailing != null) trailing!,
            ],
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

// This class defines _RowTile, used for this page/feature.
class _RowTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? subtitle;
  final VoidCallback onTap;

  const _RowTile({
    required this.icon,
    required this.label,
    this.subtitle,
    required this.onTap,
  });

  @override
  // Builds and returns the UI for this widget.
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            Icon(icon, size: 20, color: Colors.black87),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      style: const TextStyle(
                        color: Colors.black54,
                        fontWeight: FontWeight.w600,
                        fontSize: 11.5,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.black45),
          ],
        ),
      ),
    );
  }
}

// This class defines _IconLabel, used for this page/feature.
class _IconLabel extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final int badgeCount;

  const _IconLabel({
    required this.icon,
    required this.label,
    required this.onTap,
    this.badgeCount = 0,
  });

  @override
  // Builds and returns the UI for this widget.
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: SizedBox(
        width: 62,
        child: Column(
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF3F4F6),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, size: 20, color: Colors.black87),
                ),
                if (badgeCount > 0)
                  Positioned(
                    right: -6,
                    top: -6,
                    child: Container(
                      constraints: const BoxConstraints(
                        minWidth: 18,
                        minHeight: 18,
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.redAccent,
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: Colors.white, width: 1),
                      ),
                      child: Text(
                        badgeCount > 99 ? '99+' : '$badgeCount',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// This class defines _SmallChip, used for this page/feature.
class _SmallChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _SmallChip({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  // Builds and returns the UI for this widget.
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFF3F4F6),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: Colors.black87),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 12,
                ),
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.black45),
          ],
        ),
      ),
    );
  }
}
