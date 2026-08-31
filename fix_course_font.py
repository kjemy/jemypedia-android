import sys
import re

course_path = r'C:\Users\hp\.gemini\antigravity\scratch\jemypedia-android\lib\features\courses\ui\course_detail_screen.dart'
with open(course_path, 'r', encoding='utf-8') as f:
    content = f.read()

# Remove fontFamily
content = re.sub(r",\s*fontFamily:\s*'Cairo'", "", content)
content = re.sub(r",\s*fontFamily:\s*'Courier'", "", content)

# Reduce sizes in the pricing block specifically
content = content.replace("style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)", "style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)")
content = content.replace("fontSize: 16", "fontSize: 13")
content = content.replace("fontSize: 18", "fontSize: 14")
content = content.replace("fontSize: 12", "fontSize: 10")

with open(course_path, 'w', encoding='utf-8') as f:
    f.write(content)
