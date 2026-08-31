import sys

with open(r'C:\Users\hp\.gemini\antigravity\scratch\jemypedia-android\lib\features\subscriptions\screens\checkout_screen.dart', 'r', encoding='utf-8') as f:
    lines = f.readlines()

for line in lines:
    if "???? ?????" in line or "ط" in line or "ملخص" in line:
        print(ascii(line.strip()))
