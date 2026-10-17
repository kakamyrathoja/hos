import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/api_client.dart';

class HistoryNotifier extends StateNotifier<Map<String, dynamic>> {
  HistoryNotifier() : super({'transfers': [], 'purchases': [], 'isLoading': false});

  Future<void> fetchHistory() async {
    state = {...state, 'isLoading': true};
    try {
      final dio = await ApiClient.client;
      final transfersRes = await dio.get('/history/transfers');
      final purchasesRes = await dio.get('/history/purchases');
      
      state = {
        'transfers': transfersRes.data,
        'purchases': purchasesRes.data,
        'isLoading': false,
      };
    } catch (e) {
      state = {...state, 'isLoading': false};
    }
  }
}

final historyProvider = StateNotifierProvider<HistoryNotifier, Map<String, dynamic>>((ref) {
  return HistoryNotifier();
});
