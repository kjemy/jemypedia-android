import sys

with open(r'C:\Users\hp\.gemini\antigravity\scratch\jemypedia-android\lib\features\courses\ui\course_detail_screen.dart', 'r', encoding='utf-8') as f:
    lines = f.readlines()

with open('bad_lines.txt', 'w', encoding='utf-8') as out:
    for i, line in enumerate(lines):
        if "Text(locale == 'ar' ?" in line:
            out.write(f'{i}: {line}')
