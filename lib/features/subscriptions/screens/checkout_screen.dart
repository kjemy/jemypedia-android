import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:jemypedia_app/core/providers/locale_provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:jemypedia_app/core/theme/app_colors.dart';
import 'package:jemypedia_app/core/services/wordpress_service.dart';
import 'package:jemypedia_app/core/providers/auth_provider.dart';
import 'package:jemypedia_app/shared/widgets/glass_container.dart';

class CheckoutScreen extends StatefulWidget {
  final int courseId;
  final String courseTitle;
  final String price;
  final String? wooId;
  final String? imageUrl;
  final String? accessPeriod;

  const CheckoutScreen({
    super.key,
    required this.courseId,
    required this.courseTitle,
    required this.price,
    this.wooId,
    this.imageUrl,
    this.accessPeriod,
  });

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  final WordPressService _wpService = WordPressService();
  bool _isLoadingGateways = true;
  List<dynamic> _gateways = [];
  Map<String, dynamic>? _selectedGateway;
  Map<String, dynamic>? _selectedMethod;

  final TextEditingController _txHashController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  File? _receiptImage;

  bool _isSubmitting = false;
  bool _isSuccess = false;

  Timer? _countdownTimer;
  int _secondsRemaining = 30 * 60;

  @override
  void initState() {
    super.initState();
    _fetchGateways();
    _startTimer();
  }

  void _startTimer() {
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsRemaining > 0) {
        if (mounted) setState(() => _secondsRemaining--);
      } else {
        timer.cancel();
      }
    });
  }

  Future<void> _fetchGateways() async {
    final gateways = await _wpService.getGateways(widget.courseId, wooId: widget.wooId);
    if (mounted) {
      setState(() {
        _gateways = gateways;
        _isLoadingGateways = false;
      });
    }
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null && mounted) {
      setState(() {
        _receiptImage = File(pickedFile.path);
      });
    }
  }

  Future<void> _submitCheckout() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final userId = auth.userId?.toString() ?? '';

    if (userId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please log in first')));
      return;
    }

    final txHash = _txHashController.text.trim();
    if (txHash.isEmpty && _selectedGateway?['type'] != 'ewallet') {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('الرجاء إدخال رقم العملية (TX Hash)')));
      return;
    }

    if (_selectedGateway?['type'] == 'ewallet') {
      if (_phoneController.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('الرجاء إدخال رقم المحفظة')));
        return;
      }
      if (_receiptImage == null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('الرجاء إرفاق صورة الإيصال')));
        return;
      }
    }

    setState(() => _isSubmitting = true);

    final res = await _wpService.submitCheckout(
      planId: widget.courseId,
      wooId: widget.wooId,
      userId: userId,
      gateway: _selectedGateway!['id'],
      network: _selectedMethod?['network'],
      gasFee: _selectedMethod?['gas_fee']?.toString(),
      txHash: txHash,
      phoneNumber: _phoneController.text.trim(),
      receiptImagePath: _receiptImage?.path,
    );

    if (mounted) setState(() => _isSubmitting = false);

    if (res['success'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res['message'] ?? 'تم إرسال طلبك بنجاح')));
      if (mounted) {
        setState(() => _isSuccess = true);
        Navigator.of(context).pop();
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res['message'] ?? 'حدث خطأ')));
    }
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _txHashController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Widget _buildFieldLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Text(text, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildTextField({required TextEditingController controller, required String hint}) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF161616),
        border: Border.all(color: Colors.white10),
        borderRadius: BorderRadius.circular(8),
      ),
      child: TextField(
        controller: controller,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: Colors.white30, fontSize: 13),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      ),
    );
  }

  Widget _buildFilePicker() {
    return GestureDetector(
      onTap: _pickImage,
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: const Color(0xFF161616),
          border: Border.all(color: Colors.white10),
          borderRadius: BorderRadius.circular(8),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Text(
          _receiptImage == null ? 'Choose File... No file chosen' : _receiptImage!.path.split('/').last,
          style: TextStyle(color: _receiptImage == null ? Colors.white30 : Colors.white, fontSize: 13),
          textAlign: TextAlign.start,
        ),
      ),
    );
  }

  Widget _buildCopyableField(String text) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF161616),
        border: Border.all(color: Colors.white10),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Container(
            decoration: const BoxDecoration(
              border: Border(right: BorderSide(color: Colors.white10)),
            ),
            child: IconButton(
              icon: const Icon(Icons.copy_rounded, color: Colors.white70, size: 20),
              onPressed: () {
                Clipboard.setData(ClipboardData(text: text));
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم النسخ!')));
              },
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                text,
                style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCardSelector({
    required String title,
    String? subtitle,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        decoration: BoxDecoration(
          color: Colors.transparent,
          border: Border.all(color: isSelected ? Colors.red : Colors.white12, width: 1.5),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Text(
              title.toUpperCase(),
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
              textAlign: TextAlign.center,
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 4),
              Text(
                'عنوان: ',
                style: const TextStyle(color: Colors.white38, fontSize: 11),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ]
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final locale = Provider.of<LocaleProvider>(context).locale.languageCode;
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F), // Dark matching the website
      appBar: AppBar(
        title: const Text('إتمام الاشتراك', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _isLoadingGateways
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // --- Order Summary (ملخص الطلب) ---
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: const Color(0xFF161616),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white10),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        const Center(
                          child: Text(
                            'ملخص الطلب',
                            style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                        ),
                        const SizedBox(height: 20),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    widget.courseTitle,
                                    style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                                    textAlign: TextAlign.right,
                                  ),
                                ],
                              ),
                            ),
                            if (widget.imageUrl != null && widget.imageUrl!.isNotEmpty) ...[
                              const SizedBox(width: 15),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.network(
                                  widget.imageUrl!,
                                  width: 60,
                                  height: 60,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => Container(width: 60, height: 60, color: Colors.white10, child: const Icon(Icons.image, color: Colors.white30)),
                                ),
                              ),
                            ]
                          ],
                        ),
                        const SizedBox(height: 15),
                        const Divider(color: Colors.white10),
                        const SizedBox(height: 15),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('\$${widget.price}', style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
                            Text(locale == 'ar' ? 'سعر الاشتراك' : 'Subscription Price', style: TextStyle(color: Colors.white70, fontSize: 14)),
                          ],
                        ),
                        if (widget.accessPeriod != null && widget.accessPeriod!.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(widget.accessPeriod!, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
                              Text(locale == 'ar' ? 'مدة الاشتراك' : 'Access Period', style: TextStyle(color: Colors.white70, fontSize: 14)),
                            ],
                          ),
                        ],
                        const SizedBox(height: 15),
                        const Divider(color: Colors.white10),
                        const SizedBox(height: 15),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('\$${widget.price}', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                            Text(locale == 'ar' ? 'الإجمالي' : 'Total', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // --- Gateway Selection Section ---
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: const Color(0xFF161616),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white10),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        const Center(
                          child: Text(
                            'اختر طريقة الدفع',
                            style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                        ),
                        const SizedBox(height: 20),
                        if (_gateways.isEmpty)
                          Center(child: Text(locale == 'ar' ? 'لا توجد طرق دفع متاحة' : 'No Payment Methods Available', style: TextStyle(color: Colors.red)))
                        else
                          Row(
                            children: _gateways.map((gw) {
                              final isSelected = _selectedGateway?['id'] == gw['id'];
                              return Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 4.0),
                                  child: _buildCardSelector(
                                    title: (locale == 'ar' ? (gw['title_ar'] ?? gw['title']) : gw['title']) ?? '',
                                    isSelected: isSelected,
                                    onTap: () {
                                      setState(() {
                                        _selectedGateway = gw;
                                        _selectedMethod = null;
                                      });
                                    },
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // --- Details Section ---
                  if (_selectedGateway != null)
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: const Color(0xFF161616),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white10),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Center(
                            child: Text((locale == 'ar' ? '?????? ????? (' : 'Payment Details (') + ((locale == 'ar' ? (_selectedGateway!["title_ar"] ?? _selectedGateway!["title"]) : _selectedGateway!["title"]) ?? "") + ')', style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                          ),
                          if (_selectedGateway!['instructions_ar'] != null) ...[
                            const SizedBox(height: 8),
                            Center(
                              child: Text(
                                _selectedGateway!['instructions_ar'],
                                style: const TextStyle(color: Colors.white54, fontSize: 12),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ],
                          const SizedBox(height: 20),
                          
                          // -- E-Wallet Selection --
                          if (_selectedGateway!['type'] == 'ewallet' && _selectedGateway!['wallets'] != null) ...[
                            Text(locale == 'ar' ? 'اختر المحفظة أو البنك:' : 'Select Wallet/Bank:', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold), textAlign: TextAlign.right),
                            const SizedBox(height: 10),
                            Row(
                              children: (_selectedGateway!['wallets'] as List).map((wallet) {
                                final isSelected = _selectedMethod == wallet;
                                return Expanded(
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 4.0),
                                    child: _buildCardSelector(
                                      title: wallet['type'].toString(),
                                      subtitle: wallet['number'],
                                      isSelected: isSelected,
                                      onTap: () => setState(() => _selectedMethod = wallet),
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          ],

                          // -- Crypto Selection --
                          if (_selectedGateway!['type'] == 'crypto' && _selectedGateway!['networks'] != null) ...[
                            Text(locale == 'ar' ? 'اختر شبكة التحويل:' : 'Select Network:', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold), textAlign: TextAlign.right),
                            const SizedBox(height: 10),
                            Row(
                              children: (_selectedGateway!['networks'] as List).map((net) {
                                final isSelected = _selectedMethod == net;
                                return Expanded(
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 4.0),
                                    child: _buildCardSelector(
                                      title: net['network'].toString(),
                                      subtitle: net['wallet_address'],
                                      isSelected: isSelected,
                                      onTap: () => setState(() => _selectedMethod = net),
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                            if (_selectedMethod != null) ...[
                              const SizedBox(height: 20),
                              Center(
                                child: Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
                                  child: QrImageView(
                                    data: _selectedMethod!['wallet_address'] ?? '',
                                    version: QrVersions.auto,
                                    size: 160.0,
                                    backgroundColor: Colors.white,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 20),
                              _buildCopyableField(_selectedMethod!['wallet_address'] ?? ''),
                            ],
                          ],

                          const SizedBox(height: 30),

                          // -- Input Fields --
                          if (_selectedMethod != null || _selectedGateway!['type'] == 'manual') ...[
                            if (_selectedGateway!['type'] == 'ewallet') ...[
                              _buildFieldLabel(locale == 'ar' ? 'صورة إيصال التحويل *' : 'Transfer Receipt Image *'),
                              _buildFilePicker(),
                              const SizedBox(height: 20),
                              
                              _buildFieldLabel(locale == 'ar' ? 'رقم المحفظة المحول منها (رقم التليفون) *' : 'Sender Wallet/Phone Number *'),
                              _buildTextField(controller: _phoneController, hint: locale == 'ar' ? 'مثال: 01012345678' : 'Example: 01012345678'),
                              const SizedBox(height: 20),

                              _buildFieldLabel(locale == 'ar' ? 'الرقم المرجعي للعملية (Transaction ID) *' : 'Transaction ID *'),
                              _buildTextField(controller: _txHashController, hint: locale == 'ar' ? 'الرقم المرجعي' : 'Transaction ID'),
                            ] else ...[
                              _buildFieldLabel(locale == 'ar' ? 'رقم العملية (TX Hash) *' : 'Transaction Hash *'),
                              _buildTextField(controller: _txHashController, hint: locale == 'ar' ? 'أدخل TX Hash المكون من الحروف والأرقام' : 'Enter Transaction Hash'),
                            ],
                            
                            const SizedBox(height: 30),
                            
                            // -- Timer & Submit Row --
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  '${(_secondsRemaining ~/ 60).toString().padLeft(2, '0')}:${(_secondsRemaining % 60).toString().padLeft(2, '0')}',
                                  style: const TextStyle(color: Colors.red, fontSize: 24, fontWeight: FontWeight.bold),
                                ),
                                Row(
                                  children: [
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        Text('الوقت المتبقي لإتمام الدفع', style: TextStyle(color: Colors.white70, fontSize: 12)),
                                        Text('يرجى إرسال البيانات قبل انتهاء العداد', style: TextStyle(color: Colors.white38, fontSize: 10)),
                                      ],
                                    ),
                                    const SizedBox(width: 8),
                                    const Icon(Icons.hourglass_bottom, color: Colors.orange, size: 28),
                                  ],
                                ),
                              ],
                            ),
                            
                            const SizedBox(height: 20),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: _isSubmitting ? null : _submitCheckout,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.red,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                                child: _isSubmitting
                              ? const SizedBox.shrink()
                              : Text(locale == 'ar' ? 'تأكيد الدفع والاشتراك' : 'Confirm Payment & Subscribe', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
    );
  }
}


