import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:dio/dio.dart';
import 'package:lottie/lottie.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../../../core/network/api_client.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../../history/providers/history_provider.dart'; // YENİ: History yenilemek için

class TransferScreen extends ConsumerStatefulWidget {
  const TransferScreen({super.key});

  @override
  ConsumerState<TransferScreen> createState() => _TransferScreenState();
}

class _TransferScreenState extends ConsumerState<TransferScreen> {
  final _searchCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  
  Map<String, dynamic>? _searchedUser;
  bool _isSearching = false;
  bool _isTransferring = false;
  String? _searchError;

  void _searchUser() async {
    if (_searchCtrl.text.trim().isEmpty) return;
    
    setState(() { _isSearching = true; _searchError = null; _searchedUser = null; });
    try {
      final dio = await ApiClient.client;
            // + işaretinin Vercel/Express tarafında "boşluk" olarak algılanmaması için manuel olarak encode ediyoruz.
      final res = await dio.get('/user/search?query=${Uri.encodeComponent(_searchCtrl.text.trim())}');
      setState(() {
        if (res.data is List) {
          if ((res.data as List).isEmpty) {
             _searchError = 'Kullanıcı bulunamadı';
             _searchedUser = null;
          } else if ((res.data as List).length == 1) {
             _searchedUser = (res.data as List).first;
          } else {
             _searchedUser = res.data; 
          }
        } else {
          _searchedUser = res.data;
        }
        _isSearching = false;
      });
    } catch (e) {
      String errMsg = 'Kullanıcı bulunamadı';
      if (e is DioException && e.response?.data != null) {
        errMsg = e.response!.data['message'] ?? errMsg;
      }
      setState(() {
        _searchError = errMsg;
        _isSearching = false;
      });
    }
  }

  void _transferTMT() async {
    if (_searchedUser == null) return;
    if (_amountCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('please_enter_amount'.tr() ?? 'Lütfen tutar girin.'), backgroundColor: Colors.red));
      return;
    }

    setState(() => _isTransferring = true);
    try {
      final dio = await ApiClient.client;
      await dio.post('/transfer', data: {
        'receiverId': _searchedUser!['id'],
        'amount': double.parse(_amountCtrl.text.trim())
      });
      
      // Lottie Success Animasyonu Göster
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Lottie.network(
                  'https://assets3.lottiefiles.com/packages/lf20_vuliyhde.json',
                  width: 150,
                  height: 150,
                  repeat: false,
                  errorBuilder: (context, error, stackTrace) => const Icon(Icons.check_circle, color: Colors.green, size: 100),
                ),
                const SizedBox(height: 16),
                Text('transfer_success'.tr(), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.green)),
                const SizedBox(height: 8),
                Text('${_amountCtrl.text} TMT ${'transfer_sent_msg'.tr()}', textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey)),
              ],
            ),
          ),
        );
        
        // 2.5 saniye sonra dialogu kapat
        Future.delayed(const Duration(milliseconds: 2500), () {
          if (mounted) {
            Navigator.of(context, rootNavigator: true).pop(); // Siyah ekran bugını çözer (Root navigator kullanılır)
          }
        });
      }

      ref.read(authProvider.notifier).fetchProfile(); 
      // Geçmiş listesini anında yenile
      ref.read(historyProvider.notifier).fetchHistory();
      
      _amountCtrl.clear();
      _searchCtrl.clear();
      setState(() { _searchedUser = null; });
    } catch (e) {
      String errMsg = 'Transfer başarısız';
      if (e is DioException && e.response?.data != null) {
        errMsg = e.response!.data['message'] ?? errMsg;
      }
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(errMsg), backgroundColor: Colors.red));
    } finally {
      setState(() => _isTransferring = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('transfer'.tr(), style: const TextStyle(fontWeight: FontWeight.bold))),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _searchCtrl,
                        decoration: InputDecoration(
                          labelText: 'phone_number_or_nickname'.tr(),
                          prefixIcon: const Icon(Icons.person_search),
                        ),
                        onSubmitted: (_) => _searchUser(),
                      ),
                    ),
                    const SizedBox(width: 16),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        padding: const EdgeInsets.all(18)
                      ),
                      onPressed: _isSearching ? null : _searchUser,
                      child: _isSearching 
                          ? const SizedBox(height:20, width:20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) 
                          : const Icon(Icons.search),
                    )
                  ],
                ),
              ),
            ),
            
            if (_searchError != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: Colors.red.shade100, borderRadius: BorderRadius.circular(8)),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, color: Colors.red),
                    const SizedBox(width: 8),
                    Expanded(child: Text(_searchError!, style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold))),
                  ],
                ),
              ),
            ],

            if (_searchedUser != null) ...[
              const SizedBox(height: 24),
              
              if (_searchedUser is List)
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: (_searchedUser as List).length,
                  itemBuilder: (ctx, idx) {
                    final u = (_searchedUser as List)[idx];
                    return Card(
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundImage: u['profileImage'] != null ? NetworkImage(u['profileImage']) : null,
                          child: u['profileImage'] == null ? const Icon(Icons.person) : null,
                        ),
                        title: Text(u['nickname'] ?? u['firstName']),
                        subtitle: Text(u['phoneNumber'] ?? ''),
                        onTap: () {
                          setState(() { _searchedUser = u; }); // Tekil objeye çevir
                        },
                      ),
                    );
                  }
                )
              else ...[
                Card(
                  color: Theme.of(context).colorScheme.secondary.withOpacity(0.05),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 26,
                          backgroundColor: Theme.of(context).colorScheme.secondary,
                          backgroundImage: _searchedUser!['profileImage'] != null ? NetworkImage(_searchedUser!['profileImage']) : null,
                          child: _searchedUser!['profileImage'] == null ? const FaIcon(FontAwesomeIcons.user, color: Colors.white) : null,
                        ),
                        const SizedBox(width: 16),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _searchedUser!['nickname'] ?? '${_searchedUser!['firstName']}',
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                            if (_searchedUser!['nickname'] != null)
                              Text('${_searchedUser!['firstName']} ${_searchedUser!['lastName'] ?? ''}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                          ],
                        )
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                TextField(
                  controller: _amountCtrl,
                  decoration: InputDecoration(
                    labelText: 'amount_tmt'.tr(),
                    prefixIcon: const Icon(Icons.attach_money),
                  ),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _isTransferring ? null : _transferTMT,
                    icon: const Icon(Icons.send),
                    label: _isTransferring ? const Text('Processing...') : Text('confirm'.tr()),
                  ),
                )
              ]
            ]
          ],
        ),
      ),
    );
  }
}
