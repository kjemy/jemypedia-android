import sys
import re

def fix_file(file_path):
    with open(file_path, 'r', encoding='utf-8') as f:
        content = f.read()

    if content.startswith('\ufeff'):
        content = content[1:]

    def replacer(match):
        text = match.group(1)
        if '\u00d8' in text or '\u00d9' in text or '\u00da' in text:
            try:
                fixed = text.encode('cp1252').decode('utf-8')
                return "'" + fixed + "'"
            except Exception as e:
                return "'" + text + "'"
        return "'" + text + "'"

    new_content = re.sub(r"'([^'\\]*)'", replacer, content)
    
    with open(file_path, 'w', encoding='utf-8') as f:
        f.write(new_content)
    print("Processed", file_path)

fix_file(r'C:\Users\hp\.gemini\antigravity\scratch\jemypedia-android\lib\features\courses\ui\course_detail_screen.dart')
fix_file(r'C:\Users\hp\.gemini\antigravity\scratch\jemypedia-android\lib\features\subscriptions\screens\checkout_screen.dart')
