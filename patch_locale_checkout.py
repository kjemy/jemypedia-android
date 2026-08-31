import sys
import re

checkout_path = r'C:\Users\hp\.gemini\antigravity\scratch\jemypedia-android\lib\features\subscriptions\screens\checkout_screen.dart'
with open(checkout_path, 'r', encoding='utf-8') as f:
    content = f.read()

# Fix Order Summary
content = content.replace("'ملخص الطلب'", "locale == 'ar' ? 'ملخص الطلب' : 'Order Summary'")
content = content.replace("'سعر الاشتراك'", "locale == 'ar' ? 'سعر الاشتراك' : 'Subscription Price'")
content = content.replace("'مدة الاشتراك'", "locale == 'ar' ? 'مدة الاشتراك' : 'Access Period'")
content = content.replace("'الإجمالي'", "locale == 'ar' ? 'الإجمالي' : 'Total'")

# Fix Gateway section
content = content.replace("'اختر طريقة الدفع'", "locale == 'ar' ? 'اختر طريقة الدفع' : 'Choose Payment Method'")
content = content.replace("'لا توجد طرق دفع متاحة'", "locale == 'ar' ? 'لا توجد طرق دفع متاحة' : 'No Payment Methods Available'")
content = content.replace("'اختر المحفظة أو البنك:'", "locale == 'ar' ? 'اختر المحفظة أو البنك:' : 'Select Wallet/Bank:'")
content = content.replace("'اختر شبكة التحويل:'", "locale == 'ar' ? 'اختر شبكة التحويل:' : 'Select Network:'")

# Fix Form
content = content.replace("'صورة إيصال التحويل *'", "locale == 'ar' ? 'صورة إيصال التحويل *' : 'Transfer Receipt Image *'")
content = content.replace("'رقم المحفظة المحول منها (رقم التليفون) *'", "locale == 'ar' ? 'رقم المحفظة المحول منها (رقم التليفون) *' : 'Sender Wallet/Phone Number *'")
content = content.replace("'مثال: 01012345678'", "locale == 'ar' ? 'مثال: 01012345678' : 'Example: 01012345678'")
content = content.replace("'الرقم المرجعي للعملية (Transaction ID) *'", "locale == 'ar' ? 'الرقم المرجعي للعملية (Transaction ID) *' : 'Transaction ID *'")
content = content.replace("'الرقم المرجعي'", "locale == 'ar' ? 'الرقم المرجعي' : 'Transaction ID'")
content = content.replace("'رقم العملية (TX Hash) *'", "locale == 'ar' ? 'رقم العملية (TX Hash) *' : 'Transaction Hash *'")
content = content.replace("'أدخل TX Hash المكون من الحروف والأرقام'", "locale == 'ar' ? 'أدخل TX Hash المكون من الحروف والأرقام' : 'Enter Transaction Hash'")

# Fix Timer & Submit
content = content.replace("'الوقت المتبقي لإتمام الدفع'", "locale == 'ar' ? 'الوقت المتبقي لإتمام الدفع' : 'Time Remaining'")
content = content.replace("'يرجى إرسال البيانات قبل انتهاء العداد'", "locale == 'ar' ? 'يرجى إرسال البيانات قبل انتهاء العداد' : 'Please submit details before time expires'")
content = content.replace("'تأكيد الدفع والاشتراك'", "locale == 'ar' ? 'تأكيد الدفع والاشتراك' : 'Confirm Payment & Subscribe'")

# Also fix the dynamic string: 'تفاصيل الدفع (' + (locale == 'ar' ? ...
# Right now it's:
# Text('تفاصيل الدفع (${(locale == 'ar' ? (_selectedGateway!["title_ar"] ?? _selectedGateway!["title"]) : _selectedGateway!["title"]) ?? ""})', ...
# We want it to be:
# Text((locale == 'ar' ? 'تفاصيل الدفع (' : 'Payment Details (') + '${(locale == 'ar' ? (_selectedGateway!["title_ar"] ?? _selectedGateway!["title"]) : _selectedGateway!["title"]) ?? ""})', ...
content = re.sub(r"'تفاصيل الدفع \(\$\{\(locale == 'ar' \? \(_selectedGateway!\[\"title_ar\"\] \?\? _selectedGateway!\[\"title\"\]\) : _selectedGateway!\[\"title\"\]\) \?\? \"\"\}\)'", r"(locale == 'ar' ? 'تفاصيل الدفع (' : 'Payment Details (') + '${(locale == 'ar' ? (_selectedGateway![\"title_ar\"] ?? _selectedGateway![\"title\"]) : _selectedGateway![\"title\"]) ?? \"\"})'", content)

with open(checkout_path, 'w', encoding='utf-8') as f:
    f.write(content)

print("Checkout strings patched.")
