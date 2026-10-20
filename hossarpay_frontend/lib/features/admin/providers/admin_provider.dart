import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart'; 
import '../../../../core/network/api_client.dart';

class AdminState {
  final bool isLoading;
  final List<dynamic> users;
  final List<dynamic> pendingPurchases;
  final Map<String, dynamic> logs;
  final List<dynamic> reports;
  final String? error;

  AdminState({
    this.isLoading = false,
    this.users = const [],
    this.pendingPurchases = const [],
    this.logs = const {'transactions': [], 'purchases': []},
    this.reports = const [],
    this.error,
  });

  AdminState copyWith({
    bool? isLoading,
    List<dynamic>? users,
    List<dynamic>? pendingPurchases,
    Map<String, dynamic>? logs,
    List<dynamic>? reports,
    String? error,
  }) {
    return AdminState(
      isLoading: isLoading ?? this.isLoading,
      users: users ?? this.users,
      pendingPurchases: pendingPurchases ?? this.pendingPurchases,
      logs: logs ?? this.logs,
      reports: reports ?? this.reports,
      error: error, 
    );
  }
}

class AdminNotifier extends StateNotifier<AdminState> {
  AdminNotifier() : super(AdminState());

  Future<void> fetchAllData() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final dio = await ApiClient.client;
      final results = await Future.wait([
        dio.get('/admin/users'),
        dio.get('/admin/purchases/pending'),
        dio.get('/admin/logs'),
        dio.get('/admin/reports'),
      ]);

      state = state.copyWith(
        isLoading: false,
        users: results[0].data,
        pendingPurchases: results[1].data,
        logs: results[2].data,
        reports: results[3].data,
        error: null,
      );
    } catch (e) {
      String errMsg = 'Veriler alınamadı.';
      if (e is DioException && e.response?.data != null) {
        errMsg = e.response!.data['message'] ?? errMsg;
      }
      state = state.copyWith(isLoading: false, error: errMsg);
    }
  }

  Future<void> searchUsers(String query) async {
    try {
      final dio = await ApiClient.client;
      final usersRes = await dio.get('/admin/users?search=$query');
      state = state.copyWith(users: usersRes.data);
    } catch (e) {}
  }

  // YENİ: LOG EKRANI İÇİN ARAMA FİLTRESİ
  Future<void> searchLogs(String query) async {
    try {
      final dio = await ApiClient.client;
      final logsRes = await dio.get('/admin/logs?search=$query');
      state = state.copyWith(logs: logsRes.data);
    } catch (e) {}
  }

  Future<void> updateUserBalance(String userId, double newBalance) async {
    try {
      final dio = await ApiClient.client;
      await dio.put('/admin/users/balance', data: {
        'userId': userId,
        'newBalance': newBalance,
      });
      await fetchAllData(); 
    } catch (e) {}
  }

  Future<void> resolvePurchase(String purchaseId, String action) async {
    try {
      final dio = await ApiClient.client;
      await dio.put('/admin/purchases/resolve', data: {
        'purchaseId': purchaseId,
        'action': action, 
      });
      await fetchAllData(); 
    } catch (e) {}
  }
  
  // YENİ: Şikayeti işle (REMOVED = kaldır, KEPT = reddet)
  Future<void> resolveReport(String reportId, String action) async {
    try {
      final dio = await ApiClient.client;
      await dio.put('/admin/reports/$reportId', data: {'action': action});
      await fetchAllData();
    } catch (e) {}
  }
}

final adminProvider = StateNotifierProvider<AdminNotifier, AdminState>((ref) {
  return AdminNotifier();
});

