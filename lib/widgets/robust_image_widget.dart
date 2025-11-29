import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../services/network_image_service.dart';

/// Robust Image Widget with comprehensive error handling and network optimization
class RobustImageWidget extends StatefulWidget {
  final String imageUrl;
  final double? height;
  final double? width;
  final BoxFit fit;
  final bool enableDebug;
  final Widget? placeholder;
  final Widget? errorWidget;

  const RobustImageWidget({
    Key? key,
    required this.imageUrl,
    this.height,
    this.width,
    this.fit = BoxFit.contain,
    this.enableDebug = false,
    this.placeholder,
    this.errorWidget,
  }) : super(key: key);

  @override
  _RobustImageWidgetState createState() => _RobustImageWidgetState();
}

class _RobustImageWidgetState extends State<RobustImageWidget> {
  bool _isLoading = true;
  bool _hasError = false;
  String? _errorMessage;
  String? _optimizedUrl;

  @override
  void initState() {
    super.initState();
    _initializeImage();
  }

  @override
  void didUpdateWidget(RobustImageWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageUrl != widget.imageUrl) {
      _initializeImage();
    }
  }

  Future<void> _initializeImage() async {
    if (widget.imageUrl.isEmpty) {
      setState(() {
        _hasError = true;
        _errorMessage = 'Empty image URL';
        _isLoading = false;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _hasError = false;
      _errorMessage = null;
    });

    // Get optimized URL
    _optimizedUrl = NetworkImageService.getOptimizedImageUrl(
      widget.imageUrl,
      width: widget.width?.toInt(),
      height: widget.height?.toInt(),
    );

    if (widget.enableDebug) {
      print('🖼️ RobustImageWidget: ${widget.imageUrl}');
      print('🖼️ Optimized URL: $_optimizedUrl');
    }

    // Test connectivity if it's a network image
    if (widget.imageUrl.startsWith('http')) {
      try {
        final isConnected = await NetworkImageService.testConnectivity();
        if (!isConnected) {
          setState(() {
            _hasError = true;
            _errorMessage = 'No internet connection';
            _isLoading = false;
          });
          return;
        }

        // Test WooCommerce connectivity
        final isWooCommerceConnected =
            await NetworkImageService.testWooCommerceConnectivity();
        if (!isWooCommerceConnected) {
          setState(() {
            _hasError = true;
            _errorMessage = 'Server connection failed';
            _isLoading = false;
          });
          return;
        }

        // Test specific image URL
        final result = await NetworkImageService.testImageUrl(_optimizedUrl!);
        if (!result.isSuccess) {
          setState(() {
            _hasError = true;
            _errorMessage = result.error ?? 'Image not accessible';
            _isLoading = false;
          });
          return;
        }
      } catch (e) {
        if (widget.enableDebug) {
          print('❌ Image initialization error: $e');
        }
        setState(() {
          _hasError = true;
          _errorMessage = 'Network test failed';
          _isLoading = false;
        });
        return;
      }
    }

    setState(() {
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return widget.placeholder ?? _buildDefaultPlaceholder();
    }

    if (_hasError) {
      return widget.errorWidget ?? _buildErrorWidget();
    }

    return _buildImage();
  }

  Widget _buildImage() {
    if (widget.imageUrl.startsWith('http')) {
      return CachedNetworkImage(
        imageUrl: _optimizedUrl ?? widget.imageUrl,
        height: widget.height,
        width: widget.width,
        fit: widget.fit,
        placeholder: (context, url) =>
            widget.placeholder ?? _buildDefaultPlaceholder(),
        errorWidget: (context, url, error) {
          if (widget.enableDebug) {
            print('❌ CachedNetworkImage error: $error');
          }
          return widget.errorWidget ?? _buildErrorWidget();
        },
        httpHeaders: const {
          'User-Agent': 'HomeAid-Flutter-App/1.0',
          'Accept': 'image/*',
          'Accept-Encoding': 'gzip, deflate',
          'Connection': 'keep-alive',
        },
        memCacheHeight:
            widget.height != null ? (widget.height! * 1.5).toInt() : null,
        memCacheWidth:
            widget.width != null ? (widget.width! * 1.5).toInt() : null,
        maxHeightDiskCache: 800,
        maxWidthDiskCache: 800,
        fadeInDuration: const Duration(milliseconds: 300),
        fadeOutDuration: const Duration(milliseconds: 300),
      );
    } else {
      return Image.asset(
        widget.imageUrl,
        height: widget.height,
        width: widget.width,
        fit: widget.fit,
        errorBuilder: (context, error, stackTrace) {
          if (widget.enableDebug) {
            print('❌ Asset image error: $error');
          }
          return widget.errorWidget ?? _buildErrorWidget();
        },
      );
    }
  }

  Widget _buildDefaultPlaceholder() {
    return Container(
      height: widget.height ?? 100,
      width: widget.width ?? 100,
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              height: (widget.height ?? 100) / 4,
              width: (widget.width ?? 100) / 4,
              child: const CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Loading...',
              style: TextStyle(
                fontSize: 10,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorWidget() {
    return Container(
      height: widget.height ?? 100,
      width: widget.width ?? 100,
      decoration: BoxDecoration(
        color: Colors.grey[300],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[400]!, width: 1),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.image_not_supported,
              color: Colors.grey[500],
              size: (widget.height ?? 100) / 3,
            ),
            const SizedBox(height: 4),
            Text(
              _errorMessage ?? 'Error',
              style: TextStyle(
                fontSize: 8,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            if (widget.enableDebug && widget.imageUrl.isNotEmpty)
              Padding(
                padding: const EdgeInsets.all(4),
                child: Text(
                  widget.imageUrl.length > 20
                      ? '${widget.imageUrl.substring(0, 20)}...'
                      : widget.imageUrl,
                  style: TextStyle(
                    fontSize: 6,
                    color: Colors.grey[500],
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
