import 'package:shared_preferences/shared_preferences.dart';

/// Tek doğruluk kaynağı: JWT ve kullanıcı cache anahtarları.
/// Gizlilik notu: .env buraya dahil değildir, sadece anahtar İSİMLERİ tutulur.
class TokenStorage {
  static const String tokenKey = 'token';
  static const String userKey = 'user';

  /// Eski sürümden kalma anahtar (bir kez migrate edilir, sonra silinir).
  static const String _legacyTokenKey = 'jwt_token';

  static Future<String?> readToken() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(tokenKey);
    if (token != null && token.isNotEmpty) return token;

    // Eski anahtarla giriş yapmış kullanıcıları kurtar
    final legacy = prefs.getString(_legacyTokenKey);
    if (legacy != null && legacy.isNotEmpty) {
      await prefs.setString(tokenKey, legacy);
      await prefs.remove(_legacyTokenKey);
      return legacy;
    }
    return null;
  }

  static Future<void> saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(tokenKey, token);
    // Eski anahtar kalmasın, çift kaynak olmasın
    await prefs.remove(_legacyTokenKey);
  }

  static Future<void> saveUser(String userJson) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(userKey, userJson);
  }

  static Future<String?> readUserJson() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(userKey);
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(tokenKey);
    await prefs.remove(userKey);
    await prefs.remove(_legacyTokenKey);
  }
}