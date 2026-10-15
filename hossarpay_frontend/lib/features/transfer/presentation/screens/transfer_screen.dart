import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:dio/dio.dart';
import 'package:lottie/lottie.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../../../core/network/api_client.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../../history/providers/history_provider.dart'; // History yenilemek için
/// Base64 (data URL) veya normal URL fark etmez, güvenli avatar.
Widget _transferAvatar(dynamic rawImage, {double radius = 26}) {
  final img = rawImage?.toString() ?? '';
  if (img.isNotEmpty) {
    try {
      final pure = img.contains(',') ? img.split(',').last : img;
      return CircleAvatar(
        radius: radius,
        backgroundImage: MemoryImage(base64Decode(pure)),
      );
    } catch (_) {}
    if (img.startsWith('http')) {
      return CircleAvatar(
        radius: radius,
        backgroundImage: NetworkImage(img),
        child: const Icon(Icons.person),
      );
    }
  }
  return CircleAvatar(
    radius: radius,
    backgroundColor: Colors.blueAccent,
    child: const FaIcon(FontAwesomeIcons.user, color: Colors.white, size: 20),
  );
}
class TransferScreen extends ConsumerStatefulWidget {
  const TransferScreen({super.key});
  @override
  ConsumerState<TransferScreen> createState() => _TransferScreenState();
}
class _TransferScreenState extends ConsumerState<TransferScreen> {
  final _searchCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  List<dynamic> _searchResults = [];
  Map<String, dynamic>? _selectedUser;
  bool _isSearching = false;
  bool _isTransferring = false;
  String? _searchError;
  String? _amountError;
  @override
  void dispose() {
    _searchCtrl.dispose();
    _amountCtrl.dispose();
    super.dispose();
  }
  double get _currentBalance {
    final user = ref.read(authProvider).user;
    if (user is Map && user['balance'] != null) {
      return double.tryParse(user['balance'].toString()) ?? 0;
    }
    return 0;
  }
  Future<void> _searchUser() async {
    final q = _searchCtrl.text.trim();
    if (q.length < 2) {
      setState(() => _searchError = 'min_2_chars'.tr() ?? 'En az 2 karakter yazın');
      return;
    }
    setState(() {
      _isSearching = true;
      _searchError = null;
      _searchResults = [];
      _selectedUser = null;
      _amountError = null;
    });
    try {
      final dio = await ApiClient.client;
      // + işaretinin Vercel/Express tarafında "boşluk" olarak algılanmaması için manuel encode.
      final res = await dio.get('/user/search?query=${Uri.encodeComponent(q)}');
      final data = res.data is List ? res.data as List : [res.data];
      setState(() {
        _searchResults = data;
        _isSearching = false;
        if (data.isEmpty) _searchError = 'user_not_found'.tr() ?? 'Kullanıcı bulunamadı';
      });
    } catch (e) {
      String errMsg = 'user_not_found'.tr() ?? 'Kullanıcı bulunamadı';
      if (e is DioException && e.response?.data != null) {
        final m = e.response!.data['message'];
        if (m != null) errMsg = m.toString();
      }
      setState(() {
        _searchError = errMsg;
        _isSearching = false;
      });
    }
  }
  /// Tutar ön kontrolü: boş / sayı değil / sıfır-altı / bakiye üstü / kendine gönderim.
  /// Hata yoksa true döner ve onay sayfasını açar.
  bool _validateAndConfirm() {
    final raw = _amountCtrl.text.trim().replaceAll(',', '.');
    if (_selectedUser == null) return false;
    if (raw.isEmpty) {
      setState(() => _amountError = 'please_enter_amount'.tr() ?? 'Lütfen tutar girin');
      return false;
    }
    final amount = double.tryParse(raw);
    if (amount == null) {
      setState(() => _amountError = 'invalid_amount'.tr() ?? 'Geçerli bir sayı girin (örn. 50.00)');
      return false;
    }
    if (amount <= 0) {
      setState(() => _amountError = 'amount_must_be_positive'.tr() ?? 'Tutar 0\u2019dan büyük olmalı');
      return false;
    }
    if (amount > _currentBalance) {
      setState(() => _amountError = 'insufficient_balance'.tr(namedArgs: {'balance': _currentBalance.toStringAsFixed(2)}) ?? 'Yetersiz bakiye (Mevcut: ${_currentBalance.toStringAsFixed(2)} TMT)');
      return false;
    }
    final me = ref.read(authProvider).user;
    if (me is Map && me['id'] == _selectedUser!['id']) {
      setState(() => _amountError = 'self_transfer_error'.tr() ?? 'Kendinize transfer yapamazsınız');
      return false;
    }
    setState(() => _amountError = null);
    _showConfirmSheet(amount);
    return true;
  }
  /// FinTech standardı: para çıkmadan önce alıcı + tutar onayı.
  void _showConfirmSheet(double amount) {
    final u = _selectedUser!;
    final name = u['nickname'] ?? u['firstName'] ?? '';
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 40, height: 4,
                decoration: BoxDecoration(color: Colors.grey.shade400, borderRadius: BorderRadius.circular(4))),
              const SizedBox(height: 16),
              Text('confirm_transfer_title'.tr() ?? 'Transferi Onayla',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              Row(
                children: [
                  _transferAvatar(u['profileImage']),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(name.toString(),
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        if (u['nickname'] != null)
                          Text('${u['firstName'] ?? ''} ${u['lastName'] ?? ''}',
                            style: const TextStyle(color: Colors.grey, fontSize: 12)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).primaryColor.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    Text('${amount.toStringAsFixed(2)} TMT',
                      style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold,
                        color: Theme.of(context).primaryColor)),
                    const SizedBox(height: 4),
                    Text('${'current_balance'.tr() ?? 'Mevcut Bakiye'}: ${_currentBalance.toStringAsFixed(2)} TMT',
                      style: const TextStyle(color: Colors.grey, fontSize: 12)),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: Text('cancel_btn'.tr() ?? 'Vazgeç'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      onPressed: _isTransferring
                          ? null
                          : () {
                              Navigator.pop(ctx);
                              _doTransfer(amount);
                            },
                      icon: const Icon(Icons.send, size: 18),
                      label: Text('confirm_and_send'.tr() ?? 'Onayla ve Gönder'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
  Future<void> _doTransfer(double amount) async {
    if (_selectedUser == null) return;
    final receiverId = _selectedUser!['id'];
    // Dialog geç açıldığı için tutarı önceden yakala (clear sonrası boş görünmesin)
    final amountText = amount.toStringAsFixed(2);
    final receiverName =
        (_selectedUser!['nickname'] ?? _selectedUser!['firstName'] ?? '').toString();
    setState(() => _isTransferring = true);
    try {
      final dio = await ApiClient.client;
      await dio.post('/transfer', data: {
        'receiverId': receiverId,
        'amount': amount,
      });
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
                  errorBuilder: (context, error, stackTrace) =>
                      const Icon(Icons.check_circle, color: Colors.green, size: 100),
                ),
                const SizedBox(height: 16),
                Text('transfer_success'.tr(),
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.green)),
                const SizedBox(height: 8),
                Text('$amountText TMT → $receiverName',
                  textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey)),
              ],
            ),
          ),
        );
        Future.delayed(const Duration(milliseconds: 2500), () {
          if (mounted) {
            Navigator.of(context, rootNavigator: true).pop(); // Siyah ekran bugını çözer
          }
        });
      }
      ref.read(authProvider.notifier).fetchProfile();
      ref.read(historyProvider.notifier).fetchHistory();
      _amountCtrl.clear();
      _searchCtrl.clear();
      setState(() {
        _selectedUser = null;
        _searchResults = [];
      });
    } catch (e) {
      String errMsg = 'transfer_failed'.tr() ?? 'Transfer başarısız';
      if (e is DioException && e.response?.data != null) {
        final m = e.response!.data['message'];
        if (m != null) errMsg = m.toString();
      }
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(errMsg), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _isTransferring = false);
    }
  }
  @override
  Widget build(BuildContext context) {
    final balance = _currentBalance;
    return Scaffold(
      appBar: AppBar(title: Text('transfer'.tr(), style: const TextStyle(fontWeight: FontWeight.bold))),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            // Bakiye şeridi: kullanıcı ne gönderebileceğini en başta görür
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor.withOpacity(0.08),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  Icon(Icons.account_balance_wallet, color: Theme.of(context).primaryColor),
                  const SizedBox(width: 10),
                  Text('${'balance'.tr()}: ${balance.toStringAsFixed(2)} TMT',
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _searchCtrl,
                        textInputAction: TextInputAction.search,
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
                        padding: const EdgeInsets.all(18),
                      ),
                      onPressed: _isSearching ? null : _searchUser,
                      child: _isSearching
                          ? const SizedBox(height: 20, width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
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
                decoration: BoxDecoration(
                    color: Colors.red.shade100, borderRadius: BorderRadius.circular(8)),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, color: Colors.red),
                    const SizedBox(width: 8),
                    Expanded(
                        child: Text(_searchError!,
                            style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold))),
                  ],
                ),
              ),
            ],
            if (_selectedUser == null && _searchResults.isNotEmpty) ...[
              const SizedBox(height: 16),
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _searchResults.length,
                itemBuilder: (ctx, idx) {
                  final u = _searchResults[idx];
                  return Card(
                    child: ListTile(
                      leading: _transferAvatar(u['profileImage'], radius: 22),
                      title: Text((u['nickname'] ?? u['firstName'] ?? '').toString()),
                      subtitle: Text((u['phoneNumber'] ?? '').toString()),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () {
                        HapticFeedback.selectionClick();
                        setState(() {
                          _selectedUser = Map<String, dynamic>.from(u);
                          _amountError = null;
                        });
                      },
                    ),
                  );
                },
              ),
            ],
            if (_selectedUser != null) ...[
              const SizedBox(height: 24),
              Card(
                color: Theme.of(context).colorScheme.secondary.withOpacity(0.05),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      _transferAvatar(_selectedUser!['profileImage']),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              (_selectedUser!['nickname'] ?? _selectedUser!['firstName'] ?? '').toString(),
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                            if (_selectedUser!['nickname'] != null)
                              Text(
                                  '${_selectedUser!['firstName'] ?? ''} ${_selectedUser!['lastName'] ?? ''}',
                                  style: const TextStyle(fontSize: 12, color: Colors.grey)),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: 'change'.tr() ?? 'Değiştir',
                        icon: const Icon(Icons.close),
                        onPressed: () => setState(() {
                          _selectedUser = null;
                          _amountCtrl.clear();
                          _amountError = null;
                        }),
                      ),
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
                  errorText: _amountError,
                ),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                ],
                onChanged: (_) {
                  if (_amountError != null) setState(() => _amountError = null);
                },
                onSubmitted: (_) => _validateAndConfirm(),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isTransferring ? null : _validateAndConfirm,
                  icon: _isTransferring
                      ? const SizedBox(height: 20, width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.send),
                  label: _isTransferring ? const Text('Processing...') : Text('confirm'.tr()),
                ),
              )
            ]
          ],
        ),
      ),
    );
  }
}
