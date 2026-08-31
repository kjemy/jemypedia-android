import 'package:flutter/material.dart';
import 'package:jemypedia_app/core/theme/app_colors.dart';
import 'package:jemypedia_app/shared/widgets/glass_container.dart';
import 'package:jemypedia_app/core/services/wordpress_service.dart';
import 'package:jemypedia_app/main.dart'; // To navigate back to LoginScreen

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  int _step = 1;
  bool _isLoading = false;

  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _otpController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _countryController = TextEditingController();

  final WordPressService _wpService = WordPressService();
  bool _obscureText = true;

  @override
  void dispose() {
    _emailController.dispose();
    _otpController.dispose();
    _passwordController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _phoneController.dispose();
    _countryController.dispose();
    super.dispose();
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          textDirection: TextDirection.rtl,
          style: const TextStyle(fontFamily: 'Cairo', fontSize: 14),
        ),
        backgroundColor: Colors.red.shade800,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          textDirection: TextDirection.rtl,
          style: const TextStyle(fontFamily: 'Cairo', fontSize: 14),
        ),
        backgroundColor: Colors.green.shade800,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _handleSendOtp() async {
    final email = _emailController.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      _showError('يرجى إدخال بريد إلكتروني صحيح');
      return;
    }

    setState(() => _isLoading = true);
    final result = await _wpService.registerSendOtp(email);
    setState(() => _isLoading = false);

    if (result['success'] == true) {
      _showSuccess('تم إرسال كود التفعيل إلى بريدك');
      setState(() => _step = 2);
    } else {
      _showError(result['message'] ?? 'فشل إرسال كود التفعيل');
    }
  }

  Future<void> _handleRegister() async {
    final email = _emailController.text.trim();
    final otp = _otpController.text.trim();
    final pass = _passwordController.text;
    final fName = _firstNameController.text.trim();
    final lName = _lastNameController.text.trim();
    final phone = _phoneController.text.trim();
    final country = _countryController.text.trim();

    if (otp.isEmpty || pass.isEmpty || fName.isEmpty || lName.isEmpty || phone.isEmpty || country.isEmpty) {
      _showError('يرجى ملء جميع الحقول');
      return;
    }

    setState(() => _isLoading = true);
    final result = await _wpService.register(
      email: email,
      otp: otp,
      password: pass,
      firstName: fName,
      lastName: lName,
      phone: phone,
      country: country,
    );
    setState(() => _isLoading = false);

    if (result['success'] == true) {
      _showSuccess('تم إنشاء الحساب بنجاح! يرجى تسجيل الدخول');
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    } else {
      _showError(result['message'] ?? 'حدث خطأ أثناء التسجيل');
    }
  }

  Widget _buildTextField(TextEditingController controller, String hint, IconData icon, {bool isPassword = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: TextField(
        controller: controller,
        obscureText: isPassword ? _obscureText : false,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: Colors.white70),
          prefixIcon: Icon(icon, color: Colors.white70),
          suffixIcon: isPassword
              ? IconButton(
                  icon: Icon(
                    _obscureText ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                    color: Colors.white70,
                  ),
                  onPressed: () => setState(() => _obscureText = !_obscureText),
                )
              : null,
          filled: true,
          fillColor: Colors.white.withOpacity(0.05),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [AppColors.bgDark, AppColors.primary],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(height: 50),
                  Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.accentNeon.withOpacity(0.3),
                          blurRadius: 30,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: ClipOval(
                      child: Image.asset(
                        'assets/images/app_icon.png',
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => const Icon(Icons.school_rounded, size: 40, color: Colors.white24),
                      ),
                    ),
                  ),
                  const SizedBox(height: 30),
                  
                  GlassContainer(
                    blur: 20,
                    opacity: 0.1,
                    child: Column(
                      children: [
                        const Text(
                          'إنشاء حساب جديد',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 20),
                        
                        if (_step == 1) ...[
                          _buildTextField(_emailController, 'البريد الإلكتروني', Icons.email_outlined),
                          const SizedBox(height: 10),
                          Container(
                            width: double.infinity,
                            height: 55,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(15),
                              gradient: const LinearGradient(
                                colors: [AppColors.accentNeon, AppColors.primary],
                              ),
                            ),
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : _handleSendOtp,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.transparent,
                                shadowColor: Colors.transparent,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(15),
                                ),
                              ),
                              child: _isLoading 
                                ? const CircularProgressIndicator(color: Colors.white)
                                : const Text('إرسال كود التفعيل', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white)),
                            ),
                          ),
                        ] else ...[
                          Text('تم إرسال الكود إلى ${_emailController.text}', style: const TextStyle(color: Colors.white70, fontSize: 12)),
                          const SizedBox(height: 15),
                          Row(
                            children: [
                              Expanded(child: _buildTextField(_firstNameController, 'الاسم الأول', Icons.person_outline)),
                              const SizedBox(width: 10),
                              Expanded(child: _buildTextField(_lastNameController, 'الاسم الأخير', Icons.person_outline)),
                            ],
                          ),
                          _buildTextField(_passwordController, 'كلمة المرور', Icons.lock_outline, isPassword: true),
                          _buildTextField(_phoneController, 'رقم الهاتف', Icons.phone_outlined),
                          _buildTextField(_countryController, 'البلد', Icons.public_outlined),
                          _buildTextField(_otpController, 'كود التفعيل', Icons.pin_outlined),
                          
                          const SizedBox(height: 10),
                          Container(
                            width: double.infinity,
                            height: 55,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(15),
                              gradient: const LinearGradient(
                                colors: [AppColors.accentNeon, AppColors.primary],
                              ),
                            ),
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : _handleRegister,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.transparent,
                                shadowColor: Colors.transparent,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(15),
                                ),
                              ),
                              child: _isLoading 
                                ? const CircularProgressIndicator(color: Colors.white)
                                : const Text('إكمال التسجيل', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white)),
                            ),
                          ),
                          TextButton(
                            onPressed: () => setState(() => _step = 1),
                            child: const Text('تعديل البريد الإلكتروني', style: TextStyle(color: Colors.white70)),
                          ),
                        ],
                        
                        const SizedBox(height: 10),
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text(
                            'العودة لتسجيل الدخول',
                            style: TextStyle(color: Colors.white70),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 50),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
