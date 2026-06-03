import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../shared/widgets/glass_container.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/services/wordpress_service.dart';

class CertificatesScreen extends StatefulWidget {
  const CertificatesScreen({super.key});

  @override
  State<CertificatesScreen> createState() => _CertificatesScreenState();
}

class _CertificatesScreenState extends State<CertificatesScreen> {
  final WordPressService _api = WordPressService();
  List<dynamic> _certs = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadCerts();
  }

  Future<void> _loadCerts() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    if (auth.isLoggedIn && auth.userEmail != null) {
      final data = await _api.getUserCertificates(auth.userEmail!);
      setState(() { _certs = data; _loading = false; });
    } else {
      setState(() { _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;

    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.workspace_premium_rounded, color: Colors.amber),
            SizedBox(width: 10),
            Text('My Certificates', style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.accentNeon))
          : _certs.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.emoji_events_outlined, size: 80, color: textColor.withOpacity(0.15)),
                      const SizedBox(height: 20),
                      Text('No certificates yet.', style: TextStyle(color: textColor.withOpacity(0.5), fontSize: 16)),
                      const SizedBox(height: 10),
                      Text('Complete a course to earn your certificate!', style: TextStyle(color: textColor.withOpacity(0.3), fontSize: 13)),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _certs.length,
                  itemBuilder: (context, index) {
                    final cert = _certs[index];
                    final title = cert['course_title']?['en'] ?? cert['course_title']?['ar'] ?? 'Course';
                    final certId = cert['certificate_id'] ?? '';
                    final issuedAt = cert['issued_at'] ?? '';

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: GestureDetector(
                        onTap: () async {
                          final viewUrl = cert['view_url'];
                          if (viewUrl != null && await canLaunchUrl(Uri.parse(viewUrl))) {
                            await launchUrl(Uri.parse(viewUrl), mode: LaunchMode.externalApplication);
                          }
                        },
                        child: GlassContainer(
                          child: Row(
                            children: [
                              Container(
                                width: 60, height: 60,
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(colors: [Colors.amber, Colors.orange]),
                                  borderRadius: BorderRadius.circular(15),
                                ),
                                child: const Icon(Icons.workspace_premium_rounded, color: Colors.white, size: 30),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: textColor)),
                                    const SizedBox(height: 4),
                                    Text('ID: $certId', style: TextStyle(fontSize: 11, color: AppColors.accentNeon)),
                                    Text('Issued: $issuedAt', style: TextStyle(fontSize: 11, color: textColor.withOpacity(0.4))),
                                  ],
                                ),
                              ),
                              Icon(Icons.arrow_forward_ios_rounded, size: 16, color: textColor.withOpacity(0.3)),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
