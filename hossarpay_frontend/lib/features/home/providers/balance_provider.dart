import 'package:flutter_riverpod/flutter_riverpod.dart';

// Bakiye görünürlüğü artık SharedPreferences'ta tutulmuyor.
// Uygulama her açıldığında varsayılan olarak GİZLİ (true) başlar.
class BalanceVisibilityNotifier extends StateNotifier<bool> {
  // Varsayılan state = true (yani bakiye gizli başlar)
  BalanceVisibilityNotifier() : super(true);

  void toggle() {
    state = !state;
  }
}

final balanceVisibilityProvider = StateNotifierProvider<BalanceVisibilityNotifier, bool>((ref) {
  return BalanceVisibilityNotifier();
});