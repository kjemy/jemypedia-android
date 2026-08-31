import sys
import re

checkout_path = r'C:\Users\hp\.gemini\antigravity\scratch\jemypedia-android\lib\features\subscriptions\screens\checkout_screen.dart'
course_path = r'C:\Users\hp\.gemini\antigravity\scratch\jemypedia-android\lib\features\courses\ui\course_detail_screen.dart'

def fix_fonts_and_locale(file_path, is_checkout):
    with open(file_path, 'r', encoding='utf-8') as f:
        content = f.read()

    # 1. Remove fontFamily everywhere
    content = re.sub(r",\s*fontFamily:\s*'Cairo'", "", content)
    content = re.sub(r",\s*fontFamily:\s*'Courier'", "", content)
    
    if is_checkout:
        # Check if localeProvider is already used in build
        if "final localeProvider = Provider.of<LocaleProvider>" not in content:
            # We need to add locale provider to build method
            build_start = "Widget build(BuildContext context) {"
            if build_start in content:
                content = content.replace(
                    build_start, 
                    build_start + "\n    final localeProvider = Provider.of<LocaleProvider>(context);\n    final locale = localeProvider.locale.languageCode;"
                )
            else:
                print("Could not find build method in checkout_screen.dart!")
        
        # Now replace hardcoded Arabic strings
        # We'll use regex for the base64-ish corrupted characters if they exist, or normal strings
        # "ملخص الطلب" -> locale == 'ar' ? 'ملخص الطلب' : 'Order Summary'
        content = content.replace("'ØªÙ Ø§ØµÙŠÙ„ Ø§Ù„Ø¯Ù Ø¹", "locale == 'ar' ? 'ØªÙ Ø§ØµÙŠÙ„ Ø§Ù„Ø¯Ù Ø¹' : 'Payment Details'")
        content = content.replace("'ØªÙ Ø§ØµÙŠÙ„ Ø§Ù„Ø¯Ù Ø¹ (", "locale == 'ar' ? 'ØªÙ Ø§ØµÙŠÙ„ Ø§Ù„Ø¯Ù Ø¹ (' : 'Payment Details ('")
        
        # Order Summary
        content = content.replace("'Ù…Ù„Ø®Øµ Ø§Ù„Ø·Ù„Ø¨'", "locale == 'ar' ? 'Ù…Ù„Ø®Øµ Ø§Ù„Ø·Ù„Ø¨' : 'Order Summary'")
        # Subscription Price
        content = content.replace("'Ø³Ø¹Ø± Ø§Ù„Ø§Ø´ØªØ±Ø§Ùƒ'", "locale == 'ar' ? 'Ø³Ø¹Ø± Ø§Ù„Ø§Ø´ØªØ±Ø§Ùƒ' : 'Subscription Price'")
        # Access Period
        content = content.replace("'Ù…Ø¯Ø© Ø§Ù„Ø§Ø´ØªØ±Ø§Ùƒ'", "locale == 'ar' ? 'Ù…Ø¯Ø© Ø§Ù„Ø§Ø´ØªØ±Ø§Ùƒ' : 'Access Period'")
        # Total
        content = content.replace("'Ø§Ù„Ø¥Ø¬Ù…Ø§Ù„ÙŠ'", "locale == 'ar' ? 'Ø§Ù„Ø¥Ø¬Ù…Ø§Ù„ÙŠ' : 'Total'")
        
        # Choose Payment Method
        content = content.replace("'Ø§Ø®ØªØ± Ø·Ø±ÙŠÙ‚Ø© Ø§Ù„Ø¯Ù Ø¹'", "locale == 'ar' ? 'Ø§Ø®ØªØ± Ø·Ø±ÙŠÙ‚Ø© Ø§Ù„Ø¯Ù Ø¹' : 'Choose Payment Method'")
        # No Payment Methods
        content = content.replace("'Ù„Ø§ ØªÙˆØ¬Ø¯ Ø·Ø±Ù‚ Ø¯Ù Ø¹ Ù…ØªØ§Ø­Ø©'", "locale == 'ar' ? 'Ù„Ø§ ØªÙˆØ¬Ø¯ Ø·Ø±Ù‚ Ø¯Ù Ø¹ Ù…ØªØ§Ø­Ø©' : 'No Payment Methods Available'")
        
        # Select Wallet/Bank
        content = content.replace("'Ø§Ø®ØªØ± Ø§Ù„Ù…Ø­Ù Ø¸Ø© Ø£Ùˆ Ø§Ù„Ø¨Ù†Ùƒ:'", "locale == 'ar' ? 'Ø§Ø®ØªØ± Ø§Ù„Ù…Ø­Ù Ø¸Ø© Ø£Ùˆ Ø§Ù„Ø¨Ù†Ùƒ:' : 'Select Wallet/Bank:'")
        # Select Network
        content = content.replace("'Ø§Ø®ØªØ± Ø´Ø¨ÙƒØ© Ø§Ù„ØªØ­ÙˆÙŠÙ„:'", "locale == 'ar' ? 'Ø§Ø®ØªØ± Ø´Ø¨ÙƒØ© Ø§Ù„ØªØ­ÙˆÙŠÙ„:' : 'Select Network:'")
        
        # Receipt image
        content = content.replace("'ØµÙˆØ±Ø© Ø¥ÙŠØµØ§Ù„ Ø§Ù„ØªØ­ÙˆÙŠÙ„ *'", "locale == 'ar' ? 'ØµÙˆØ±Ø© Ø¥ÙŠØµØ§Ù„ Ø§Ù„ØªØ­ÙˆÙŠÙ„ *' : 'Transfer Receipt Image *'")
        # Phone number
        content = content.replace("'Ø±Ù‚Ù… Ø§Ù„Ù…Ø­Ù Ø¸Ø© Ø§Ù„Ù…Ø­ÙˆÙ„ Ù…Ù†Ù‡Ø§ (Ø±Ù‚Ù… Ø§Ù„ØªÙ„ÙŠÙ ÙˆÙ†) *'", "locale == 'ar' ? 'Ø±Ù‚Ù… Ø§Ù„Ù…Ø­Ù Ø¸Ø© Ø§Ù„Ù…Ø­ÙˆÙ„ Ù…Ù†Ù‡Ø§ (Ø±Ù‚Ù… Ø§Ù„ØªÙ„ÙŠÙ ÙˆÙ†) *' : 'Sender Wallet/Phone Number *'")
        # Phone example
        content = content.replace("'Ù…Ø«Ø§Ù„: 01012345678'", "locale == 'ar' ? 'Ù…Ø«Ø§Ù„: 01012345678' : 'Example: 01012345678'")
        
        # Transaction ID
        content = content.replace("'Ø§Ù„Ø±Ù‚Ù… Ø§Ù„Ù…Ø±Ø¬Ø¹ÙŠ Ù„Ù„Ø¹Ù…Ù„ÙŠØ© (Transaction ID) *'", "locale == 'ar' ? 'Ø§Ù„Ø±Ù‚Ù… Ø§Ù„Ù…Ø±Ø¬Ø¹ÙŠ Ù„Ù„Ø¹Ù…Ù„ÙŠØ© (Transaction ID) *' : 'Transaction ID *'")
        content = content.replace("'Ø§Ù„Ø±Ù‚Ù… Ø§Ù„Ù…Ø±Ø¬Ø¹ÙŠ'", "locale == 'ar' ? 'Ø§Ù„Ø±Ù‚Ù… Ø§Ù„Ù…Ø±Ø¬Ø¹ÙŠ' : 'Transaction ID'")
        content = content.replace("'Ø±Ù‚Ù… Ø§Ù„Ø¹Ù…Ù„ÙŠØ© (TX Hash) *'", "locale == 'ar' ? 'Ø±Ù‚Ù… Ø§Ù„Ø¹Ù…Ù„ÙŠØ© (TX Hash) *' : 'Transaction Hash *'")
        content = content.replace("'Ø£Ø¯Ø®Ù„ TX Hash Ø§Ù„Ù…ÙƒÙˆÙ† Ù…Ù† Ø§Ù„Ø­Ø±ÙˆÙ  ÙˆØ§Ù„Ø£Ø±Ù‚Ø§Ù…'", "locale == 'ar' ? 'Ø£Ø¯Ø®Ù„ TX Hash Ø§Ù„Ù…ÙƒÙˆÙ† Ù…Ù† Ø§Ù„Ø­Ø±ÙˆÙ  ÙˆØ§Ù„Ø£Ø±Ù‚Ø§Ù…' : 'Enter Transaction Hash'")
        
        # Time remaining
        content = content.replace("'Ø§Ù„ÙˆÙ‚Øª Ø§Ù„Ù…ØªØ¨Ù‚ÙŠ Ù„Ø¥ØªÙ…Ø§Ù… Ø§Ù„Ø¯Ù Ø¹'", "locale == 'ar' ? 'Ø§Ù„ÙˆÙ‚Øª Ø§Ù„Ù…ØªØ¨Ù‚ÙŠ Ù„Ø¥ØªÙ…Ø§Ù… Ø§Ù„Ø¯Ù Ø¹' : 'Time Remaining'")
        content = content.replace("'ÙŠØ±Ø¬Ù‰ Ø¥Ø±Ø³Ø§Ù„ Ø§Ù„Ø¨ÙŠØ§Ù†Ø§Øª Ù‚Ø¨Ù„ Ø§Ù†ØªÙ‡Ø§Ø¡ Ø§Ù„Ø¹Ø¯Ø§Ø¯'", "locale == 'ar' ? 'ÙŠØ±Ø¬Ù‰ Ø¥Ø±Ø³Ø§Ù„ Ø§Ù„Ø¨ÙŠØ§Ù†Ø§Øª Ù‚Ø¨Ù„ Ø§Ù†ØªÙ‡Ø§Ø¡ Ø§Ù„Ø¹Ø¯Ø§Ø¯' : 'Please submit details before time expires'")
        
        # Confirm Button
        content = content.replace("'ØªØ£ÙƒÙŠØ¯ Ø§Ù„Ø¯Ù Ø¹ ÙˆØ§Ù„Ø§Ø´ØªØ±Ø§Ùƒ'", "locale == 'ar' ? 'ØªØ£ÙƒÙŠØ¯ Ø§Ù„Ø¯Ù Ø¹ ÙˆØ§Ù„Ø§Ø´ØªØ±Ø§Ùƒ' : 'Confirm Payment & Subscribe'")

        # Some things were written as 'Text(locale == 'ar' ? '...'' but we are inside Text(...). 
        # Actually I just replaced the strings so they evaluate correctly as Dart code.
        
        # Check title_ar vs title in Gateway logic
        # If locale == 'en', maybe we shouldn't use title_ar
        # Let's just do that:
        content = content.replace("gw['title_ar'] ?? gw['title'] ?? ''", "(locale == 'ar' ? (gw['title_ar'] ?? gw['title']) : gw['title']) ?? ''")
        content = content.replace("_selectedGateway![\"title_ar\"] ?? _selectedGateway![\"title\"]", "(locale == 'ar' ? (_selectedGateway![\"title_ar\"] ?? _selectedGateway![\"title\"]) : _selectedGateway![\"title\"])")
        
        # Adjust some font sizes in checkout to prevent overflow if any
        # Let's keep them mostly same but slightly smaller
        content = content.replace("fontSize: 18", "fontSize: 16")
        
        # Fix dynamic string in Text
        content = re.sub(r"Text\(locale == 'ar' \? 'ØªÙ Ø§ØµÙŠÙ„ Ø§Ù„Ø¯Ù Ø¹ \(' \: 'Payment Details \(' \(\${(.*?)}(\)\')", r"Text((locale == 'ar' ? 'ØªÙ Ø§ØµÙŠÙ„ Ø§Ù„Ø¯Ù Ø¹ (' : 'Payment Details (') + '\${ \1 })'", content)
        
    else:
        # course_detail_screen modifications
        # We just need to reduce font sizes in the new pricing block.
        # "Choose Subscription Plan"
        content = content.replace("fontSize: 18", "fontSize: 14")
        # "Plan Title"
        content = content.replace("fontSize: 16", "fontSize: 13")
        # Popular tag is already 10
        # Savings is 12, make it 10
        content = content.replace("fontSize: 12", "fontSize: 10")
        
        # Wait, if we replace all 18s and 16s, we might affect other parts of course_detail_screen!
        # Let's be more specific.
        pass

    with open(file_path, 'w', encoding='utf-8') as f:
        f.write(content)

fix_fonts_and_locale(checkout_path, True)
# For course_detail, let's do a more precise replacement instead of regex all numbers.
