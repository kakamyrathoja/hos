import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import 'dart:async';
import 'package:easy_localization/easy_localization.dart';
import '../../../../core/network/api_client.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../../../auth/providers/auth_provider.dart';

MemoryImage? _getMemoryImage(String? base64Str) {
  if (base64Str == null || base64Str.isEmpty) return null;
  try {
    return MemoryImage(base64Decode(base64Str.split(',').last));
  } catch (e) {
    return null;
  }
}

Widget _buildDynamicAvatar(String name, String? base64Image, {double radius = 24}) {
  if (base64Image != null && base64Image.isNotEmpty) {
    try {
      return CircleAvatar(
        radius: radius,
        backgroundImage: MemoryImage(base64Decode(base64Image.split(',').last)),
      );
    } catch (e) {}
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

Widget _buildTelegramActionButton(BuildContext context, IconData icon, String label, VoidCallback onTap, {Color? color}) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  final bgColor = isDark ? const Color(0xFF1E293B) : Colors.grey.shade200;
  final fgColor = color ?? (isDark ? Colors.white : Colors.black87);

  return GestureDetector(
    onTap: onTap,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 54,
          height: 54,
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Icon(icon, color: fgColor, size: 24),
        ),
        const SizedBox(height: 6),
        Text(label, style: TextStyle(fontSize: 12, color: fgColor, fontWeight: FontWeight.w500)),
      ],
    ),
  );
}

// ===============================================
// CONTACT INFO
// ===============================================
class ContactInfoScreen extends StatefulWidget {
  final String userId;
  final String name;

  const ContactInfoScreen({super.key, required this.userId, required this.name});

  @override
  State<ContactInfoScreen> createState() => _ContactInfoScreenState();
}

class _ContactInfoScreenState extends State<ContactInfoScreen> {
  dynamic _userDetails;
  bool _isLoading = true;
  bool _isMuted = false;

  @override
  void initState() {
    super.initState();
    _fetchUserDetails();
    _loadMuteState();
  }
  
  Future<void> _loadMuteState() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() { _isMuted = prefs.getBool('mute_${widget.userId}') ?? false; });
  }

  Future<void> _toggleMute() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() { _isMuted = !_isMuted; });
    await prefs.setBool('mute_${widget.userId}', _isMuted);
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(_isMuted ? 'Bildirimler sessize alındı' : 'Bildirimlerin sesi açıldı'),
        duration: const Duration(seconds: 2),
      ));
    }
  }

  Future<void> _fetchUserDetails() async {
    try {
      final dio = await ApiClient.client;
      final res = await dio.get('/user/search?query=${Uri.encodeComponent(widget.name)}');
      if (mounted) setState(() { _userDetails = res.data is List ? (res.data.isNotEmpty ? res.data.first : null) : res.data; _isLoading = false; });
    } catch (e) {
      if (mounted) setState(() { _userDetails = {'firstName': widget.name, 'phoneNumber': 'hidden'.tr()}; _isLoading = false; });
    }
  }

  // YENİ: Sohbeti Gerçekten Temizleme Fonksiyonu (Backend'e Bağlı)
  void _clearChatHistory() async {
    // Önce kullanıcıdan onay alıyoruz
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('clear_history'.tr()),
        content: Text('Sohbet silinecek onaylıyor musunuz?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('cancel_btn'.tr()),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text('clear_btn'.tr(), style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final dio = await ApiClient.client;
      // Backend'e silme isteğini gönderiyoruz
      await dio.delete('/chat/history/${widget.userId}');
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('chat_history_cleared'.tr()), backgroundColor: Colors.green),
        );
        Navigator.pop(context); // Profil sayfasını kapat (Önceki ekran olan ChatDetailScreen _fetchMessages yapıp ekranı güncelleyecek)
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Sohbet silinirken bir hata oluştu.'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    final memImg = _getMemoryImage(_userDetails['profileImage']);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? const Color(0xFF1E293B) : Colors.white;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 350.0,
            pinned: true,
            stretch: true,
            backgroundColor: Theme.of(context).primaryColor,
            iconTheme: const IconThemeData(color: Colors.white),
            flexibleSpace: FlexibleSpaceBar(
              title: Text(widget.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, shadows: [Shadow(blurRadius: 10, color: Colors.black54)])),
              titlePadding: const EdgeInsets.only(left: 20, bottom: 16),
              stretchModes: const [StretchMode.zoomBackground],
              background: memImg != null 
                ? Image(image: memImg, fit: BoxFit.cover)
                : Container(
                    decoration: const BoxDecoration(gradient: LinearGradient(colors: [Colors.blueAccent, Colors.indigo], begin: Alignment.topLeft, end: Alignment.bottomRight)),
                    child: Center(child: Text(widget.name[0].toUpperCase(), style: const TextStyle(fontSize: 120, color: Colors.white24, fontWeight: FontWeight.bold))),
                  ),
            ),
          ),
          
          SliverToBoxAdapter(
            child: Column(
              children: [
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildTelegramActionButton(context, Icons.chat, 'chat'.tr(), () => Navigator.pop(context)),
                    _buildTelegramActionButton(context, Icons.call, 'call'.tr(), () {}),
                    _buildTelegramActionButton(
                      context, 
                      _isMuted ? Icons.notifications_off : Icons.notifications_active, 
                      _isMuted ? 'sessiz'.tr() ?? 'Sessiz' : 'sessize_al'.tr() ?? 'Sesi Kapat', 
                      _toggleMute,
                      color: _isMuted ? Colors.red : null
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(16)),
                  child: Column(
                    children: [
                      ListTile(
                        title: Text(_userDetails['phoneNumber'] ?? 'hidden'.tr(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        subtitle: Text('phone_number'.tr(), style: const TextStyle(color: Colors.grey, fontSize: 13)),
                      ),
                      const Divider(height: 1, indent: 16),
                      ListTile(
                        title: Text('@${_userDetails['nickname'] ?? _userDetails['firstName'].toLowerCase()}', style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 16)),
                        subtitle: Text('username'.tr(), style: const TextStyle(color: Colors.grey, fontSize: 13)),
                      ),
                    ],
                  ),
                ),

                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(16)),
                  child: ListTile(
                    leading: const Icon(Icons.delete_sweep, color: Colors.redAccent),
                    title: Text('clear_history'.tr(), style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
                    onTap: _clearChatHistory, // Tıklandığında çalışır
                  ),
                ),
                const SizedBox(height: 40),
              ],
            ),
          )
        ],
      ),
    );
  }
}

// ===============================================
// GROUP INFO
// ===============================================
class GroupInfoScreen extends ConsumerStatefulWidget {
  final String groupId;
  final bool isCreator;

  const GroupInfoScreen({super.key, required this.groupId, required this.isCreator});

  @override
  ConsumerState<GroupInfoScreen> createState() => _GroupInfoScreenState();
}

class _GroupInfoScreenState extends ConsumerState<GroupInfoScreen> {
  dynamic _groupDetails;
  bool _isLoading = true;
  bool _isMuted = false;

  @override
  void initState() {
    super.initState();
    _fetchGroupDetails();
    _loadMuteState();
  }
  
  Future<void> _loadMuteState() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() { _isMuted = prefs.getBool('mute_${widget.groupId}') ?? false; });
  }

  Future<void> _toggleMute() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() { _isMuted = !_isMuted; });
    await prefs.setBool('mute_${widget.groupId}', _isMuted);
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(_isMuted ? 'Grup sessize alındı' : 'Grup bildirimleri açıldı'),
        duration: const Duration(seconds: 2),
      ));
    }
  }

  Future<void> _fetchGroupDetails() async {
    try {
      final dio = await ApiClient.client;
      final res = await dio.get('/chat/group/${widget.groupId}');
      if (mounted) setState(() { _groupDetails = res.data; _isLoading = false; });
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _editGroupNameDialog() {
    final nameCtrl = TextEditingController(text: _groupDetails['name']);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('edit'.tr()),
        content: TextField(controller: nameCtrl, decoration: InputDecoration(labelText: 'group_info'.tr())),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (nameCtrl.text.trim().isEmpty) return;
              try {
                final dio = await ApiClient.client;
                await dio.put('/chat/group/${widget.groupId}', data: {'name': nameCtrl.text.trim()});
                Navigator.pop(ctx);
                _fetchGroupDetails();
              } catch (e) {}
            },
            child: const Text('OK'),
          )
        ],
      )
    );
  }

  Future<void> _updateGroupImage() async {
    final picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery, imageQuality: 40, maxWidth: 600);
    if (image != null) {
      final bytes = await image.readAsBytes();
      final base64Image = "data:image/jpeg;base64,${base64Encode(bytes)}";
      try {
        final dio = await ApiClient.client;
        await dio.put('/chat/group/${widget.groupId}', data: {'groupImage': base64Image});
        _fetchGroupDetails();
      } catch (e) {}
    }
  }

  Future<void> _removeMember(String memberId) async {
    try {
      final dio = await ApiClient.client;
      await dio.delete('/chat/group/members', data: {'groupId': widget.groupId, 'targetUserId': memberId});
      _fetchGroupDetails();
    } catch (e) {}
  }

  Future<void> _leaveOrDeleteGroup() async {
    try {
      final dio = await ApiClient.client;
      if (widget.isCreator) {
        await dio.delete('/chat/group/${widget.groupId}');
      } else {
        await dio.delete('/chat/group/members', data: {'groupId': widget.groupId});
      }
      Navigator.of(context).popUntil((route) => route.isFirst); 
    } catch (e) {}
  }

  void _showAddMemberDialog() {
    final searchCtrl = TextEditingController();
    List<dynamic> searchResults = [];
    bool isSearching = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (context, setModalState) {
        return AlertDialog(
          title: Text('add_member'.tr()),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: searchCtrl,
                decoration: InputDecoration(
                  labelText: 'search_person'.tr(),
                  suffixIcon: IconButton(
                    icon: isSearching ? const SizedBox(width:16,height:16,child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.search),
                    onPressed: () async {
                      if (searchCtrl.text.isEmpty) return;
                      setModalState(() => isSearching = true);
                      try {
                        final dio = await ApiClient.client;
                                                final res = await dio.get('/user/search?query=${Uri.encodeComponent(searchCtrl.text.trim())}');
                        setModalState(() { searchResults = res.data is List ? res.data : [res.data]; isSearching = false; });
                      } catch (e) { setModalState(() { searchResults = []; isSearching = false; }); }
                    },
                  )
                ),
              ),
              const SizedBox(height: 16),
              if (searchResults.isNotEmpty)
                ListTile(
                  leading: CircleAvatar(child: Text(searchResults.first['firstName'][0])),
                  title: Text(searchResults.first['nickname'] ?? searchResults.first['firstName']),
                  trailing: const Icon(Icons.add_circle, color: Colors.green),
                  onTap: () async {
                    try {
                      final dio = await ApiClient.client;
                      await dio.post('/chat/group/members', data: {'groupId': widget.groupId, 'newMemberId': searchResults.first['id']});
                      Navigator.pop(ctx);
                      _fetchGroupDetails();
                    } catch (e) { Navigator.pop(ctx); }
                  },
                )
            ],
          ),
          actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK'))],
        );
      })
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    final currentUserId = ref.read(authProvider).user?['id'];
    final amICreator = _groupDetails['creatorId'] == currentUserId;

    final members = _groupDetails['members'] as List<dynamic>;
    final memImg = _getMemoryImage(_groupDetails['groupImage']);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? const Color(0xFF1E293B) : Colors.white;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 350.0,
            pinned: true,
            stretch: true,
            backgroundColor: Theme.of(context).primaryColor,
            iconTheme: const IconThemeData(color: Colors.white),
            actions: [
              if (amICreator) IconButton(icon: const Icon(Icons.edit, color: Colors.white), onPressed: _editGroupNameDialog),
              if (amICreator) IconButton(icon: const Icon(Icons.add_a_photo, color: Colors.white), onPressed: _updateGroupImage),
            ],
            flexibleSpace: FlexibleSpaceBar(
              title: Text(_groupDetails['name'], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, shadows: [Shadow(blurRadius: 10, color: Colors.black54)])),
              titlePadding: const EdgeInsets.only(left: 20, bottom: 16),
              stretchModes: const [StretchMode.zoomBackground],
              background: memImg != null 
                ? Image(image: memImg, fit: BoxFit.cover)
                : Container(
                    decoration: const BoxDecoration(gradient: LinearGradient(colors: [Colors.teal, Colors.blue], begin: Alignment.topLeft, end: Alignment.bottomRight)),
                    child: Center(child: FaIcon(FontAwesomeIcons.users, size: 100, color: Colors.white24)),
                  ),
            ),
          ),

          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildTelegramActionButton(context, Icons.chat, 'chat'.tr(), () => Navigator.pop(context)),
                    _buildTelegramActionButton(
                      context, 
                      _isMuted ? Icons.notifications_off : Icons.notifications_active, 
                      _isMuted ? 'sessiz'.tr() ?? 'Sessiz' : 'sessize_al'.tr() ?? 'Sesi Kapat', 
                      _toggleMute,
                      color: _isMuted ? Colors.red : null
                    ),
                    // YENİ: Ekleme Butonu Aktif Edildi
                    if (amICreator)
                      _buildTelegramActionButton(context, Icons.group_add, 'add_member'.tr() ?? 'Üye Ekle', _showAddMemberDialog, color: Colors.blueAccent),
                    _buildTelegramActionButton(context, Icons.exit_to_app, amICreator ? 'delete_group'.tr() ?? 'Grubu Sil' : 'leave_group'.tr() ?? 'Gruptan Ayrıl', _leaveOrDeleteGroup, color: Colors.red),
                  ],
                ),
                const SizedBox(height: 24),

                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(16)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Text('${members.length} ${'members'.tr()}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blueAccent)),
                      ),
                      const Divider(height: 1),
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: members.length,
                        itemBuilder: (context, index) {
                          final user = members[index]['user'];
                          final isGroupAdmin = user['id'] == _groupDetails['creatorId'];
                          final memAvatar = _getMemoryImage(user['profileImage']);
                          
                          return ListTile(
                            leading: CircleAvatar(
                              backgroundColor: Colors.grey.shade300,
                              backgroundImage: memAvatar,
                              child: memAvatar == null ? Text(user['firstName'][0], style: const TextStyle(color: Colors.black54)) : null,
                            ),
                            title: Text(user['nickname'] ?? user['firstName'], style: const TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Text(isGroupAdmin ? 'creator'.tr() : 'member'.tr(), style: TextStyle(color: isGroupAdmin ? Colors.blueAccent : Colors.grey, fontSize: 12)),
                            // YENİ: Atma Butonu Aktif Edildi
                            trailing: (amICreator && !isGroupAdmin) 
                              ? IconButton(
                                  icon: const Icon(Icons.remove_circle_outline, color: Colors.redAccent, size: 24), 
                                  tooltip: 'remove_member_title'.tr(),
                                  onPressed: () {
                                    showDialog(
                                      context: context,
                                      builder: (ctx) => AlertDialog(
                                        title: Text('remove_member_title'.tr()),
                                        content: Text('${user['firstName']} adlı kullanıcıyı gruptan çıkarmak istediğinize emin misiniz?'),
                                        actions: [
                                          TextButton(onPressed: () => Navigator.pop(ctx), child: Text('cancel_btn'.tr())),
                                          TextButton(
                                            onPressed: () {
                                              Navigator.pop(ctx);
                                              _removeMember(user['id']);
                                            }, 
                                            child: const Text('Çıkar', style: TextStyle(color: Colors.red))
                                          ),
                                        ],
                                      )
                                    );
                                  }
                                )
                              : null,
                          );
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
              ],
            ),
          )
        ],
      ),
    );
  }
}

// ===============================================
// CHAT EKRANI (DİL DESTEKLİ)
// ===============================================
class ChatDetailScreen extends ConsumerStatefulWidget {
  final String id;
  final String name;
  final bool isGroup;
  final bool isCreator;

  const ChatDetailScreen({super.key, required this.id, required this.name, required this.isGroup, this.isCreator = false});

  @override
  ConsumerState<ChatDetailScreen> createState() => _ChatDetailScreenState();
}

class _ChatDetailScreenState extends ConsumerState<ChatDetailScreen> {
  final _msgCtrl = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();
  
  bool _showScrollToBottomBtn = false;
  List<dynamic> _messages = [];
  bool _isLoading = true;
  bool _isUploadingImage = false;
  String? _editingMessageId;
  dynamic _replyingToMessage;
  bool _isTyping = false;
  bool _showEmojiPicker = false;
  bool _hasText = false;
  Timer? _typingTimer;

  // --- Audio Recording Vars ---
  final _audioRecorder = AudioRecorder();
  bool _isRecording = false;
  String? _audioPath;
  
  // --- Audio Player Vars ---
  final _audioPlayer = AudioPlayer();
  String? _currentlyPlayingMsgId;
  bool _isPlaying = false;
  Duration _audioDuration = Duration.zero;
  Duration _audioPosition = Duration.zero;

  @override
  void initState() {
    super.initState();
    _fetchMessages();
    
    // Audio Player Listeners
    _audioPlayer.onDurationChanged.listen((d) { if (mounted) setState(() => _audioDuration = d); });
    _audioPlayer.onPositionChanged.listen((p) { if (mounted) setState(() => _audioPosition = p); });
    _audioPlayer.onPlayerStateChanged.listen((state) {
      if (mounted) {
        setState(() {
          _isPlaying = state == PlayerState.playing;
          if (state == PlayerState.completed) {
            _audioPosition = Duration.zero;
            _isPlaying = false;
            _currentlyPlayingMsgId = null;
          }
        });
      }
    });

    _msgCtrl.addListener(() {
      final hasText = _msgCtrl.text.trim().isNotEmpty;
      if (_hasText != hasText && mounted) {
        setState(() => _hasText = hasText);
      }
    });
    _scrollController.addListener(() {
      // position.pixels > 100 demek liste yukari kaydirildi demek
      if (_scrollController.position.pixels > 100) {
        if (!_showScrollToBottomBtn) setState(() => _showScrollToBottomBtn = true);
      } else {
        if (_showScrollToBottomBtn) setState(() => _showScrollToBottomBtn = false);
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _focusNode.dispose();
    _msgCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchMessages() async {
    try {
      final dio = await ApiClient.client;
      final queryParam = widget.isGroup ? 'groupId=${widget.id}' : 'otherUserId=${widget.id}';
      final res = await dio.get('/chat/messages?$queryParam');
      if (mounted) {
        setState(() {
          _messages = List.from(res.data.reversed);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _scrollToBottom() {
    _scrollController.animateTo(0.0, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
  }

  void _onTextChanged(String text) {
    final hasText = text.trim().isNotEmpty;
    if (_hasText != hasText) {
      setState(() => _hasText = hasText);
    }

    if (text.isNotEmpty) {
      setState(() => _isTyping = true);
      _typingTimer?.cancel();
      _typingTimer = Timer(const Duration(seconds: 2), () {
        if (mounted) setState(() => _isTyping = false);
      });
    } else {
      setState(() => _isTyping = false);
    }
  }

  void _openEmojiKeyboard() {
    if (_showEmojiPicker) {
      FocusScope.of(context).requestFocus(_focusNode);
      SystemChannels.textInput.invokeMethod('TextInput.show');
      setState(() => _showEmojiPicker = false);
    } else {
      FocusScope.of(context).unfocus();
      SystemChannels.textInput.invokeMethod('TextInput.hide');
      setState(() => _showEmojiPicker = true);
    }
  }

  void _onTextFieldTap() {
    if (_showEmojiPicker) {
      setState(() => _showEmojiPicker = false);
    }
  }

  Future<void> _startRecording() async {
    try {
      if (await _audioRecorder.hasPermission()) {
        final dir = await getApplicationDocumentsDirectory();
        _audioPath = '${dir.path}/ses_mesaji_${DateTime.now().millisecondsSinceEpoch}.m4a';
        await _audioRecorder.start(const RecordConfig(), path: _audioPath!);
        setState(() => _isRecording = true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Mikrofon izni verilmedi.')));
      }
    } catch (e) {
      debugPrint("Kayıt hatası: $e");
    }
  }

  Future<void> _stopRecording() async {
    try {
      final path = await _audioRecorder.stop();
      setState(() => _isRecording = false);
      if (path != null) {
        final bytes = await File(path).readAsBytes();
        final base64Audio = "data:audio/m4a;base64,${base64Encode(bytes)}";
        _sendMessage(audioUrl: base64Audio);
      }
    } catch (e) {
      debugPrint("Kayıt durdurma hatası: $e");
    }
  }

  Future<void> _playPauseAudio(String msgId, String base64Url) async {
    if (_currentlyPlayingMsgId == msgId && _isPlaying) {
      await _audioPlayer.pause();
    } else {
      try {
        final bytes = base64Decode(base64Url.split(',').last);
        final dir = await getApplicationDocumentsDirectory();
        final file = File('${dir.path}/temp_play_$msgId.m4a');
        await file.writeAsBytes(bytes);
        
        await _audioPlayer.play(DeviceFileSource(file.path));
        setState(() => _currentlyPlayingMsgId = msgId);
      } catch (e) {
        debugPrint("Çalma hatası: $e");
      }
    }
  }

  String _formatTime(String utcDateString) {
    try {
      final localDate = DateTime.parse(utcDateString).toLocal(); 
      return DateFormat('HH:mm').format(localDate);
    } catch (e) {
      return "";
    }
  }

  Future<void> _sendMessage({String? text, String? imageUrl, String? audioUrl}) async {
    final finalTxt = text?.trim() ?? _msgCtrl.text.trim();
    if (finalTxt.isEmpty && imageUrl == null && audioUrl == null) return;
    
    try {
      final dio = await ApiClient.client;
      
      if (_editingMessageId != null) {
        await dio.put('/chat/message/$_editingMessageId', data: {'content': finalTxt});
        setState(() => _editingMessageId = null);
      } 
      else {
        final data = {
          'content': finalTxt,
          'imageUrl': imageUrl,
          'replyToId': _replyingToMessage != null ? _replyingToMessage['id'] : null,
          widget.isGroup ? 'groupId' : 'receiverId': widget.id
        };
        await dio.post('/chat/send', data: data);
        setState(() {
          _replyingToMessage = null; 
          _isTyping = false;
        }); 
      }
      
      _msgCtrl.clear();
      await _fetchMessages(); 
      _scrollToBottom();
    } catch (e) {}
  }

  Future<void> _sendImage() async {
    final picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery, imageQuality: 40, maxWidth: 800);
    
    if (image != null) {
      setState(() => _isUploadingImage = true);
      final bytes = await image.readAsBytes();
      final base64Image = "data:image/jpeg;base64,${base64Encode(bytes)}";
      await _sendMessage(imageUrl: base64Image);
      setState(() => _isUploadingImage = false);
    }
  }

  void _deleteMessage(String messageId) async {
    try {
      final dio = await ApiClient.client;
      await dio.delete('/chat/message/$messageId');
      _fetchMessages();
    } catch (e) {}
  }

  void _pinMessage(String messageId) async {
    try {
      final dio = await ApiClient.client;
      await dio.put('/chat/message/$messageId/pin');
      _fetchMessages();
    } catch (e) {}
  }

  void _forwardMessage(String textToForward) {
    final searchCtrl = TextEditingController();
    List<dynamic> searchResults = [];
    bool isSearching = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(builder: (context, setModalState) {
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 24, right: 24, top: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('forward'.tr(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              const SizedBox(height: 16),
              TextField(
                controller: searchCtrl,
                decoration: InputDecoration(
                  labelText: 'search_person'.tr(),
                  suffixIcon: IconButton(
                    icon: isSearching ? const SizedBox(width:16,height:16,child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.search),
                    onPressed: () async {
                      if (searchCtrl.text.isEmpty) return;
                      setModalState(() => isSearching = true);
                      try {
                        final dio = await ApiClient.client;
                                                final res = await dio.get('/user/search?query=${Uri.encodeComponent(searchCtrl.text.trim())}');
                        setModalState(() { searchResults = res.data is List ? res.data : [res.data]; isSearching = false; });
                      } catch (e) { setModalState(() { searchResults = []; isSearching = false; }); }
                    },
                  )
                ),
              ),
              const SizedBox(height: 16),
              if (searchResults.isNotEmpty)
                ListTile(
                  leading: _buildDynamicAvatar(searchResults.first['nickname'] ?? searchResults.first['firstName'], searchResults.first['profileImage']),
                  title: Text(searchResults.first['nickname'] ?? searchResults.first['firstName']),
                  trailing: const Icon(Icons.send, color: Colors.blueAccent),
                  onTap: () async {
                    try {
                      final dio = await ApiClient.client;
                      await dio.post('/chat/send', data: {
                        'content': 'İletilen Mesaj:\n$textToForward',
                        'receiverId': searchResults.first['id']
                      });
                      Navigator.pop(ctx);
                    } catch (e) {}
                  },
                ),
              const SizedBox(height: 24),
            ],
          ),
        );
      })
    );
  }

  void _viewFullScreenImage(String url) {
    showDialog(
      context: context,
      barrierColor: Colors.black,
      builder: (ctx) => Dialog.fullscreen(
        backgroundColor: Colors.black,
        child: Stack(
          children: [
            Center(child: Image.memory(base64Decode(url.split(',').last), fit: BoxFit.contain)),
            Positioned(top: 40, right: 20, child: IconButton(icon: const Icon(Icons.close, color: Colors.white, size: 32), onPressed: () => Navigator.pop(ctx)))
          ]
        )
      )
    );
  }

  void _showTelegramMenu(dynamic msg, bool isMe) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).cardTheme.color,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.reply),
                title: Text('reply'.tr()),
                onTap: () { 
                  Navigator.pop(ctx); 
                  setState(() => _replyingToMessage = msg);
                },
              ),
              ListTile(
                leading: const Icon(Icons.copy),
                title: Text('copy'.tr()),
                onTap: () {
                  Navigator.pop(ctx);
                  if (msg['content'] != null) {
                    Clipboard.setData(ClipboardData(text: msg['content']));
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.forward),
                title: Text('forward'.tr()),
                onTap: () { 
                  Navigator.pop(ctx); 
                  if (msg['content'] != null) _forwardMessage(msg['content']);
                },
              ),
              ListTile(
                leading: const Icon(Icons.push_pin_outlined),
                title: Text(msg['isPinned'] == true ? 'unpin'.tr() : 'pin'.tr()),
                onTap: () { 
                  Navigator.pop(ctx); 
                  _pinMessage(msg['id']);
                },
              ),
              if (isMe && msg['content'] != null)
                ListTile(
                  leading: const Icon(Icons.edit),
                  title: Text('edit'.tr()),
                  onTap: () { 
                    Navigator.pop(ctx); 
                    setState(() {
                      _editingMessageId = msg['id'];
                      _msgCtrl.text = msg['content'];
                    });
                  },
                ),
              if (isMe)
                ListTile(
                  leading: const Icon(Icons.delete_outline, color: Colors.redAccent),
                  title: Text('delete'.tr(), style: const TextStyle(color: Colors.redAccent)),
                  onTap: () {
                    Navigator.pop(ctx);
                    _deleteMessage(msg['id']);
                  },
                ),
            ],
          ),
        );
      }
    );
  }

  @override
  Widget build(BuildContext context) {
    final myUserId = ref.read(authProvider).user?['id'];
    final pinnedMessages = _messages.where((m) => m['isPinned'] == true).toList();
    final currentPinnedMsg = pinnedMessages.isNotEmpty ? pinnedMessages.last : null;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: InkWell(
          onTap: () {
            if (widget.isGroup) {
              Navigator.push(context, MaterialPageRoute(builder: (context) => GroupInfoScreen(groupId: widget.id, isCreator: widget.isCreator))).then((_) => _fetchMessages());
            } else {
              Navigator.push(context, MaterialPageRoute(builder: (context) => ContactInfoScreen(userId: widget.id, name: widget.name))).then((_) => _fetchMessages());
            }
          },
          child: Row(
            children: [
              _buildDynamicAvatar(widget.name, null, radius: 20), 
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                  Text(_isTyping ? 'typing...'.tr() : (widget.isGroup ? 'group_chat'.tr() : 'online'.tr()), style: TextStyle(fontSize: 12, color: _isTyping ? Theme.of(context).primaryColor : Colors.grey)),
                ],
              ),
            ],
          ),
        ),
      ),
      body: Stack(
        children: [
          Column(
            children: [
              if (currentPinnedMsg != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  color: Theme.of(context).scaffoldBackgroundColor,
                  child: Row(
                    children: [
                      const Icon(Icons.push_pin, color: Colors.blueAccent, size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('pinned_message'.tr(), style: const TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold, fontSize: 12)),
                            Text(currentPinnedMsg['content'] ?? 'photo'.tr(), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14)),
                          ],
                        ),
                      ),
                      IconButton(icon: const Icon(Icons.close, size: 18, color: Colors.grey), onPressed: () => _pinMessage(currentPinnedMsg['id']))
                    ],
                  ),
                ),
              
              Expanded(
                child: _isLoading 
                  ? const Center(child: CircularProgressIndicator())
                  : ListView.builder(
                      controller: _scrollController,
                      reverse: true, 
                      padding: const EdgeInsets.all(16),
                      itemCount: _messages.length,
                      itemBuilder: (context, index) {
                        final msg = _messages[index];
                        final isMe = msg['senderId'] == myUserId;
                        
                        dynamic replyMsg;
                        if (msg['replyToId'] != null) {
                          replyMsg = _messages.firstWhere((m) => m['id'] == msg['replyToId'], orElse: () => null);
                        }

                        return Align(
                          alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                          child: GestureDetector(
                            onLongPress: () => _showTelegramMenu(msg, isMe),
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: EdgeInsets.all(msg['imageUrl'] != null ? 4 : 12),
                              decoration: BoxDecoration(
                                color: isMe ? Theme.of(context).colorScheme.secondary : (Theme.of(context).brightness == Brightness.dark ? Colors.grey.shade800 : Colors.white),
                                borderRadius: BorderRadius.only(
                                  topLeft: const Radius.circular(16),
                                  topRight: const Radius.circular(16),
                                  bottomLeft: Radius.circular(isMe ? 16 : 0),
                                  bottomRight: Radius.circular(isMe ? 0 : 16),
                                ),
                                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4, offset: const Offset(0,2))]
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (replyMsg != null)
                                    Container(
                                      margin: const EdgeInsets.only(bottom: 6),
                                      padding: const EdgeInsets.all(6),
                                      decoration: BoxDecoration(
                                        color: Colors.black.withOpacity(0.1),
                                        border: const Border(left: BorderSide(color: Colors.white, width: 3)),
                                        borderRadius: BorderRadius.circular(4)
                                      ),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(replyMsg['sender']['nickname'] ?? replyMsg['sender']['firstName'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.white70)),
                                          Text(replyMsg['content'] ?? 'photo'.tr(), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: Colors.white)),
                                        ],
                                      ),
                                    ),

                                  if (!isMe && widget.isGroup)
                                    Padding(
                                      padding: EdgeInsets.only(bottom: 4, left: msg['imageUrl'] != null ? 8 : 0, top: msg['imageUrl'] != null ? 4 : 0),
                                      child: Text(msg['sender']['nickname'] ?? msg['sender']['firstName'], style: TextStyle(fontSize: 10, color: Theme.of(context).colorScheme.secondary, fontWeight: FontWeight.bold)),
                                    ),
                                  if (msg['imageUrl'] != null)
                                    GestureDetector(
                                      onTap: () => _viewFullScreenImage(msg['imageUrl']),
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(12),
                                        child: Image.memory(base64Decode(msg['imageUrl'].split(',').last), width: 200, height: 200, fit: BoxFit.cover),
                                      ),
                                    ),
                                  
                                  if (msg['audioUrl'] != null)
                                    Container(
                                      width: 220,
                                      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                                      decoration: BoxDecoration(
                                        color: isMe ? Colors.white24 : Colors.blue.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(30)
                                      ),
                                      child: Row(
                                        children: [
                                          CircleAvatar(
                                            backgroundColor: isMe ? Colors.white : Theme.of(context).primaryColor,
                                            radius: 20,
                                            child: IconButton(
                                              icon: Icon(
                                                (_currentlyPlayingMsgId == msg['id'] && _isPlaying) ? Icons.pause : Icons.play_arrow,
                                                color: isMe ? Theme.of(context).primaryColor : Colors.white,
                                                size: 20,
                                              ),
                                              onPressed: () => _playPauseAudio(msg['id'], msg['audioUrl']),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                SliderTheme(
                                                  data: SliderThemeData(
                                                    trackHeight: 3,
                                                    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                                                    overlayShape: const RoundSliderOverlayShape(overlayRadius: 10),
                                                    activeTrackColor: isMe ? Colors.white : Theme.of(context).primaryColor,
                                                    inactiveTrackColor: isMe ? Colors.white38 : Colors.grey.shade300,
                                                    thumbColor: isMe ? Colors.white : Theme.of(context).primaryColor,
                                                  ),
                                                  child: Slider(
                                                    value: (_currentlyPlayingMsgId == msg['id']) ? _audioPosition.inSeconds.toDouble() : 0,
                                                    max: (_currentlyPlayingMsgId == msg['id'] && _audioDuration.inSeconds > 0) ? _audioDuration.inSeconds.toDouble() : 1.0,
                                                    onChanged: (val) {
                                                      if (_currentlyPlayingMsgId == msg['id']) {
                                                        _audioPlayer.seek(Duration(seconds: val.toInt()));
                                                      }
                                                    },
                                                  ),
                                                ),
                                              ],
                                            ),
                                          )
                                        ],
                                      ),
                                    ),

                                  if (msg['content'] != null && msg['content'].toString().isNotEmpty)
                                    Padding(
                                      padding: EdgeInsets.only(top: msg['imageUrl'] != null ? 8 : 0, left: msg['imageUrl'] != null ? 8 : 0, bottom: msg['imageUrl'] != null ? 8 : 0),
                                      child: Text(msg['content'], style: TextStyle(fontSize: 15, color: isMe ? Colors.white : Theme.of(context).textTheme.bodyMedium?.color)),
                                    ),
                                  
                                  Padding(
                                    padding: const EdgeInsets.only(top: 4.0),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      mainAxisAlignment: MainAxisAlignment.end,
                                      children: [
                                        if (msg['isEdited'] == true)
                                           Padding(
                                            padding: const EdgeInsets.only(right: 4.0),
                                            child: Text('edited'.tr(), style: const TextStyle(fontSize: 10, color: Colors.white70, fontStyle: FontStyle.italic)),
                                          ),
                                        Text(
                                          _formatTime(msg['createdAt'].toString()), 
                                          style: TextStyle(fontSize: 10, color: isMe ? Colors.white70 : Colors.grey),
                                        ),
                                        if (isMe) ...[
                                          const SizedBox(width: 4),
                                          const Icon(Icons.done, size: 14, color: Colors.white70),
                                        ]
                                      ],
                                    ),
                                  )
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
              ),
              
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                color: Theme.of(context).scaffoldBackgroundColor,
                child: SafeArea(
                  child: Column(
                    children: [
                      if (_replyingToMessage != null || _editingMessageId != null)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          margin: const EdgeInsets.only(bottom: 8),
                          decoration: BoxDecoration(color: Theme.of(context).primaryColor.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                          child: Row(
                            children: [
                              Icon(_editingMessageId != null ? Icons.edit : Icons.reply, color: Theme.of(context).primaryColor),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(_editingMessageId != null ? 'edit'.tr() : '${'reply'.tr()} ${_replyingToMessage['sender']['nickname'] ?? _replyingToMessage['sender']['firstName']}', style: TextStyle(color: Theme.of(context).primaryColor, fontWeight: FontWeight.bold, fontSize: 12)),
                                    Text(_editingMessageId != null ? 'edit'.tr() : (_replyingToMessage['content'] ?? 'photo'.tr()), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12)),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.close, size: 20, color: Colors.grey),
                                onPressed: () {
                                  setState(() { _replyingToMessage = null; _editingMessageId = null; _msgCtrl.clear(); });
                                },
                              )
                            ],
                          ),
                        ),

                      Row(
                        children: [
                          Expanded(
                            child: Container(
                              decoration: BoxDecoration(
                                color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF1E293B) : Colors.white,
                                borderRadius: BorderRadius.circular(24),
                              ),
                              child: Row(
                                children: [
                                  IconButton(icon: const Icon(Icons.sentiment_satisfied_alt, color: Colors.grey), onPressed: _openEmojiKeyboard), 
                                  Expanded(
                                    child: TextField(
                                      controller: _msgCtrl,
                                      focusNode: _focusNode,
                                      onTap: _onTextFieldTap,
                                      onChanged: _onTextChanged, 
                                      decoration: InputDecoration(
                                        hintText: 'message_hint'.tr(),
                                        border: InputBorder.none,
                                        enabledBorder: InputBorder.none,
                                        focusedBorder: InputBorder.none,
                                        filled: false,
                                        contentPadding: const EdgeInsets.symmetric(vertical: 12),
                                      ),
                                    ),
                                  ),
                                  IconButton(
                                    icon: _isUploadingImage ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.attach_file, color: Colors.grey),
                                    onPressed: _isUploadingImage ? null : _sendImage, 
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          GestureDetector(
                            onLongPressStart: (_) {
                              if (!_hasText) _startRecording();
                            },
                            onLongPressEnd: (_) {
                              if (!_hasText) _stopRecording();
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              curve: Curves.easeInOut,
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: _hasText ? Theme.of(context).colorScheme.secondary : Colors.green,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  if (!_hasText)
                                    BoxShadow(color: Colors.green.withOpacity(0.4), blurRadius: 8, spreadRadius: 2)
                                ],
                              ),
                              child: IconButton(
                                icon: AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 200),
                                  transitionBuilder: (child, anim) => ScaleTransition(scale: anim, child: child),
                                  child: Icon(
                                    _hasText ? Icons.send : Icons.mic,
                                    key: ValueKey(_hasText),
                                    color: Colors.white,
                                    size: _hasText ? 20 : 24,
                                  ),
                                ),
                                onPressed: () {
                                  if (_hasText) {
                                    _sendMessage();
                                  } else {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('Sesli mesaj kaydetmek için basılı tutun! 🎤')),
                                    );
                                  }
                                },
                              ),
                            ),
                          )
                        ],
                      ),
                      
                      // EMOJI PICKER BURAYA GELIYOR
                      if (_showEmojiPicker)
                        SizedBox(
                          height: 250,
                          child: EmojiPicker(
                            onEmojiSelected: (category, emoji) {
                              _msgCtrl.text = _msgCtrl.text + emoji.emoji;
                              _onTextChanged(_msgCtrl.text);
                            },
                            onBackspacePressed: () {
                              final text = _msgCtrl.text;
                              if (text.isNotEmpty) {
                                _msgCtrl.text = text.substring(0, text.length - 1);
                                _onTextChanged(_msgCtrl.text);
                              }
                            },
                            // Config sürüm çakışması olmaması için varsayılan bırakıldı
                          ),
                        ),
                    ],
                  ),
                ),
              )
            ],
          ),

          if (_showScrollToBottomBtn)
            Positioned(
              right: 16,
              bottom: 90, 
              child: FloatingActionButton(
                mini: true,
                backgroundColor: Colors.white,
                foregroundColor: Colors.grey.shade700,
                onPressed: _scrollToBottom,
                child: const Icon(Icons.keyboard_arrow_down),
              ),
            ),
        ],
      ),
    );
  }
}