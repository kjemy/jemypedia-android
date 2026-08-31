import 'package:flutter/material.dart';

class FlashScreen extends StatelessWidget {
  const FlashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: PageView.builder(
        scrollDirection: Axis.vertical,
        itemCount: 5,
        itemBuilder: (context, index) {
          return Stack(
            fit: StackFit.expand,
            children: [
              // Mock Video Placeholder
              Container(
                color: Colors.primaries[index % Colors.primaries.length].shade900,
                child: Center(
                  child: Icon(Icons.play_circle_outline, size: 80, color: Colors.white54),
                ),
              ),
              // Overlay UI
              Positioned(
                bottom: 20,
                left: 16,
                right: 80,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Microlearning Video ${index + 1}',
                      style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Learn something new in 60 seconds! Swipe up for more.',
                      style: const TextStyle(color: Colors.white70, fontSize: 14),
                    ),
                  ],
                ),
              ),
              // Right Action Buttons
              Positioned(
                bottom: 20,
                right: 16,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    _buildActionItem(Icons.favorite_border, '1.2k'),
                    const SizedBox(height: 20),
                    _buildActionItem(Icons.comment_outlined, '45'),
                    const SizedBox(height: 20),
                    _buildActionItem(Icons.share_outlined, 'Share'),
                  ],
                ),
              )
            ],
          );
        },
      ),
    );
  }

  Widget _buildActionItem(IconData icon, String label) {
    return Column(
      children: [
        Icon(icon, color: Colors.white, size: 32),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(color: Colors.white, fontSize: 12)),
      ],
    );
  }
}
