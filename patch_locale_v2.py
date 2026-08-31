import sys

checkout_path = r'C:\Users\hp\.gemini\antigravity\scratch\jemypedia-android\lib\features\subscriptions\screens\checkout_screen.dart'
with open(checkout_path, 'r', encoding='utf-8') as f:
    content = f.read()

# Remove fontFamily everywhere safely
content = content.replace(", fontFamily: 'Cairo'", "")
content = content.replace(", fontFamily: 'Courier'", "")
content = content.replace("fontFamily: 'Cairo'", "")
content = content.replace("fontFamily: 'Courier'", "")

# We need to import LocaleProvider if we use locale
if "import 'package:jemypedia_app/core/providers/locale_provider.dart';" not in content:
    content = content.replace("import 'package:provider/provider.dart';", "import 'package:provider/provider.dart';\nimport 'package:jemypedia_app/core/providers/locale_provider.dart';")

# In build method:
build_start = "Widget build(BuildContext context) {"
if "final locale =" not in content:
    content = content.replace(
        build_start, 
        build_start + "\n    final locale = Provider.of<LocaleProvider>(context).locale.languageCode;"
    )

# Fix const Text -> Text
content = content.replace("const Text('ملخص الطلب'", "Text(locale == 'ar' ? 'ملخص الطلب' : 'Order Summary'")
content = content.replace("const Text('سعر الاشتراك'", "Text(locale == 'ar' ? 'سعر الاشتراك' : 'Subscription Price'")
content = content.replace("const Text('مدة الاشتراك'", "Text(locale == 'ar' ? 'مدة الاشتراك' : 'Access Period'")
content = content.replace("const Text('الإجمالي'", "Text(locale == 'ar' ? 'الإجمالي' : 'Total'")

content = content.replace("const Text(\n                            'اختر طريقة الدفع',", "Text(\n                            locale == 'ar' ? 'اختر طريقة الدفع' : 'Choose Payment Method',")
content = content.replace("const Text('لا توجد طرق دفع متاحة'", "Text(locale == 'ar' ? 'لا توجد طرق دفع متاحة' : 'No Payment Methods Available'")
content = content.replace("const Text('اختر المحفظة أو البنك:'", "Text(locale == 'ar' ? 'اختر المحفظة أو البنك:' : 'Select Wallet/Bank:'")
content = content.replace("const Text('اختر شبكة التحويل:'", "Text(locale == 'ar' ? 'اختر شبكة التحويل:' : 'Select Network:'")
content = content.replace("const Text('الوقت المتبقي لإتمام الدفع'", "Text(locale == 'ar' ? 'الوقت المتبقي لإتمام الدفع' : 'Time Remaining'")
content = content.replace("const Text('يرجى إرسال البيانات قبل انتهاء العداد'", "Text(locale == 'ar' ? 'يرجى إرسال البيانات قبل انتهاء العداد' : 'Please submit details before time expires'")
content = content.replace("const Text('تأكيد الدفع والاشتراك'", "Text(locale == 'ar' ? 'تأكيد الدفع والاشتراك' : 'Confirm Payment & Subscribe'")

# Fix Gateway title logic
content = content.replace("gw['title_ar'] ?? gw['title'] ?? ''", "(locale == 'ar' ? (gw['title_ar'] ?? gw['title']) : gw['title']) ?? ''")

# Fix Payment Details string dynamically
bad_details = "Text('تفاصيل الدفع (${_selectedGateway![\"title_ar\"] ?? _selectedGateway![\"title\"] ?? \"\"})'"
good_details = "Text((locale == 'ar' ? 'تفاصيل الدفع (' : 'Payment Details (') + ((locale == 'ar' ? (_selectedGateway![\"title_ar\"] ?? _selectedGateway![\"title\"]) : _selectedGateway![\"title\"]) ?? \"\") + ')'"
content = content.replace(bad_details, good_details)

# Fix input fields labels (not const)
content = content.replace("'صورة إيصال التحويل *'", "locale == 'ar' ? 'صورة إيصال التحويل *' : 'Transfer Receipt Image *'")
content = content.replace("'رقم المحفظة المحول منها (رقم التليفون) *'", "locale == 'ar' ? 'رقم المحفظة المحول منها (رقم التليفون) *' : 'Sender Wallet/Phone Number *'")
content = content.replace("'مثال: 01012345678'", "locale == 'ar' ? 'مثال: 01012345678' : 'Example: 01012345678'")
content = content.replace("'الرقم المرجعي للعملية (Transaction ID) *'", "locale == 'ar' ? 'الرقم المرجعي للعملية (Transaction ID) *' : 'Transaction ID *'")
content = content.replace("'الرقم المرجعي'", "locale == 'ar' ? 'الرقم المرجعي' : 'Transaction ID'")
content = content.replace("'رقم العملية (TX Hash) *'", "locale == 'ar' ? 'رقم العملية (TX Hash) *' : 'Transaction Hash *'")
content = content.replace("'أدخل TX Hash المكون من الحروف والأرقام'", "locale == 'ar' ? 'أدخل TX Hash المكون من الحروف والأرقام' : 'Enter Transaction Hash'")

# The const children array issue in Timer section
content = content.replace("children: const [\n                                        Text(locale == 'ar'", "children: [\n                                        Text(locale == 'ar'")

with open(checkout_path, 'w', encoding='utf-8') as f:
    f.write(content)
print("done checkout")
