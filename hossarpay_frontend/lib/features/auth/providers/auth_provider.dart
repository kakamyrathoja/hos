import 'package:google_sign_in/google_sign_in.dart';
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dio/dio.dart';
import '../../../core/network/api_client.dart';

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier();
});

class AuthState {
  final bool isLoading;
  final bool isAuthenticated;
  final dynamic user;
  final String? token;
  final String? error;

  AuthState({
    this.isLoading = false,
    this.isAuthenticated = false,
    this.user,
    this.token,
    this.error,
  });

  AuthState copyWith({
    bool? isLoading,
    bool? isAuthenticated,
    dynamic user,
    String? token,
    String? error,
  }) {
    return AuthState(
      isLoading: isLoading ?? this.isLoading,
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      user: user ?? this.user,
      token: token ?? this.token,
      error: error,
    );
  }
}

class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier() : super(AuthState()) {
    _loadUser();
  }

  Future<void> _loadUser() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    final userStr = prefs.getString('user');

    if (token != null && userStr != null) {
      state = state.copyWith(isAuthenticated: true, token: token, user: jsonDecode(userStr));
      fetchProfile();
    }
  }

  Future<void> telegramLogin(String tgId, String? firstName, String? lastName, String? username) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final dio = await ApiClient.client;
      final response = await dio.post('/auth/telegram', data: {
        'tgId': tgId,
        'firstName': firstName,
        'lastName': lastName,
        'username': username
      });
      final token = response.data['token'];
      final user = response.data['user'];

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('token', token);
      await prefs.setString('user', jsonEncode(user));

      state = state.copyWith(isLoading: false, isAuthenticated: true, user: user, token: token);
    } catch (e) {
      String errMsg = 'Telegram girisi başarsız';
      if (e is DioException && e.response?.data != null) {
        errMsg = e.response!.data['message'] ?? errMsg;
      }
      state = state.copyWith(isLoading: false, error: errMsg);
    }
  }

  Future<void> login(String nickname, String password) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final dio = await ApiClient.client;
      final response = await dio.post('/auth/login', data: {
        'nickname': nickname,
        'password': password,
      });

      final token = response.data['token'];
      final user = response.data['user'];

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('token', token);
      await prefs.setString('user', jsonEncode(user));

      state = state.copyWith(isLoading: false, isAuthenticated: true, user: user, token: token);
    } catch (e) {
      String errMsg = 'Giriş başarısız';
      if (e is DioException && e.response?.data != null) {
        errMsg = e.response!.data['message'] ?? errMsg;
      }
      state = state.copyWith(isLoading: false, error: errMsg);
    }
  }

  Future<void> registerAdvanced(String firstName, String lastName, String nickname, String password, String email, String referralCode, String verificationCode) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final dio = await ApiClient.client;
      
      final response = await dio.post('/auth/register', data: {
        'firstName': firstName,
        'lastName': lastName,
        'nickname': nickname,
        'email': email.isNotEmpty ? email : null,
        'password': password,
        'verificationCode': verificationCode,
        'referralCode': referralCode.isNotEmpty ? referralCode : null
      });

      final token = response.data['token'];
      final user = response.data['user'];

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('token', token);
      await prefs.setString('user', jsonEncode(user));

      state = state.copyWith(isLoading: false, isAuthenticated: true, user: user, token: token);
    } catch (e) {
      String errMsg = 'Kayıt başarısız';
      if (e is DioException && e.response?.data != null) {
        errMsg = e.response!.data['message'] ?? errMsg;
      }
      state = state.copyWith(isLoading: false, error: errMsg);
    }
  }

  
  Future<void> googleLogin() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final GoogleSignIn googleSignIn = GoogleSignIn(clientId: 'BURAYA_GOOGLE_CLIENT_ID_GELECEK.apps.googleusercontent.com');
      final GoogleSignInAccount? googleUser = await googleSignIn.signIn();

      if (googleUser == null) {
        state = state.copyWith(isLoading: false); // Kullanıcı iptal etti
        return;
      }

      final dio = await ApiClient.client;
      final response = await dio.post('/auth/google', data: {
        'email': googleUser.email,
        'firstName': googleUser.displayName?.split(' ').first ?? 'Google',
        'lastName': googleUser.displayName?.split(' ').skip(1).join(' ') ?? '',
        'photoUrl': googleUser.photoUrl,
        'googleId': googleUser.id,
      });

      final token = response.data['token'];
      final user = response.data['user'];

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('token', token);
      await prefs.setString('user', jsonEncode(user));

      state = state.copyWith(isLoading: false, isAuthenticated: true, user: user, token: token);
    } catch (e) {
      String errMsg = 'Google girişi başarısız: ${e.toString()}';
      if (e is DioException && e.response?.data != null) {
        errMsg = e.response!.data['message'] ?? errMsg;
      }
      state = state.copyWith(isLoading: false, error: errMsg);
    }
  }

  Future<void> fetchProfile() async {
    try {
      final dio = await ApiClient.client;
      final response = await dio.get('/user/profile');
      final user = response.data;
      
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user', jsonEncode(user));
      
      state = state.copyWith(user: user);
    } catch (e) {
      // Token expired vs. log out is handled elsewhere if needed
    }
  }

  Future<void> setFCMToken(String token) async {
    if (state.user != null) {
      try {
        final dio = await ApiClient.client;
        await dio.put('/user/profile', data: {'fcmToken': token});
      } catch (e) {}
    }
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('token');
    await prefs.remove('user');
    state = AuthState(); // Reset
  }
}
