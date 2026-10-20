import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/utils/image_utils.dart';
import 'dart:convert';
import '../../../auth/providers/auth_provider.dart';
import '../../../../core/theme/theme_provider.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/utils/phone_countries.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  bool _isUploadingAvatar = false;

  Future<void> _pickAndUploadImage(BuildContext context) async {
    // Ortak yardımcı: sıkıştırır + ~1,5 MB sınırını denetler (ImageUtils).
    late final String? base64Image;
    try {
      base64Image = await ImageUtils.pickAsBase64(maxWidth: 600, imageQuality: 50);
    } on ImageTooLargeException catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message), backgroundColor: Colors.orange));
      return;
    }
    if (base64Image == null) return; // kullanıcı vazgeçti

    setState(() => _isUploadingAvatar = true);
    try {
      final dio = await ApiClient.client;
      await dio.put('/user/profile', data: {'profileImage': base64Image});
      ref.read(authProvider.notifier).fetchProfile();
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('profile_image_updated'.tr() ?? 'Profil resmi güncellendi!'), backgroundColor: Colors.green));
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('profile_image_failed'.tr() ?? 'Resim yüklenemedi. İnternetinizi kontrol edin.'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isUploadingAvatar = false);
    }
  }

  void _showEditNicknameDialog(BuildContext context, String currentNickname) {
    final nicknameCtrl = TextEditingController(text: currentNickname);
    bool isProcessing = false;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setModalState) {
        return AlertDialog(
          title: Text('edit_nickname_title'.tr() ?? 'Takma Adı Değiştir'),
          content: TextField(
            controller: nicknameCtrl,
            decoration: InputDecoration(labelText: 'new_nickname_label'.tr() ?? 'Yeni Takma Ad'),
          ),
          actions: [
            TextButton(onPressed: isProcessing ? null : () => Navigator.pop(ctx), child: Text('cancel_btn'.tr() ?? 'İptal')),
            ElevatedButton(
              onPressed: isProcessing ? null : () async {
                setModalState(() => isProcessing = true);
                try {
                  final dio = await ApiClient.client;
                  await dio.put('/user/profile', data: {'nickname': nicknameCtrl.text.trim()});
                  await ref.read(authProvider.notifier).fetchProfile();
                  if (!ctx.mounted) return;
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('nickname_updated'.tr() ?? 'Takma ad güncellendi!'), backgroundColor: Colors.green));
                } catch (e) {
                  setModalState(() => isProcessing = false);
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('nickname_taken'.tr() ?? 'Bu takma ad kullanımda olabilir.'), backgroundColor: Colors.red));
                }
              },
              child: isProcessing
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : Text('save_btn'.tr() ?? 'Kaydet'),
            )
          ],
        );
      }),
    );
  }

  void _showEditEmailDialog(BuildContext context, String currentEmail) {
    final emailCtrl = TextEditingController(text: currentEmail);
    bool isProcessing = false;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setModalState) {
        return AlertDialog(
          title: Text('edit_email_title'.tr() ?? 'E-Posta (Email) Değiştir'),
          content: TextField(
            controller: emailCtrl,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(labelText: 'E-mail'),
          ),
          actions: [
            TextButton(onPressed: isProcessing ? null : () => Navigator.pop(ctx), child: Text('cancel_btn'.tr() ?? 'İptal')),
            ElevatedButton(
              onPressed: isProcessing ? null : () async {
                setModalState(() => isProcessing = true);
                try {
                  final dio = await ApiClient.client;
                  await dio.put('/user/profile', data: {'email': emailCtrl.text.trim()});
                  await ref.read(authProvider.notifier).fetchProfile();
                  if (!ctx.mounted) return;
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('email_updated'.tr() ?? 'Email güncellendi!'), backgroundColor: Colors.green));
                } catch (e) {
                  setModalState(() => isProcessing = false);
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('email_taken'.tr() ?? 'Bu email kullanımda veya hatalı.'), backgroundColor: Colors.red));
                }
              },
              child: isProcessing
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : Text('save_btn'.tr() ?? 'Kaydet'),
            )
          ],
        );
      }),
    );
  }

  void _showEditPhoneDialog(BuildContext context, String currentPhone) {
    final phoneCtrl = TextEditingController(text: currentPhone.startsWith('+MAIL') || currentPhone.startsWith('+TG') || currentPhone.startsWith('+GL') ? '' : currentPhone);
    bool isProcessing = false;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setModalState) {
        return AlertDialog(
          title: Text('edit_phone'.tr() ?? 'Telefon Numarası Değiştir'),
          content: TextField(
            controller: phoneCtrl,
            keyboardType: TextInputType.phone,
            onChanged: (_) => setModalState(() {}),
            decoration: InputDecoration(
              labelText: 'phone_hint'.tr() ?? 'Ülke koduyla (+90...)',
              prefixIcon: Padding(
                padding: const EdgeInsets.only(left: 4),
                child: Center(
                  widthFactor: 1,
                  child: Text(
                    detectFlagEmoji(phoneCtrl.text),
                    style: const TextStyle(fontSize: 26),
                  ),
                ),
              ),
              prefixIconConstraints: const BoxConstraints(minWidth: 44),
            ),
          ),
          actions: [
            TextButton(onPressed: isProcessing ? null : () => Navigator.pop(ctx), child: Text('cancel_btn'.tr() ?? 'İptal')),
            ElevatedButton(
              onPressed: isProcessing ? null : () async {
                final phone = phoneCtrl.text.trim().replaceAll(RegExp(r'[\s\-().]'), '');
                if (!isValidInternationalPhone(phone)) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('invalid_phone'.tr() ?? 'Geçersiz numara'), backgroundColor: Colors.red));
                  return;
                }
                setModalState(() => isProcessing = true);
                try {
                  final dio = await ApiClient.client;
                  await dio.put('/user/profile', data: {'phoneNumber': phone});
                  await ref.read(authProvider.notifier).fetchProfile();
                  if (!ctx.mounted) return;
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('phone_saved'.tr() ?? 'Telefon numarası güncellendi!'), backgroundColor: Colors.green));
                } catch (e) {
                  setModalState(() => isProcessing = false);
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('phone_taken'.tr() ?? 'Bu telefon numarası başkasına ait olabilir.'), backgroundColor: Colors.red));
                }
              },
              child: isProcessing
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : Text('save_btn'.tr() ?? 'Kaydet'),
            )
          ],
        );
      }),
    );
  }

  void _showSecureAccountDialog(BuildContext context) {
    final phoneCtrl = TextEditingController();
    final passCtrl = TextEditingController();
    bool isProcessing = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(builder: (context, setModalState) {
        return AlertDialog(
          title: Text('secure_account_title'.tr() ?? 'Hesabınızı Güvenceye Alın', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: phoneCtrl,
                keyboardType: TextInputType.phone,
                onChanged: (_) => setModalState(() {}),
                decoration: InputDecoration(
                  labelText: 'phone_hint'.tr() ?? 'Ülke koduyla (+90...)',
                  prefixIcon: Padding(
                    padding: const EdgeInsets.only(left: 4),
                    child: Center(
                      widthFactor: 1,
                      child: Text(
                        detectFlagEmoji(phoneCtrl.text),
                        style: const TextStyle(fontSize: 26),
                      ),
                    ),
                  ),
                  prefixIconConstraints: const BoxConstraints(minWidth: 44),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: passCtrl,
                obscureText: true,
                decoration: InputDecoration(labelText: 'new_password'.tr() ?? 'Yeni Şifre', prefixIcon: const Icon(Icons.lock)),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: isProcessing ? null : () => Navigator.pop(ctx), child: Text('cancel_btn'.tr() ?? 'İptal', style: const TextStyle(color: Colors.grey))),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
              onPressed: isProcessing ? null : () async {
                final phone = phoneCtrl.text.trim().replaceAll(RegExp(r'[\s\-().]'), '');
                final pass = passCtrl.text.trim();

                if (phone.isEmpty || pass.length < 8) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('pass_min_8'.tr() ?? 'Şifre en az 8 karakter olmalıdır.'), backgroundColor: Colors.red));
                  return;
                }

                if (!isValidInternationalPhone(phone)) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('invalid_phone'.tr() ?? 'Geçersiz numara'), backgroundColor: Colors.red));
                  return;
                }

                setModalState(() => isProcessing = true);
                try {
                  final dio = await ApiClient.client;
                  await dio.post('/user/secure', data: {'phoneNumber': phone, 'password': pass});
                  await ref.read(authProvider.notifier).fetchProfile();
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('account_secured'.tr() ?? 'Hesabınız başarıyla güvenceye alındı!'), backgroundColor: Colors.green));
                } catch (e) {
                  setModalState(() => isProcessing = false);
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('phone_taken'.tr() ?? 'Bu telefon numarası başkasına ait olabilir.'), backgroundColor: Colors.red));
                }
              },
              child: isProcessing ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : Text('confirm'.tr() ?? 'Onayla', style: const TextStyle(color: Colors.white)),
            )
          ],
        );
      })
    );
  }

  Widget _buildInfoRow(BuildContext context, IconData icon, String title, String value, {VoidCallback? onEdit}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 16.0),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: Theme.of(context).primaryColor.withOpacity(0.1), shape: BoxShape.circle),
            child: Icon(icon, color: Theme.of(context).primaryColor, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(color: Colors.grey.shade500, fontSize: 12, fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              ],
            ),
          ),
          if (onEdit != null)
            IconButton(
              icon: Icon(Icons.edit_outlined, color: Theme.of(context).primaryColor, size: 20),
              onPressed: onEdit,
            )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final user = authState.user;
    final themeMode = ref.watch(themeProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (user == null) {
      // Sonsuz dönen çember yerine: tekrar dene + çıkış seçenekleri
      return Scaffold(
        appBar: AppBar(
          title: Text('profile'.tr(), style: const TextStyle(fontWeight: FontWeight.bold)),
          elevation: 0,
          backgroundColor: Colors.transparent,
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(width: 48, height: 48, child: CircularProgressIndicator(strokeWidth: 3)),
                const SizedBox(height: 16),
                Text('profile_load_failed'.tr() ?? 'Profil bilgileri yüklenemedi.', textAlign: TextAlign.center),
                const SizedBox(height: 20),
                Wrap(
                  spacing: 12,
                  children: [
                    ElevatedButton.icon(
                      onPressed: () => ref.read(authProvider.notifier).fetchProfile(),
                      icon: const Icon(Icons.refresh),
                      label: Text('retry_btn'.tr() ?? 'Tekrar Dene'),
                    ),
                    OutlinedButton.icon(
                      onPressed: () {
                        ref.read(authProvider.notifier).logout();
                        context.go('/login');
                      },
                      icon: const Icon(Icons.logout),
                      label: Text('logout'.tr() ?? 'Çıkış Yap'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('profile'.tr(), style: const TextStyle(fontWeight: FontWeight.bold)),
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
        child: Column(
          children: [
            // Profile Image Section
            Center(
              child: Stack(
                alignment: Alignment.bottomRight,
                children: [
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [Theme.of(context).primaryColor, Colors.blueAccent],
                        begin: Alignment.topLeft, end: Alignment.bottomRight
                      ),
                    ),
                    child: CircleAvatar(
                      radius: 56,
                      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
                      child: CircleAvatar(
                        radius: 52,
                        backgroundColor: Theme.of(context).colorScheme.secondary.withOpacity(0.1),
                        backgroundImage: user['profileImage'] != null ? MemoryImage(base64Decode(user['profileImage'].split(',').last)) : null,
                        child: user['profileImage'] == null ? Icon(Icons.person, size: 50, color: Theme.of(context).primaryColor) : null,
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: _isUploadingAvatar ? null : () => _pickAndUploadImage(context),
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Theme.of(context).primaryColor,
                        shape: BoxShape.circle,
                        border: Border.all(color: Theme.of(context).scaffoldBackgroundColor, width: 3),
                        boxShadow: [BoxShadow(color: Theme.of(context).primaryColor.withOpacity(0.4), blurRadius: 8, offset: const Offset(0, 4))]
                      ),
                      child: _isUploadingAvatar
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.camera_alt, color: Colors.white, size: 18),
                    ),
                  )
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text(user['nickname'] ?? user['firstName'], style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, letterSpacing: -0.5)),
            Text('${user['firstName']} ${user['lastName'] ?? ''}', style: TextStyle(color: Colors.grey.shade500, fontSize: 14, fontWeight: FontWeight.w500)),
            const SizedBox(height: 32),
            
            // YENİ: TELEGRAM HESABINI GERÇEK HESABA ÇEVİRME KUTUSU
            if (user['phoneNumber'] != null && user['phoneNumber'].toString().startsWith('+TG'))
              Container(
                margin: const EdgeInsets.only(bottom: 24),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.redAccent.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: Colors.redAccent.withOpacity(0.3), width: 2)
                ),
                child: Column(
                  children: [
                    const Icon(Icons.security, color: Colors.redAccent, size: 48),
                    const SizedBox(height: 12),
                    Text('secure_account_title'.tr() ?? 'Hesabınızı Güvenceye Alın', style: const TextStyle(color: Colors.redAccent, fontSize: 18, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 8),
                    Text('secure_account_desc'.tr() ?? 'Uygulamadan (APK) da giriş yapabilmek için gerçek telefon numaranızı ve şifrenizi belirleyin.', textAlign: TextAlign.center, style: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color, fontSize: 13, fontWeight: FontWeight.w500)),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                        onPressed: () => _showSecureAccountDialog(context),
                        child: Text('set_credentials'.tr() ?? 'Bilgileri Belirle', style: const TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    )
                  ],
                ),
              ),
            
            // Bilgiler Kartı
            Container(
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [BoxShadow(color: Theme.of(context).shadowColor.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))]
              ),
              child: Column(
                children: [
                  _buildInfoRow(context, Icons.alternate_email, 'nickname'.tr() ?? 'Kullanıcı Adı', user['nickname'] ?? 'no_nickname'.tr(), 
                    onEdit: () => _showEditNicknameDialog(context, user['nickname'] ?? '')
                  ),
                  Divider(height: 1, color: Colors.grey.withOpacity(0.2), indent: 64),
                  _buildInfoRow(context, Icons.phone_android, 'phone_number'.tr() ?? 'Telefon Numarası', phoneWithFlag(user['phoneNumber'] ?? ''),
                    onEdit: () => _showEditPhoneDialog(context, user['phoneNumber'] ?? '')
                  ),
                  Divider(height: 1, color: Colors.grey.withOpacity(0.2), indent: 64),
                  _buildInfoRow(context, Icons.mail_outline, 'add_email'.tr() ?? 'E-mail goşmak...', user['email'] ?? 'add_email'.tr() ?? 'E-mail goşmak...', 
                    onEdit: () => _showEditEmailDialog(context, user['email'] ?? '')
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Ayarlar Kartı (Dil ve Tema)
            Container(
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [BoxShadow(color: Theme.of(context).shadowColor.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))]
              ),
              child: Column(
                children: [
                  ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: Colors.orange.withOpacity(0.1), shape: BoxShape.circle),
                      child: const Icon(Icons.language, color: Colors.orange, size: 20),
                    ),
                    title: Text('language'.tr() ?? 'Dil', style: const TextStyle(fontWeight: FontWeight.w600)),
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(color: Colors.grey.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                      child: DropdownButton<String>(
                        value: context.locale.languageCode,
                        icon: const Icon(Icons.keyboard_arrow_down, size: 16),
                        underline: const SizedBox(),
                        style: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color, fontWeight: FontWeight.bold, fontSize: 13),
                        items: const [
                          DropdownMenuItem(value: 'tr', child: Text('TR')),
                          DropdownMenuItem(value: 'en', child: Text('EN')),
                          DropdownMenuItem(value: 'ru', child: Text('RU')),
                          DropdownMenuItem(value: 'tk', child: Text('TK')),
                        ],
                        onChanged: (val) {
                          if (val != null) context.setLocale(Locale(val));
                        },
                      ),
                    ),
                  ),
                  Divider(height: 1, color: Colors.grey.withOpacity(0.2), indent: 64),
                  SwitchListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                    secondary: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: Colors.purple.withOpacity(0.1), shape: BoxShape.circle),
                      child: Icon(themeMode == ThemeMode.dark ? Icons.dark_mode : Icons.light_mode, color: Colors.purple, size: 20),
                    ),
                    title: Text('dark_mode'.tr() ?? 'Karanlık Mod', style: const TextStyle(fontWeight: FontWeight.w600)),
                    activeColor: Theme.of(context).primaryColor,
                    value: themeMode == ThemeMode.dark,
                    onChanged: (val) {
                      ref.read(themeProvider.notifier).setTheme(val ? ThemeMode.dark : ThemeMode.light);
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            
            if (user['role'] == 'ADMIN') ...[
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size.fromHeight(56),
                  backgroundColor: Colors.black87,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))
                ),
                onPressed: () => context.push('/admin'),
                icon: const Icon(Icons.admin_panel_settings),
                label: Text('admin_panel'.tr() ?? 'Yönetici Paneli', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ),
              const SizedBox(height: 16),
            ] else ...[
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size.fromHeight(56),
                  backgroundColor: Colors.green.withOpacity(0.1),
                  foregroundColor: Colors.green,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))
                ),
                onPressed: () async {
                  try {
                    final dio = await ApiClient.client;
                    final res = await dio.get('/chat/admin');
                    if (res.data != null) {
                      context.push('/chat_detail', extra: {
                        'id': res.data['id'],
                        'name': res.data['nickname'] ?? res.data['firstName'],
                        'isGroup': false,
                        'isCreator': false
                      });
                    }
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('error_occurred'.tr() ?? 'Hata oluştu')));
                  }
                },
                icon: const Icon(Icons.headset_mic),
                label: Text('write_to_admin'.tr() ?? 'Destek', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ),
              const SizedBox(height: 16),
            ],

            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(56),
                foregroundColor: Colors.redAccent,
                side: BorderSide(color: Colors.redAccent.withOpacity(0.5), width: 2),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              onPressed: () {
                ref.read(authProvider.notifier).logout();
                context.go('/login');
              },
              icon: const Icon(Icons.logout),
              label: Text('logout'.tr() ?? 'Çıkış Yap', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}