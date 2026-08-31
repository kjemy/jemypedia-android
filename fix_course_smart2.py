import sys
import re

def fix_file(file_path):
    with open(file_path, 'r', encoding='utf-8') as f:
        content = f.read()

    def replacer(match):
        text = match.group(0) # this includes the quotes!
        # we need to decode just the inside, or just decode the whole match
        try:
            # text includes the quotes, e.g. 'درس'
            fixed = text.encode('cp1252').decode('utf-8')
            return fixed
        except Exception as e:
            return text

    new_content = re.sub(r"'([^']*)'", replacer, content)
    new_content = re.sub(r'"([^"]*)"', replacer, new_content)
    
    with open(file_path, 'w', encoding='utf-8') as f:
        f.write(new_content)
    print("Processed", file_path)

fix_file(r'C:\Users\hp\.gemini\antigravity\scratch\jemypedia-android\lib\features\courses\ui\course_detail_screen.dart')
