import sys
import re

file_path = r'C:\Users\hp\.gemini\antigravity\scratch\jemypedia-android\lib\features\courses\ui\course_detail_screen.dart'
with open(file_path, 'r', encoding='utf-8') as f:
    lines = f.readlines()

# Fix 1: Add _selectedPlan to state
search_state = "class _CourseDetailScreenState extends State<CourseDetailScreen> {\n  String? _currentVideoUrl;\n"
replace_state = "class _CourseDetailScreenState extends State<CourseDetailScreen> {\n  dynamic _selectedPlan;\n  String? _currentVideoUrl;\n"
content = "".join(lines)
if "_selectedPlan" not in content:
    content = content.replace("class _CourseDetailScreenState extends State<CourseDetailScreen> {\n  String? _currentVideoUrl;\n", replace_state)
    
search_init = "  void initState() {\n    super.initState();\n    _quizzes = widget.course.quizzes;\n"
replace_init = "  void initState() {\n    super.initState();\n    if (widget.course.pricingPlans.isNotEmpty) {\n      _selectedPlan = widget.course.pricingPlans[0];\n    } else {\n      _selectedPlan = 'full_access';\n    }\n    _quizzes = widget.course.quizzes;\n"
if "if (widget.course.pricingPlans.isNotEmpty) {" not in content:
    content = content.replace(search_init, replace_init)

lines = content.splitlines(True) # split keeping newlines

new_block = '''                  Consumer<CoursesProvider>(
                    builder: (context, provider, child) {
                      bool isUnlocked = provider.unlockedCourses.contains(widget.course.id) || widget.course.isFree;
                      if (isUnlocked) return const SizedBox.shrink();
                      
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                            Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: const Color(0xFF161616),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.white10),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Center(
                                    child: Text(
                                      locale == 'ar' ? 'اختر خطة الاشتراك المناسبة لك' : 'Choose Subscription Plan',
                                      style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold, fontFamily: 'Cairo'),
                                    ),
                                  ),
                                  const SizedBox(height: 20),
                                  if (widget.course.pricingPlans.isNotEmpty)
                                    ...widget.course.pricingPlans.map((plan) {
                                      final isSelected = _selectedPlan == plan;
                                      final title = plan['title'] is Map ? (plan['title'][locale] ?? plan['title']['en'] ?? 'باقة') : (plan['title']?.toString() ?? 'باقة');
                                      final salePrice = plan['sale_price'] ?? plan['regular_price'];
                                      final regularPrice = plan['regular_price'];
                                      final hasDiscount = plan['sale_price'] != null && plan['sale_price'] != plan['regular_price'];
                                      
                                      int savingsPercent = 0;
                                      if (hasDiscount && regularPrice != null && regularPrice.toString().isNotEmpty) {
                                        try {
                                          final r = double.parse(regularPrice.toString());
                                          final s = double.parse(salePrice.toString());
                                          if (r > 0) savingsPercent = ((r - s) / r * 100).round();
                                        } catch (_) {}
                                      }
                                      
                                      final isPopular = plan['is_popular'] == true || plan['is_popular'] == 'yes' || plan['popular'] == true || title.toString().contains('6');

                                      return GestureDetector(
                                        onTap: () => setState(() => _selectedPlan = plan),
                                        child: Container(
                                          margin: const EdgeInsets.only(bottom: 12),
                                          padding: const EdgeInsets.all(16),
                                          decoration: BoxDecoration(
                                            color: Colors.transparent,
                                            border: Border.all(color: isSelected ? Colors.red : Colors.white12, width: 1.5),
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: Stack(
                                            clipBehavior: Clip.none,
                                            children: [
                                              if (isPopular)
                                                Positioned(
                                                  top: -26,
                                                  right: 16,
                                                  child: Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                    decoration: BoxDecoration(
                                                      color: Colors.amber,
                                                      borderRadius: BorderRadius.circular(4),
                                                    ),
                                                    child: Text(
                                                      locale == 'ar' ? 'الأكثر شعبية' : 'Popular',
                                                      style: const TextStyle(color: Colors.black, fontSize: 10, fontWeight: FontWeight.bold, fontFamily: 'Cairo'),
                                                    ),
                                                  ),
                                                ),
                                              Row(
                                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                children: [
                                                  // Right side (RTL logic) - Prices
                                                  Column(
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    children: [
                                                      Text('\\$${salePrice}', style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 18)),
                                                      if (hasDiscount) ...[
                                                        const SizedBox(height: 2),
                                                        Text('\\$${regularPrice}', style: const TextStyle(color: Colors.white38, decoration: TextDecoration.lineThrough, fontSize: 12)),
                                                        const SizedBox(height: 6),
                                                        Text('✓ وفر ${savingsPercent}%', style: const TextStyle(color: Colors.greenAccent, fontSize: 12, fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
                                                      ],
                                                    ],
                                                  ),
                                                  // Left side (RTL logic) - Title & Radio
                                                  Row(
                                                    children: [
                                                      Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16, fontFamily: 'Cairo')),
                                                      const SizedBox(width: 12),
                                                      Icon(
                                                        isSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                                                        color: isSelected ? Colors.white : Colors.white38,
                                                      ),
                                                    ],
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                      );
                                    }).toList()
                                  else
                                    GestureDetector(
                                      onTap: () => setState(() => _selectedPlan = 'full_access'),
                                      child: Container(
                                        padding: const EdgeInsets.all(16),
                                        decoration: BoxDecoration(
                                          border: Border.all(color: Colors.red, width: 1.5),
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text('\\$${widget.course.price['sale_price'] ?? widget.course.price['regular_price']}', style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 18)),
                                            Row(
                                              children: [
                                                Text(locale == 'ar' ? 'الاشتراك الكامل' : 'Full Access', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16, fontFamily: 'Cairo')),
                                                const SizedBox(width: 12),
                                                const Icon(Icons.radio_button_checked, color: Colors.white),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  
                                  const SizedBox(height: 20),
                                  SizedBox(
                                    width: double.infinity,
                                    child: ElevatedButton(
                                      onPressed: () {
                                        String price = '';
                                        String? wooId;
                                        String? accessPeriod;
                                        String planTitle = '';
                                        
                                        if (_selectedPlan == 'full_access') {
                                          price = (widget.course.price['sale_price'] ?? widget.course.price['regular_price']).toString();
                                          planTitle = locale == 'ar' ? 'الاشتراك الكامل' : 'Full Access';
                                        } else if (_selectedPlan != null) {
                                          price = (_selectedPlan['sale_price'] ?? _selectedPlan['regular_price']).toString();
                                          wooId = _selectedPlan['id']?.toString();
                                          accessPeriod = _selectedPlan['access_period']?[locale];
                                          planTitle = _selectedPlan['title'] is Map ? (_selectedPlan['title'][locale] ?? _selectedPlan['title']['en'] ?? '') : (_selectedPlan['title']?.toString() ?? '');
                                        }

                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(builder: (_) => CheckoutScreen(
                                            courseId: widget.course.id,
                                            courseTitle: "${widget.course.getLocalizedTitle(locale)} - $planTitle",
                                            price: price,
                                            wooId: wooId,
                                            imageUrl: widget.course.coverImageUrl,
                                            accessPeriod: accessPeriod,
                                          )),
                                        );
                                      },
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.red,
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(vertical: 16),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                      ),
                                      child: Text(locale == 'ar' ? 'اشترك الآن' : 'Subscribe Now', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, fontFamily: 'Cairo')),
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  Center(
                                    child: Text(
                                      locale == 'ar' ? 'الدفع آمن 100%. يمكنك إلغاء الاشتراك في أي وقت.' : '100% Secure Payment. Cancel anytime.',
                                      style: const TextStyle(color: Colors.white38, fontSize: 10, fontFamily: 'Cairo'),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          const SizedBox(height: 30),
                        ],
                      );
                    },
                  ),
'''

# We need to find where the block begins and ends dynamically to avoid hardcoded line numbers.
start_index = -1
end_index = -1

for i, line in enumerate(lines):
    if "Consumer<CoursesProvider>" in line and "bool isUnlocked = provider.unlockedCourses.contains(widget.course.id)" in lines[i+2]:
        if "if (isUnlocked) return const SizedBox.shrink();" in lines[i+3]:
            start_index = i
            break

if start_index != -1:
    # Find the end of this block
    # It ends with:
    #                     ],
    #                   );
    #                 },
    #               ),
    for i in range(start_index, len(lines)):
        if "const SizedBox(height: 30)," in lines[i] and "]," in lines[i+1] and ");" in lines[i+2]:
            end_index = i + 4
            break

if start_index != -1 and end_index != -1:
    lines = lines[:start_index] + [new_block] + lines[end_index+1:]
else:
    print("Could not find block boundaries:", start_index, end_index)

with open(file_path, 'w', encoding='utf-8') as f:
    f.writelines(lines)

print("course_detail_screen patched!")
