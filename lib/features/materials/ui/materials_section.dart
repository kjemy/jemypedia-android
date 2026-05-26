import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/providers/locale_provider.dart';
import '../../../shared/widgets/glass_container.dart';
import '../models/material_model.dart';

class MaterialsSection extends StatelessWidget {
  final List<MaterialModel> materials;

  const MaterialsSection({super.key, required this.materials});

  IconData _iconForType(String type) {
    switch (type) {
      case 'pdf':      return Icons.picture_as_pdf_rounded;
      case 'video':    return Icons.play_circle_outline_rounded;
      case 'image':    return Icons.image_rounded;
      case 'archive':  return Icons.folder_zip_rounded;
      case 'document': return Icons.description_rounded;
      default:         return Icons.attach_file_rounded;
    }
  }

  Color _colorForType(String type) {
    switch (type) {
      case 'pdf':      return Colors.redAccent;
      case 'video':    return AppColors.primary;
      case 'image':    return Colors.teal;
      case 'archive':  return Colors.orange;
      case 'document': return Colors.blue;
      default:         return Colors.grey;
    }
  }

  Future<void> _openFile(BuildContext context, String url, String locale) async {
    try {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(locale == 'ar' ? 'تعذر فتح الملف' : 'Could not open file'),
          backgroundColor: Colors.redAccent,
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (materials.isEmpty) return const SizedBox.shrink();

    final locale = Provider.of<LocaleProvider>(context).locale.languageCode;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.attach_file_rounded, color: AppColors.accentNeon, size: 20),
            const SizedBox(width: 8),
            Text(
              locale == 'ar' ? 'مواد الكورس' : 'Course Materials',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textColor),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...materials.map((m) {
          final color = _colorForType(m.type);
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: GlassContainer(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Container(
                    width: 44, height: 44,
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(_iconForType(m.type), color: color, size: 24),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      m.getLocalizedTitle(locale),
                      style: TextStyle(color: textColor, fontWeight: FontWeight.w600),
                    ),
                  ),
                  IconButton(
                    onPressed: () => _openFile(context, m.url, locale),
                    icon: const Icon(Icons.download_rounded, color: AppColors.accentNeon),
                    tooltip: locale == 'ar' ? 'تحميل' : 'Download',
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }
}
