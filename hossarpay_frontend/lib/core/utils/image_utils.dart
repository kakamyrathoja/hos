import 'dart:convert';
import 'package:image_picker/image_picker.dart';

/// Resim üst sınırı aşıldığında fırlatılır — ekranda anlaşılır mesaj gösterilir.
class ImageTooLargeException implements Exception {
  final String message;
  ImageTooLargeException(
      [this.message =
        'Resim çok büyük (en fazla ~1,5 MB). Lütfen daha küçük bir resim seçin.']);
  @override
  String toString() => message;
}

class ImageUtils {
  ImageUtils._();

  static final ImagePicker _picker = ImagePicker();

  /// Sunucuya base64 ile giden resimler için üst sınır (ham bayt).
  /// Base64 veriyi ~%33 şişirir; 1,5 MB dosya ≈ 2 MB istek demektir.
  /// Bu sınır veritabanını ve yavaş bağlantıları korur.
  /// Kalıcı çözüm dosya deposudur (S3 / Supabase Storage + URL saklama).
  static const int maxBytes = 1500 * 1024;

  /// Galeriden/kameradan resim seçer, sıkıştırır, boyutu denetler.
  /// Başarılıysa `data:image/jpeg;base64,...` döner.
  /// Kullanıcı vazgeçerse null döner, resim büyükse [ImageTooLargeException] atar.
  static Future<String?> pickAsBase64({
    ImageSource source = ImageSource.gallery,
    double maxWidth = 800,
    int imageQuality = 40,
  }) async {
    final XFile? file = await _picker.pickImage(
      source: source,
      maxWidth: maxWidth,
      imageQuality: imageQuality,
    );
    if (file == null) return null; // kullanıcı vazgeçti
    final bytes = await file.readAsBytes();
    if (bytes.lengthInBytes > maxBytes) throw ImageTooLargeException();
    return 'data:image/jpeg;base64,${base64Encode(bytes)}';
  }

  /// Ham baytı data-URL'e çevirir, üst sınırı denetler.
  /// Sesli mesaj gibi resim-dışı içerikler için kullanılır.
  static String encodeDataUrl(String mimeType, List<int> bytes) {
    if (bytes.length > maxBytes) throw ImageTooLargeException(
      'Dosya çok büyük (en fazla ~1,5 MB). Daha kısa bir kayıt deneyin.');
    return 'data:$mimeType;base64,${base64Encode(bytes)}';
  }
}