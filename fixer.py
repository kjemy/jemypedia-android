import sys

with open(r'C:\Users\hp\.gemini\antigravity\scratch\jemypedia-android\lib\features\courses\ui\course_detail_screen.dart', 'r', encoding='utf-8') as f:
    content = f.read()

# Fix 1: Add _selectedPlan to state
search_state = '''class _CourseDetailScreenState extends State<CourseDetailScreen> {
  String? _currentVideoUrl;'''

replace_state = '''class _CourseDetailScreenState extends State<CourseDetailScreen> {
  dynamic _selectedPlan;
  String? _currentVideoUrl;'''

if search_state in content:
    content = content.replace(search_state, replace_state)

search_init = '''  void initState() {
    super.initState();
    _quizzes = widget.course.quizzes;'''

replace_init = '''  void initState() {
    super.initState();
    if (widget.course.pricingPlans.isNotEmpty) {
      _selectedPlan = widget.course.pricingPlans[0];
    } else {
      _selectedPlan = 'full_access';
    }
    _quizzes = widget.course.quizzes;'''

if search_init in content:
    content = content.replace(search_init, replace_init)

# Fix CheckoutScreen at the top
search_nav_1 = '''                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => CheckoutScreen(
                      courseId: widget.course.id,
                      courseTitle: widget.course.getLocalizedTitle(locale),
                      price: price,
                      wooId: wooId,
                    )),
                  );'''

replace_nav_1 = '''                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => CheckoutScreen(
                      courseId: widget.course.id,
                      courseTitle: widget.course.getLocalizedTitle(locale),
                      price: price,
                      wooId: wooId,
                      imageUrl: widget.course.coverImageUrl,
                      accessPeriod: widget.course.pricingPlans.isNotEmpty ? (widget.course.pricingPlans[0]['access_period']?[locale] ?? '') : '',
                    )),
                  );'''

if search_nav_1 in content:
    content = content.replace(search_nav_1, replace_nav_1)

# Find the pricing block
search_block_start = "Text(locale == 'ar' ? 'باقات الاشتراك' : 'Subscription Packages',"
search_block_end = "child: Text(locale == 'ar' ? 'اشترك' : 'Subscribe'),\n                                      ),\n                                    ],\n                                  ),\n                                ),\n                              ),"

idx1 = content.find(search_block_start)
idx2 = content.find(search_block_end, idx1)
if idx1 != -1 and idx2 != -1:
    idx2 += len(search_block_end)
    
    new_block = '''Container(
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
                                        
                                        if (_selectedPlan == 'full_access') {
                                          price = (widget.course.price['sale_price'] ?? widget.course.price['regular_price']).toString();
                                        } else if (_selectedPlan != null) {
                                          price = (_selectedPlan['sale_price'] ?? _selectedPlan['regular_price']).toString();
                                          wooId = _selectedPlan['id']?.toString();
                                          accessPeriod = _selectedPlan['access_period']?[locale];
                                        }

                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(builder: (_) => CheckoutScreen(
                                            courseId: widget.course.id,
                                            courseTitle: widget.course.getLocalizedTitle(locale),
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
                            ),'''
    content = content[:idx1] + new_block + content[idx2:]
    
with open(r'C:\Users\hp\.gemini\antigravity\scratch\jemypedia-android\lib\features\courses\ui\course_detail_screen.dart', 'w', encoding='utf-8') as f:
    f.write(content)

print("Fixes applied successfully via python!")
