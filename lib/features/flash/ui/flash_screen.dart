import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import 'package:jemypedia_app/core/providers/locale_provider.dart';
import 'package:jemypedia_app/core/theme/app_colors.dart';
import '../models/flash_model.dart';
import '../providers/flash_provider.dart';
import 'package:jemypedia_app/features/courses/ui/course_detail_screen.dart';
import 'package:jemypedia_app/core/providers/courses_provider.dart';

class FlashScreen extends StatefulWidget {
  const FlashScreen({super.key});

  @override
  State<FlashScreen> createState() => _FlashScreenState();
}

class _FlashScreenState extends State<FlashScreen> {
  final PageController _pageController = PageController();
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = Provider.of<FlashProvider>(context, listen: false);
      if (provider.items.isEmpty) {
        provider.fetchFlashItems(refresh: true);
      }
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Consumer<FlashProvider>(
        builder: (context, provider, _) {
          if (provider.isLoading && provider.items.isEmpty) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            );
          }

          if (provider.error != null && provider.items.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.flash_off, color: Colors.white54, size: 64),
                  const SizedBox(height: 16),
                  Text(
                    'No Flash videos available',
                    style: TextStyle(color: Colors.white70, fontSize: 16),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: () => provider.fetchFlashItems(refresh: true),
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                    child: const Text('Retry', style: TextStyle(color: Colors.white)),
                  ),
                ],
              ),
            );
          }

          if (provider.items.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.flash_on, color: Colors.white38, size: 80),
                  SizedBox(height: 16),
                  Text('Coming Soon...', style: TextStyle(color: Colors.white54, fontSize: 18)),
                ],
              ),
            );
          }

          return PageView.builder(
            controller: _pageController,
            scrollDirection: Axis.vertical,
            itemCount: provider.items.length,
            onPageChanged: (index) {
              setState(() => _currentIndex = index);
              // Load more when near end
              if (index >= provider.items.length - 3 && provider.hasMore) {
                provider.fetchFlashItems();
              }
            },
            itemBuilder: (context, index) {
              return _FlashVideoCard(
                item: provider.items[index],
                isActive: index == _currentIndex,
              );
            },
          );
        },
      ),
    );
  }
}

// â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
// â”€â”€â”€ Single Flash Video Card â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
// â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•

class _FlashVideoCard extends StatefulWidget {
  final FlashItem item;
  final bool isActive;

  const _FlashVideoCard({required this.item, required this.isActive});

  @override
  State<_FlashVideoCard> createState() => _FlashVideoCardState();
}

class _FlashVideoCardState extends State<_FlashVideoCard> {
  VideoPlayerController? _controller;
  bool _isInitialized = false;
  bool _showPlayButton = false;

  @override
  void initState() {
    super.initState();
    _initVideo();
  }

  Future<void> _initVideo() async {
    String url = widget.item.flashVideoUrl;
    if (url.isEmpty) return;

    try {
      if (url.contains('youtube.com') || url.contains('youtu.be')) {
        try {
          final yt = YoutubeExplode();
          final video = await yt.videos.get(url);
          final manifest = await yt.videos.streamsClient.getManifest(video.id);
          // Get standard quality (360p or 480p) for faster loading on mobile
          final muxedStreams = manifest.muxed.sortByVideoQuality().toList();
          final streamInfo = muxedStreams.firstWhere(
            (s) => s.videoQuality.name.contains('360') || s.videoQuality.name.contains('480'),
            orElse: () => muxedStreams.last, // Fallback to lowest quality if not found
          );
          url = streamInfo.url.toString();
          yt.close();
        } catch (e) {
          debugPrint('YouTube Extract Error: $e');
        }
      }

      _controller = VideoPlayerController.networkUrl(Uri.parse(url))
        ..initialize().then((_) {
          if (mounted) {
            setState(() => _isInitialized = true);
            _controller!.setLooping(true);
            if (widget.isActive) {
              _controller!.play();
            }
          }
        }).catchError((e) {
          debugPrint('Flash video init error: $e');
        });
    } catch (e) {
      debugPrint('Flash video error: $e');
    }
  }

  @override
  void didUpdateWidget(covariant _FlashVideoCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive && !oldWidget.isActive) {
      _controller?.play();
    } else if (!widget.isActive && oldWidget.isActive) {
      _controller?.pause();
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  void _togglePlayPause() {
    if (_controller == null || !_isInitialized) return;
    setState(() {
      if (_controller!.value.isPlaying) {
        _controller!.pause();
        _showPlayButton = true;
      } else {
        _controller!.play();
        _showPlayButton = false;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final langCode = context.read<LocaleProvider>().isArabic ? 'ar' : 'en';

    return Stack(
      fit: StackFit.expand,
      children: [
        // â”€â”€ Video / Thumbnail Background â”€â”€
        GestureDetector(
          onTap: _togglePlayPause,
          behavior: HitTestBehavior.opaque,
          child: _buildVideoLayer(),
        ),

        // â”€â”€ Dark gradient at bottom â”€â”€
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            height: MediaQuery.of(context).size.height * 0.4,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withOpacity(0.8),
                  ],
                ),
              ),
            ),
          ),

          // â”€â”€ Play/Pause indicator â”€â”€
          if (_showPlayButton)
            Center(
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.black45,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 50),
              ),
            ),

          // â”€â”€ Right side action buttons â”€â”€
          Positioned(
            right: 12,
            bottom: 120,
            child: _buildActionButtons(context),
          ),

          // â”€â”€ Bottom info overlay â”€â”€
          Positioned(
            bottom: 20,
            left: 16,
            right: 80,
            child: _buildInfoOverlay(langCode),
          ),

          // â”€â”€ Progress bar â”€â”€
          if (_isInitialized && _controller != null)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: VideoProgressIndicator(
                _controller!,
                allowScrubbing: true,
                colors: const VideoProgressColors(
                  playedColor: AppColors.primary,
                  bufferedColor: Colors.white24,
                  backgroundColor: Colors.white10,
                ),
                padding: EdgeInsets.zero,
              ),
            ),
        ],
      );
  }

  Widget _buildVideoLayer() {
    if (_isInitialized && _controller != null) {
      return SizedBox.expand(
        child: FittedBox(
          fit: BoxFit.cover,
          child: SizedBox(
            width: _controller!.value.size.width,
            height: _controller!.value.size.height,
            child: VideoPlayer(_controller!),
          ),
        ),
      );
    }

    // Thumbnail fallback
    final thumb = widget.item.flashThumbnail.isNotEmpty
        ? widget.item.flashThumbnail
        : widget.item.coverImageUrl;

    if (thumb.isNotEmpty) {
      return Image.network(
        thumb,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Container(color: Colors.grey[900]),
      );
    }

    return Container(
      color: Colors.grey[900],
      child: const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    final provider = Provider.of<FlashProvider>(context);
    final item = widget.item;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // â¤ï¸ Like
        _ActionButton(
          icon: item.isLiked ? Icons.favorite : Icons.favorite_border,
          color: item.isLiked ? AppColors.primary : Colors.white,
          label: _formatCount(item.likesCount),
          onTap: () => provider.toggleLike(item),
        ),
        const SizedBox(height: 20),

        // ðŸ”– Save for Later (course)
        _ActionButton(
          icon: item.isSavedForLater ? Icons.bookmark : Icons.bookmark_border,
          color: item.isSavedForLater ? Colors.amber : Colors.white,
          label: item.isSavedForLater ? 'Saved' : 'Save',
          onTap: () => provider.toggleSaveForLater(item),
        ),
        const SizedBox(height: 20),

        // â™¡ Favorite (course)
        _ActionButton(
          icon: item.isFavorited ? Icons.star : Icons.star_border,
          color: item.isFavorited ? Colors.amber : Colors.white,
          label: item.isFavorited ? 'Favorited' : 'Favorite',
          onTap: () => provider.toggleFavorite(item),
        ),
      ],
    );
  }

  Widget _buildInfoOverlay(String langCode) {
    final item = widget.item;
    final isArabic = langCode == 'ar';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // "Learn More" button
        GestureDetector(
          onTap: () => _navigateToCourse(context),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isArabic ? Icons.arrow_back_ios : Icons.arrow_forward_ios,
                  color: Colors.white,
                  size: 14,
                ),
                const SizedBox(width: 6),
                Text(
                  isArabic ? 'Ø§Ø¹Ø±Ù Ø§Ù„Ù…Ø²ÙŠØ¯' : 'Learn More',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),

        // Course Title
        Text(
          item.getLocalizedTitle(langCode),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 6),

        // Category
        if (item.category.isNotEmpty)
          Row(
            children: [
              const Icon(Icons.folder_outlined, color: Colors.white70, size: 14),
              const SizedBox(width: 4),
              Text(
                item.category,
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ],
          ),
        const SizedBox(height: 4),

        // Instructor
        Row(
          children: [
            const Icon(Icons.person_outline, color: Colors.white70, size: 14),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                item.getLocalizedInstructor(langCode),
                style: const TextStyle(color: Colors.white70, fontSize: 12),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),

        // Description
        if (item.getLocalizedDescription(langCode).isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            item.getLocalizedDescription(langCode),
            style: const TextStyle(color: Colors.white60, fontSize: 12),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ],
    );
  }

  void _navigateToCourse(BuildContext context) {
    final coursesProvider = Provider.of<CoursesProvider>(context, listen: false);
    
    final courses = coursesProvider.courses;
    final courseId = widget.item.courseId;
    final index = courses.indexWhere((c) => c.id == courseId);
    
    if (index != -1) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => CourseDetailScreen(course: courses[index])),
      );
    } else {
      // Fallback if course not found in memory (could show a toast or fetch it)
      debugPrint('Course not found locally');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.read<LocaleProvider>().isArabic ? 'Ø¬Ø§Ø±ÙŠ ØªØ­Ù…ÙŠÙ„ Ø§Ù„ÙƒÙˆØ±Ø³...' : 'Loading course...')),
      );
    }
  }

  String _formatCount(int count) {
    if (count >= 1000000) return '${(count / 1000000).toStringAsFixed(1)}M';
    if (count >= 1000) return '${(count / 1000).toStringAsFixed(1)}K';
    return count.toString();
  }
}

// â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
// â”€â”€â”€ Reusable Action Button Widget â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
// â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.color,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 30),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(color: Colors.white, fontSize: 11),
          ),
        ],
      ),
    );
  }
}
