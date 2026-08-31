import 'package:flutter/material.dart';
import 'package:jemypedia_app/core/theme/app_colors.dart';
import 'package:jemypedia_app/shared/widgets/glass_container.dart';
import 'package:jemypedia_app/core/services/wordpress_service.dart';
import 'package:provider/provider.dart';
import 'package:jemypedia_app/core/providers/auth_provider.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';

class CheckoutScreen extends StatefulWidget {
  final int courseId;
  final String courseTitle;
  final String price;
  final String? wooId;
  
  const CheckoutScreen({
    super.key,
    required this.courseId,
    required this.courseTitle,
    required this.price,
    this.wooId,
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

  @override
  void initState() {
    super.initState();
    _fetchGateways();
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
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter TX Hash')));
      return;
    }

    setState(() => _isSubmitting = true);

    final res = await _wpService.submitCheckout(
      planId: widget.courseId,
      userId: userId,
      gateway: _selectedGateway!['id'],
      txHash: txHash.isEmpty ? 'EWALLET_TX' : txHash,
      wooId: widget.wooId,
      network: _selectedMethod?['network'],
      gasFee: _selectedMethod?['gas_fee']?.toString(),
      phoneNumber: _phoneController.text.trim(),
      receiptImagePath: _receiptImage?.path,
    );

    setState(() => _isSubmitting = false);

    if (res['success'] == true) {
      setState(() => _isSuccess = true);
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) Navigator.pop(context);
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res['message'] ?? 'Error')));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isSuccess) {
      return Scaffold(
        backgroundColor: AppColors.bgDark,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.check_circle_outline, color: Colors.green, size: 100),
              const SizedBox(height: 20),
              const Text('تم استلام طلبك بنجاح!', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold, fontFamily: 'Cairo')),
              const SizedBox(height: 10),
              const Text('سيتم مراجعة الدفع وتفعيل الكورس قريباً', style: TextStyle(color: Colors.white70, fontFamily: 'Cairo')),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.bgDark,
      appBar: AppBar(
        title: const Text('إتمام الاشتراك', style: TextStyle(fontFamily: 'Cairo')),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: _isLoadingGateways
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  GlassContainer(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(widget.courseTitle, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold, fontFamily: 'Cairo')),
                        const SizedBox(height: 10),
                        Text('السعر: ${widget.price} \$', style: const TextStyle(color: AppColors.accentNeon, fontSize: 16, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text('اختر طريقة الدفع:', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold, fontFamily: 'Cairo')),
                  const SizedBox(height: 10),
                  if (_gateways.isEmpty)
                    const Text('لا توجد طرق دفع متاحة', style: TextStyle(color: Colors.red))
                  else
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: _gateways.map((gw) {
                        final isSelected = _selectedGateway?['id'] == gw['id'];
                        return GestureDetector(
                          onTap: () {
                            setState(() {
                              _selectedGateway = gw;
                              _selectedMethod = null;
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            decoration: BoxDecoration(
                              color: isSelected ? AppColors.accentNeon.withOpacity(0.2) : Colors.white10,
                              border: Border.all(color: isSelected ? AppColors.accentNeon : Colors.white24),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(gw['title_ar'] ?? gw['title'] ?? '', style: TextStyle(color: isSelected ? AppColors.accentNeon : Colors.white, fontFamily: 'Cairo')),
                          ),
                        );
                      }).toList(),
                    ),
                  const SizedBox(height: 20),
                  if (_selectedGateway != null) ...[
                    Text(_selectedGateway!['instructions_ar'] ?? '', style: const TextStyle(color: Colors.white70, fontFamily: 'Cairo')),
                    const SizedBox(height: 20),
                    
                    if (_selectedGateway!['type'] == 'ewallet' && _selectedGateway!['wallets'] != null) ...[
                      const Text('اختر المحفظة:', style: TextStyle(color: Colors.white, fontFamily: 'Cairo')),
                      const SizedBox(height: 10),
                      ...(_selectedGateway!['wallets'] as List).map((wallet) {
                        final isSelected = _selectedMethod == wallet;
                        return RadioListTile<Map<String, dynamic>>(
                          title: Text(wallet['type'].toString().toUpperCase(), style: const TextStyle(color: Colors.white)),
                          subtitle: Text(wallet['number'] ?? '', style: const TextStyle(color: Colors.white70)),
                          value: wallet,
                          groupValue: _selectedMethod,
                          activeColor: AppColors.accentNeon,
                          onChanged: (val) => setState(() => _selectedMethod = val),
                        );
                      }).toList(),
                    ],

                    if (_selectedGateway!['type'] == 'crypto' && _selectedGateway!['networks'] != null) ...[
                      const Text('اختر الشبكة:', style: TextStyle(color: Colors.white, fontFamily: 'Cairo')),
                      const SizedBox(height: 10),
                      ...(_selectedGateway!['networks'] as List).map((net) {
                        final isSelected = _selectedMethod == net;
                        return RadioListTile<Map<String, dynamic>>(
                          title: Text(net['network'].toString().toUpperCase(), style: const TextStyle(color: Colors.white)),
                          subtitle: Text(net['wallet_address'] ?? '', style: const TextStyle(color: Colors.white70)),
                          value: net,
                          groupValue: _selectedMethod,
                          activeColor: AppColors.accentNeon,
                          onChanged: (val) => setState(() => _selectedMethod = val),
                        );
                      }).toList(),
                    ],

                    const SizedBox(height: 20),
                    if (_selectedMethod != null || _selectedGateway!['type'] == 'manual') ...[
                      if (_selectedGateway!['type'] == 'ewallet') ...[
                        TextField(
                          controller: _phoneController,
                          style: const TextStyle(color: Colors.white),
                          decoration: const InputDecoration(
                            labelText: 'رقم المحفظة المحول منها',
                            labelStyle: TextStyle(color: Colors.white70, fontFamily: 'Cairo'),
                            enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                            focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: AppColors.accentNeon)),
                          ),
                        ),
                        const SizedBox(height: 10),
                        ElevatedButton.icon(
                          onPressed: _pickImage,
                          icon: const Icon(Icons.image),
                          label: Text(_receiptImage == null ? 'إرفاق صورة الإيصال' : 'تم الإرفاق: ${_receiptImage!.path.split('/').last}', style: const TextStyle(fontFamily: 'Cairo')),
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.white10),
                        ),
                      ] else ...[
                        TextField(
                          controller: _txHashController,
                          style: const TextStyle(color: Colors.white),
                          decoration: const InputDecoration(
                            labelText: 'TX Hash / الرقم المرجعي',
                            labelStyle: TextStyle(color: Colors.white70, fontFamily: 'Cairo'),
                            enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                            focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: AppColors.accentNeon)),
                          ),
                        ),
                      ],
                      
                      const SizedBox(height: 30),
                      ElevatedButton(
                        onPressed: _isSubmitting ? null : _submitCheckout,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.accentNeon,
                          padding: const EdgeInsets.symmetric(vertical: 15),
                        ),
                        child: _isSubmitting
                            ? const CircularProgressIndicator(color: Colors.white)
                            : const Text('تأكيد الدفع والاشتراك', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 16, fontFamily: 'Cairo')),
                      ),
                    ],
                  ],
                ],
              ),
            ),
    );
  }
}
