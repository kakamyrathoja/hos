import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../providers/admin_provider.dart';

class AdminDashboard extends ConsumerStatefulWidget {
  const AdminDashboard({super.key});

  @override
  ConsumerState<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends ConsumerState<AdminDashboard> {
  int _selectedIndex = 0;
  final TextEditingController _searchCtrl = TextEditingController();
  final TextEditingController _logsSearchCtrl = TextEditingController(); 

  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(adminProvider.notifier).fetchAllData());
  }

  void _onSearchChanged(String value) {
    if (_selectedIndex == 0) {
      ref.read(adminProvider.notifier).searchUsers(value);
    }
  }

  void _onLogsSearchChanged(String value) {
    if (_selectedIndex == 2) {
      ref.read(adminProvider.notifier).searchLogs(value);
    }
  }

  String _formatDate(String utcDateString) {
    try {
      final utcDate = DateTime.parse(utcDateString); 
      final localDate = utcDate.toLocal(); 
      return DateFormat('yyyy-MM-dd HH:mm').format(localDate);
    } catch (e) {
      return utcDateString.substring(0, 16).replaceAll('T', ' '); 
    }
  }

  // YENİ: İstenilen tüm numaralama / sıyırma (kopyalama) kuralları güncellendi
  String _extractNumberToCopy(String serviceName, String targetAccount) {
    final sName = serviceName.toLowerCase();

    // 1. Telecom Internet: Sebit kodu ve numarayı alıp boşlukları/tireleri siler
    // "Sarahs (134) - 54321"  => "13454321"
    if (sName.contains('telecom internet')) {
      return targetAccount.replaceAll(RegExp(r'\D'), '');
    }

    // 2. ÄlemTV kuralları
    if (sName.contains('alemtv')) {
      if (targetAccount.startsWith('dalem-')) {
        return targetAccount.replaceFirst('dalem-', '').trim();
      }
      if (targetAccount.startsWith('2100')) {
        return targetAccount.replaceAll(RegExp(r'\s+'), '');
      }
      // "Telekom ÄlemTV" ise +993 ile gönderiliyordu, kopyalanmasın
      if (targetAccount.startsWith('+993 ')) {
        return targetAccount.replaceFirst('+993 ', '').trim();
      }
    }

    // 3. Astu İnternet & Astu Telefon: "+993 " kısmını sil, "12 " VE "NUMARAYI" KOPYALA
    // Örnek Gelen: "+993 12 123456" => Çıktı: "12123456" (boşluğu silip birleştirdik)
    if (sName.contains('astu')) {
      if (targetAccount.startsWith('+993 ')) {
        final without993 = targetAccount.replaceFirst('+993 ', '').trim(); // "12 123456" kalır
        return without993.replaceAll(RegExp(r'\s+'), ''); // Boşlukları sil -> "12123456"
      }
    }

    // 4. TurkmenistanaJan: "00 " dahil tüm numarayı kopyala
    if (sName.contains('turkmenistanajan')) {
      final justNumbers = targetAccount.split('(')[0].replaceAll(RegExp(r'\s+'), '');
      return justNumbers;
    }

    // 5. GB, TMcell, Beletfilm, Telekom Telefon (Diğer tüm +993 ile başlayanlar)
    // Örnek Gelen: "+993 62389390 (50 Mb)" veya "+993 62389390"
    // SADECE +993'TEN SONRAKİ RAKAMLARI KOPYALA, Notları ve +993'ü SİL.
    final parts = targetAccount.split('(');
    String cleanNum = parts[0].trim(); 
    if (cleanNum.startsWith('+993 ')) {
      return cleanNum.replaceFirst('+993 ', '').trim(); // Sadece telefon numarası kalır
    }

    return targetAccount;
  }

  void _showBalanceDialog(dynamic user) {
    final amountCtrl = TextEditingController(text: user['balance'].toString());
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Update Balance: ${user['nickname'] ?? user['firstName']}'),
        content: TextField(
          controller: amountCtrl,
          decoration: const InputDecoration(labelText: 'New Balance (TMT)'),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              final newBal = double.tryParse(amountCtrl.text.trim());
              if (newBal != null && newBal >= 0) {
                ref.read(adminProvider.notifier).updateUserBalance(user['id'], newBal);
                Navigator.pop(ctx);
              }
            },
            child: const Text('Update'),
          ),
        ],
      ),
    );
  }

  Widget _buildUsersList(List<dynamic> users) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(20.0),
          child: TextField(
            controller: _searchCtrl,
            onChanged: _onSearchChanged,
            decoration: InputDecoration(
              hintText: 'Kullanıcı Adı, Numara veya Lakap Ara...',
              prefixIcon: Icon(Icons.search, color: Theme.of(context).primaryColor),
              filled: true,
              fillColor: isDark ? const Color(0xFF1E293B) : Colors.white,
              contentPadding: const EdgeInsets.symmetric(vertical: 16),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: Theme.of(context).primaryColor)),
            ),
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () => ref.read(adminProvider.notifier).fetchAllData(),
            child: ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.only(bottom: 20),
              itemCount: users.length,
              itemBuilder: (context, index) {
                final u = users[index];
                final isAdmin = u['role'] == 'ADMIN';
                
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E293B) : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [BoxShadow(color: Theme.of(context).shadowColor.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 3))]
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    leading: CircleAvatar(
                      radius: 24,
                      backgroundColor: isAdmin ? Colors.purple.withOpacity(0.15) : Theme.of(context).primaryColor.withOpacity(0.15),
                      child: Text(u['firstName'][0], style: TextStyle(color: isAdmin ? Colors.purple : Theme.of(context).primaryColor, fontWeight: FontWeight.bold, fontSize: 18)),
                    ),
                    title: Row(
                      children: [
                        Expanded(child: Text('${u['firstName']} ${u['lastName'] ?? ''}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700))),
                        const SizedBox(width: 8),
                        if (isAdmin) Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(color: Colors.purple, borderRadius: BorderRadius.circular(8)),
                          child: const Text('ADMIN', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                        )
                      ],
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 4),
                        Text(u['phoneNumber'], style: TextStyle(color: Colors.grey.shade500, fontWeight: FontWeight.w500)),
                        if (u['nickname'] != null) Text('@${u['nickname']}', style: TextStyle(color: Theme.of(context).primaryColor, fontSize: 12)),
                      ],
                    ),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('${u['balance']}', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                        Text('TMT', style: TextStyle(color: Colors.grey.shade500, fontSize: 10, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    onTap: () => _showBalanceDialog(u),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPendingPurchases(List<dynamic> purchases) {
    if (purchases.isEmpty) return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.done_all, size: 64, color: Colors.grey.shade300), const SizedBox(height: 16), Text('Bekleyen işlem yok', style: TextStyle(color: Colors.grey.shade500, fontWeight: FontWeight.bold))]));
    
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;

    return RefreshIndicator(
      onRefresh: () => ref.read(adminProvider.notifier).fetchAllData(),
      child: ListView.builder(
        padding: const EdgeInsets.all(20),
        itemCount: purchases.length,
        itemBuilder: (context, index) {
          final p = purchases[index];
          final cleanAmount = p['amount'].toString().split('.')[0]; 
          final copiedText = _extractNumberToCopy(p['service']['name'], p['targetAccount']);

          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.orange.withOpacity(0.3), width: 2),
              boxShadow: [BoxShadow(color: Colors.orange.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))]
            ),
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(color: Colors.orange.withOpacity(0.15), borderRadius: BorderRadius.circular(8)),
                        child: Text(p['service']['name'], style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold, fontSize: 12)),
                      ),
                      Text('$cleanAmount TMT', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  
                  GestureDetector(
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: copiedText));
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Kopyalandı: $copiedText'), backgroundColor: Colors.black87));
                    },
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: Colors.grey.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(child: Text(p['targetAccount'], style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 16, letterSpacing: 1))),
                          const Icon(Icons.copy, size: 18, color: Colors.grey),
                        ],
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(p['user']['nickname'] ?? p['user']['firstName'], style: const TextStyle(fontWeight: FontWeight.w600)),
                            Text(p['user']['phoneNumber'], style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
                          ],
                        ),
                      ),
                      Row(
                        children: [
                          InkWell(
                            onTap: () => ref.read(adminProvider.notifier).resolvePurchase(p['id'], 'FAILED'),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                              decoration: BoxDecoration(color: Colors.red.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                              child: const Text('İPTAL', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                            ),
                          ),
                          const SizedBox(width: 8),
                          InkWell(
                            onTap: () => ref.read(adminProvider.notifier).resolvePurchase(p['id'], 'COMPLETED'),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                              decoration: BoxDecoration(color: Colors.green, borderRadius: BorderRadius.circular(12), boxShadow: [BoxShadow(color: Colors.green.withOpacity(0.4), blurRadius: 8, offset: const Offset(0, 4))]),
                              child: const Text('ONAYLA', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildLogs(Map<String, dynamic> logs) {
    final transactions = logs['transactions'] as List<dynamic>? ?? [];
    final purchases = logs['purchases'] as List<dynamic>? ?? [];
    
    List<dynamic> combinedLogs = [
      ...transactions.map((t) => {...t, 'logType': 'TRANSACTION'}),
      ...purchases.map((p) => {...p, 'logType': 'PURCHASE'})
    ];

    combinedLogs.sort((a, b) => DateTime.parse(b['createdAt']).compareTo(DateTime.parse(a['createdAt'])));

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(20.0),
          child: TextField(
            controller: _logsSearchCtrl,
            onChanged: _onLogsSearchChanged,
            decoration: InputDecoration(
              hintText: 'İşlem, Kişi veya Numara Ara...',
              prefixIcon: Icon(Icons.search, color: Theme.of(context).primaryColor),
              filled: true,
              fillColor: isDark ? const Color(0xFF1E293B) : Colors.white,
              contentPadding: const EdgeInsets.symmetric(vertical: 16),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: Theme.of(context).primaryColor)),
            ),
          ),
        ),
        Expanded(
          child: combinedLogs.isEmpty
            ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.history_toggle_off, size: 64, color: Colors.grey.shade300), const SizedBox(height: 16), Text('Kayıt bulunamadı', style: TextStyle(color: Colors.grey.shade500, fontWeight: FontWeight.bold))]))
            : RefreshIndicator(
                onRefresh: () => ref.read(adminProvider.notifier).fetchAllData(),
                child: ListView.builder(
                  padding: const EdgeInsets.only(bottom: 20),
                  itemCount: combinedLogs.length,
                  itemBuilder: (context, index) {
                    final log = combinedLogs[index];
                    final dateStr = _formatDate(log['createdAt'].toString());

                    if (log['logType'] == 'TRANSACTION') {
                      return Container(
                        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                        decoration: BoxDecoration(color: isDark ? const Color(0xFF1E293B) : Colors.white, borderRadius: BorderRadius.circular(16)),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          leading: Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: Colors.blueAccent.withOpacity(0.15), shape: BoxShape.circle), child: const Icon(Icons.swap_horiz, color: Colors.blueAccent)),
                          title: Text('${log['sender']['nickname'] ?? log['sender']['firstName']} ➔ ${log['receiver']['nickname'] ?? log['receiver']['firstName']}', style: const TextStyle(fontWeight: FontWeight.w700)),
                          subtitle: Padding(padding: const EdgeInsets.only(top: 4.0), child: Text(dateStr, style: TextStyle(color: Colors.grey.shade500, fontSize: 12))),
                          trailing: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text('${log['amount']} TMT', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                              Text(log['status'], style: const TextStyle(color: Colors.green, fontSize: 10, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                      );
                    } else {
                      Color sColor = log['status'] == 'COMPLETED' ? Colors.green : (log['status'] == 'FAILED' ? Colors.redAccent : Colors.orange);
                      String resolvedText = '';
                      if (log['status'] != 'PENDING' && log['resolvedBy'] != null) {
                        resolvedText = ' • Onay: ${log['resolvedBy']['nickname'] ?? log['resolvedBy']['firstName']}';
                      }

                      return Container(
                        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                        decoration: BoxDecoration(color: isDark ? const Color(0xFF1E293B) : Colors.white, borderRadius: BorderRadius.circular(16)),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          leading: Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: Colors.deepPurple.withOpacity(0.15), shape: BoxShape.circle), child: const Icon(Icons.bolt, color: Colors.deepPurple)),
                          title: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(child: Text(log['service']['name'], style: const TextStyle(fontWeight: FontWeight.w700))),
                              Text('${log['amount']} TMT', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                            ],
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 8),
                              GestureDetector(
                                onTap: () {
                                  final copiedText = _extractNumberToCopy(log['service']['name'], log['targetAccount']);
                                  Clipboard.setData(ClipboardData(text: copiedText));
                                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Kopyalandı: $copiedText'), backgroundColor: Colors.black87));
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(color: Colors.grey.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(log['targetAccount'], style: TextStyle(fontWeight: FontWeight.bold, color: textColor, fontSize: 13)), 
                                      const SizedBox(width: 8),
                                      const Icon(Icons.copy, size: 12, color: Colors.grey),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text('${log['user']['nickname'] ?? log['user']['firstName']} (${log['user']['phoneNumber']})', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Text(dateStr, style: TextStyle(color: Colors.grey.shade500, fontSize: 11)),
                                  if (resolvedText.isNotEmpty) Text(resolvedText, style: TextStyle(color: Colors.grey.shade500, fontSize: 11)),
                                ],
                              ),
                            ],
                          ),
                          isThreeLine: true,
                        ),
                      );
                    }
                  },
                ),
              ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final adminState = ref.watch(adminProvider);

    Widget content;
    
    if (adminState.error != null) {
      content = Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 64),
            const SizedBox(height: 16),
            Text(adminState.error!, style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => ref.read(adminProvider.notifier).fetchAllData(),
              child: const Text('Tekrar Dene'),
            )
          ],
        ),
      );
    } 
    else if (adminState.isLoading) {
      content = const Center(child: CircularProgressIndicator());
    } 
    else {
      switch (_selectedIndex) {
        case 0: content = _buildUsersList(adminState.users); break;
        case 1: content = _buildPendingPurchases(adminState.pendingPurchases); break;
        case 2: content = _buildLogs(adminState.logs); break;
        default: content = const SizedBox();
      }
    }

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor, // Arkaplanı garanti altına aldık
      appBar: AppBar(title: Text('admin_panel'.tr() ?? 'Yönetici Paneli', style: const TextStyle(fontWeight: FontWeight.bold))),
      body: Row(
        children: [
          NavigationRail(
            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
            selectedIndex: _selectedIndex,
            onDestinationSelected: (int index) {
              setState(() { 
                _selectedIndex = index; 
                _searchCtrl.clear();
                _logsSearchCtrl.clear(); 
              });
              ref.read(adminProvider.notifier).fetchAllData();
            },
            labelType: NavigationRailLabelType.all,
            selectedIconTheme: IconThemeData(color: Theme.of(context).colorScheme.secondary),
            selectedLabelTextStyle: TextStyle(color: Theme.of(context).colorScheme.secondary, fontWeight: FontWeight.bold),
            destinations: const [
              NavigationRailDestination(icon: Icon(Icons.people_alt_outlined), selectedIcon: Icon(Icons.people), label: Text('Users')),
              NavigationRailDestination(icon: Icon(Icons.pending_actions_outlined), selectedIcon: Icon(Icons.pending_actions), label: Text('Pending')),
              NavigationRailDestination(icon: Icon(Icons.history_outlined), selectedIcon: Icon(Icons.history), label: Text('Logs')),
            ],
          ),
          const VerticalDivider(thickness: 1, width: 1),
          Expanded(
            child: SizedBox(
              height: MediaQuery.of(context).size.height,
              child: content,
            ),
          ),
        ],
      ),
    );
  }
}