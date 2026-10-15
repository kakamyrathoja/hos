import 'package:flutter/material.dart';

class AppTheme {
  // =====================================================
  // MARKA RENKLERİ — BURADAN DEĞİŞTİR!
  // =====================================================
  // Açık temada da kullanılan ana vurgu rengi (mavi 0xFF0066FF)
  static const Color brandPrimary = Color(0xFF7C3AED); // mor (istediğin rengi yaz: 0xFF16A34A yeşil, 0xFFEF4444 kırmızı...)

  // Karanlık tema: vurgu rengi (arka planla uyumlu, daha parlak bir ton)
  static const Color brandPrimaryDark = Color(0xFF8B5CF6); // mor vurgu

  // Karanlık tema: gerçek siyah arka plan
  static const Color darkBackground = Color(0xFF000000); // düz siyah

  // Karanlık tema: kart / yüzey rengi (hafif gri ton, siyahla uyumlu)
  static const Color darkSurface = Color(0xFF17181C);

  // Karanlık tema: buton scroll/activation renkleri
  static const Color darkAccent = Color(0xFF22C55E); // yeşil vurgu (başarı/para)
  // =====================================================

  static ThemeData get lightTheme {
    return ThemeData(
      brightness: Brightness.light,
      primaryColor: brandPrimary,
      scaffoldBackgroundColor: const Color(0xFFF4F6F9), // Göz yormayan buz/gri arka plan
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.black87,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: Colors.black87),
      ),
      // HATA DÜZELTİLDİ: Flutter'ın bu sürümünde CardThemeData kullanılması gerekir.
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 8,
        shadowColor: brandPrimary.withOpacity(0.08),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: brandPrimary,
          foregroundColor: Colors.white,
          elevation: 6,
          shadowColor: brandPrimary.withOpacity(0.4),
          padding: const EdgeInsets.symmetric(vertical: 18),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.grey.shade300, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: brandPrimary, width: 2),
        ),
        labelStyle: const TextStyle(color: Colors.black54),
      ),
      colorScheme: const ColorScheme.light(
        primary: brandPrimary,
        secondary: Color(0xFF00C853),
        surface: Colors.white,
      ),
      useMaterial3: true,
    );
  }

  static ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      primaryColor: brandPrimaryDark,
      scaffoldBackgroundColor: darkBackground, // gerçek siyah
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: Colors.white),
      ),
      cardTheme: CardThemeData(
        color: darkSurface,
        elevation: 8,
        shadowColor: Colors.black.withOpacity(0.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: brandPrimaryDark,
          foregroundColor: Colors.white,
          elevation: 6,
          shadowColor: brandPrimaryDark.withOpacity(0.4),
          padding: const EdgeInsets.symmetric(vertical: 18),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: darkSurface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.grey.shade800, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: brandPrimaryDark, width: 2),
        ),
        labelStyle: const TextStyle(color: Colors.white54),
      ),
      colorScheme: const ColorScheme.dark(
        primary: brandPrimaryDark,
        secondary: darkAccent,
        surface: darkSurface,
      ),
      useMaterial3: true,
    );
  }
}