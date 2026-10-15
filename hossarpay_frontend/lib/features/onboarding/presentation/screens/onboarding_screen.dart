import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:lottie/lottie.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<Map<String, dynamic>> _pages = [
    {
      'title': 'Finansal Özgürlük',
      'description': 'Tüm paranızı, transferlerinizi ve hizmet ödemelerinizi tek bir yerden saniyeler içinde yönetin.',
      'icon': Icons.account_balance_wallet,
      'color': Colors.blueAccent
    },
    {
      'title': 'Sınırsız İletişim',
      'description': 'Sadece para göndermekle kalmayın. Sevdiklerinizle mesajlaşın, gruplar kurun ve hikayeler paylaşın.',
      'icon': Icons.chat_bubble_outline,
      'color': Colors.purpleAccent
    },
    {
      'title': 'Üstün Güvenlik',
      'description': 'Uçtan uca şifreleme ve modern güvenlik altyapısı ile verileriniz her zaman güvende.',
      'icon': Icons.security,
      'color': Colors.green
    }
  ];

  void _onNext() async {
    if (_currentPage == _pages.length - 1) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('seen_onboarding', true);
      if (mounted) context.go('/login');
    } else {
      _pageController.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
    }
  }

  void _onSkip() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('seen_onboarding', true);
    if (mounted) context.go('/login');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.topRight,
              child: TextButton(
                onPressed: _onSkip,
                child: const Text('Atla', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: (index) => setState(() => _currentPage = index),
                itemCount: _pages.length,
                itemBuilder: (context, index) {
                  return Padding(
                    padding: const EdgeInsets.all(40.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(40),
                          decoration: BoxDecoration(
                            color: _pages[index]['color'].withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(_pages[index]['icon'], size: 100, color: _pages[index]['color']),
                        ),
                        const SizedBox(height: 48),
                        Text(
                          _pages[index]['title'],
                          style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _pages[index]['description'],
                          style: TextStyle(fontSize: 16, color: Colors.grey.shade600, height: 1.5),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: List.generate(_pages.length, (index) => AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      margin: const EdgeInsets.only(right: 8),
                      height: 8,
                      width: _currentPage == index ? 24 : 8,
                      decoration: BoxDecoration(
                        color: _currentPage == index ? Theme.of(context).primaryColor : Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(4)
                      ),
                    )),
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                      backgroundColor: Theme.of(context).primaryColor,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30))
                    ),
                    onPressed: _onNext,
                    child: Text(
                      _currentPage == _pages.length - 1 ? 'Başla' : 'İleri',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)
                    ),
                  )
                ],
              ),
            )
          ],
        ),
      ),
    );
  }
}