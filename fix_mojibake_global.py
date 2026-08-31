import sys

def check_file(file_path):
    with open(file_path, 'r', encoding='utf-8') as f:
        content = f.read()
    try:
        fixed = content.encode('cp1252').decode('utf-8')
        with open(file_path, 'w', encoding='utf-8') as f:
            f.write(fixed)
        print("Success for", file_path)
    except Exception as e:
        print("Failed for", file_path, ":", e)

check_file(r'C:\Users\hp\.gemini\antigravity\scratch\jemypedia-android\lib\features\courses\ui\course_detail_screen.dart')
check_file(r'C:\Users\hp\.gemini\antigravity\scratch\jemypedia-android\lib\features\subscriptions\screens\checkout_screen.dart')
