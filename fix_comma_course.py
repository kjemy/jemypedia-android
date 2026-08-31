import sys
import re

course_path = r'C:\Users\hp\.gemini\antigravity\scratch\jemypedia-android\lib\features\courses\ui\course_detail_screen.dart'
with open(course_path, 'r', encoding='utf-8') as f:
    content = f.read()

content = content.replace("TextStyle(, ", "TextStyle(")
content = content.replace("TextStyle( , ", "TextStyle(")

with open(course_path, 'w', encoding='utf-8') as f:
    f.write(content)
