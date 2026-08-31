import sys
import re

def fix_file(file_path):
    with open(file_path, 'r', encoding='utf-8') as f:
        content = f.read()

    def replacer(match):
        text = match.group(0)
        try:
            fixed = text.encode('cp1252').decode('utf-8')
            return fixed
        except Exception as e:
            return text

    # Match any word containing Ø, Ù, Ú and other mojibake chars and spaces
    # It's better to match strings in single OR double quotes.
    new_content = re.sub(r"'([^']*)'", replacer, content)
    new_content = re.sub(r'"([^"]*)"', replacer, new_content)
    
    with open(file_path, 'w', encoding='utf-8') as f:
        f.write(new_content)
    print("Processed", file_path)

fix_file(r'C:\Users\hp\.gemini\antigravity\scratch\jemypedia-android\lib\features\courses\ui\course_detail_screen.dart')
