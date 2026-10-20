import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:dio/dio.dart';
import '../network/api_client.dart';

/// Şikayet + engelleme için ortak yardımcılar.
/// targetType: 'USER' | 'MESSAGE' | 'STORY' (backend ile aynı)

const List<Map<String, String>> reportReasons = [
  {'key': 'SPAM', 'labelKey': 'report_spam'},
  {'key': 'ABUSE', 'labelKey': 'report_abuse'},
  {'key': 'HARASSMENT', 'labelKey': 'report_harassment'},
  {'key': 'OTHER', 'labelKey': 'report_other'},
];

/// Şikayet nedeni seçtirir ve POST /report gönderir.
Future<void> showReportDialog(
  BuildContext context, {
  required String targetType,
  required String targetId,
}) async {
  final selectedKey = await showModalBottomSheet<String>(
    context: context,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade400,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'report_reason'.tr() ?? 'Şikayet Nedeni',
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          ...reportReasons.map(
            (r) => ListTile(
              leading: Icon(
                r['key'] == 'SPAM'
                    ? Icons.campaign_outlined
                    : r['key'] == 'ABUSE'
                        ? Icons.report_gmailerrorred
                        : r['key'] == 'HARASSMENT'
                            ? Icons.gpp_bad_outlined
                            : Icons.more_horiz,
              ),
              title: Text(r['labelKey']!.tr() ?? r['labelKey']!),
              onTap: () => Navigator.pop(ctx, r['key']),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );

  if (selectedKey == null || !context.mounted) return;

  try {
    final dio = await ApiClient.client;
    await dio.post('/report', data: {
      'targetType': targetType,
      'targetId': targetId,
      'reason': selectedKey,
    });
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('report_sent'.tr() ?? 'Şikayetiniz alındı. Teşekkürler!'),
        backgroundColor: Colors.green,
      ),
    );
  } catch (e) {
    if (!context.mounted) return;
    String msg = 'report_failed'.tr() ?? 'Şikayet gönderilemedi.';
    if (e is DioException && e.response?.data != null) {
      msg = e.response!.data['message'] ?? msg;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.red),
    );
  }
}

/// Kullanıcıyı engeller (POST /block).
Future<void> blockUser(BuildContext context, String userId) async {
  try {
    final dio = await ApiClient.client;
    await dio.post('/block', data: {'blockedUserId': userId});
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('user_blocked'.tr() ?? 'Kullanıcı engellendi.'),
        backgroundColor: Colors.red,
      ),
    );
  } catch (e) {
    if (!context.mounted) return;
    String msg = 'block_failed'.tr() ?? 'Engelleme başarısız.';
    if (e is DioException && e.response?.data != null) {
      msg = e.response!.data['message'] ?? msg;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.red),
    );
  }
}

/// Engeli kaldırır (DELETE /block/:userId).
Future<void> unblockUser(BuildContext context, String userId) async {
  try {
    final dio = await ApiClient.client;
    await dio.delete('/block/$userId');
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('user_unblocked'.tr() ?? 'Engel kaldırıldı.'),
        backgroundColor: Colors.green,
      ),
    );
  } catch (e) {
    if (!context.mounted) return;
    String msg = 'unblock_failed'.tr() ?? 'Engel kaldırılamadı.';
    if (e is DioException && e.response?.data != null) {
      msg = e.response!.data['message'] ?? msg;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.red),
    );
  }
}

/// Engellediğim kullanıcıların id listesini döner (GET /blocks).
Future<Set<String>> fetchBlockedIds() async {
  try {
    final dio = await ApiClient.client;
    final res = await dio.get('/blocks');
    final data = res.data;
    if (data is! List) return {};
    return data.map((b) => b['blockedId'].toString()).toSet();
  } catch (e) {
    return {};
  }
}