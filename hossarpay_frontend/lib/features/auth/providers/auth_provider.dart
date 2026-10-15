import 'package:google_sign_in/google_sign_in.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/token_storage.dart';

// Google Cloud Console'dan aldığın OAuth 2.0 Web Client ID'yi buraya yapıştır.
// Örn: '1234567890-abc...apps.googleusercontent.com'
const String GOOGLE_CLIENT_ID = '388116351159-9fubrbqle4do3jlsvpqhgfufv0bgrmbi.apps.googleusercontent.com'; // ← BURAYI DOLDUR

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

  Future<void> _persistSession(String token, dynamic user) async {
    await TokenStorage.saveToken(token);
    await TokenStorage.saveUser(jsonEncode(user));
  }

  // FCM push token'ı alır (mobilde). Web'de FCM yok → null döner, sorun değil.
  Future<String?> _getFcmToken() async {
    if (kIsWeb) return null;
    try {
      return await FirebaseMessaging.instance.getToken();
    } catch (_) {
      return null;
    }
  }

  Future<void> _loadUser() async {
    final token = await TokenStorage.readToken();
    final userStr = await TokenStorage.readUserJson();

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

      await _persistSession(token, user);

      state = state.copyWith(isLoading: false, isAuthenticated: true, user: user, token: token);
    } catch (e) {
      String errMsg = 'Telegram girisi başarsız';
      if (e is DioException && e.response?.data != null) {
        errMsg = e.response!.data['message'] ?? errMsg;
      }
      state = state.copyWith(isLoading: false, error: errMsg);
    }
  }

  Future<void> login(String email, String password) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final fcmToken = await _getFcmToken();
      final dio = await ApiClient.client;
      final response = await dio.post('/auth/login', data: {
        'email': email,
        'password': password,
        'fcmToken': fcmToken,
      });

      final token = response.data['token'];
      final user = response.data['user'];

      await _persistSession(token, user);

      state = state.copyWith(isLoading: false, isAuthenticated: true, user: user, token: token);
      await fetchProfile(); // Profil bilgilerini (e-posta dahil) tazele
    } catch (e) {
      String errMsg = 'Giriş başarısız';
      if (e is DioException && e.response?.data != null) {
        errMsg = e.response!.data['message'] ?? errMsg;
      }
      state = state.copyWith(isLoading: false, error: errMsg);
    }
  }

  Future<void> registerAdvanced(String firstName, String lastName, String? nickname, String password, String email, String referralCode, String verificationCode) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final fcmToken = await _getFcmToken();
      final dio = await ApiClient.client;

      final response = await dio.post('/auth/register', data: {
        'firstName': firstName,
        'lastName': lastName,
        'nickname': (nickname != null && nickname.isNotEmpty) ? nickname : null,
        'email': email.isNotEmpty ? email : null,
        'password': password,
        'verificationCode': verificationCode,
        'referralCode': referralCode.isNotEmpty ? referralCode : null,
        'fcmToken': fcmToken
      });

      final token = response.data['token'];
      final user = response.data['user'];

      await _persistSession(token, user);

      state = state.copyWith(isLoading: false, isAuthenticated: true, user: user, token: token);
      await fetchProfile(); // Kayıt sonrası e-posta profil alanını otomatik doldur
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
      if (GOOGLE_CLIENT_ID.isEmpty) {
        state = state.copyWith(isLoading: false, error: 'Google girişi yapılandırılmamış. GOOGLE_CLIENT_ID boş.');
        return;
      }
      final GoogleSignIn googleSignIn = GoogleSignIn(clientId: GOOGLE_CLIENT_ID);
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

      await _persistSession(token, user);

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

      await TokenStorage.saveUser(jsonEncode(user));

      state = state.copyWith(user: user);
    } catch (e) {
      // Token geçersizse sessizce çıkış yap (401): karışık state kalmasın
      if (e is DioException && e.response?.statusCode == 401) {
        await logout();
      }
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
    await TokenStorage.clear();
    state = AuthState(); // Reset
  }
}
