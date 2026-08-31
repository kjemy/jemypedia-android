import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../shared/widgets/glass_container.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/locale_provider.dart';
import 'terms_screen.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final isArabic = context.watch<LocaleProvider>().isArabic;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;
    final displayName = authProvider.displayName ?? (isArabic ? 'طالب' : 'Student');
    final userEmail = authProvider.userEmail ?? '';
    final subscriptions = authProvider.subscriptions;

    return Scaffold(
      appBar: AppBar(
        title: Text(isArabic ? 'حسابي' : 'My Account'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Profile Section
            GlassContainer(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: AppColors.primary.withOpacity(0.2),
                    child: Text(
                      displayName.isNotEmpty ? displayName[0].toUpperCase() : 'S',
                      style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.primary),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${isArabic ? 'مرحباً' : 'Hello'}, $displayName!', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: textColor)),
                        Text(userEmail, style: TextStyle(color: textColor.withOpacity(0.6), fontSize: 14)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 30),
            
            Text(isArabic ? 'اشتراكاتي' : 'My Subscriptions', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: textColor)),
            const SizedBox(height: 12),
            
            if (subscriptions.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Center(child: Text(isArabic ? 'لا توجد اشتراكات نشطة.' : 'No active subscriptions found.', style: TextStyle(color: textColor.withOpacity(0.5)))),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: subscriptions.length,
                itemBuilder: (context, index) {
                  final sub = subscriptions[index];
                  final days = sub['days_remaining'];
                  final isActive = sub['status'] == 'active';
                  
                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: GlassContainer(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(sub['package_name'], style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: textColor)),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: (isActive ? AppColors.accentNeon : Colors.redAccent).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  isActive ? (isArabic ? 'نشط' : 'ACTIVE') : (isArabic ? 'منتهي' : 'EXPIRED'),
                                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: isActive ? AppColors.accentNeon : Colors.redAccent),
                                ),
                              ),
                            ],
                          ),
                          const Divider(height: 24, color: Colors.white10),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              _buildInfoColumn(isArabic ? 'رقم الطلب' : 'Order ID', sub['order_id'].toString(), textColor),
                              _buildInfoColumn(isArabic ? 'تاريخ الشراء' : 'Purchased', sub['purchase_date'], textColor),
                              _buildInfoColumn(isArabic ? 'تاريخ الانتهاء' : 'Expires', (sub['expire_date'] as String).contains(' ') ? sub['expire_date'].split(' ')[0] : sub['expire_date'], textColor),
                              _buildInfoColumn(isArabic ? 'المتبقي' : 'Remaining', days == -1 ? '∞' : '$days ${isArabic ? 'يوم' : 'd'}', isActive ? AppColors.accentNeon : Colors.redAccent),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
              
            const SizedBox(height: 30),
            Text(isArabic ? 'الإعدادات والمزيد' : 'Settings & More', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textColor)),
            const SizedBox(height: 10),
            
            // Drawer-like Options
            _buildOptionTile(context, Icons.language, isArabic ? 'تغيير اللغة' : 'Change Language', textColor, () {
               context.read<LocaleProvider>().toggleLocale();
            }),
            _buildOptionTile(context, Icons.card_membership, isArabic ? 'الشهادات' : 'Certificates', textColor, () {}),
            _buildOptionTile(context, Icons.info_outline, isArabic ? 'عن جيميبيديا' : 'About Jemypedia', textColor, () {}),
            _buildOptionTile(context, Icons.description_outlined, isArabic ? 'الشروط والأحكام' : 'Terms & Conditions', textColor, () {
              Navigator.push(context, MaterialPageRoute(builder: (context) => const TermsScreen()));
            }),
            _buildOptionTile(context, Icons.privacy_tip_outlined, isArabic ? 'سياسة الخصوصية' : 'Privacy Policy', textColor, () {}),
            _buildOptionTile(context, Icons.help_outline, isArabic ? 'المساعدة' : 'Help', textColor, () {}),
            _buildOptionTile(context, Icons.question_answer_outlined, isArabic ? 'الأسئلة الشائعة' : 'FAQ', textColor, () {}),
            
            // App version read-only tile
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: Icon(Icons.system_update, color: textColor.withOpacity(0.7)),
                title: Text(isArabic ? 'إصدار التطبيق' : 'App Version', style: TextStyle(color: textColor)),
                trailing: Text('1.0.0', style: TextStyle(color: textColor.withOpacity(0.5))),
              ),
            ),
            
            const SizedBox(height: 30),
            // Optional Footer
            Center(
              child: Text(
                '© 2026 Jemypedia',
                style: TextStyle(color: textColor.withOpacity(0.5), fontSize: 12),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildOptionTile(BuildContext context, IconData icon, String title, Color textColor, VoidCallback onTap) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(icon, color: textColor.withOpacity(0.7)),
        title: Text(title, style: TextStyle(color: textColor)),
        trailing: const Icon(Icons.chevron_right, size: 18, color: Colors.white24),
        onTap: onTap,
      ),
    );
  }

  Widget _buildInfoColumn(String label, String value, Color textColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
        const SizedBox(height: 4),
        Text(value, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: textColor)),
      ],
    );
  }
}
