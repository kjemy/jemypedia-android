import sys
import re

file_path = r'C:\Users\hp\.gemini\antigravity\scratch\jemypedia-android\lib\features\subscriptions\screens\checkout_screen.dart'
with open(file_path, 'r', encoding='utf-8') as f:
    content = f.read()

# Fix 1: widget.price
content = content.replace("Text('\\{widget.price}'", "Text('\\$${widget.price}'")
content = content.replace("Text('{widget.price}'", "Text('\\$${widget.price}'")

# Fix 2: Payment details empty parentheses
# In Arabic it is 'تفاصيل الدفع ()'
# Let's use a regex to match it in case there are invisible characters.
content = re.sub(r"Text\(\s*['\"](.*?) \(\)['\"],\s*style:\s*const\s*TextStyle\(color:\s*Colors\.white,\s*fontSize:\s*16,\s*fontWeight:\s*FontWeight\.bold,\s*fontFamily:\s*'Cairo'\)", 
                 r"Text('\1 (${_selectedGateway![\'title_ar\'] ?? _selectedGateway![\'title\'] ?? \'\'})', style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold, fontFamily: 'Cairo')", 
                 content)

content = content.replace("'تفاصيل الدفع ()'", "'تفاصيل الدفع (${_selectedGateway![\\'title_ar\\'] ?? _selectedGateway![\\'title\\'] ?? \\'\\'})'")
content = content.replace("ØªÙ\x81Ø§ØµÙ\x8aÙ\x84 Ø§Ù\x84Ø¯Ù\x81Ø¹ ()", "تفاصيل الدفع (${_selectedGateway![\\'title_ar\\'] ?? _selectedGateway![\\'title\\'] ?? \\'\\'})")

# Fix 3: Timer
# The timer is currently: Text(':', style: const TextStyle(color: Colors.red, fontSize: 24, fontWeight: FontWeight.bold, fontFamily: 'Courier'))
timer_search = "Text(\n                                  ':',"
timer_replace = '''Text(
                                  '${(_secondsRemaining ~/ 60).toString().padLeft(2, '0')}:${(_secondsRemaining % 60).toString().padLeft(2, '0')}','''
if timer_search in content:
    content = content.replace(timer_search, timer_replace)
else:
    # Try regex
    content = re.sub(r"Text\(\s*':',\s*style:\s*const\s*TextStyle\(color:\s*Colors\.red,\s*fontSize:\s*24,\s*fontWeight:\s*FontWeight\.bold,\s*fontFamily:\s*'Courier'\)",
                     r"Text('${(_secondsRemaining ~/ 60).toString().padLeft(2, '0')}:${(_secondsRemaining % 60).toString().padLeft(2, '0')}', style: const TextStyle(color: Colors.red, fontSize: 24, fontWeight: FontWeight.bold, fontFamily: 'Courier')",
                     content)

with open(file_path, 'w', encoding='utf-8') as f:
    f.write(content)

print("Checkout screen patched!")
