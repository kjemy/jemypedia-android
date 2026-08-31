import sys

def fix_mojibake(text):
    try:
        return text.encode('cp1252').decode('utf-8')
    except Exception as e:
        return f"Error: {e}"

test_str = 'ملخص الطلب'
print('Test 1:', fix_mojibake(test_str))
test_str2 = 'سعر الاشتراك'
print('Test 2:', fix_mojibake(test_str2))

