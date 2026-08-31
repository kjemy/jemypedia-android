import sys

with open(r'C:\Users\hp\.gemini\antigravity\scratch\jemypedia-android\lib\features\courses\ui\course_detail_screen.dart', 'r', encoding='utf-8') as f:
    lines = f.readlines()

for line in lines:
    if "Text(locale == 'ar' ?" in line:
        # print the repr of the string
        print(repr(line.strip()))
        break
