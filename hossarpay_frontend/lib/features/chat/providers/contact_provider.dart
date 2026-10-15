import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../../../core/network/api_client.dart';

class ContactNotifier extends StateNotifier<List<dynamic>> {
  ContactNotifier() : super([]);

  bool isSyncing = false;

  Future<void> fetchAndSyncContacts() async {
    if (isSyncing) return;
    
    // 1. İzin iste
    final status = await Permission.contacts.request();
    if (!status.isGranted) return; 

    isSyncing = true;
    try {
      // 2. Telefondaki rehberi oku (Sadece numarası olanları)
      List<Contact> contacts = await FlutterContacts.getContacts(withProperties: true);
      
      List<Map<String, String>> phonesToSync = [];
      for (var c in contacts) {
        if (c.phones.isNotEmpty) {
          String cleanPhone = c.phones.first.number.replaceAll(RegExp(r'\D'), '');
          if (cleanPhone.isNotEmpty) {
            // HATA DÜZELTİLDİ: Dart dilinde listeye eleman eklerken push değil, add kullanılır.
            phonesToSync.add({'name': c.displayName, 'phone': cleanPhone});
          }
        }
      }

      // 3. Backend'e gönderip Hossarpay kullananları eşleştir (Sync)
      final dio = await ApiClient.client;
      await dio.post('/user/contacts/sync', data: {'phones': phonesToSync});

      // 4. Eşleşen kişileri geri al (Listede göstermek için)
      await fetchSavedContacts();
    } catch (e) {
      print('Rehber senkronizasyon hatası: $e');
    } finally {
      isSyncing = false;
    }
  }

  // Sadece veritabanındaki kayıtlı (eşleşmiş) kişileri çeker
  Future<void> fetchSavedContacts() async {
    try {
      final dio = await ApiClient.client;
      final res = await dio.get('/user/contacts');
      state = res.data;
    } catch (e) {}
  }
}

final contactProvider = StateNotifierProvider<ContactNotifier, List<dynamic>>((ref) {
  return ContactNotifier();
});