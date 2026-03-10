// How this file works:
// 1) Data/models are declared first (if any).
// 2) UI widgets are built in build() methods.
// 3) Helper methods are used to keep UI code clean.

// File purpose: This file handles order page widgets screen/logic.

import 'package:flutter/material.dart';

import 'package:fyp/components/app_store.dart';
import 'package:fyp/components/ui_cards.dart';

// This class defines OrderPageScaffold, used for this page/feature.
class OrderPageScaffold extends StatelessWidget {
  final String title;
  final Widget body;
  final Color appBarColor;

  const OrderPageScaffold({
    super.key,
    required this.title,
    required this.body,
    this.appBarColor = const Color(0xFFFF6A00),
  });

  @override
  // Builds and returns the UI for this widget.
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        backgroundColor: appBarColor,
        foregroundColor: Colors.black,
      ),
      body: body,
    );
  }
}

// This class defines OrderListView, used for this page/feature.
class OrderListView extends StatelessWidget {
  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;

  const OrderListView({
    super.key,
    required this.itemCount,
    required this.itemBuilder,
  });

  @override
  // Builds and returns the UI for this widget.
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.all(14),
      itemCount: itemCount,
      separatorBuilder: (_, __) {
        return const SizedBox(height: 10);
      },
      itemBuilder: itemBuilder,
    );
  }
}

// This class defines StoreOrderPage, used for this page/feature.
class StoreOrderPage extends StatelessWidget {
  final String title;
  final List<OrderItem> Function(AppStore store) ordersBuilder;
  final Widget Function(BuildContext context, OrderItem order) orderCardBuilder;
  final Widget Function(BuildContext context) emptyBuilder;
  final Color appBarColor;

  const StoreOrderPage({
    super.key,
    required this.title,
    required this.ordersBuilder,
    required this.orderCardBuilder,
    required this.emptyBuilder,
    this.appBarColor = const Color(0xFFFF6A00),
  });

  @override
  // Builds and returns the UI for this widget.
  Widget build(BuildContext context) {
    final store = AppStore.instance;
    return AnimatedBuilder(
      animation: store,
      builder: (context, _) {
        final orders = ordersBuilder(store);
        return OrderPageScaffold(
          title: title,
          appBarColor: appBarColor,
          body: orders.isEmpty
              ? emptyBuilder(context)
              : OrderListView(
                  itemCount: orders.length,
                  itemBuilder: (_, i) {
                    return orderCardBuilder(context, orders[i]);
                  },
                ),
        );
      },
    );
  }
}

// This class defines OrderEmptyMessage, used for this page/feature.
class OrderEmptyMessage extends StatelessWidget {
  final String text;

  const OrderEmptyMessage({super.key, required this.text});

  @override
  // Builds and returns the UI for this widget.
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        text,
        style: const TextStyle(fontWeight: FontWeight.w800),
      ),
    );
  }
}

// This class defines OrderInfoCard, used for this page/feature.
class OrderInfoCard extends StatelessWidget {
  final String orderId;
  final List<Widget> children;

  const OrderInfoCard({
    super.key,
    required this.orderId,
    required this.children,
  });

  @override
  // Builds and returns the UI for this widget.
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(orderId, style: const TextStyle(fontWeight: FontWeight.w900)),
          ...children,
        ],
      ),
    );
  }
}


