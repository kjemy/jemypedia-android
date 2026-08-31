import sys

file_path = r'C:\Users\hp\.gemini\antigravity\scratch\jemypedia-android\lib\features\subscriptions\screens\checkout_screen.dart'
with open(file_path, 'r', encoding='utf-8') as f:
    content = f.read()

bad_string = "child: Text('ØªÙ Ø§ØµÙŠÙ„ Ø§Ù„Ø¯Ù Ø¹ (${_selectedGateway![\\'title_ar\\'] ?? _selectedGateway![\\'title\\'] ?? \\'\\'})', style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold, fontFamily: 'Cairo'),"
good_string = "child: Text('ØªÙ Ø§ØµÙŠÙ„ Ø§Ù„Ø¯Ù Ø¹ (${_selectedGateway![\"title_ar\"] ?? _selectedGateway![\"title\"] ?? \"\"})', style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold, fontFamily: 'Cairo'),"

content = content.replace(bad_string, good_string)

# also check if the other replacement happened
bad_string2 = "'تفاصيل الدفع (${_selectedGateway![\\'title_ar\\'] ?? _selectedGateway![\\'title\\'] ?? \\'\\'})'"
good_string2 = "'تفاصيل الدفع (${_selectedGateway![\"title_ar\"] ?? _selectedGateway![\"title\"] ?? \"\"})'"
content = content.replace(bad_string2, good_string2)

with open(file_path, 'w', encoding='utf-8') as f:
    f.write(content)
