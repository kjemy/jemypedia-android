import sys
import re

checkout_path = r'C:\Users\hp\.gemini\antigravity\scratch\jemypedia-android\lib\features\subscriptions\screens\checkout_screen.dart'
with open(checkout_path, 'r', encoding='utf-8') as f:
    content = f.read()

content = content.replace("TextStyle(, ", "TextStyle(")
content = content.replace("TextStyle( , ", "TextStyle(")

with open(checkout_path, 'w', encoding='utf-8') as f:
    f.write(content)
