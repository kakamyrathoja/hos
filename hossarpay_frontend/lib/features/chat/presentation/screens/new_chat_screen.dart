import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:dio/dio.dart';
import '../../../../core/utils/image_utils.dart';
import 'dart:convert';
import '../../../../core/network/api_client.dart';
import '../../../home/providers/home_data_provider.dart';
import '../../providers/contact_provider.dart'; 
import 'package:flutter_riverpod/flutter_riverpod.dart';

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

class NewChatScreen extends ConsumerStatefulWidget {
  const NewChatScreen({super.key});

  @override
  ConsumerState<NewChatScreen> createState() => _NewChatScreenState();
}

class _NewChatScreenState extends ConsumerState<NewChatScreen> {
  final _searchCtrl = TextEditingController();
  dynamic _searchedUser;
  bool _isSearching = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(contactProvider.notifier).fetchSavedContacts());
  }

  void _search() async {
    if (_searchCtrl.text.trim().isEmpty) return;
    setState(() { _isSearching = true; _error = null; _searchedUser = null; });
    try {
      final dio = await ApiClient.client;
            final res = await dio.get('/user/search?query=${Uri.encodeComponent(_searchCtrl.text.trim())}');
      setState(() { _searchedUser = res.data is List ? (res.data.isNotEmpty ? res.data.first : null) : res.data; _isSearching = false; });
    } catch (e) {
      setState(() { _isSearching = false; _error = 'Kullanıcı bulunamadı'; });
    }
  }

  void _openCreateGroupScreen() {
    final nameCtrl = TextEditingController();
    final groupSearchCtrl = TextEditingController();
    
    bool isPrivate = false;
    bool isCreating = false;
    bool isSearchingGroupUser = false;
    
    String? base64GroupImage;
    List<dynamic> groupSearchResults = [];
    List<dynamic> selectedMembers = []; 

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (context, setModalState) {
        
        Future<void> pickGroupImage() async {
          // Ortak yardımcı: sıkıştırır + ~1,5 MB sınırını denetler (ImageUtils).
          late final String? picked;
          try {
            picked = await ImageUtils.pickAsBase64(maxWidth: 600, imageQuality: 40);
          } on ImageTooLargeException catch (e) {
            ScaffoldMessenger.of(context)
                .showSnackBar(SnackBar(content: Text(e.message), backgroundColor: Colors.orange));
            return;
          }
          if (picked == null) return; // kullanıcı vazgeçti
          setModalState(() {
            base64GroupImage = picked;
          });
        }

        Future<void> searchUserForGroup() async {
          if (groupSearchCtrl.text.trim().isEmpty) return;
          setModalState(() { isSearchingGroupUser = true; groupSearchResults = []; });
          try {
            final dio = await ApiClient.client;
                        final res = await dio.get('/user/search?query=${Uri.encodeComponent(groupSearchCtrl.text.trim())}');
            setModalState(() {
              final user = res.data is List ? (res.data.isNotEmpty ? res.data.first : null) : res.data;
              if (user == null) return;
              bool alreadyAdded = selectedMembers.any((m) => m['id'] == user['id']);
              if (!alreadyAdded) groupSearchResults = [user];
              isSearchingGroupUser = false;
            });
          } catch (e) {
            setModalState(() { isSearchingGroupUser = false; });
          }
        }

        return Dialog.fullscreen(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          child: Column(
            children: [
              AppBar(
                backgroundColor: Colors.transparent,
                elevation: 0,
                leading: IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                title: Text('create_new_group'.tr(), style: TextStyle(fontWeight: FontWeight.bold)),
                actions: [
                  TextButton(
                    onPressed: isCreating ? null : () async {
                      if (nameCtrl.text.trim().isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Grup adı zorunludur!'), backgroundColor: Colors.red));
                        return;
                      }
                      setModalState(() => isCreating = true);
                      try {
                        final dio = await ApiClient.client;
                        await dio.post('/chat/group', data: {
                          'name': nameCtrl.text.trim(), 
                          'isPrivate': isPrivate,
                          'groupImage': base64GroupImage, 
                          'memberIds': selectedMembers.map((m) => m['id']).toList() 
                        });
                        ref.read(homeDataProvider.notifier).fetchHomeData();
                        Navigator.pop(ctx);
                        context.pop(); 
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Grup başarıyla oluşturuldu!'), backgroundColor: Colors.green));
                      } catch (e) {
                        setModalState(() => isCreating = false);
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Hata oluştu.'), backgroundColor: Colors.red));
                      }
                    },
                    child: isCreating 
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                      : Text('create_btn'.tr(), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Theme.of(context).colorScheme.primary)),
                  )
                ],
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          GestureDetector(
                            onTap: pickGroupImage,
                            child: Stack(
                              alignment: Alignment.bottomRight,
                              children: [
                                _buildDynamicAvatar(nameCtrl.text, base64GroupImage, radius: 36),
                                Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(color: Theme.of(context).primaryColor, shape: BoxShape.circle),
                                  child: const Icon(Icons.camera_alt, color: Colors.white, size: 14),
                                )
                              ],
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: TextField(
                              controller: nameCtrl,
                              decoration: InputDecoration(
                                hintText: 'group_name_hint'.tr(),
                                border: UnderlineInputBorder(),
                                enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.grey)),
                                focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.blueAccent, width: 2)),
                                filled: false,
                              ),
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                          )
                        ],
                      ),
                      const SizedBox(height: 24),
                      
                      Card(
                        elevation: 0,
                        color: Theme.of(context).colorScheme.surface,
                        child: SwitchListTile(
                          title: Text('private_group'.tr()),
                          subtitle: Text('private_group_desc'.tr(), style: TextStyle(fontSize: 12)),
                          value: isPrivate,
                          activeColor: Colors.blueAccent,
                          onChanged: (val) => setModalState(() => isPrivate = val),
                        ),
                      ),
                      const SizedBox(height: 24),

                      if (selectedMembers.isNotEmpty) ...[
                        Text('selected_persons'.tr(), style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          children: selectedMembers.map((m) {
                            return Chip(
                              avatar: _buildDynamicAvatar(m['nickname'] ?? m['firstName'], m['profileImage']),
                              label: Text(m['nickname'] ?? m['firstName']),
                              deleteIcon: const Icon(Icons.cancel, size: 18),
                              onDeleted: () {
                                setModalState(() => selectedMembers.removeWhere((item) => item['id'] == m['id']));
                              },
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 16),
                      ],

                      Text('add_member_title'.tr() ?? 'Üye Ekle', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      const SizedBox(height: 8),
                      TextField(
                        controller: groupSearchCtrl,
                        decoration: InputDecoration(
                          hintText: 'search_member_hint'.tr() ?? 'Numara veya Takma Ad',
                          suffixIcon: IconButton(
                            icon: isSearchingGroupUser ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.search),
                            onPressed: searchUserForGroup,
                          )
                        ),
                        onSubmitted: (_) => searchUserForGroup(),
                      ),
                      
                      if (groupSearchResults.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        ListTile(
                          leading: _buildDynamicAvatar(groupSearchResults.first['nickname'] ?? groupSearchResults.first['firstName'], groupSearchResults.first['profileImage']),
                          title: Text('${groupSearchResults.first['firstName']} ${groupSearchResults.first['lastName'] ?? ''}'),
                          subtitle: Text(groupSearchResults.first['nickname'] ?? 'Lakap yok'),
                          trailing: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 12), backgroundColor: Colors.green),
                            onPressed: () {
                              setModalState(() {
                                selectedMembers.add(groupSearchResults.first);
                                groupSearchResults.clear();
                                groupSearchCtrl.clear();
                              });
                            },
                            icon: const Icon(Icons.add, size: 16, color: Colors.white),
                            label: Text('add_btn'.tr(), style: TextStyle(color: Colors.white)),
                          ),
                        )
                      ],
                      
                      const SizedBox(height: 32),
                      Text('contacts_title'.tr() ?? 'Rehberindeki Kişiler', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      const SizedBox(height: 8),
                      Consumer(
                        builder: (context, ref, _) {
                          final contacts = ref.watch(contactProvider);
                          if (contacts.isEmpty) return Text('no_contacts_hint'.tr() ?? 'Rehberinizde Hossarpay kullanan kimse bulunamadı.', style: const TextStyle(color: Colors.grey));
                          
                          return ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: contacts.length,
                            itemBuilder: (context, index) {
                              final contactUser = contacts[index]['contactUser'];
                              bool alreadyAdded = selectedMembers.any((m) => m['id'] == contactUser['id']);
                              
                              return ListTile(
                                leading: _buildDynamicAvatar(contactUser['nickname'] ?? contactUser['firstName'], contactUser['profileImage']),
                                title: Text(contacts[index]['savedName'] ?? contactUser['firstName'], style: const TextStyle(fontWeight: FontWeight.bold)),
                                subtitle: Text(contactUser['phoneNumber']),
                                trailing: alreadyAdded
                                  ? const Icon(Icons.check_circle, color: Colors.green)
                                  : IconButton(
                                      icon: const Icon(Icons.add_circle_outline, color: Colors.blueAccent),
                                      onPressed: () {
                                        setModalState(() {
                                          selectedMembers.add(contactUser);
                                        });
                                      },
                                    ),
                              );
                            },
                          );
                        }
                      )
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      })
    );
  }

  @override
  Widget build(BuildContext context) {
    final contacts = ref.watch(contactProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text('new_chat'.tr() ?? 'Yeni Sohbet', style: const TextStyle(fontWeight: FontWeight.bold)),
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Arama Kutusu
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
              child: Container(
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [BoxShadow(color: Theme.of(context).shadowColor.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))]
                ),
                child: TextField(
                  controller: _searchCtrl,
                  decoration: InputDecoration(
                    hintText: 'search_person_hint'.tr(),
                    hintStyle: TextStyle(color: Colors.grey.shade500),
                    prefixIcon: Icon(Icons.search, color: Theme.of(context).primaryColor),
                    suffixIcon: _isSearching ? const Padding(padding: EdgeInsets.all(12), child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))) : null,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  onSubmitted: (_) => _search(),
                ),
              ),
            ),
            
            // Arama Sonucu Hata veya Kişi
            if (_error != null)
              Padding(padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8), child: Text(_error!, style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold))),
            
            if (_searchedUser != null)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                decoration: BoxDecoration(color: Theme.of(context).primaryColor.withOpacity(0.1), borderRadius: BorderRadius.circular(16)),
                child: ListTile(
                  leading: _buildDynamicAvatar(_searchedUser['nickname'] ?? _searchedUser['firstName'], _searchedUser['profileImage']),
                  title: Text('${_searchedUser['firstName']} ${_searchedUser['lastName'] ?? ''}', style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(_searchedUser['nickname'] ?? 'Lakap yok'),
                  trailing: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Theme.of(context).primaryColor, shape: BoxShape.circle), child: const Icon(Icons.chat_bubble, color: Colors.white, size: 16)),
                  onTap: () {
                    context.pushReplacement('/chat_detail', extra: {
                      'id': _searchedUser['id'],
                      'name': _searchedUser['nickname'] ?? _searchedUser['firstName'],
                      'isGroup': false,
                      'isCreator': false
                    });
                  },
                ),
              ),
            
            // Yeni Grup Butonu
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: ListTile(
                onTap: _openCreateGroupScreen,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                tileColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: Colors.green.withOpacity(0.15), shape: BoxShape.circle),
                  child: const FaIcon(FontAwesomeIcons.users, color: Colors.green, size: 20),
                ),
                title: Text('create_new_group'.tr(), style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: Colors.green)),
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Rehber Listesi
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('my_contacts'.tr(), style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: isDark ? Colors.white70 : Colors.black87)),
                  TextButton.icon(
                    style: TextButton.styleFrom(
                      backgroundColor: Theme.of(context).primaryColor.withOpacity(0.1),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () async {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('scanning_contacts'.tr())));
                      await ref.read(contactProvider.notifier).fetchAndSyncContacts();
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('scan_complete'.tr()), backgroundColor: Colors.green));
                    },
                    icon: Icon(Icons.sync, size: 16, color: Theme.of(context).primaryColor),
                    label: Text('refresh'.tr(), style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).primaryColor)),
                  )
                ],
              ),
            ),
            const SizedBox(height: 12),
            
            if (contacts.isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(40.0),
                  child: Column(
                    children: [
                      Icon(Icons.contacts_outlined, size: 64, color: Colors.grey.shade300),
                      const SizedBox(height: 16),
                      Text('no_contacts_found'.tr(), textAlign: TextAlign.center, style: TextStyle(color: Colors.grey.shade500, fontWeight: FontWeight.w500)),
                    ],
                  ),
                ),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                physics: const NeverScrollableScrollPhysics(),
                itemCount: contacts.length,
                itemBuilder: (context, index) {
                  final contact = contacts[index];
                  final userObj = contact['contactUser'];
                  final displayName = contact['savedName'] ?? userObj['nickname'] ?? userObj['firstName'];

                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E293B) : Colors.white,
                      borderRadius: BorderRadius.circular(16)
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      leading: _buildDynamicAvatar(displayName, userObj['profileImage']),
                      title: Text(displayName, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 4.0),
                        child: Text(userObj['phoneNumber'], style: TextStyle(fontSize: 13, color: Colors.grey.shade500, fontWeight: FontWeight.w500)),
                      ),
                      trailing: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(color: Theme.of(context).primaryColor.withOpacity(0.1), shape: BoxShape.circle),
                        child: Icon(Icons.chat_bubble_outline, color: Theme.of(context).primaryColor, size: 18),
                      ),
                      onTap: () {
                        context.pushReplacement('/chat_detail', extra: {
                          'id': userObj['id'],
                          'name': displayName,
                          'isGroup': false,
                          'isCreator': false
                        });
                      },
                    ),
                  );
                },
              ),
              
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}
