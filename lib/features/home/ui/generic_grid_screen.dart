import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/providers/locale_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/course_image.dart';

class GenericGridScreen extends StatefulWidget {
  final String titleAr;
  final String titleEn;
  final Future<List<dynamic>> Function() fetchData;

  const GenericGridScreen({
    super.key,
    required this.titleAr,
    required this.titleEn,
    required this.fetchData,
  });

  @override
  State<GenericGridScreen> createState() => _GenericGridScreenState();
}

class _GenericGridScreenState extends State<GenericGridScreen> {
  late Future<List<dynamic>> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.fetchData();
  }

  @override
  Widget build(BuildContext context) {
    final locale = Provider.of<LocaleProvider>(context).locale.languageCode;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;

    return Scaffold(
      appBar: AppBar(
        title: Text(locale == 'ar' ? widget.titleAr : widget.titleEn),
        backgroundColor: Colors.transparent,
        elevation: 0,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [AppColors.primary, AppColors.primary.withOpacity(0.8)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
      ),
      body: FutureBuilder<List<dynamic>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: AppColors.accentNeon));
          }
          if (snapshot.hasError || !snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(child: Text(locale == 'ar' ? 'لا يوجد بيانات حالياً' : 'No data available', style: TextStyle(color: textColor)));
          }

          final groups = snapshot.data!;
          return ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            itemCount: groups.length,
            itemBuilder: (context, index) {
              final group = groups[index];
              final groupName = group['group_name'] ?? '';
              final shape = group['shape'] ?? 'circle';
              
              // Safe Parsing for Size
              double size = 50.0; // Default smaller size
              var rawSize = group['size'];
              if (rawSize != null) {
                if (rawSize is num) {
                  size = rawSize.toDouble();
                } else {
                  size = double.tryParse(rawSize.toString()) ?? 50.0;
                }
              }
              
              // Cap size for professional look
              if (size < 30) size = 30;
              if (size > 100) size = 100;

              final List items = group['items'] ?? [];
              if (items.isEmpty) return const SizedBox.shrink();

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Group Header (Elegant Style)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12, left: 4),
                    child: Row(
                      children: [
                        Container(width: 4, height: 16, color: AppColors.accentNeon),
                        const SizedBox(width: 8),
                        Text(
                          groupName,
                          style: TextStyle(
                            fontSize: 16, 
                            fontWeight: FontWeight.bold, 
                            color: textColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  // Group Items in a structured Wrap
                  Wrap(
                    spacing: 12,
                    runSpacing: 16,
                    alignment: WrapAlignment.start,
                    children: items.map((item) {
                      final name = item['name'] ?? '';
                      final imageUrl = item['image_url'] ?? '';
                      final actionUrl = item['action_url'] ?? '';

                      final double itemWidth = (shape == 'rectangle' ? size * 1.6 : size) + 10;

                      return SizedBox(
                        width: itemWidth,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // The Image Shape (Explicitly sized)
                            _buildShape(shape, size, imageUrl),
                            const SizedBox(height: 6),
                            // Name
                            Text(
                              name,
                              style: TextStyle(
                                fontWeight: FontWeight.bold, 
                                color: textColor, 
                                fontSize: 11,
                              ),
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            // Optional Link
                            if (actionUrl.isNotEmpty) ...[
                              const SizedBox(height: 2),
                              InkWell(
                                onTap: () => _launchURL(actionUrl),
                                child: Text(
                                  locale == 'ar' ? 'الموقع' : 'Site',
                                  style: const TextStyle(
                                    color: AppColors.accentNeon, 
                                    fontSize: 9,
                                    decoration: TextDecoration.underline,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 30),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildShape(String shape, double size, String url) {
    BoxShape boxShape = BoxShape.circle;
    BorderRadius? borderRadius;

    double width = size;
    double height = size;

    if (shape == 'circle') {
      boxShape = BoxShape.circle;
    } else if (shape == 'square') {
      boxShape = BoxShape.rectangle;
      borderRadius = BorderRadius.circular(8);
    } else {
      // Rectangle
      boxShape = BoxShape.rectangle;
      borderRadius = BorderRadius.circular(4);
      width = size * 1.6;
      height = size * 0.9;
    }

    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        shape: boxShape,
        borderRadius: borderRadius,
        border: Border.all(
          color: AppColors.primary.withOpacity(0.3), 
          width: 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: CourseImage(
        url: url,
        width: width,
        height: height,
        fit: BoxFit.cover,
      ),
    );
  }

  Future<void> _launchURL(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}
