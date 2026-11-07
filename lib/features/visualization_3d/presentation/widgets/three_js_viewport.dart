import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../../../../core/theme/app_theme.dart';

class ThreeJsViewport extends StatefulWidget {
  final Map<String, dynamic>? meshData;

  const ThreeJsViewport({super.key, this.meshData});

  @override
  State<ThreeJsViewport> createState() => _ThreeJsViewportState();
}

class _ThreeJsViewportState extends State<ThreeJsViewport> {
  late final WebViewController _controller;
  bool _isPageLoaded = false;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(AppTheme.darkBackground)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (String url) {
            setState(() {
              _isPageLoaded = true;
            });
            _syncMesh();
          },
        ),
      )
      ..loadFlutterAsset('assets/web/scene3d.html');
  }

  @override
  void didUpdateWidget(covariant ThreeJsViewport oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.meshData != widget.meshData && _isPageLoaded) {
      _syncMesh();
    }
  }

  void _syncMesh() {
    if (widget.meshData != null && widget.meshData!.isNotEmpty) {
      final jsonStr = jsonEncode(widget.meshData);
      // Safe injection into the Three.js viewport
      _controller.runJavaScript('window.renderMeshData($jsonStr);');
    }
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (!_isPageLoaded)
            const Center(
              child: CircularProgressIndicator(color: AppTheme.primaryBlue),
            ),
        ],
      ),
    );
  }
}
