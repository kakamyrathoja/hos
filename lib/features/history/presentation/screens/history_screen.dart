import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../providers/history_provider.dart'; 

class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> with SingleTickerProviderStateMixin {
  
  Widget _buildReceiptRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey, fontSize: 14)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
        ],
      ),
    );
  }
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    Future.microtask(() => ref.read(historyProvider.notifier).fetchHistory());
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

  Widget _buildTransferHistory(List<dynamic> transfers) {
    if (transfers.isEmpty) return Center(child: Text('no_transfers'.tr()));

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: transfers.length,
      itemBuilder: (context, index) {
        final t = transfers[index];
        final isSent = t['type'] == 'SENT';
        
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Theme.of(context).shadowColor.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              )
            ]
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            leading: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isSent ? Colors.redAccent.withOpacity(0.15) : Colors.green.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: FaIcon(
                isSent ? FontAwesomeIcons.arrowUpRightFromSquare : FontAwesomeIcons.arrowDown, 
                color: isSent ? Colors.redAccent : Colors.green, size: 18
              ),
            ),
            title: Text(
              t['party']['nickname'] ?? '${t['party']['firstName']}', 
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 4.0),
              child: Text(
                _formatDate(t['date'].toString()), 
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${isSent ? '-' : '+'}${t['amount']}',
                  style: TextStyle(
                    fontWeight: FontWeight.w800, fontSize: 16,
                    color: isSent ? Colors.redAccent : Colors.green
                  ),
                ),
                Text('TMT', style: TextStyle(color: Colors.grey.shade500, fontSize: 10, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildPurchaseHistory(List<dynamic> purchases) {
    if (purchases.isEmpty) return Center(child: Text('no_receipts'.tr()));

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: purchases.length,
      itemBuilder: (context, index) {
        final p = purchases[index];
        IconData statusIcon;
        Color statusColor;

        if (p['status'] == 'COMPLETED') {
          statusIcon = FontAwesomeIcons.circleCheck;
          statusColor = Colors.green;
        } else if (p['status'] == 'FAILED') {
          statusIcon = FontAwesomeIcons.circleXmark;
          statusColor = Colors.red;
        } else {
          statusIcon = FontAwesomeIcons.clock;
          statusColor = Colors.orange;
        }

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Theme.of(context).shadowColor.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              )
            ]
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            leading: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: FaIcon(statusIcon, color: statusColor, size: 18),
            ),
            title: Text(p['service']['name'], style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 4.0),
              child: Text(
                _formatDate(p['createdAt'].toString()), 
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '-${p['amount']}',
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: Colors.redAccent),
                ),
                Text('TMT', style: TextStyle(color: Colors.grey.shade500, fontSize: 10, fontWeight: FontWeight.bold)),
              ],
            ),
            onTap: () {
              showDialog(
                context: context,
                barrierColor: Colors.black54, 
                builder: (ctx) => Dialog(
                  backgroundColor: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF1E293B) : Colors.white,
                  surfaceTintColor: Colors.transparent,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                  insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
                  child: Stack(
                    clipBehavior: Clip.none,
                    alignment: Alignment.topCenter,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 50.0, left: 24.0, right: 24.0, bottom: 24.0),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(p['service']['name'].toUpperCase(), style: TextStyle(fontSize: 14, color: Colors.grey.shade500, letterSpacing: 1.2)),
                            const SizedBox(height: 8),
                            Text('${p['amount']} TMT', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 32)),
                            const SizedBox(height: 4),
                            Text(p['status'] == 'COMPLETED' ? 'status_completed'.tr() : (p['status'] == 'PENDING' ? 'status_pending'.tr() : 'status_failed'.tr()), style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 14)),
                            
                            const SizedBox(height: 24),
                            const Divider(height: 1),
                            const SizedBox(height: 16),
                            
                            _buildReceiptRow('receipt_phone'.tr(), p['targetAccount']),
                            _buildReceiptRow('receipt_time'.tr(), _formatDate(p['createdAt'].toString())),
                            _buildReceiptRow('receipt_id'.tr(), p['id'].toString().substring(0, 8).toUpperCase()),
                            _buildReceiptRow('server_id'.tr(), p['id'].hashCode.abs().toString()),
                            
                            const SizedBox(height: 24),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Theme.of(context).primaryColor.withOpacity(0.1),
                                  foregroundColor: Theme.of(context).primaryColor,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))
                                ),
                                onPressed: () => Navigator.pop(ctx),
                                child: Text('close_btn'.tr(), style: TextStyle(fontWeight: FontWeight.bold)),
                              ),
                            )
                          ],
                        ),
                      ),
                      Positioned(
                        top: -30,
                        child: CircleAvatar(
                          radius: 32,
                          backgroundColor: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF1E293B) : Colors.white,
                          child: CircleAvatar(
                            radius: 26,
                            backgroundColor: statusColor.withOpacity(0.15),
                            child: FaIcon(statusIcon, color: statusColor, size: 28),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final historyState = ref.watch(historyProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text('history'.tr(), style: const TextStyle(fontWeight: FontWeight.bold)),
        elevation: 0,
        backgroundColor: Colors.transparent,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Theme.of(context).colorScheme.secondary,
          indicatorWeight: 3,
          labelColor: Theme.of(context).colorScheme.secondary,
          unselectedLabelColor: Colors.grey,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          tabs: [
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const FaIcon(FontAwesomeIcons.moneyBillTransfer, size: 16),
                  const SizedBox(width: 8),
                  Text('transfers_tab'.tr()),
                ],
              ),
            ),
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const FaIcon(FontAwesomeIcons.receipt, size: 16),
                  const SizedBox(width: 8),
                  Text('receipts_tab'.tr()),
                ],
              ),
            ),
          ],
        ),
      ),
      body: historyState['isLoading']
        ? const Center(child: CircularProgressIndicator())
        : TabBarView(
            controller: _tabController,
            children: [
              _buildTransferHistory(historyState['transfers']),
              _buildPurchaseHistory(historyState['purchases']),
            ],
          ),
    );
  }
}
