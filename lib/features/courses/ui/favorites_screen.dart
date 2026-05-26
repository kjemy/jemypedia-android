import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../shared/widgets/glass_container.dart';
import '../../../shared/widgets/animated_hover_card.dart';
import '../../../shared/widgets/course_image.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/providers/courses_provider.dart';
import '../../../core/providers/favorites_provider.dart';
import '../../../core/providers/locale_provider.dart';
import 'course_detail_screen.dart';

class FavoritesScreen extends StatelessWidget {
  const FavoritesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;

    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.favorite_rounded, color: Colors.redAccent),
            SizedBox(width: 10),
            Text('My Favorites', style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: textColor),
      ),
      body: Consumer2<CoursesProvider, FavoritesProvider>(
        builder: (context, provider, favProvider, child) {
          if (provider.isLoading) {
            return const Center(child: CircularProgressIndicator(color: AppColors.accentNeon));
          }

          final favCourses = provider.courses
              .where((c) => favProvider.isCourseFavorite(c.id))
              .toList();

          if (favCourses.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.favorite_border_rounded, size: 80, color: Colors.white12),
                  const SizedBox(height: 20),
                  Text('No favorites yet.',
                      style: TextStyle(color: textColor.withOpacity(0.5), fontSize: 16)),
                  const SizedBox(height: 10),
                  Text('Tap ❤️ on any course to save it here.',
                      style: TextStyle(color: textColor.withOpacity(0.3), fontSize: 13)),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: favCourses.length,
            itemBuilder: (context, index) {
              final course = favCourses[index];
              final locale = Provider.of<LocaleProvider>(context).locale.languageCode;

              return Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: AnimatedHoverCard(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => CourseDetailScreen(course: course)),
                  ),
                  child: GlassContainer(
                    padding: EdgeInsets.zero,
                    child: Row(
                      children: [
                        CourseImage(
                          url: course.coverImageUrl,
                          width: 110,
                          height: 100,
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(20),
                            bottomLeft: Radius.circular(20),
                          ),
                        ),
                        const SizedBox(width: 15),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  course.getLocalizedTitle(locale),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                      color: textColor),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  course.getLocalizedInstructor(locale),
                                  style: TextStyle(
                                      fontSize: 12, color: textColor.withOpacity(0.6)),
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Icon(Icons.access_time_rounded,
                                        size: 13, color: AppColors.accentNeon),
                                    const SizedBox(width: 5),
                                    Text('${course.duration} hrs',
                                        style: TextStyle(
                                            fontSize: 12, color: textColor.withOpacity(0.6))),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                        // Remove from favorites
                        Padding(
                          padding: const EdgeInsets.only(right: 12),
                          child: GestureDetector(
                            onTap: () => favProvider.toggleCourseFavorite(course.id),
                            child: const Icon(Icons.favorite_rounded,
                                color: Colors.redAccent, size: 22),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
