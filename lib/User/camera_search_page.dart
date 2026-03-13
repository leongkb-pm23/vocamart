import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:fyp/User/detail_ui.dart';
import 'package:fyp/components/app_store.dart';
import 'package:fyp/services/search_service.dart';
import 'package:fyp/services/firestore_search_service.dart';
import 'package:image_picker/image_picker.dart';

class CameraSearchPage extends StatefulWidget {
  const CameraSearchPage({super.key});

  @override
  State<CameraSearchPage> createState() => _CameraSearchPageState();
}

class _CameraSearchPageState extends State<CameraSearchPage> {
  CameraController? _controller;
  final ImagePicker _picker = ImagePicker();
  bool _initializing = true;
  bool _takingPicture = false;

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  Future<void> _initCamera() async {
    try {
      final cameras = await availableCameras();

      if (cameras.isEmpty) {
        if (!mounted) return;
        setState(() => _initializing = false);
        _showSnack('No camera found on this device.');
        return;
      }

      CameraDescription backCam = cameras.first;
      for (final camera in cameras) {
        if (camera.lensDirection == CameraLensDirection.back) {
          backCam = camera;
          break;
        }
      }

      final controller = CameraController(
        backCam,
        ResolutionPreset.high,
        enableAudio: false,
      );

      await controller.initialize();

      if (!mounted) {
        await controller.dispose();
        return;
      }

      setState(() {
        _controller = controller;
        _initializing = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _initializing = false);
      _showSnack('Camera error: $e');
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _capture() async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized || _takingPicture) {
      return;
    }

    setState(() => _takingPicture = true);

    try {
      final file = await controller.takePicture();
      await _searchByImageFile(File(file.path));
    } catch (e) {
      if (!mounted) return;
      _showSnack('Error: $e');
    } finally {
      if (mounted) {
        setState(() => _takingPicture = false);
      }
    }
  }

  Future<void> _pickFromGallery() async {
    if (_takingPicture) return;
    setState(() => _takingPicture = true);

    try {
      final picked = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 90,
      );
      if (picked == null) return;
      if (!mounted) return;

      await _searchByImageFile(File(picked.path));
    } catch (e) {
      if (!mounted) return;
      _showSnack('Error: $e');
    } finally {
      if (mounted) {
        setState(() => _takingPicture = false);
      }
    }
  }

  Future<void> _searchByImageFile(File imageFile) async {
    bool loadingShown = false;

    try {
      _showLoadingDialog('Recognizing product...');
      loadingShown = true;

      final aiResult = await searchService.searchByImage(imageFile);

      final labelsRaw = aiResult['labels'];
      final labels = labelsRaw is List
          ? labelsRaw.map((e) => e.toString().trim()).where((e) => e.isNotEmpty).toList()
          : <String>[];

      if (!mounted) return;

      if (loadingShown) {
        Navigator.of(context, rootNavigator: true).pop();
        loadingShown = false;
      }

      if (labels.isEmpty) {
        _showSnack('Could not recognize product. Try again.');
        return;
      }

      _showLoadingDialog('Searching your products...');
      loadingShown = true;

      final products = await firestoreSearchService.searchByLabels(labels);

      if (!mounted) return;

      if (loadingShown) {
        Navigator.of(context, rootNavigator: true).pop();
        loadingShown = false;
      }

      _showResultsDialog(
        imageFile: imageFile,
        labels: labels,
        products: products,
      );
    } catch (e) {
      if (mounted && loadingShown) {
        Navigator.of(context, rootNavigator: true).pop();
      }
      rethrow;
    }
  }

  void _showLoadingDialog(String message) {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(message),
            const SizedBox(height: 8),
            const Text(
              'Please wait...',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  void _showResultsDialog({
    required File imageFile,
    required List<String> labels,
    required List<FirestoreProduct> products,
  }) {
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Search Results'),
        content: SizedBox(
          width: double.maxFinite,
          height: 500,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.file(
                    imageFile,
                    height: 150,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(height: 12),

                Text(
                  'Found ${products.length} matching product(s):',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),

                if (products.isEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Column(
                      children: [
                        Icon(Icons.search_off, size: 40, color: Colors.grey),
                        SizedBox(height: 8),
                        Text(
                          'No matching products found in your store.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  )
                else
                  ...products.map(
                        (product) => _FirestoreProductTile(
                      product: product,
                      onTap: () => _openProductDetail(product),
                    ),
                  ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _openProductDetail(FirestoreProduct product) {
    if (!mounted) return;
    Navigator.of(context).pop();

    final live = AppStore.instance.productById(product.id);
    final detailProduct = live ??
        ProductItem(
          id: product.id,
          name: product.name,
          category: product.category,
          description: product.description,
          unit: product.unit,
          quantity: product.quantity.toInt(),
          imageUrl: product.imageUrl,
          createdAt: DateTime.now(),
          prices: const <ProductPrice>[],
        );

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ProductDetailPage(product: detailProduct),
      ),
    );
  }

  Widget _buildBody() {
    final controller = _controller;

    if (_initializing) {
      return const Center(child: CircularProgressIndicator());
    }

    if (controller == null || !controller.value.isInitialized) {
      return const Center(
        child: Text(
          'Camera not available',
          style: TextStyle(color: Colors.white),
        ),
      );
    }

    return Stack(
      children: [
        Positioned.fill(
          child: CameraPreview(controller),
        ),
        const Positioned(
          top: 16,
          left: 0,
          right: 0,
          child: Center(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.black45,
                  borderRadius: BorderRadius.all(Radius.circular(8)),
                ),
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Text(
                    'Point at a product and tap to search',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),
          ),
        ),
        Positioned(
          left: 24,
          right: 24,
          bottom: 26,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              GestureDetector(
                onTap: _pickFromGallery,
                child: Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white24,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: const Icon(
                    Icons.photo_library,
                    color: Colors.white,
                    size: 26,
                  ),
                ),
              ),
              GestureDetector(
                onTap: _capture,
                child: Container(
                  width: 74,
                  height: 74,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white24,
                    border: Border.all(color: Colors.white, width: 4),
                  ),
                  child: _takingPicture
                      ? const Padding(
                    padding: EdgeInsets.all(18),
                    child: CircularProgressIndicator(
                      strokeWidth: 3,
                      color: Colors.white,
                    ),
                  )
                      : const Icon(
                    Icons.camera_alt,
                    color: Colors.white,
                    size: 30,
                  ),
                ),
              ),
              const SizedBox(width: 54, height: 54),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('Camera Search'),
      ),
      body: _buildBody(),
    );
  }
}

class _FirestoreProductTile extends StatelessWidget {
  final FirestoreProduct product;
  final VoidCallback onTap;

  const _FirestoreProductTile({required this.product, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
      ),
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.all(8),
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: product.imageUrl.isNotEmpty
              ? Image.network(
            product.imageUrl,
            width: 55,
            height: 55,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) =>
            const Icon(Icons.shopping_basket, size: 30),
          )
              : const Icon(Icons.shopping_basket, size: 30),
        ),
        title: Text(
          product.name,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              product.category,
              style: TextStyle(
                color: Colors.deepPurple.shade400,
                fontSize: 12,
              ),
            ),
            if (product.description.isNotEmpty)
              Text(
                product.description,
                style: const TextStyle(
                  fontSize: 11,
                  color: Colors.grey,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '${product.quantity} ${product.unit}',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.deepPurple,
              ),
            ),
            const SizedBox(height: 4),
            const Icon(Icons.chevron_right, size: 18, color: Colors.grey),
          ],
        ),
      ),
    );
  }
}
