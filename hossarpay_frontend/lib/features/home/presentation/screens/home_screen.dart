import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:go_router/go_router.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:convert';
import 'package:firebase_messaging/firebase_messaging.dart'; 
import 'package:flutter/foundation.dart' show kIsWeb;

import '../../../auth/providers/auth_provider.dart';
import '../../providers/home_data_provider.dart';
import '../../providers/balance_provider.dart'; 
import '../../../chat/providers/contact_provider.dart'; 
import '../../../../core/network/api_client.dart';

Widget _buildDynamicAvatar(String name, String? base64Image, {double radius = 24}) {
  if (base64Image != null && base64Image.isNotEmpty) {
    return CircleAvatar(
      radius: radius,
      backgroundImage: MemoryImage(base64Decode(base64Image.split(',').last)),
    );
  }
  
  final firstLetter = name.isNotEmpty ? name[0].toUpperCase() : '?';
  final colorIndex = name.codeUnits.fold(0, (a, b) => a + b) % 6; 
  final List<Color> bgColors = [
    Colors.blueAccent, Colors.orangeAccent, Colors.purpleAccent,
    Colors.teal, Colors.pinkAccent, Colors.indigo
  ];

  return CircleAvatar(
    radius: radius,
    backgroundColor: bgColors[colorIndex],
    child: Text(firstLetter, style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: radius * 0.8)),
  );
}

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  bool _isUploadingStory = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(homeDataProvider.notifier).fetchHomeData();
      ref.read(contactProvider.notifier).fetchAndSyncContacts(); 
      _ensureFCMTokenUpdated(); 
    });
  }

  Future<void> _ensureFCMTokenUpdated() async {
    if (kIsWeb) return; // Web'de FCM token ile ugrasmiyoruz
    try {
      FirebaseMessaging messaging = FirebaseMessaging.instance;
      await messaging.requestPermission();
      String? token = await messaging.getToken();
      if (token != null) {
        ref.read(authProvider.notifier).setFCMToken(token);
        final currentUser = ref.read(authProvider).user;
        if (currentUser != null && currentUser['fcmToken'] != token) {
           final dio = await ApiClient.client;
           await dio.put('/user/profile', data: {'fcmToken': token});
        }
      }
    } catch (e) {}
  }

  Future<void> _addStory() async {
    final picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery, imageQuality: 30, maxWidth: 800);
    
    if (image != null) {
      setState(() => _isUploadingStory = true);
      final bytes = await image.readAsBytes();
      final base64Image = "data:image/jpeg;base64,${base64Encode(bytes)}";
      
      try {
        await ref.read(homeDataProvider.notifier).createStory(base64Image);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('story_shared'.tr() ?? 'Hikayeniz başarıyla paylaşıldı!'), backgroundColor: Colors.green));
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString().replaceAll('Exception:', '')), backgroundColor: Colors.red));
      } finally {
        setState(() => _isUploadingStory = false);
      }
    }
  }

  void _viewStory(dynamic userStoryObj) async {
    final stories = userStoryObj['stories'] as List<dynamic>;
    if (stories.isEmpty) return;
    
    final latestStoryId = stories.last['id'];
    final latestStoryUrl = stories.last['mediaUrl'];
    final isMyStory = userStoryObj['user']['id'] == ref.read(authProvider).user?['id'];
    
    if (!isMyStory) {
      try {
        final dio = await ApiClient.client;
        await dio.post('/story/view', data: {'storyId': latestStoryId});
      } catch (e) {}
    }
    
    showDialog(
      context: context,
      barrierColor: Colors.black, 
      builder: (ctx) => Dialog.fullscreen(
        backgroundColor: Colors.black,
        child: Stack(
          children: [
            Center(
              child: Image.memory(
                base64Decode(latestStoryUrl.split(',').last),
                fit: BoxFit.contain,
              ),
            ),
            Positioned(
              top: 40,
              right: 20,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 32),
                onPressed: () => Navigator.pop(ctx),
              )
            ),
            if (isMyStory) ...[
              Positioned(
                bottom: 40,
                left: 20,
                right: 80,
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(16)
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('story_views_reactions'.tr(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      if (stories.last['views'] != null && (stories.last['views'] as List).isNotEmpty)
                        ...((stories.last['views'] as List).take(3).map((v) => Text('👁️ ${v['user']['nickname'] ?? v['user']['firstName']}', style: const TextStyle(color: Colors.white70, fontSize: 12)))),
                      if (stories.last['reactions'] != null && (stories.last['reactions'] as List).isNotEmpty)
                        ...((stories.last['reactions'] as List).take(3).map((r) => Text('${r['emoji']} ${r['user']['nickname'] ?? r['user']['firstName']}', style: const TextStyle(color: Colors.white70, fontSize: 12)))),
                      if ((stories.last['views']?.isEmpty ?? true) && (stories.last['reactions']?.isEmpty ?? true))
                        Text('no_views_yet'.tr(), style: const TextStyle(color: Colors.white54, fontSize: 12)),
                    ],
                  ),
                )
              ),
              Positioned(
                bottom: 40,
                right: 20,
                child: IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red, size: 32),
                  onPressed: () async {
                    Navigator.pop(ctx);
                    try {
                      final dio = await ApiClient.client;
                      await dio.delete('/story/$latestStoryId');
                      ref.read(homeDataProvider.notifier).fetchHomeData();
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('story_deleted'.tr()), backgroundColor: Colors.red));
                    } catch (e) {}
                  },
                )
              )
            ] else
              Positioned(
                bottom: 40,
                left: 0,
                right: 0,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: ['❤️', '🔥', '😂', '😮', '😢'].map((emoji) {
                    return GestureDetector(
                      onTap: () async {
                        Navigator.pop(ctx);
                        try {
                          final dio = await ApiClient.client;
                          await dio.post('/story/react', data: {'storyId': latestStoryId, 'emoji': emoji});
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('reaction_sent'.tr()), backgroundColor: Colors.green));
                        } catch (e) {}
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12.0),
                        child: Text(emoji, style: const TextStyle(fontSize: 32)),
                      ),
                    );
                  }).toList(),
                ),
              )
          ]
        )
      )
    );
  }

  void _showAllStories(List<dynamic> allStories) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        height: MediaQuery.of(context).size.height * 0.75,
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24))
        ),
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade400, borderRadius: BorderRadius.circular(4))),
            const SizedBox(height: 16),
            Text('discover'.tr() ?? 'Keşfet', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Expanded(
              child: allStories.isEmpty 
                ? Center(child: Text('no_stories'.tr() ?? 'Hikaye yok'))
                : GridView.builder(
                    padding: const EdgeInsets.all(16),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, crossAxisSpacing: 16, mainAxisSpacing: 16, childAspectRatio: 0.8),
                    itemCount: allStories.length,
                    itemBuilder: (context, index) {
                      final storyObj = allStories[index];
                      final userObj = storyObj['user'];
                      return GestureDetector(
                        onTap: () {
                           Navigator.pop(ctx);
                           _viewStory(storyObj);
                        },
                        child: Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(3),
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: LinearGradient(colors: [Colors.purple, Colors.red, Colors.orange], begin: Alignment.topRight, end: Alignment.bottomLeft),
                              ),
                              child: Container(
                                padding: const EdgeInsets.all(2),
                                decoration: BoxDecoration(color: Theme.of(context).scaffoldBackgroundColor, shape: BoxShape.circle),
                                child: _buildDynamicAvatar(userObj['nickname'] ?? userObj['firstName'], userObj['profileImage'], radius: 28),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(userObj['nickname'] ?? userObj['firstName'], maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      );
                    },
                  )
            )
          ],
        )
      )
    );
  }

  String _formatTime(String? utcDateString) {
    if (utcDateString == null) return '';
    try {
      final localDate = DateTime.parse(utcDateString).toLocal(); 
      final now = DateTime.now();
      if (localDate.year == now.year && localDate.month == now.month && localDate.day == now.day) {
        return DateFormat('HH:mm').format(localDate);
      } else {
        return DateFormat('dd/MM HH:mm').format(localDate);
      }
    } catch (e) {
      return "";
    }
  }
  
  Widget _buildActionBtn(BuildContext context, String label, IconData icon, Color bgColor, VoidCallback onTap) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 58, height: 58,
            decoration: BoxDecoration(
              color: bgColor,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: bgColor.withOpacity(isDark ? 0.2 : 0.4), 
                  blurRadius: 16, 
                  offset: const Offset(0, 8)
                )
              ]
            ),
            child: Icon(icon, color: Colors.white, size: 24),
          ),
          const SizedBox(height: 10),
          Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Theme.of(context).textTheme.bodyMedium?.color)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final user = authState.user;
    final homeData = ref.watch(homeDataProvider);
    final hideBalance = ref.watch(balanceVisibilityProvider); 
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (user == null) return const Center(child: CircularProgressIndicator());

    final allStories = homeData['stories'] as List<dynamic>? ?? [];
    final conversations = homeData['conversations'] is List ? (homeData['conversations'] as List) : [];
    
    final activeChatUserIds = conversations.map((c) => c['id']).toSet();
    final topStories = allStories.where((s) {
      final sUserId = s['user']['id'];
      return sUserId == user['id'] || activeChatUserIds.contains(sUserId);
    }).toList();
    
    // Güvenlik: Telefon numarasının son 4 hanesini alma
    String maskedPhone = '****';
    if (user['phoneNumber'] != null && user['phoneNumber'].length >= 4) {
      String p = user['phoneNumber'];
      maskedPhone = p.substring(p.length - 4);
    }

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF5F7FA), // LumenCüzdan tarzı temiz arka plan
      body: RefreshIndicator(
        onRefresh: () async {
          await ref.read(homeDataProvider.notifier).fetchHomeData();
        },
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()), 
          slivers: [
            // YENİ: Başlık ve Profil Fotoğrafı (AppBar Yerine)
            SliverSafeArea(
              bottom: false,
              sliver: SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 10),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Hossarpay', 
                        style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, letterSpacing: -1)
                      ),
                      GestureDetector(
                        onTap: () => context.push('/profile'),
                        child: _buildDynamicAvatar(user['nickname'] ?? user['firstName'], user['profileImage'], radius: 22),
                      )
                    ],
                  ),
                ),
              ),
            ),
            
            // YENİ: Hikayeler (Stories) Tasarımı
            SliverToBoxAdapter(
              child: SizedBox(
                height: 115,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  itemCount: topStories.length + 1,
                  itemBuilder: (context, index) {
                    if (index == 0) {
                      return GestureDetector(
                        onTap: _isUploadingStory ? null : _addStory,
                        child: Padding(
                          padding: const EdgeInsets.only(right: 16.0),
                          child: Column(
                            children: [
                              Container(
                                width: 68, height: 68,
                                padding: const EdgeInsets.all(3),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: isDark ? const Color(0xFF1E293B) : Colors.white,
                                  boxShadow: [BoxShadow(color: Colors.green.withOpacity(0.15), blurRadius: 16, offset: const Offset(0, 6))],
                                ),
                                child: Container(
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle, 
                                    border: Border.all(color: Colors.green.shade400, width: 2)
                                  ),
                                  child: CircleAvatar(
                                    backgroundColor: Colors.green.withOpacity(0.1),
                                    child: _isUploadingStory 
                                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.green)) 
                                      : const Icon(Icons.add, color: Colors.green, size: 28),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text('my_story'.tr() ?? 'Hikayem', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ),
                      );
                    }
                    
                    final userStoryObj = topStories[index - 1];
                    final storyUser = userStoryObj['user'];
                    
                    return GestureDetector(
                      onTap: () => _viewStory(userStoryObj),
                      child: Padding(
                        padding: const EdgeInsets.only(right: 16.0),
                        child: Column(
                          children: [
                            Container(
                              width: 68, height: 68,
                              padding: const EdgeInsets.all(3),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                                boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.1), blurRadius: 12, offset: const Offset(0, 6))],
                              ),
                              child: Container(
                                padding: const EdgeInsets.all(2),
                                decoration: const BoxDecoration(
                                  shape: BoxShape.circle, 
                                  gradient: LinearGradient(colors: [Colors.purple, Colors.red, Colors.orange], begin: Alignment.topRight, end: Alignment.bottomLeft),
                                ),
                                child: Container(
                                  padding: const EdgeInsets.all(2),
                                  decoration: BoxDecoration(color: Theme.of(context).scaffoldBackgroundColor, shape: BoxShape.circle),
                                  child: _buildDynamicAvatar(storyUser['nickname'] ?? storyUser['firstName'], storyUser['profileImage'], radius: 30),
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              (storyUser['nickname'] ?? storyUser['firstName']), 
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                              maxLines: 1, overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),

            // YENİ: Cüzdan Kartı (LumenCüzdan Stili)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E293B) : Colors.white,
                    borderRadius: BorderRadius.circular(32),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(isDark ? 0.2 : 0.04),
                        blurRadius: 24,
                        offset: const Offset(0, 10),
                      )
                    ]
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              '${user['firstName']} ${user['lastName'] ?? ''}', 
                              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                              maxLines: 1, overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          GestureDetector(
                            onTap: () => ref.read(balanceVisibilityProvider.notifier).toggle(),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: isDark ? Colors.black26 : const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(20)
                              ),
                              child: Row(
                                children: [
                                  Text(hideBalance ? ('hidden'.tr() ?? 'Gizlenmiş') : ('visible'.tr() ?? 'Açık'), style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey.shade600)),
                                  const SizedBox(width: 8),
                                  Icon(hideBalance ? Icons.circle : Icons.circle_outlined, size: 12, color: Colors.grey.shade500)
                                ],
                              ),
                            ),
                          )
                        ],
                      ),
                      const SizedBox(height: 20),
                      Text('•••• •••• •••• $maskedPhone', style: TextStyle(fontSize: 18, letterSpacing: 2, color: Colors.grey.shade600, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 28),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('current_balance'.tr() ?? 'Toplam Bakiye', style: TextStyle(fontSize: 13, color: Colors.grey.shade500, fontWeight: FontWeight.w600)),
                              const SizedBox(height: 4),
                              Text(
                                hideBalance ? '****' : '${user["balance"] ?? "0.00"}', 
                                style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w900, letterSpacing: -1)
                              ),
                            ],
                          ),
                          Padding(
                            padding: const EdgeInsets.only(bottom: 6.0),
                            child: Text('TMT', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.grey.shade500)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
            
            // YENİ: Kaydırılabilir İşlem Butonları
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 16.0),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: Row(
                    children: [
                      _buildActionBtn(context, 'transfer'.tr() ?? 'Gönder', Icons.send, const Color(0xFF4F46E5), () => context.push('/transfer')),
                      const SizedBox(width: 24),
                      _buildActionBtn(context, 'services'.tr() ?? 'Hizmetler', Icons.grid_view_rounded, const Color(0xFFEF4444), () => context.push('/services')),
                      const SizedBox(width: 24),
                      _buildActionBtn(context, 'history'.tr() ?? 'Geçmiş', Icons.history, const Color(0xFFF59E0B), () => context.push('/history')),
                      const SizedBox(width: 24),
                      _buildActionBtn(context, 'discover'.tr() ?? 'Keşfet', Icons.explore, const Color(0xFF10B981), () => _showAllStories(allStories)),
                      const SizedBox(width: 24),
                      _buildActionBtn(context, 'new_chat'.tr() ?? 'Sohbet', Icons.chat_bubble, Colors.purple, () => context.push('/new_chat')),
                    ],
                  ),
                ),
              ),
            ),

            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('recent_activities'.tr() ?? 'Son Aktiviteler', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                    Text('all'.tr() ?? 'Tümü', style: TextStyle(fontSize: 14, color: Colors.grey.shade600, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ),

            if (homeData['isLoading'] && conversations.isEmpty)
              const SliverToBoxAdapter(child: Padding(padding: EdgeInsets.all(32), child: Center(child: CircularProgressIndicator())))
            else if (conversations.isEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(32.0),
                  child: Center(
                    child: Column(
                      children: [
                        FaIcon(FontAwesomeIcons.comments, size: 64, color: Colors.grey.shade300),
                        const SizedBox(height: 16),
                        Text('no_chats'.tr(), style: TextStyle(color: Colors.grey.shade500, fontWeight: FontWeight.w500)),
                      ],
                    ),
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final chat = conversations[index];
                      final isGroup = chat['isGroup'] ?? false;
                      final isCreator = chat['isCreator'] ?? false; 
                      final chatName = chat['name'] ?? 'Bilinmeyen';
                      final unreadCount = chat['unreadCount'] ?? 0;
                      
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          color: isDark ? const Color(0xFF1E293B) : Colors.white,
                          boxShadow: [
                            BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))
                          ]
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          leading: Stack(
                            children: [
                              _buildDynamicAvatar(chatName, chat['image'], radius: 26),
                              if (isGroup)
                                Positioned(
                                  bottom: 0, right: 0,
                                  child: Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: BoxDecoration(color: Theme.of(context).colorScheme.secondary, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2)),
                                    child: const Icon(Icons.group, size: 10, color: Colors.white),
                                  ),
                                )
                            ],
                          ),
                          title: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(child: Text(chatName, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: unreadCount > 0 ? FontWeight.w900 : FontWeight.w700, fontSize: 16))),
                              if (chat['lastMessageDate'] != null)
                                Text(_formatTime(chat['lastMessageDate']), style: TextStyle(fontSize: 12, color: unreadCount > 0 ? Theme.of(context).primaryColor : Colors.grey.shade500, fontWeight: FontWeight.w600)),
                            ],
                          ),
                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: 6.0),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    chat['lastMessage'] ?? (isGroup ? 'Grup Sohbeti' : 'Özel Sohbet'), 
                                    maxLines: 1, 
                                    overflow: TextOverflow.ellipsis, 
                                    style: TextStyle(color: unreadCount > 0 ? Theme.of(context).textTheme.bodyMedium?.color : Colors.grey.shade500, fontSize: 13, fontWeight: FontWeight.w500)
                                  ),
                                ),
                                if (unreadCount > 0)
                                  Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      color: Theme.of(context).colorScheme.secondary,
                                      shape: BoxShape.circle
                                    ),
                                    child: Text(
                                      unreadCount.toString(),
                                      style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                                    ),
                                  )
                              ],
                            ),
                          ),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                          onTap: () {
                            context.push('/chat_detail', extra: {
                              'id': chat['id'],
                              'name': chatName,
                              'isGroup': isGroup,
                              'isCreator': isCreator
                            }).then((_) {
                              ref.read(homeDataProvider.notifier).fetchHomeData();
                            });
                          },
                        ),
                      );
                    },
                    childCount: conversations.length,
                  ),
                ),
              ),
              
              // Alt bosluk
              const SliverToBoxAdapter(child: SizedBox(height: 80))
          ],
        ),
      ),
      );
  }
}