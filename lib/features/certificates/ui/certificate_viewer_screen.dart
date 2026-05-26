import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/services/wordpress_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/glass_container.dart';

class CertificateViewerScreen extends StatefulWidget {
  final int courseId;
  final String certificateId;
  final String studentName;
  final String courseTitleEn;
  final String courseTitleAr;
  final String issuedAt;
  final String viewUrl;

  const CertificateViewerScreen({
    super.key,
    required this.courseId,
    required this.certificateId,
    required this.studentName,
    required this.courseTitleEn,
    required this.courseTitleAr,
    required this.issuedAt,
    required this.viewUrl,
  });

  @override
  State<CertificateViewerScreen> createState() => _CertificateViewerScreenState();
}

class _CertificateViewerScreenState extends State<CertificateViewerScreen> {
  final WordPressService _api = WordPressService();
  Map<String, dynamic>? _template;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _fetchTemplate();
  }

  Future<void> _fetchTemplate() async {
    final data = await _api.getCertificateTemplate(widget.courseId);
    if (mounted) {
      setState(() {
        _template = data;
        _loading = false;
      });
    }
  }

  String _replaceVariables(String text) {
    return text
        .replaceAll('{student_name}', widget.studentName)
        .replaceAll('{course_name}', widget.courseTitleEn)
        .replaceAll('{course_name_ar}', widget.courseTitleAr)
        .replaceAll('{certificate_id}', widget.certificateId)
        .replaceAll('{completion_date}', widget.issuedAt)
        .replaceAll('{site_name}', 'Jemy Academy')
        .replaceAll('{instructor_name}', 'Dr. Jemy');
  }

  Future<void> _downloadCertificate() async {
    final url = Uri.parse('${widget.viewUrl}&print=1');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open download link.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark ? Colors.black : Colors.grey[100];

    // Safety check for template structure
    final dynamic textElementsRaw = _template?['text_elements'];
    final List<dynamic> textElements = (textElementsRaw is List) ? textElementsRaw : [];

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: const Text('View Certificate', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.share_rounded),
            onPressed: _downloadCertificate,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.accentNeon))
          : _template == null
              ? const Center(child: Text('Failed to load certificate template'))
              : SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final width = constraints.maxWidth;
                            // Assume a standard A4 landscape aspect ratio (1.414)
                            final height = width / 1.414;

                            return Container(
                              width: width,
                              height: height,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(10),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.1),
                                    blurRadius: 20,
                                    offset: const Offset(0, 10),
                                  ),
                                ],
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: Stack(
                                  children: [
                                    // Background Image
                                    if (_template!['bg_image_url'] != null && _template!['bg_image_url'].toString().isNotEmpty)
                                      Image.network(
                                        WordPressService.normalizeUrl(_template!['bg_image_url']),
                                        width: width,
                                        height: height,
                                        fit: BoxFit.fill,
                                        errorBuilder: (context, error, stackTrace) => Container(color: Colors.white, child: const Center(child: Icon(Icons.broken_image, color: Colors.grey))),
                                      ),
                                    
                                    // Dynamic Text Elements
                                    ...textElements.map((el) {
                                      try {
                                        final x = (el['x_percent'] ?? el['x'] ?? 0).toDouble();
                                        final y = (el['y_percent'] ?? el['y'] ?? 0).toDouble();
                                        final fontSize = (el['font_size'] ?? el['size'] ?? 18).toDouble() * (width / 800); // Scale font size
                                        final colorHex = el['color'] ?? '#000000';
                                        final color = Color(int.parse(colorHex.replaceFirst('#', '0xFF')));
                                        final fontWeight = el['font_weight'] == 'bold' ? FontWeight.bold : FontWeight.normal;
                                        final align = el['align'] == 'center' ? TextAlign.center : TextAlign.left;

                                        final text = _replaceVariables(el['variable'] ?? el['content'] ?? '');

                                        return Positioned(
                                          left: align == TextAlign.center ? 0 : (x * width / 100),
                                          right: align == TextAlign.center ? 0 : null,
                                          top: y * height / 100,
                                          child: Text(
                                            text,
                                            textAlign: align,
                                            style: GoogleFonts.cairo(
                                              fontSize: fontSize,
                                              color: color,
                                              fontWeight: fontWeight,
                                            ),
                                          ),
                                        );
                                      } catch (e) {
                                        return const SizedBox.shrink();
                                      }
                                    }),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 30),
                        GlassContainer(
                          child: Column(
                            children: [
                              const Row(
                                children: [
                                  Icon(Icons.info_outline_rounded, color: AppColors.accentNeon),
                                  SizedBox(width: 10),
                                  Text('Certificate Details', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                ],
                              ),
                              const Divider(height: 20),
                              _buildDetailRow('ID', widget.certificateId, isDark),
                              _buildDetailRow('Date', widget.issuedAt, isDark),
                              _buildDetailRow('Course', widget.courseTitleAr, isDark),
                              const SizedBox(height: 20),
                              ElevatedButton.icon(
                                onPressed: _downloadCertificate,
                                icon: const Icon(Icons.download_rounded),
                                label: const Text('Download PDF/Image'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primary,
                                  foregroundColor: Colors.white,
                                  minimumSize: const Size(double.infinity, 50),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
    );
  }

  Widget _buildDetailRow(String label, String value, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: isDark ? Colors.white54 : Colors.black54)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}
