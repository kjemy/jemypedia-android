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

class MyCoursesScreen extends StatelessWidget {
  const MyCoursesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;

    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.play_lesson_rounded, color: AppColors.accentNeon),
            SizedBox(width: 10),
            Text('My Courses', style: TextStyle(fontWeight: FontWeight.bold)),
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

          // Show only enrolled/unlocked courses
          final myCourses = provider.unlockedCourses.isNotEmpty
              ? provider.courses.where((c) => provider.unlockedCourses.contains(c.id)).toList()
              : provider.courses.where((c) => c.progress > 0).toList();

          if (myCourses.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.school_outlined, size: 80, color: textColor.withOpacity(0.2)),
                  const SizedBox(height: 20),
                  Text('No enrolled courses yet.',
                      style: TextStyle(color: textColor.withOpacity(0.5), fontSize: 16)),
                  const SizedBox(height: 10),
                  Text('Subscribe to unlock premium content.',
                      style: TextStyle(color: textColor.withOpacity(0.3), fontSize: 13)),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: myCourses.length,
            itemBuilder: (context, index) {
              final course = myCourses[index];
              final locale = Provider.of<LocaleProvider>(context).locale.languageCode;
              final isFav = favProvider.isCourseFavorite(course.id);
              final progressPercent = (course.progress * 100).toInt();

              return Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: AnimatedHoverCard(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => CourseDetailScreen(course: course)),
                  ),
                  child: GlassContainer(
                    padding: EdgeInsets.zero,
                    child: Row(
                      children: [
                        // Course Thumbnail
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
                        // Course Info
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
                                      fontWeight: FontWeight.bold, fontSize: 15, color: textColor),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  course.getLocalizedInstructor(locale),
                                  style:
                                      TextStyle(fontSize: 12, color: textColor.withOpacity(0.6)),
                                ),
                                const SizedBox(height: 10),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text('Progress',
                                        style: TextStyle(
                                            fontSize: 11, color: textColor.withOpacity(0.5))),
                                    Text('$progressPercent%',
                                        style: const TextStyle(
                                            fontSize: 12,
                                            color: AppColors.accentNeon,
                                            fontWeight: FontWeight.bold)),
                                  ],
                                ),
                                const SizedBox(height: 5),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(5),
                                  child: LinearProgressIndicator(
                                    value: course.progress,
                                    backgroundColor:
                                        isDark ? Colors.white10 : Colors.black12,
                                    color: AppColors.accentNeon,
                                    minHeight: 6,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        // Favorite Toggle
                        Padding(
                          padding: const EdgeInsets.only(right: 12),
                          child: GestureDetector(
                            onTap: () => favProvider.toggleCourseFavorite(course.id),
                            child: Icon(
                              isFav ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                              color: isFav ? Colors.redAccent : textColor.withOpacity(0.3),
                              size: 22,
                            ),
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
