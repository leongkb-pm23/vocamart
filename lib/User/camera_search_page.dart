// How this file works:
// 1) Data/models are declared first (if any).
// 2) UI widgets are built in build() methods.
// 3) Helper methods are used to keep UI code clean.

// File purpose: This file handles camera search page screen/logic.

import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import 'package:fyp/components/app_store.dart';
import 'package:fyp/User/detail_ui.dart';

// This class defines CameraSearchPage, used for this page/feature.
class CameraSearchPage extends StatefulWidget {
  const CameraSearchPage({super.key});

  @override
  State<CameraSearchPage> createState() => _CameraSearchPageState();
}

// This class defines _CameraSearchPageState, used for this page/feature.
class _CameraSearchPageState extends State<CameraSearchPage> {
  CameraController? _controller;
  bool _initializing = true;
  bool _takingPicture = false;

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  List<DropdownMenuItem<String>> _productItems(List<ProductItem> products) {
    final items = <DropdownMenuItem<String>>[];
    for (final product in products) {
      items.add(
        DropdownMenuItem<String>(
          value: product.id,
          child: Text(product.name),
        ),
      );
    }
    return items;
  }

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  Future<void> _initCamera() async {
    try {
      final cameras = await availableCameras();
      CameraDescription backCam = cameras.first;
      for (final camera in cameras) {
        if (camera.lensDirection == CameraLensDirection.back) {
          backCam = camera;
          break;
        }
      }

      final controller = CameraController(backCam, ResolutionPreset.high, enableAudio: false);
      await controller.initialize();

      if (!mounted) return;
      setState(() {
        _controller = controller;
        _initializing = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _initializing = false;
      });
      _showSnack('Camera error: $e');
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _capture() async {
    final c = _controller;
    if (c == null || !c.value.isInitialized || _takingPicture) return;

    setState(() {
      _takingPicture = true;
    });
    try {
      final file = await c.takePicture();
      if (!mounted) return;

      final products = AppStore.instance.products;
      if (products.isEmpty) {
        _showSnack('No products in Firestore yet.');
        return;
      }
      String selectedId = products.first.id;

      await showDialog(
        context: context,
        builder: (_) {
          return AlertDialog(
            title: const Text('Image Search Result'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Image.file(File(file.path), height: 160),
                  const SizedBox(height: 10),
                  const Text('Select recognized product (demo):'),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: selectedId,
                    items: _productItems(products),
                    onChanged: (v) {
                      if (v != null) selectedId = v;
                    },
                    decoration: const InputDecoration(border: OutlineInputBorder()),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                },
                child: const Text('Close'),
              ),
              ElevatedButton(
                onPressed: () {
                  final p = AppStore.instance.productById(selectedId);
                  Navigator.pop(context);
                  if (p == null) return;
                  AppStore.instance.markViewed(p.id);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ProductDetailPage(product: p),
                    ),
                  );
                },
                child: const Text('Open Product'),
              ),
            ],
          );
        },
      );
    } catch (e) {
      if (!mounted) return;
      _showSnack('Capture failed: $e');
    } finally {
      if (mounted) {
        setState(() {
          _takingPicture = false;
        });
      }
    }
  }

  Widget _buildBody() {
    final controller = _controller;
    if (_initializing) {
      return const Center(child: CircularProgressIndicator());
    }
    if (controller == null || !controller.value.isInitialized) {
      return const Center(
        child: Text('Camera not available', style: TextStyle(color: Colors.white)),
      );
    }

    return Stack(
      children: [
        Center(child: CameraPreview(controller)),
        Positioned(
          left: 0,
          right: 0,
          bottom: 26,
          child: Center(
            child: GestureDetector(
              onTap: _capture,
              child: Container(
                width: 74,
                height: 74,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 4),
                ),
                child:
                    _takingPicture
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
          ),
        ),
      ],
    );
  }

  @override
  // Builds and returns the UI for this widget.
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



