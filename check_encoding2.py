import sys

def check_file(path):
    with open(path, 'r', encoding='utf-8') as f:
        content = f.read()
    
    bad_count = content.count('\u00d8') + content.count('\u00d9')
    good_count = content.count('\u0645') 
    
    print(f"{path}: Bad={bad_count}, Good={good_count}")

check_file(r'C:\Users\hp\.gemini\antigravity\scratch\jemypedia-android\lib\features\courses\ui\course_detail_screen.dart')
check_file(r'C:\Users\hp\.gemini\antigravity\scratch\jemypedia-android\lib\features\subscriptions\screens\checkout_screen.dart')
