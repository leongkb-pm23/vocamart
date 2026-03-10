// How this file works:
// 1) Data/models are declared first (if any).
// 2) UI widgets are built in build() methods.
// 3) Helper methods are used to keep UI code clean.
//
// File purpose: This file handles main screen/logic.

import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:fyp/User/firebase_options.dart';

// AUTH
import 'package:fyp/User/login.dart';
import 'package:fyp/User/register.dart';
import 'package:fyp/User/login_phone.dart';
import 'package:fyp/User/otp_page.dart';
import 'package:fyp/User/forgot_password.dart';
import 'package:fyp/User/create_new_password.dart';

// MAIN
import 'package:fyp/User/homepage.dart';

// ACCOUNT
import 'package:fyp/User/account_page.dart';
import 'package:fyp/User/edit_profile_page.dart';

// ACCOUNT FEATURE PAGES
import 'package:fyp/User/my_tier_page.dart';
import 'package:fyp/User/purchase_status_page.dart';
import 'package:fyp/User/purchase_history_page.dart';
import 'package:fyp/User/detail_ui.dart';
import 'package:fyp/User/wallet_voucher_discount_page.dart';
import 'package:fyp/User/activities_page.dart';
import 'package:fyp/User/likes_page.dart';
import 'package:fyp/User/recently_viewed_page.dart';
import 'package:fyp/User/help_center_page.dart';
import 'package:fyp/User/search_history_page.dart';
import 'package:fyp/User/notifications_page.dart';

// ADMIN / DELIVERY
import 'package:fyp/Admin/admin_panel_page.dart';
import 'package:fyp/delivery_man/delivery_panel_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MyApp());
}

/// Keep route names in one place.
class AppRoutes {
  // OTP (needs args)
  static const otp = '/otp';

  // Account
  static const account = '/account';
  static const editProfile = '/edit-profile';

  // Admin / Delivery
  static const adminPanel = '/admin-panel';
  static const deliveryPanel = '/delivery-panel';

  // Account features
  static const myTier = '/my-tier';
  static const purchaseStatus = '/purchase-status'; // needs args
  static const purchaseHistory = '/purchase-history';
  static const cardDetail = '/card-detail';
  static const walletVoucherDiscount = '/wallet-voucher-discount';
  static const activities = '/activities';
  static const likes = '/likes';
  static const recentlyViewed = '/recently-viewed';
  static const helpCenter = '/help-center';
  static const searchHistory = '/search-history';
  static const notifications = '/notifications';
}

// This class defines MyApp, used for this page/feature.
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  Map<String, WidgetBuilder> _appRoutes() {
    return {
      // AUTH
      LoginPage.routeName: (_) => const LoginPage(),
      RegistrationPage.routeName: (_) => const RegistrationPage(),
      LoginPhonePage.routeName: (_) => const LoginPhonePage(),
      ForgotPasswordPage.routeName: (_) => const ForgotPasswordPage(),
      CreateNewPasswordPage.routeName: (_) => const CreateNewPasswordPage(),

      // MAIN
      HomePage.routeName: (_) => const HomePage(),

      // ACCOUNT
      AppRoutes.account: (_) => const AccountPage(),
      AppRoutes.editProfile: (_) => const EditProfilePage(),

      // ACCOUNT FEATURE PAGES
      AppRoutes.myTier: (_) => const MyTierPage(),
      AppRoutes.purchaseHistory: (_) => const PurchaseHistoryPage(),
      AppRoutes.cardDetail: (_) => const CardDetailPage(),
      AppRoutes.walletVoucherDiscount: (_) =>
      const WalletVoucherDiscountPage(),
      AppRoutes.activities: (_) => const ActivitiesPage(),
      AppRoutes.likes: (_) => const LikesPage(),
      AppRoutes.recentlyViewed: (_) => const RecentlyViewedPage(),
      AppRoutes.helpCenter: (_) => const HelpCenterPage(),
      AppRoutes.searchHistory: (_) => const SearchHistoryPage(),
      AppRoutes.notifications: (_) => const NotificationsPage(),

      // ADMIN / DELIVERY
      AppRoutes.adminPanel: (_) => const AdminPanelPage(),
      AppRoutes.deliveryPanel: (_) => const DeliveryPanelPage(),
    };
  }

  MaterialPageRoute _errorRoute(String msg) {
    return MaterialPageRoute(
      builder: (_) => Scaffold(
        appBar: AppBar(title: const Text("Route Error")),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              msg,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                color: Colors.red,
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'VOCAMART',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFFF6A00),
        ),
        scaffoldBackgroundColor: Colors.white,
      ),

      // Auth gate decides first screen.
      home: const AuthGate(),

      // Static routes.
      routes: _appRoutes(),

      // Dynamic routes.
      onGenerateRoute: (settings) {
        if (settings.name == AppRoutes.otp) {
          final args = settings.arguments;

          if (args is Map<String, dynamic> &&
              args['phoneE164'] is String &&
              args['verificationId'] is String) {
            return MaterialPageRoute(
              builder: (_) => OtpPage(
                phoneE164: args['phoneE164'] as String,
                verificationId: args['verificationId'] as String,
              ),
              settings: settings,
            );
          }

          return _errorRoute(
            "OTP route arguments missing: phoneE164 / verificationId",
          );
        }

        if (settings.name == AppRoutes.purchaseStatus) {
          final args = settings.arguments;

          if (args is Map<String, dynamic> && args['status'] is String) {
            return MaterialPageRoute(
              builder: (_) => PurchaseStatusPage(
                status: args['status'] as String,
              ),
              settings: settings,
            );
          }

          return _errorRoute(
            "PurchaseStatus route arguments missing: status",
          );
        }

        return null;
      },
    );
  }
}

/// Auth gate: guest/login/user/admin/delivery role routing.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  Widget _loadingView() {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }

  Future<bool> _safeDocExists(
      DocumentReference<Map<String, dynamic>> ref,
      ) async {
    try {
      final snap = await ref.get();
      return snap.exists;
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') return false;
      rethrow;
    }
  }

  Future<String> _roleFor(User user) async {
    if (user.isAnonymous) return 'guest';

    final db = FirebaseFirestore.instance;

    final isAdmin = await _safeDocExists(
      db.collection('admins').doc(user.uid),
    );
    if (isAdmin) return 'admin';

    final isDelivery = await _safeDocExists(
      db.collection('delivery_staff').doc(user.uid),
    );
    if (isDelivery) return 'delivery';

    // Fallback if delivery_staff collection read is restricted.
    try {
      final userDoc = await db.collection('users').doc(user.uid).get();
      final data = userDoc.data() ?? const <String, dynamic>{};

      if ((data['role'] ?? '').toString().toLowerCase() == 'delivery') {
        return 'delivery';
      }
      if (data['isDelivery'] == true) {
        return 'delivery';
      }
    } on FirebaseException catch (_) {}

    return 'user';
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return _loadingView();
        }

        final authUser = snap.data;
        if (authUser == null) {
          return const LoginPage();
        }

        return FutureBuilder<String>(
          future: _roleFor(authUser),
          builder: (context, roleSnap) {
            if (roleSnap.connectionState == ConnectionState.waiting) {
              return _loadingView();
            }

            final role = roleSnap.data ?? 'user';

            if (role == 'admin') {
              return const AdminPanelPage();
            }

            if (role == 'delivery') {
              return const DeliveryPanelPage();
            }

            return const HomePage();
          },
        );
      },
    );
  }
}