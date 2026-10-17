import 'package:flutter/material.dart';

class AppTheme {
  // YENİ: Modern FinTech "Güven Mavisi" 
  static const Color brandBlue = Color(0xFF0066FF);

  static ThemeData get lightTheme {
    return ThemeData(
      brightness: Brightness.light,
      primaryColor: brandBlue,
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
        shadowColor: brandBlue.withOpacity(0.08), 
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)), 
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: brandBlue, 
          foregroundColor: Colors.white,
          elevation: 6,
          shadowColor: brandBlue.withOpacity(0.4), 
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
          borderSide: const BorderSide(color: brandBlue, width: 2), 
        ),
        labelStyle: const TextStyle(color: Colors.black54),
      ),
      colorScheme: const ColorScheme.light(
        primary: brandBlue,
        secondary: Color(0xFF00C853), 
        surface: Colors.white,
      ),
      useMaterial3: true,
    );
  }

  static ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      primaryColor: brandBlue,
      scaffoldBackgroundColor: const Color(0xFF0F172A), 
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: Colors.white),
      ),
      cardTheme: CardThemeData(
        color: const Color(0xFF1E293B), 
        elevation: 8,
        shadowColor: Colors.black.withOpacity(0.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: brandBlue,
          foregroundColor: Colors.white,
          elevation: 6,
          shadowColor: brandBlue.withOpacity(0.4),
          padding: const EdgeInsets.symmetric(vertical: 18),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF1E293B),
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
          borderSide: const BorderSide(color: brandBlue, width: 2),
        ),
        labelStyle: const TextStyle(color: Colors.white54),
      ),
      colorScheme: const ColorScheme.dark(
        primary: brandBlue,
        secondary: Color(0xFF00C853),
        surface: Color(0xFF1E293B),
      ),
      useMaterial3: true,
    );
  }
}