import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class MainLayout extends StatelessWidget {
  final Widget child;
  const MainLayout({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: child,
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Theme.of(context).colorScheme.secondary,
        unselectedItemColor: Colors.grey,
        currentIndex: _calculateSelectedIndex(context),
        onTap: (int idx) => _onItemTapped(idx, context),
        items: [
          BottomNavigationBarItem(icon: const FaIcon(FontAwesomeIcons.house), label: 'home'.tr()),
          BottomNavigationBarItem(icon: const FaIcon(FontAwesomeIcons.moneyBillTransfer), label: 'transfer'.tr()),
          BottomNavigationBarItem(icon: const FaIcon(FontAwesomeIcons.bolt), label: 'services'.tr()),
          BottomNavigationBarItem(icon: const FaIcon(FontAwesomeIcons.clockRotateLeft), label: 'history'.tr()),
          BottomNavigationBarItem(icon: const FaIcon(FontAwesomeIcons.user), label: 'profile'.tr()),
        ],
      ),
    );
  }

  static int _calculateSelectedIndex(BuildContext context) {
    final String location = GoRouterState.of(context).uri.toString();
    if (location.startsWith('/home')) return 0;
    if (location.startsWith('/transfer')) return 1;
    if (location.startsWith('/services')) return 2;
    if (location.startsWith('/history')) return 3;
    if (location.startsWith('/profile')) return 4;
    return 0;
  }

  void _onItemTapped(int index, BuildContext context) {
    switch (index) {
      case 0: context.go('/home'); break;
      case 1: context.go('/transfer'); break;
      case 2: context.go('/services'); break;
      case 3: context.go('/history'); break;
      case 4: context.go('/profile'); break;
    }
  }
}
