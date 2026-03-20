// How this file works:
// 1) Data/models are declared first (if any).
// 2) UI widgets are built in build() methods.
// 3) Helper methods are used to keep UI code clean.

// File purpose: This file handles homepage screen/logic.

import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_image_slideshow/flutter_image_slideshow.dart';
import 'package:speech_to_text/speech_to_text.dart';

import 'package:fyp/User/account_page.dart';
import 'package:fyp/components/app_store.dart';
import 'package:fyp/User/camera_search_page.dart';
import 'package:fyp/User/cart_page.dart';
import 'package:fyp/User/top_menu_page.dart';
import 'package:fyp/User/help_center_page.dart';
import 'package:fyp/User/likes_page.dart';
import 'package:fyp/User/login.dart';
import 'package:fyp/User/new_products_page.dart';
import 'package:fyp/User/notifications_page.dart';
import 'package:fyp/delivery_man/delivery_panel_page.dart';
import 'package:fyp/User/price_dropping_page.dart';
import 'package:fyp/User/price_tracker_page.dart';
import 'package:fyp/User/recently_viewed_page.dart';
import 'package:fyp/User/search_history_page.dart';
import 'package:fyp/User/detail_ui.dart';
import 'package:fyp/User/event_detail_page.dart';
import 'package:fyp/User/voucher_page.dart';
import 'package:fyp/User/wallet_voucher_discount_page.dart';

// This class defines HomePage, used for this page/feature.
class HomePage extends StatefulWidget {
  static const routeName = '/home';
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

// This class defines _HomePageState, used for this page/feature.
class _HomePageState extends State<HomePage> {
  static const kOrange = Color(0xFFFF6A00);
  static const _allCategories = <String>[
    'For baby',
    'Beverage',
    'Food',
    'Household',
    'Fresh Food',
    'Chilled & Frozen',
    'Health & Beauty',
  ];

  int _currentIndex = 0;
  String _categoryFilter = '';
  String _search = '';
  bool _checkedDeliveryRedirect = false;
  final SpeechToText _speech = SpeechToText();
  bool _voiceReady = false;
  bool _voiceListening = false;
  bool _awaitingCommand = false;
  bool _handlingVoiceResult = false;
  bool _manualVoiceRequest = false;
  bool _voiceFatalErrorShown = false;
  bool _voiceInitInProgress = false;
  DateTime? _lastVoiceErrorAt;
  Timer? _voiceRestartTimer;
  Timer? _voiceSessionTimer;
  String? _voiceLocaleId;
  static const Duration _voiceSessionDuration = Duration(seconds: 25);
  static const String _wakePhrase = 'hey vocamart';
  static const String _wakePhraseAlt = 'hey voca mart';

  Future<void> _openPage(Widget page) async {
    await _pauseVoiceAssistant();
    if (!mounted) return;
    await Navigator.push(context, MaterialPageRoute(builder: (_) => page));
    await _resumeVoiceAssistant();
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _openVoiceRoute(String? route) async {
    if (route == null || !mounted) return;

    switch (route) {
      case '/cart':
        await _openPage(const CartPage());
        break;
      case '/likes':
        await _openPage(const LikesPage());
        break;
      case '/wallet-voucher-discount':
        await _openPage(const WalletVoucherDiscountPage());
        break;
      case '/account':
        setState(() {
          _currentIndex = 4;
        });
        break;
      case '/price-tracker':
        setState(() {
          _currentIndex = 3;
        });
        break;
      case '/help-center':
        await _openPage(const HelpCenterPage());
        break;
      case '/recently-viewed':
        await _openPage(const RecentlyViewedPage());
        break;
      case '/search-history':
        await _openPage(const SearchHistoryPage());
        break;
      case '/notifications':
        await _openPage(const NotificationsPage());
        break;
      default:
        break;
    }
  }

  @override
  void initState() {
    super.initState();
    _redirectDeliveryIfNeeded();
    if (!_isGuest()) _initVoiceAssistant();
  }

  @override
  void dispose() {
    _voiceRestartTimer?.cancel();
    _voiceSessionTimer?.cancel();
    _speech.stop();
    _speech.cancel();
    super.dispose();
  }

  void _startVoiceSessionTimer() {
    _voiceSessionTimer?.cancel();
    _voiceSessionTimer = Timer(_voiceSessionDuration, () async {
      if (!mounted) return;
      _manualVoiceRequest = false;
      _awaitingCommand = false;
      await _pauseVoiceAssistant();
      if (!mounted) return;
      _showSnack('Voice assistant off. Tap mic again to listen.');
    });
  }

  Future<void> _stopVoiceSession({bool notify = false}) async {
    _voiceSessionTimer?.cancel();
    _voiceSessionTimer = null;
    _manualVoiceRequest = false;
    _awaitingCommand = false;
    await _pauseVoiceAssistant();
    if (notify && mounted) {
      _showSnack('Voice assistant off.');
    }
  }

  Future<void> _redirectDeliveryIfNeeded() async {
    // Prevent duplicate redirects when widget rebuilds.
    if (_checkedDeliveryRedirect) return;
    _checkedDeliveryRedirect = true;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.isAnonymous) return;

    final db = FirebaseFirestore.instance;
    bool isDelivery = false;

    try {
      // First try role from users/{uid}, because this is the main profile doc.
      final uDoc = await db.collection('users').doc(user.uid).get();
      final data = uDoc.data() ?? const {};
      if ((data['role'] ?? '').toString().toLowerCase() == 'delivery' ||
          data['isDelivery'] == true) {
        isDelivery = true;
      }
    } on FirebaseException catch (_) {}

    if (!isDelivery) {
      try {
        // Fallback: check dedicated delivery_staff role collection.
        final dDoc = await db.collection('delivery_staff').doc(user.uid).get();
        isDelivery = dDoc.exists;
      } on FirebaseException catch (_) {}
    }

    if (!mounted || !isDelivery) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) {
          return const DeliveryPanelPage();
        },
      ),
    );
  }

  bool _isGuest() {
    final u = FirebaseAuth.instance.currentUser;
    return (u == null) || u.isAnonymous;
  }

  Widget _guestLocked({
    required String message,
    required BuildContext context,
  }) {
    return _RequireLoginView(
      message: message,
      onLogin: () {
        Navigator.pushNamed(context, LoginPage.routeName);
      },
    );
  }

  void _openCamera(BuildContext context) {
    _pauseVoiceAssistant();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) {
          return const CameraSearchPage();
        },
      ),
    ).whenComplete(() {
      _resumeVoiceAssistant();
    });
  }

  Future<void> _handleVoiceCommand(String command) async {
    final trimmed = command.trim();
    if (trimmed.isEmpty) return;

    final result = await AppStore.instance.handleVoiceCommand(trimmed);
    if (!mounted) return;

    if (result.categoryFilter != null) {
      // Voice can change category directly (example: "show vegetables").
      setState(() {
        _categoryFilter = result.categoryFilter!;
        _search = '';
      });
    }

    if (result.searchText != null) {
      // Save the voice keyword so Search History works for voice too.
      setState(() {
        _search = result.searchText!;
      });
      await AppStore.instance.recordSearch(result.searchText!);
    }

    if (result.product != null) {
      // If command resolved to one exact product, open product detail page.
      await AppStore.instance.markViewed(result.product!.id);
      if (!mounted) return;
      await _openPage(ProductDetailPage(product: result.product!));
    }

    await _openVoiceRoute(result.route);

    if (!mounted) return;
    _showSnack(result.message);
  }

  String _normalizeVoice(String text) {
    final lower = text.toLowerCase();
    final cleaned = lower.replaceAll(RegExp(r'[^a-z0-9\s]'), ' ');
    return cleaned.trim().replaceAll(RegExp(r'\s+'), ' ');
  }

  String _extractCommandAfterWakePhrase(String spoken) {
    final normalized = _normalizeVoice(spoken);
    final patterns = <RegExp>[
      RegExp(r'\bhey\s+vocamart\b'),
      RegExp(r'\bhey\s+voca\s+mart\b'),
      RegExp(r'\bhey\s+voka\s+mart\b'),
      RegExp(r'\bhey\s+voca\s+mark\b'),
      RegExp(r'\bhey\s+voka\s+mark\b'),
    ];

    for (final pattern in patterns) {
      final match = pattern.firstMatch(normalized);
      if (match == null) continue;
      final after = normalized.substring(match.end).trim();
      if (after.isNotEmpty) {
        return after;
      }
    }

    for (final wake in const [_wakePhrase, _wakePhraseAlt]) {
      final i = normalized.indexOf(wake);
      if (i < 0) continue;
      final after = normalized.substring(i + wake.length).trim();
      if (after.isNotEmpty) {
        return after;
      }
    }
    return '';
  }

  bool _hasWakePhrase(String spoken) {
    final normalized = _normalizeVoice(spoken);
    if (normalized.contains(_wakePhrase) ||
        normalized.contains(_wakePhraseAlt)) {
      return true;
    }
    final hasHey = RegExp(r'\bhey\b').hasMatch(normalized);
    final hasVoca =
        normalized.contains('voca') ||
        normalized.contains('voka') ||
        normalized.contains('vocar') ||
        normalized.contains('vokar');
    final hasMart =
        normalized.contains('mart') ||
        normalized.contains('mark') ||
        normalized.contains('matt');
    return hasHey && hasVoca && hasMart;
  }

  bool _isBenignVoiceError(String code) {
    const benign = {
      'error_no_match',
      'error_speech_timeout',
      'error_client',
      'error_network',
      'error_network_timeout',
      'error_recognizer_busy',
      'error_server_disconnected',
      'error_too_many_requests',
    };
    return benign.contains(code);
  }

  Future<String?> _pickSupportedVoiceLocale() async {
    try {
      final locales = await _speech.locales();
      if (locales.isEmpty) return null;

      bool hasLocale(String id) {
        for (final l in locales) {
          if (l.localeId.toLowerCase() == id.toLowerCase()) {
            return true;
          }
        }
        return false;
      }

      for (final preferred in const ['en_US', 'en_GB', 'en_MY']) {
        if (hasLocale(preferred)) return preferred;
      }

      final system = await _speech.systemLocale();
      if (system != null && hasLocale(system.localeId)) {
        return system.localeId;
      }
    } catch (_) {}
    return null;
  }

  void _scheduleAssistantRestart({
    Duration delay = const Duration(milliseconds: 900),
  }) {
    if (!mounted || !_voiceReady) return;
    if (_handlingVoiceResult) return;
    if (!_manualVoiceRequest) return;
    if (_currentIndex != 0 && _currentIndex != 2) return;
    if (_voiceRestartTimer?.isActive == true) return;
    _voiceRestartTimer = Timer(delay, () {
      _restartAssistantListening();
    });
  }

  Future<void> _pauseVoiceAssistant() async {
    _voiceRestartTimer?.cancel();
    _awaitingCommand = false;
    if (_voiceListening) {
      try {
        await _speech.stop();
      } catch (_) {}
    }
    if (!mounted) return;
    setState(() {
      _voiceListening = false;
    });
  }

  Future<void> _resumeVoiceAssistant() async {
    if (!mounted || !_voiceReady) return;
    if (_currentIndex != 0 && _currentIndex != 2) return;
    if (!_manualVoiceRequest) return;
    _scheduleAssistantRestart(delay: const Duration(milliseconds: 300));
  }

  Future<void> _initVoiceAssistant() async {
    if (_voiceInitInProgress) return;
    _voiceInitInProgress = true;
    bool ready = false;
    try {
      ready = await _speech.initialize(
        onStatus: (status) {
          if (!mounted) return;
          final lower = status.toLowerCase();
          if (lower == 'done' ||
              lower == 'notlistening' ||
              lower == 'donenoresult') {
            setState(() {
              _voiceListening = false;
            });
            _scheduleAssistantRestart();
          }
        },
        onError: (error) {
          if (!mounted) return;
          setState(() {
            _voiceListening = false;
          });
          final code = (error.errorMsg).toLowerCase().trim();
          final isBusy = code.contains('busy');
          final isLangUnsupported =
              code.contains('language') &&
              (code.contains('supported') || code.contains('available'));

          // Permission/audio-recording errors are fatal until user fixes settings.
          final fatal =
              code == 'error_insufficient_permissions' ||
              code == 'error_permission_denied' ||
              code == 'error_audio';

          if (fatal) {
            _voiceReady = false;
            if (!_voiceFatalErrorShown) {
              _voiceFatalErrorShown = true;
              _showSnack(
                'Voice assistant disabled: microphone permission/audio unavailable.',
              );
            }
            return;
          }

          if (isLangUnsupported) {
            // Fallback to plugin/device default locale.
            _voiceLocaleId = null;
            _showSnack('Selected voice language not supported. Using default.');
            _scheduleAssistantRestart(delay: const Duration(milliseconds: 700));
            return;
          }

          if (isBusy) {
            _scheduleAssistantRestart(
              delay: const Duration(milliseconds: 1500),
            );
            return;
          }

          final now = DateTime.now();
          final shouldNotifyError =
              _manualVoiceRequest &&
              !_isBenignVoiceError(code) &&
              (_lastVoiceErrorAt == null ||
                  now.difference(_lastVoiceErrorAt!).inSeconds >= 3);
          if (shouldNotifyError) {
            _lastVoiceErrorAt = now;
            _showSnack('Voice assistant error: ${error.errorMsg}');
          }
          _scheduleAssistantRestart(delay: const Duration(milliseconds: 1300));
        },
      );
      if (ready) {
        _voiceLocaleId = await _pickSupportedVoiceLocale();
      }
    } catch (_) {
      ready = false;
    } finally {
      _voiceInitInProgress = false;
    }
    if (!mounted) return;
    setState(() {
      _voiceReady = ready;
      if (ready) {
        _voiceFatalErrorShown = false;
      }
    });
    if (ready && mounted && (_currentIndex == 0 || _currentIndex == 2)) {
      _scheduleAssistantRestart(delay: const Duration(milliseconds: 350));
    }
  }

  Future<void> _restartAssistantListening() async {
    if (!mounted || !_voiceReady || _handlingVoiceResult) return;
    if (!_manualVoiceRequest) return;
    if (_currentIndex != 0 && _currentIndex != 2) return;
    if (_voiceListening) return;

    try {
      if (_speech.isListening) {
        await _speech.stop();
        await Future<void>.delayed(const Duration(milliseconds: 180));
      }

      await _speech.listen(
        onResult: (result) {
          final spoken = _normalizeVoice(result.recognizedWords);
          if (spoken.isEmpty) return;

          if (_awaitingCommand) {
            if (result.finalResult) {
              _awaitingCommand = false;
              final commandFromWake = _extractCommandAfterWakePhrase(spoken);
              final command =
                  commandFromWake.isNotEmpty ? commandFromWake : spoken;
              _handlingVoiceResult = true;
              _speech.stop();
              setState(() {
                _voiceListening = false;
              });
              _handleVoiceCommand(command).whenComplete(() {
                _handlingVoiceResult = false;
                _restartAssistantListening();
              });
            }
            return;
          }

          // In manual mic session, allow direct command.
          // If wake phrase is present, strip it before dispatching command.
          if (result.finalResult && _manualVoiceRequest) {
            final commandFromWake = _extractCommandAfterWakePhrase(spoken);
            if (commandFromWake.isNotEmpty) {
              _handlingVoiceResult = true;
              _speech.stop();
              setState(() {
                _voiceListening = false;
              });
              _handleVoiceCommand(commandFromWake).whenComplete(() {
                _handlingVoiceResult = false;
                _restartAssistantListening();
              });
              return;
            }

            if (_hasWakePhrase(spoken)) {
              _awaitingCommand = true;
              _showSnack('Hey VocaMart detected. Say your command.');
              return;
            }

            _handlingVoiceResult = true;
            _speech.stop();
            setState(() {
              _voiceListening = false;
            });
            _handleVoiceCommand(spoken).whenComplete(() {
              _handlingVoiceResult = false;
              _restartAssistantListening();
            });
            return;
          }

          if (_hasWakePhrase(spoken)) {
            final directCommand = _extractCommandAfterWakePhrase(spoken);
            if (directCommand.isNotEmpty) {
              _handlingVoiceResult = true;
              _speech.stop();
              setState(() {
                _voiceListening = false;
              });
              _handleVoiceCommand(directCommand).whenComplete(() {
                _handlingVoiceResult = false;
                _restartAssistantListening();
              });
              return;
            }

            _awaitingCommand = true;
            _showSnack('Hey VocaMart detected. Say your command.');
          }
        },
        listenOptions: SpeechListenOptions(
          cancelOnError: false,
          partialResults: true,
        ),
        localeId: _voiceLocaleId,
        listenFor: const Duration(minutes: 1),
        pauseFor: const Duration(seconds: 4),
      );

      if (!mounted) return;
      setState(() {
        _voiceListening = true;
      });
    } catch (e) {
      final code = e.toString().toLowerCase();
      if (code.contains('busy')) {
        try {
          await _speech.stop();
          await _speech.cancel();
        } catch (_) {}
        _scheduleAssistantRestart(delay: const Duration(milliseconds: 1700));
        return;
      }
      if (code.contains('language') &&
          (code.contains('supported') || code.contains('available'))) {
        _voiceLocaleId = null;
      }
      if (!mounted) return;
      setState(() {
        _voiceListening = false;
      });
      _scheduleAssistantRestart(delay: const Duration(milliseconds: 1500));
    }
  }

  Future<void> _openVoiceCommand() async {
    if (_isGuest()) {
      _showSnack('Please login to use voice assistant.');
      return;
    }

    // Toggle behavior: tap once to start a short listening session, tap again to stop.
    if (_manualVoiceRequest) {
      await _stopVoiceSession(notify: true);
      return;
    }

    if (!_voiceReady) {
      await _initVoiceAssistant();
      if (!_voiceReady) {
        _showSnack(
          'Voice recognition is not ready. Please allow microphone permission and try again.',
        );
        return;
      }
    }

    _manualVoiceRequest = true;
    _awaitingCommand = false;
    _startVoiceSessionTimer();
    if (_voiceListening) {
      try {
        await _speech.stop();
      } catch (_) {}
      if (!mounted) return;
      setState(() {
        _voiceListening = false;
      });
    }

    _showSnack(
      'Voice assistant on for ${_voiceSessionDuration.inSeconds}s. Say "Hey VocaMart" then your command.',
    );
    await _restartAssistantListening();
  }

  @override
  // Builds and returns the UI for this widget.
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: _SearchFab(
        isActive: _currentIndex == 2,
        onTap: () {
          _openCamera(context);
        },
      ),
      bottomNavigationBar: _BottomBar(
        currentIndex: _currentIndex,
        onTap: (i) async {
          setState(() {
            _currentIndex = i;
          });
          if (i == 0 || i == 2) {
            await _resumeVoiceAssistant();
          } else {
            await _pauseVoiceAssistant();
          }
        },
      ),
      body: SafeArea(child: _buildBody(context)),
    );
  }

  Widget _buildBody(BuildContext context) {
    final isGuest = _isGuest();

    // Bottom tab index controls which main section is displayed.
    switch (_currentIndex) {
      case 0:
      case 2:
        return _homeContent(context);
      case 1:
        if (isGuest) {
          return _guestLocked(
            message: 'Login required to view vouchers.',
            context: context,
          );
        }
        return const VoucherPage();
      case 3:
        if (isGuest) {
          return _guestLocked(
            message: 'Login required to use Price Tracker.',
            context: context,
          );
        }
        return const PriceTrackerPage();
      case 4:
        if (isGuest) {
          return _guestLocked(
            message: 'Please login to view your profile.',
            context: context,
          );
        }
        return const AccountPage();
      default:
        return _homeContent(context);
    }
  }

  Widget _homeContent(BuildContext context) {
    final store = AppStore.instance;

    return AnimatedBuilder(
      animation: store,
      builder: (context, _) {
        final products = store.filteredProducts(
          category: _categoryFilter,
          search: _search,
        );
        // Limit price-drop section size so home stays fast and clean.
        final priceDrops = <ProductItem>[];
        for (final product in store.priceDrops) {
          if (priceDrops.length >= 8) break;
          priceDrops.add(product);
        }

        return ListView(
          padding: EdgeInsets.zero,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
              child: _TopSearchBar(
                search: _search,
                cartItemCount: _cartItemCount(store.cart),
                unreadNotificationsStream: _unreadNotificationsStream(),
                onChanged: (v) {
                  setState(() {
                    _search = v;
                  });
                },
                onSubmitted: (v) {
                  AppStore.instance.recordSearch(v);
                },
                onVoice: _openVoiceCommand,
                onCameraInBox: () {
                  _openCamera(context);
                },
                onList: () {
                  _openPage(const TopMenuPage());
                },
                onCart: () {
                  _openPage(const CartPage());
                },
                onBell: () {
                  _openPage(const NotificationsPage());
                },
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(14, 6, 14, 8),
              child: Text(
                'Up Coming Event',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: kOrange,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: const _EventsBanner(),
            ),
            const SizedBox(height: 14),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: _CategoriesSection(
                selected: _categoryFilter,
                onSeeAll: () async {
                  final picked = await Navigator.push<String>(
                    context,
                    MaterialPageRoute(
                      builder: (_) {
                        return _AllCategoriesPage(
                          selected: _categoryFilter,
                          categories: _allCategories,
                        );
                      },
                    ),
                  );
                  if (!mounted || picked == null) return;
                  setState(() {
                    _categoryFilter = picked;
                  });
                },
                onTapCategory: (v) {
                  setState(() {
                    _categoryFilter = v;
                  });
                },
              ),
            ),
            if (_categoryFilter.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Chip(
                    label: Text('Filter: $_categoryFilter'),
                    onDeleted: () {
                      setState(() {
                        _categoryFilter = '';
                      });
                    },
                  ),
                ),
              ),
            const SizedBox(height: 14),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: _ProductSection(
                title: 'Products',
                products: products.take(8).toList(),
                onSeeAll: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) {
                        return _AllProductsPage(
                          initialCategory: _categoryFilter,
                          initialSearch: _search,
                        );
                      },
                    ),
                  );
                },
              ),
            ),
            if (priceDrops.isNotEmpty) ...[
              const SizedBox(height: 20),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: _ProductSection(
                  title: 'Price Dropping Products',
                  products: priceDrops,
                  onSeeAll: () {
                    _openPage(const PriceDroppingPage());
                  },
                ),
              ),
            ],
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: _ProductSection(
                title: 'Latest Products',
                products: store.newProducts,
                onSeeAll: () {
                  _openPage(const NewProductsPage());
                },
              ),
            ),
            const SizedBox(height: 24),
          ],
        );
      },
    );
  }

  int _cartItemCount(List<CartItem> items) {
    var count = 0;
    for (final item in items) {
      if (item.qty > 0) {
        count += item.qty;
      }
    }
    return count;
  }

  Stream<bool> _unreadNotificationsStream() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.isAnonymous) {
      return Stream<bool>.value(false).asBroadcastStream();
    }

    return FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('notifications')
        .where('read', isEqualTo: false)
        .limit(1)
        .snapshots()
        .map((snap) => snap.docs.isNotEmpty)
        .asBroadcastStream();
  }
}

// This class defines _RequireLoginView, used for this page/feature.
class _RequireLoginView extends StatelessWidget {
  final String message;
  final VoidCallback onLogin;

  const _RequireLoginView({required this.message, required this.onLogin});

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
                color: Color(0xFFFF6A00),
              ),
              const SizedBox(height: 10),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF6A00),
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: onLogin,
                  child: const Text(
                    'Login',
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

// This class defines _TopSearchBar, used for this page/feature.
class _TopSearchBar extends StatelessWidget {
  static const kOrange = Color(0xFFFF6A00);

  final String search;
  final int cartItemCount;
  final Stream<bool> unreadNotificationsStream;
  final ValueChanged<String> onChanged;
  final ValueChanged<String> onSubmitted;
  final VoidCallback onVoice;
  final VoidCallback onCameraInBox;
  final VoidCallback onList;
  final VoidCallback onCart;
  final VoidCallback onBell;

  const _TopSearchBar({
    required this.search,
    required this.cartItemCount,
    required this.unreadNotificationsStream,
    required this.onChanged,
    required this.onSubmitted,
    required this.onVoice,
    required this.onCameraInBox,
    required this.onList,
    required this.onCart,
    required this.onBell,
  });

  @override
  // Builds and returns the UI for this widget.
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 390;
        final outerGap = compact ? 4.0 : 8.0;
        final endGap = compact ? 2.0 : 6.0;
        final actionConstraints = BoxConstraints.tightFor(
          width: compact ? 32 : 36,
          height: compact ? 32 : 36,
        );

        return Row(
          children: [
            IconButton(
              onPressed: onList,
              icon: const Icon(
                Icons.format_list_bulleted,
                color: kOrange,
                size: 24,
              ),
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              constraints: actionConstraints,
            ),
            SizedBox(width: outerGap),
            Expanded(
              child: Container(
                height: 46,
                padding: EdgeInsets.symmetric(horizontal: compact ? 6 : 10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: kOrange, width: 1.6),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.search, color: kOrange, size: 19),
                    const SizedBox(width: 6),
                    Expanded(
                      child: TextField(
                        onChanged: onChanged,
                        onSubmitted: onSubmitted,
                        decoration: const InputDecoration(
                          hintText: 'Search products',
                          border: InputBorder.none,
                          isCollapsed: true,
                        ),
                      ),
                    ),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                      constraints: actionConstraints,
                      onPressed: onCameraInBox,
                      icon: const Icon(
                        Icons.photo_camera_outlined,
                        color: kOrange,
                        size: 22,
                      ),
                    ),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                      constraints: actionConstraints,
                      onPressed: onVoice,
                      icon: const Icon(
                        Icons.mic_none,
                        color: kOrange,
                        size: 22,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(width: outerGap),
            Stack(
              clipBehavior: Clip.none,
              children: [
                IconButton(
                  onPressed: onCart,
                  icon: const Icon(
                    Icons.shopping_cart_outlined,
                    color: kOrange,
                    size: 22,
                  ),
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: actionConstraints,
                ),
                if (cartItemCount > 0)
                  Positioned(
                    right: -2,
                    top: -2,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 16,
                        minHeight: 16,
                      ),
                      child: Text(
                        cartItemCount > 99 ? '99+' : '$cartItemCount',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            SizedBox(width: endGap),
            StreamBuilder<bool>(
              stream: unreadNotificationsStream,
              initialData: false,
              builder: (context, snap) {
                final hasUnread = snap.data == true;
                return Stack(
                  clipBehavior: Clip.none,
                  children: [
                    IconButton(
                      onPressed: onBell,
                      icon: const Icon(
                        Icons.notifications_none,
                        color: kOrange,
                        size: 22,
                      ),
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                      constraints: actionConstraints,
                    ),
                    if (hasUnread)
                      const Positioned(
                        right: 2,
                        top: 2,
                        child: SizedBox(
                          width: 9,
                          height: 9,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: Colors.red,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ],
        );
      },
    );
  }
}

// This class defines _CategoriesSection, used for this page/feature.
class _CategoriesSection extends StatelessWidget {
  static const kOrange = Color(0xFFFF6A00);

  final String selected;
  final VoidCallback onSeeAll;
  final ValueChanged<String> onTapCategory;

  const _CategoriesSection({
    required this.selected,
    required this.onSeeAll,
    required this.onTapCategory,
  });

  @override
  // Builds and returns the UI for this widget.
  Widget build(BuildContext context) {
    final items = <_CategoryItemData>[
      _CategoryItemData('For baby', Icons.child_friendly_outlined),
      _CategoryItemData('Beverage', Icons.local_drink_outlined),
      _CategoryItemData('Food', Icons.egg_outlined),
      _CategoryItemData('Household', Icons.cleaning_services_outlined),
      _CategoryItemData('Fresh Food', Icons.eco_outlined),
      _CategoryItemData('Chilled & Frozen', Icons.ac_unit),
      _CategoryItemData('Health & Beauty', Icons.spa_outlined),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              'Categories',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: kOrange,
              ),
            ),
            const Spacer(),
            TextButton(
              onPressed: onSeeAll,
              child: const Text(
                'SEE ALL',
                style: TextStyle(fontWeight: FontWeight.w900, color: kOrange),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        GridView.builder(
          itemCount: items.length,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 4,
            mainAxisSpacing: 14,
            crossAxisSpacing: 14,
            childAspectRatio: 0.72,
          ),
          itemBuilder: (_, i) {
            final it = items[i];
            return _CategoryItem(
              label: it.label,
              icon: it.icon,
              selected: selected.toLowerCase() == it.label.toLowerCase(),
              onTap: () {
                onTapCategory(it.label);
              },
            );
          },
        ),
      ],
    );
  }
}

// This class defines _CategoryItemData, used for this page/feature.
class _CategoryItemData {
  final String label;
  final IconData icon;
  _CategoryItemData(this.label, this.icon);
}

// This class defines _CategoryItem, used for this page/feature.
class _CategoryItem extends StatelessWidget {
  static const kOrange = Color(0xFFFF6A00);

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _CategoryItem({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  // Builds and returns the UI for this widget.
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Column(
        children: [
          Container(
            height: 64,
            width: 64,
            decoration: BoxDecoration(
              color: selected ? const Color(0xFFFFF1E8) : Colors.white,
              border: Border.all(color: kOrange, width: selected ? 2.4 : 1.8),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(icon, color: Colors.black87, size: 28),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w900,
              color: Colors.black,
              height: 1.1,
            ),
          ),
        ],
      ),
    );
  }
}

// This class defines _ProductSection, used for this page/feature.
class _ProductSection extends StatelessWidget {
  static const kOrange = Color(0xFFFF6A00);

  final String title;
  final List<ProductItem> products;
  final VoidCallback onSeeAll;

  const _ProductSection({
    required this.title,
    required this.products,
    required this.onSeeAll,
  });

  @override
  // Builds and returns the UI for this widget.
  Widget build(BuildContext context) {
    final store = AppStore.instance;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: kOrange,
                ),
              ),
            ),
            TextButton(
              onPressed: onSeeAll,
              child: const Text(
                'SEE ALL',
                style: TextStyle(fontWeight: FontWeight.w900, color: kOrange),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (products.isEmpty)
          const SizedBox(
            height: 88,
            child: Center(
              child: Text(
                'No items available',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          )
        else
          SizedBox(
            height: 190,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: products.length,
              separatorBuilder: (_, __) {
                return const SizedBox(width: 12);
              },
              itemBuilder: (_, i) {
                final p = products[i];
                return InkWell(
                  onTap: () {
                    store.markViewed(p.id);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) {
                          return ProductDetailPage(product: p);
                        },
                      ),
                    );
                  },
                  child: _ProductCard(product: p),
                );
              },
            ),
          ),
      ],
    );
  }
}

// This class defines _ProductCard, used for this page/feature.
class _ProductCard extends StatelessWidget {
  static const kOrange = Color(0xFFFF6A00);

  final ProductItem product;

  const _ProductCard({required this.product});

  bool _isHttpImageUrl(String? raw) {
    if (raw == null || raw.trim().isEmpty) return false;
    final uri = Uri.tryParse(raw.trim());
    return uri != null && (uri.scheme == 'http' || uri.scheme == 'https');
  }

  @override
  // Builds and returns the UI for this widget.
  Widget build(BuildContext context) {
    return Container(
      width: 145,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE6E6E6)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final imageHeight = (constraints.maxHeight * 0.42).clamp(74.0, 90.0);

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                height: imageHeight,
                decoration: BoxDecoration(
                  color: const Color(0xFFEDEDED),
                  borderRadius: BorderRadius.circular(8),
                ),
                child:
                    _isHttpImageUrl(product.imageUrl)
                        ? ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(
                            product.imageUrl!,
                            width: double.infinity,
                            height: double.infinity,
                            fit: BoxFit.cover,
                            errorBuilder:
                                (_, __, ___) => const Center(
                                  child: Icon(
                                    Icons.shopping_bag_outlined,
                                    color: Colors.black45,
                                  ),
                                ),
                          ),
                        )
                        : const Center(
                          child: Icon(
                            Icons.shopping_bag_outlined,
                            color: Colors.black45,
                          ),
                        ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      product.cheapestStore,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 10,
                        color: Colors.black54,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      product.isOutOfStock
                          ? 'Stock: 0'
                          : 'Stock: ${product.quantity}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color:
                            product.isOutOfStock
                                ? Colors.redAccent
                                : Colors.black54,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      product.isOutOfStock
                          ? 'Out of stock'
                          : 'RM ${product.lowestPrice.toStringAsFixed(2)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        color:
                            product.isOutOfStock ? Colors.redAccent : kOrange,
                      ),
                    ),
                  ),
                  if (product.oldPrice != null && !product.isOutOfStock) ...[
                    const SizedBox(width: 6),
                    Text(
                      'RM ${product.oldPrice!.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 10,
                        color: Colors.black38,
                        decoration: TextDecoration.lineThrough,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

// This class defines _AllCategoriesPage, used for this page/feature.
class _AllCategoriesPage extends StatelessWidget {
  final String selected;
  final List<String> categories;

  const _AllCategoriesPage({required this.selected, required this.categories});

  @override
  // Builds and returns the UI for this widget.
  Widget build(BuildContext context) {
    const kOrange = Color(0xFFFF6A00);

    return Scaffold(
      appBar: AppBar(
        title: const Text('All Categories'),
        backgroundColor: kOrange,
        foregroundColor: Colors.black,
      ),
      body: ListView.separated(
        padding: const EdgeInsets.all(14),
        itemCount: categories.length + 1,
        separatorBuilder: (_, __) {
          return const SizedBox(height: 8);
        },
        itemBuilder: (_, i) {
          final label = i == 0 ? 'All' : categories[i - 1];
          final value = i == 0 ? '' : categories[i - 1];
          final isSelected = selected.toLowerCase() == value.toLowerCase();
          return ListTile(
            tileColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: const BorderSide(color: Color(0xFFE6E6E6)),
            ),
            title: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            trailing:
                isSelected ? const Icon(Icons.check, color: kOrange) : null,
            onTap: () {
              Navigator.pop(context, value);
            },
          );
        },
      ),
    );
  }
}

// This class defines _AllProductsPage, used for this page/feature.
class _AllProductsPage extends StatefulWidget {
  final String initialCategory;
  final String initialSearch;

  const _AllProductsPage({
    required this.initialCategory,
    required this.initialSearch,
  });

  @override
  State<_AllProductsPage> createState() => _AllProductsPageState();
}

// This class defines _AllProductsPageState, used for this page/feature.
class _AllProductsPageState extends State<_AllProductsPage> {
  late String _search;
  late String _category;

  List<Widget> _buildCategoryChips(List<String> categories) {
    final chips = <Widget>[];
    for (final category in categories) {
      chips.add(
        Padding(
          padding: const EdgeInsets.only(right: 8),
          child: ChoiceChip(
            label: Text(category),
            selected: _category.toLowerCase() == category.toLowerCase(),
            onSelected: (_) {
              setState(() {
                _category = category;
              });
            },
          ),
        ),
      );
    }
    return chips;
  }

  @override
  void initState() {
    super.initState();
    _search = widget.initialSearch;
    _category = widget.initialCategory;
  }

  @override
  // Builds and returns the UI for this widget.
  Widget build(BuildContext context) {
    const kOrange = Color(0xFFFF6A00);
    final store = AppStore.instance;

    return AnimatedBuilder(
      animation: store,
      builder: (context, _) {
        final products = store.filteredProducts(
          category: _category,
          search: _search,
        );
        final categoryMap = <String, String>{};
        for (final p in store.products) {
          final raw = p.category.trim();
          if (raw.isEmpty) continue;
          final key = raw.toLowerCase();
          categoryMap[key] = categoryMap[key] ?? raw;
        }
        final categories = categoryMap.values.toList()..sort();

        return Scaffold(
          appBar: AppBar(
            title: const Text('All Products'),
            backgroundColor: kOrange,
            foregroundColor: Colors.black,
          ),
          body: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              children: [
                TextField(
                  onChanged: (v) {
                    setState(() {
                      _search = v;
                    });
                  },
                  decoration: const InputDecoration(
                    hintText: 'Search products',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.search),
                  ),
                ),
                const SizedBox(height: 10),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      ChoiceChip(
                        label: const Text('All'),
                        selected: _category.isEmpty,
                        onSelected: (_) {
                          setState(() {
                            _category = '';
                          });
                        },
                      ),
                      const SizedBox(width: 8),
                      ..._buildCategoryChips(categories),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child:
                      products.isEmpty
                          ? const Center(
                            child: Text(
                              'No products found',
                              style: TextStyle(fontWeight: FontWeight.w800),
                            ),
                          )
                          : GridView.builder(
                            itemCount: products.length,
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 2,
                                  mainAxisSpacing: 12,
                                  crossAxisSpacing: 12,
                                  childAspectRatio: 0.72,
                                ),
                            itemBuilder: (_, i) {
                              final p = products[i];
                              return InkWell(
                                onTap: () {
                                  store.markViewed(p.id);
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) {
                                        return ProductDetailPage(product: p);
                                      },
                                    ),
                                  );
                                },
                                child: _ProductCard(product: p),
                              );
                            },
                          ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// This class defines _SearchFab, used for this page/feature.
class _SearchFab extends StatelessWidget {
  static const kOrange = Color(0xFFFF6A00);

  final VoidCallback onTap;
  final bool isActive;

  const _SearchFab({required this.onTap, required this.isActive});

  @override
  // Builds and returns the UI for this widget.
  Widget build(BuildContext context) {
    final shortest = MediaQuery.of(context).size.shortestSide;
    final compact = shortest < 360;
    final buttonSize = compact ? 52.0 : 56.0;
    final wrapperSize = compact ? 64.0 : 68.0;
    final iconSize = compact ? 22.0 : 24.0;

    return SizedBox(
      width: wrapperSize,
      height: wrapperSize,
      child: Material(
        color: Colors.white,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: Container(
            width: buttonSize,
            height: buttonSize,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: kOrange, width: 2),
            ),
            child: Icon(
              Icons.camera_alt_outlined,
              color: kOrange,
              size: iconSize,
            ),
          ),
        ),
      ),
    );
  }
}

// This class defines _BottomBar, used for this page/feature.
class _BottomBar extends StatelessWidget {
  static const kOrange = Color(0xFFFF6A00);

  final int currentIndex;
  final ValueChanged<int> onTap;

  const _BottomBar({required this.currentIndex, required this.onTap});

  Color _itemColor(int index) {
    if (currentIndex == index) {
      return Colors.white;
    }
    return Colors.black;
  }

  @override
  // Builds and returns the UI for this widget.
  Widget build(BuildContext context) {
    final shortest = MediaQuery.of(context).size.shortestSide;
    final compact = shortest < 360;
    final horizontalPadding = compact ? 8.0 : 10.0;
    final centerGap = compact ? 56.0 : 62.0;
    final itemWidth = compact ? 58.0 : 64.0;

    return BottomAppBar(
      color: kOrange,
      height: compact ? 62 : 66,
      shape: const CircularNotchedRectangle(),
      notchMargin: 8,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _NavItem(
              label: 'Deals',
              icon: Icons.local_offer_outlined,
              color: _itemColor(0),
              width: itemWidth,
              onPressed: () {
                onTap(0);
              },
            ),
            _NavItem(
              label: 'Voucher',
              icon: Icons.confirmation_number_outlined,
              color: _itemColor(1),
              width: itemWidth,
              onPressed: () {
                onTap(1);
              },
            ),
            SizedBox(width: centerGap),
            _NavItem(
              label: 'Price Tracker',
              icon: Icons.trending_up,
              color: _itemColor(3),
              width: itemWidth,
              onPressed: () {
                onTap(3);
              },
            ),
            _NavItem(
              label: 'Account',
              icon: Icons.person_outline,
              color: _itemColor(4),
              width: itemWidth,
              onPressed: () {
                onTap(4);
              },
            ),
          ],
        ),
      ),
    );
  }
}

// This class defines _NavItem, used for this page/feature.
class _NavItem extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onPressed;
  final Color color;
  final double width;

  const _NavItem({
    required this.label,
    required this.icon,
    required this.onPressed,
    required this.color,
    required this.width,
  });

  @override
  // Builds and returns the UI for this widget.
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(10),
      child: SizedBox(
        width: width,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 4),
            Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// This class defines _EventsBanner, used for this page/feature.
class _EventsBanner extends StatelessWidget {
  const _EventsBanner();

  bool _isHttpImageUrl(String? raw) {
    if (raw == null || raw.trim().isEmpty) return false;
    final uri = Uri.tryParse(raw.trim());
    return uri != null && (uri.scheme == 'http' || uri.scheme == 'https');
  }

  Future<void> _openEventDetail(
    BuildContext context,
    String eventId,
    Map<String, dynamic> data,
  ) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EventDetailPage(eventId: eventId, data: data),
      ),
    );
  }

  Widget _eventSlide(
    BuildContext context,
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();
    final imageUrl = (data['imageUrl'] ?? '').toString();
    final title =
        (data['title'] ?? data['name'] ?? 'Upcoming Event').toString().trim();
    final message =
        (data['message'] ?? data['description'] ?? '').toString().trim();

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _openEventDetail(context, doc.id, data),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (_isHttpImageUrl(imageUrl))
              Image.network(
                imageUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) {
                  return const ColoredBox(color: Color(0xFFEDEDED));
                },
              )
            else
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFFFF8A3D), Color(0xFFFF6A00)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
              ),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.transparent, Color(0xB3000000)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
            Positioned(
              left: 12,
              right: 12,
              bottom: 12,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title.isEmpty ? 'Upcoming Event' : title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 15,
                    ),
                  ),
                  if (message.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      message,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const Positioned(
              right: 10,
              top: 10,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Color(0xCC000000),
                  borderRadius: BorderRadius.all(Radius.circular(16)),
                ),
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  child: Text(
                    'Tap for details',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<QueryDocumentSnapshot<Map<String, dynamic>>> _activeDocs(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    final todayStart = DateTime.now();
    final minDate = DateTime(
      todayStart.year,
      todayStart.month,
      todayStart.day,
    ).subtract(const Duration(days: 1));
    final output = <QueryDocumentSnapshot<Map<String, dynamic>>>[];
    for (final doc in docs) {
      final data = doc.data();
      if (data['active'] != true) {
        continue;
      }
      final rawDate = data['date'];
      if (rawDate is! Timestamp) {
        // Ignore legacy/incomplete event docs with no event date.
        continue;
      }
      final eventDate = rawDate.toDate();
      if (eventDate.isBefore(minDate)) {
        // Do not show expired/old events in user banner.
        continue;
      }
      output.add(doc);
      if (output.length == 5) {
        break;
      }
    }
    return output;
  }

  List<Widget> _slideWidgets(
    BuildContext context,
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    final widgets = <Widget>[];
    for (final doc in docs) {
      widgets.add(_eventSlide(context, doc));
    }
    return widgets;
  }

  @override
  // Builds and returns the UI for this widget.
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream:
          FirebaseFirestore.instance
              .collection('events')
              .orderBy('updatedAt', descending: true)
              .limit(20)
              .snapshots(),
      builder: (context, snap) {
        if (snap.hasError) {
          return Container(
            height: 160,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: const Color(0xFFEDEDED),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                'Unable to load events right now.',
                textAlign: TextAlign.center,
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          );
        }
        final docs = snap.data?.docs ?? const [];
        final activeDocs = _activeDocs(docs);
        if (activeDocs.isEmpty) {
          return ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: ImageSlideshow(
              width: double.infinity,
              height: 160,
              indicatorColor: const Color(0xFFFF6A00),
              indicatorBackgroundColor: Colors.black12,
              autoPlayInterval: 0,
              isLoop: false,
              children: const [
                ColoredBox(color: Color(0xFFEDEDED)),
                ColoredBox(color: Color(0xFFE2E2E2)),
                ColoredBox(color: Color(0xFFDADADA)),
              ],
            ),
          );
        }

        return ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: ImageSlideshow(
            width: double.infinity,
            height: 160,
            indicatorColor: const Color(0xFFFF6A00),
            indicatorBackgroundColor: Colors.black12,
            autoPlayInterval: 0,
            isLoop: false,
            children: _slideWidgets(context, activeDocs),
          ),
        );
      },
    );
  }
}
