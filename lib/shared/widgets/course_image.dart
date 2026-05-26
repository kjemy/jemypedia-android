import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/theme/app_colors.dart';

/// A robust image loader that handles CORS on Web and Caching on Mobile.
class CourseImage extends StatelessWidget {
  final String url;
  final double? width;
  final double? height;
  final BoxFit fit;
  final BorderRadius? borderRadius;

  const CourseImage({
    super.key,
    required this.url,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    if (url.isEmpty) return _buildPlaceholder();

    // Fix for Web: Use standard Image.network to leverage browser's native image loading
    // which is more lenient with CORS than XHR-based loading used by CachedNetworkImage.
    if (kIsWeb) {
      return _buildDecoratedImage(
        Image.network(
          url,
          width: width,
          height: height,
          fit: fit,
          errorBuilder: (context, error, stackTrace) => _buildPlaceholder(),
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return _buildLoadingState();
          },
        ),
      );
    }

    // For Mobile: Keep using CachedNetworkImage for performance and offline support
    return _buildDecoratedImage(
      CachedNetworkImage(
        imageUrl: url,
        width: width,
        height: height,
        fit: fit,
        placeholder: (context, url) => _buildLoadingState(),
        errorWidget: (context, url, error) => _buildPlaceholder(),
      ),
    );
  }

  Widget _buildDecoratedImage(Widget image) {
    if (borderRadius != null) {
      return ClipRRect(borderRadius: borderRadius!, child: image);
    }
    return image;
  }

  Widget _buildLoadingState() {
    return Container(
      width: width,
      height: height,
      color: Colors.white.withOpacity(0.05),
      child: const Center(
        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white12),
      ),
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primary.withOpacity(0.4),
            AppColors.primary.withOpacity(0.1),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: const Center(
        child: Icon(Icons.image_not_supported_outlined, color: Colors.white24, size: 30),
      ),
    );
  }
}
