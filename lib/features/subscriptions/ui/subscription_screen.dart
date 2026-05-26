import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/providers/courses_provider.dart';
import '../../../core/providers/locale_provider.dart';
import '../../../shared/widgets/glass_container.dart';
import '../../../core/theme/app_colors.dart';
import '../../../features/subscriptions/models/package_model.dart';

class SubscriptionScreen extends StatelessWidget {
  const SubscriptionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;
    final locale = Provider.of<LocaleProvider>(context).locale.languageCode;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Subscription Packages'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: textColor),
      ),
      body: Consumer<CoursesProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading) {
            return const Center(child: CircularProgressIndicator(color: AppColors.primary));
          }

          if (provider.packages.isEmpty) {
            return Center(
              child: Text(
                'No packages available at the moment.',
                style: TextStyle(color: textColor, fontSize: 18),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: provider.packages.length,
            itemBuilder: (context, index) {
              final pkg = provider.packages[index];
              return _buildPackageCard(context, pkg, isDark, textColor, locale);
            },
          );
        },
      ),
    );
  }

  Widget _buildPackageCard(BuildContext context, PackageModel pkg, bool isDark, Color textColor, String locale) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: GlassContainer(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    pkg.getLocalizedTitle(locale),
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: textColor),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.accentNeon.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.accentNeon.withOpacity(0.5)),
                  ),
                  child: Text(
                    '\$${pkg.price.toStringAsFixed(2)}',
                    style: const TextStyle(color: AppColors.accentNeon, fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 15),
            Text(
              pkg.durationDays == 0 ? 'Lifetime Access' : 'Valid for ${pkg.durationDays} Days',
              style: const TextStyle(color: Colors.grey, fontSize: 14),
            ),
            const SizedBox(height: 15),
            if (pkg.coursesIncluded.isNotEmpty) ...[
              Text('Unlocks ${pkg.coursesIncluded.length} Courses', style: TextStyle(fontWeight: FontWeight.bold, color: textColor)),
              const SizedBox(height: 10),
            ],
            const Divider(color: Colors.white24),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Payment gateway integration pending...')),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                ),
                child: const Text('Subscribe Now', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
