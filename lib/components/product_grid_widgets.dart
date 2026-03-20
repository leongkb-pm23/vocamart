// How this file works:
// 1) Data/models are declared first (if any).
// 2) UI widgets are built in build() methods.
// 3) Helper methods are used to keep UI code clean.

// File purpose: This file handles product grid widgets screen/logic.

import 'package:flutter/material.dart';

// This class defines ProductSearchBox, used for this page/feature.
class ProductSearchBox extends StatelessWidget {
  static const kOrange = Color(0xFFFF6A00);
  final String hintText;
  final ValueChanged<String> onChanged;

  const ProductSearchBox({
    super.key,
    required this.hintText,
    required this.onChanged,
  });

  @override
  // Builds and returns the UI for this widget.
  Widget build(BuildContext context) {
    return Container(
      height: 46,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: kOrange, width: 1.6),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          const Icon(Icons.search, color: kOrange),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              onChanged: onChanged,
              decoration: InputDecoration(
                hintText: hintText,
                border: InputBorder.none,
                isCollapsed: true,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// This class defines ProductGridCard, used for this page/feature.
class ProductGridCard extends StatelessWidget {
  static const kOrange = Color(0xFFFF6A00);

  final String title;
  final String price;
  final String? oldPrice;
  final int? stockQty;
  final bool isOutOfStock;
  final String? imageUrl;
  final IconData fallbackIcon;
  final VoidCallback onTap;

  const ProductGridCard({
    super.key,
    required this.title,
    required this.price,
    this.oldPrice,
    this.stockQty,
    this.isOutOfStock = false,
    required this.imageUrl,
    required this.fallbackIcon,
    required this.onTap,
  });

  bool _isHttpImageUrl(String? raw) {
    if (raw == null || raw.trim().isEmpty) return false;
    final uri = Uri.tryParse(raw.trim());
    return uri != null && (uri.scheme == 'http' || uri.scheme == 'https');
  }

  @override
  // Builds and returns the UI for this widget.
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE6E6E6)),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final imageHeight = (constraints.maxHeight * 0.44).clamp(
              86.0,
              110.0,
            );
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  height: imageHeight,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEDEDED),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child:
                      _isHttpImageUrl(imageUrl)
                          ? ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: Image.network(
                              imageUrl!,
                              width: double.infinity,
                              height: double.infinity,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) {
                                return Center(
                                  child: Icon(
                                    fallbackIcon,
                                    color: Colors.black45,
                                  ),
                                );
                              },
                            ),
                          )
                          : Center(
                            child: Icon(fallbackIcon, color: Colors.black45),
                          ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 2),
                      if (stockQty != null)
                        Text(
                          isOutOfStock ? 'Stock: 0' : 'Stock: $stockQty',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color:
                                isOutOfStock
                                    ? Colors.redAccent
                                    : Colors.black54,
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                if (oldPrice == null)
                  Text(
                    price,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: isOutOfStock ? Colors.redAccent : kOrange,
                      fontWeight: FontWeight.w900,
                      fontSize: 13,
                    ),
                  )
                else
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          price,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: kOrange,
                            fontWeight: FontWeight.w900,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        oldPrice!,
                        style: const TextStyle(
                          color: Colors.black38,
                          fontSize: 11,
                          decoration: TextDecoration.lineThrough,
                        ),
                      ),
                    ],
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}
