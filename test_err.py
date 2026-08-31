import sys
import re

def check_file(file_path):
    with open(file_path, 'r', encoding='utf-8') as f:
        content = f.read()

    def replacer(match):
        text = match.group(0)
        if '\u00d8' in text:
            try:
                fixed = text.encode('cp1252').decode('utf-8')
            except Exception as e:
                # print error but safely (avoid printing mojibake to cp1252 terminal)
                print(f'Error on a string: {e}')
        return text

    re.sub(r"'([^']*)'", replacer, content)

check_file(r'C:\Users\hp\.gemini\antigravity\scratch\jemypedia-android\lib\features\courses\ui\course_detail_screen.dart')
