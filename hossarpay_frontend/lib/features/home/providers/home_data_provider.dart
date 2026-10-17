import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import '../../../../core/network/api_client.dart';

class HomeDataNotifier extends StateNotifier<Map<String, dynamic>> {
  HomeDataNotifier() : super({'stories': [], 'conversations': [], 'isLoading': false});

  Future<void> fetchHomeData() async {
    state = {...state, 'isLoading': true};
    try {
      final dio = await ApiClient.client;
      
      // Her zaman hikayeleri çek (Finans uygulamasina sosyal his katar)
      final storiesRes = await dio.get('/stories');
      
      final convsRes = await dio.get('/chat/conversations');
      
      state = {
        'stories': storiesRes.data,
        'conversations': convsRes.data,
        'isLoading': false,
      };
    } catch (e) {
      state = {...state, 'isLoading': false};
    }
  }

  Future<void> createStory(String url) async {
    try {
      final dio = await ApiClient.client;
      await dio.post('/story', data: {'mediaUrl': url});
      await fetchHomeData(); // Başarılıysa listeyi yenile
    } catch (e) {
      if (e is DioException && e.response?.data != null) {
        throw Exception(e.response!.data['message']);
      }
      throw Exception('Hikaye yüklenirken bir hata oluştu.');
    }
  }
}

final homeDataProvider = StateNotifierProvider<HomeDataNotifier, Map<String, dynamic>>((ref) {
  return HomeDataNotifier();
});