import sys

checkout_path = r'C:\Users\hp\.gemini\antigravity\scratch\jemypedia-android\lib\features\subscriptions\screens\checkout_screen.dart'
with open(checkout_path, 'r', encoding='utf-8') as f:
    content = f.read()

# Fix non_constant_list_element
content = content.replace("children: const [\n                                        Text(locale == 'ar'", "children: [\n                                        Text(locale == 'ar'")

with open(checkout_path, 'w', encoding='utf-8') as f:
    f.write(content)
