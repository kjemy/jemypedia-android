import sys
import re

with open(r'C:\Users\hp\.gemini\antigravity\scratch\jemypedia-android\lib\features\subscriptions\screens\checkout_screen.dart', 'r', encoding='utf-8') as f:
    lines = f.readlines()

for i, line in enumerate(lines):
    if '\u00d8' in line or '\u00d9' in line:
        print(f"{i}: {ascii(line.strip())}")
