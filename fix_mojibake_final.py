import sys
import re

file_path = r'C:\Users\hp\.gemini\antigravity\scratch\jemypedia-android\lib\features\subscriptions\screens\checkout_screen.dart'

with open(file_path, 'r', encoding='utf-8') as f:
    content = f.read()

# Fix BOM
if content.startswith('\ufeff'):
    content = content[1:]

def fix_string(s):
    try:
        # Convert the mojibake characters back to their original utf-8 bytes
        b = s.encode('cp1252')
        # Decode as utf-8
        return b.decode('utf-8')
    except Exception as e:
        return s

# We will apply this to every line, but only for the substrings that look like mojibake.
# Mojibake in this file starts with \xd8, \xd9, \xda and has cp1252 characters.
# Actually, if we apply it to the whole line, it might fail if the line contains standard English letters?
# No! 'abc'.encode('cp1252') -> b'abc'.decode('utf-8') -> 'abc'. It works for ASCII!
# It only fails if the line contains REAL utf-8 Arabic characters!
# But we already counted 7 real Arabic characters in this file (probably '?? ?????').
# Let's just find and replace specific substrings.

new_lines = []
for line in content.split('\n'):
    if '\u00d8' in line or '\u00d9' in line or '\u00da' in line:
        # This line has mojibake. 
        # Find all sequences of non-ASCII characters and fix them.
        def replacer(match):
            return fix_string(match.group(0))
        
        # Match sequences of characters >= \x80
        fixed_line = re.sub(r'[^\x00-\x7F]+', replacer, line)
        new_lines.append(fixed_line)
    else:
        new_lines.append(line)

with open(file_path, 'w', encoding='utf-8') as f:
    f.write('\n'.join(new_lines))
print("Fixed!")
