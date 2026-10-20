import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:dio/dio.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../../../core/network/api_client.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../../history/providers/history_provider.dart'; 

class ServicesScreen extends ConsumerStatefulWidget {
  const ServicesScreen({super.key});

  @override
  ConsumerState<ServicesScreen> createState() => _ServicesScreenState();
}

class _ServicesScreenState extends ConsumerState<ServicesScreen> {
  List<dynamic> services = [];
  bool isLoading = true;

  final List<String> _validMobilePrefixes = ['61', '62', '63', '64', '65', '71', '72'];

  final Map<String, List<Map<String, String>>> telecomRegions = {
    'Ahal welaýaty': [
      {'name': 'Bäherden', 'code': '131'}, {'name': 'Gökdepe', 'code': '132'},
      {'name': 'Kaka', 'code': '133'}, {'name': 'Sarahs', 'code': '134'},
      {'name': 'Tejen', 'code': '135'}, {'name': 'Altyn Asyr', 'code': '1354'},
      {'name': 'Babadaýhan', 'code': '136'}, {'name': 'Änew', 'code': '137'},
    ],
    'Balkan welaýaty': [
      {'name': 'Türkmenbaşy', 'code': '243'}, {'name': 'Hazar', 'code': '222'},
      {'name': 'Gumdag', 'code': '242'}, {'name': 'Etrek', 'code': '242'},
      {'name': 'Balkanabat', 'code': '222'}, {'name': 'Esenguly', 'code': '245'},
      {'name': 'Serdar', 'code': '246'}, {'name': 'Bereket', 'code': '247'},
      {'name': 'Magtymguly', 'code': '248'},
    ],
    'Daşoguz welaýaty': [
      {'name': 'Daşoguz', 'code': '322'}, {'name': 'Tagta', 'code': '340'},
      {'name': 'Ýylanly', 'code': '343'}, {'name': 'Akdepe', 'code': '344'},
      {'name': 'Gubadag', 'code': '345'}, {'name': 'Boldumsaz', 'code': '346'},
      {'name': 'Köneürgenç', 'code': '347'}, {'name': 'Nyýazow', 'code': '348'},
      {'name': 'Türkmenbaşy', 'code': '349'},
    ],
    'Lebap welaýaty': [
      {'name': 'Türkmenabat şäheri', 'code': '422'}, {'name': 'Magdanly', 'code': '434'},
      {'name': 'Dänew', 'code': '446'}, {'name': 'Çärjew etraby', 'code': '433'},
      {'name': 'Köýtendag etraby', 'code': '440'}, {'name': 'Halaç etraby', 'code': '441'},
      {'name': 'Hojambaz etraby', 'code': '442'}, {'name': 'Garabekewül etraby', 'code': '443'},
      {'name': 'Kerki', 'code': '444'}, {'name': 'Darganata', 'code': '445'},
      {'name': 'B.S. Türkmenbaşy', 'code': '465'}, {'name': 'Saýat', 'code': '447'},
      {'name': 'Farap', 'code': '448'}, {'name': 'Seýdi', 'code': '446'},
    ],
    'Mary welaýaty': [
      {'name': 'Mary', 'code': '522'}, {'name': 'Garagum', 'code': '557'},
      {'name': 'Wekilbazar', 'code': '558'}, {'name': 'Oguzhan', 'code': '559'},
      {'name': 'Şatlyk', 'code': '566'}, {'name': 'Ýölöten', 'code': '560'},
      {'name': 'Serhetabat', 'code': '568'}, {'name': 'Baýramaly', 'code': '564'},
      {'name': 'Murgap', 'code': '565'}, {'name': 'Sakarçäge', 'code': '566'},
      {'name': 'Tahtabazar', 'code': '568'}, {'name': 'Türkmengala', 'code': '569'},
    ],
  };

  @override
  void initState() {
    super.initState();
    _fetchServices();
  }

  Future<void> _fetchServices() async {
    try {
      final dio = await ApiClient.client;
      final res = await dio.get('/services');
      setState(() {
        services = res.data;
        isLoading = false;
      });
    } catch (e) {
      setState(() => isLoading = false);
    }
  }

  IconData _getServiceIcon(String name) {
    final lowerName = name.toLowerCase();
    if (lowerName.contains('tmcell')) return FontAwesomeIcons.mobileScreen;
    if (lowerName.contains('telecom internet')) return FontAwesomeIcons.wifi;
    if (lowerName.contains('telekom telefon')) return FontAwesomeIcons.phone;
    if (lowerName.contains('astu internet')) return FontAwesomeIcons.towerBroadcast; 
    if (lowerName.contains('astu telefon')) return FontAwesomeIcons.squarePhone; 
    if (lowerName.contains('beletfilm')) return FontAwesomeIcons.film;
    if (lowerName.contains('alemtv')) return FontAwesomeIcons.tv;
    if (lowerName.contains('gb')) return FontAwesomeIcons.database;
    if (lowerName.contains('turkmenistanajan')) return FontAwesomeIcons.headset;
    return FontAwesomeIcons.bolt; 
  }

  void _onSuccessPurchase(BuildContext context, String message) {
    ref.read(authProvider.notifier).fetchProfile(); 
    ref.read(historyProvider.notifier).fetchHistory(); 
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), backgroundColor: Colors.green));
  }

  void _onErrorPurchase(BuildContext context, dynamic e) {
    String errMsg = 'Hata oluştu!';
    if (e is DioException && e.response?.data != null) {
      errMsg = e.response!.data['message'] ?? errMsg;
    }
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(errMsg), backgroundColor: Colors.red));
  }

  // ==========================================
  // 1. STANDART HİZMETLER 
  // ==========================================
  void _showDefaultPurchaseDialog(dynamic service, bool isMobile) {
    final accountCtrl = TextEditingController();
    final amountCtrl = TextEditingController();
    bool isProcessing = false;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(builder: (context, setModalState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Text(service['name'], style: const TextStyle(fontWeight: FontWeight.bold)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: accountCtrl, 
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(8),
                  ],
                  decoration: InputDecoration(
                    prefixText: '+993 ',
                    labelText: 'receipt_phone'.tr()
                  )
                ),
                SizedBox(height: 16),
                TextField(
                  controller: amountCtrl, 
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: InputDecoration(labelText: 'amount_tmt'.tr())
                ),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: Text('cancel'.tr() ?? 'İptal', style: const TextStyle(color: Colors.grey))),
              ElevatedButton(
                onPressed: isProcessing ? null : () async {
                  final phoneText = accountCtrl.text.trim();
                  if (phoneText.isEmpty || amountCtrl.text.isEmpty) return;
                  if (phoneText.length != 8) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('phone_must_8'.tr() ?? 'Telefon numarası tam 8 haneli olmalıdır.'), backgroundColor: Colors.red));
                    return;
                  }

                  if (isMobile) {
                    bool isValidPrefix = _validMobilePrefixes.any((prefix) => phoneText.startsWith(prefix));
                    if (!isValidPrefix) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('phone_prefix_error'.tr() ?? 'Geçersiz numara! Kod 61, 62, 63, 64, 65, 71 veya 72 ile başlamalıdır.'), backgroundColor: Colors.red));
                      return;
                    }
                  }
                  
                  setModalState(() => isProcessing = true);
                  try {
                    final dio = await ApiClient.client;
                    await dio.post('/services/purchase', data: {
                      'serviceId': service['id'],
                      'targetAccount': '+993$phoneText',
                      'amount': int.parse(amountCtrl.text.trim()) 
                    });
                    _onSuccessPurchase(ctx, 'payment_success'.tr() ?? 'Ödeme başarıyla gönderildi!');
                  } catch (e) {
                    setModalState(() => isProcessing = false);
                    _onErrorPurchase(ctx, e);
                  }
                },
                child: isProcessing ? SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : Text('confirm'.tr()),
              )
            ],
          );
        });
      }
    );
  }

  // ==========================================
  // 2. ASTU INTERNET VE ASTU TELEFON
  // ==========================================
  void _showAstuDialog(dynamic service) {
    final accountCtrl = TextEditingController();
    final amountCtrl = TextEditingController();
    bool isProcessing = false;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(builder: (context, setModalState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Text(service['name'], style: const TextStyle(fontWeight: FontWeight.bold)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: accountCtrl, 
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(6), 
                  ],
                  decoration: InputDecoration(
                    prefixText: '+993 12 ',
                    labelText: 'receipt_phone'.tr()
                  )
                ),
                SizedBox(height: 16),
                TextField(
                  controller: amountCtrl, 
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: InputDecoration(labelText: 'amount_tmt'.tr())
                ),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: Text('cancel'.tr() ?? 'İptal', style: const TextStyle(color: Colors.grey))),
              ElevatedButton(
                onPressed: isProcessing ? null : () async {
                  final phoneText = accountCtrl.text.trim();
                  if (phoneText.length != 6 || amountCtrl.text.isEmpty) return;
                  
                  setModalState(() => isProcessing = true);
                  try {
                    final dio = await ApiClient.client;
                    await dio.post('/services/purchase', data: {
                      'serviceId': service['id'],
                      'targetAccount': '+993 12 $phoneText',
                      'amount': int.parse(amountCtrl.text.trim()) 
                    });
                    _onSuccessPurchase(ctx, 'payment_success'.tr() ?? 'Ödeme başarıyla gönderildi!');
                  } catch (e) {
                    setModalState(() => isProcessing = false);
                    _onErrorPurchase(ctx, e);
                  }
                },
                child: isProcessing ? SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : Text('confirm'.tr()),
              )
            ],
          );
        });
      }
    );
  }

  // ==========================================
  // 3. TURKMENISTANAJAN (DAKİKA HESAPLAMA)
  // ==========================================
  void _showTurkmenistanaJanDialog(dynamic service) {
    final accountCtrl = TextEditingController();
    final minuteCtrl = TextEditingController();
    bool isProcessing = false;
    double totalTmt = 0.0;
    int enteredMins = 0;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(builder: (context, setModalState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Text(service['name'], style: const TextStyle(fontWeight: FontWeight.bold)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: accountCtrl, 
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(12),
                  ],
                  decoration: InputDecoration(
                    prefixText: '00 ',
                    labelText: 'receipt_phone'.tr()
                  )
                ),
                SizedBox(height: 16),
                TextField(
                  controller: minuteCtrl, 
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: InputDecoration(labelText: 'minutes_label'.tr() ?? 'Kaç Dakika'),
                  onChanged: (val) {
                    setModalState(() {
                      enteredMins = int.tryParse(val) ?? 0;
                      totalTmt = enteredMins * 1.3;
                    });
                  },
                ),
                SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: Theme.of(context).primaryColor.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('total_amount'.tr() ?? 'Toplam Ödeme:', style: const TextStyle(fontWeight: FontWeight.bold)),
                      Text('${totalTmt.toStringAsFixed(2)} TMT', style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).primaryColor, fontSize: 18)),
                    ],
                  ),
                )
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: Text('cancel'.tr() ?? 'İptal', style: const TextStyle(color: Colors.grey))),
              ElevatedButton(
                onPressed: isProcessing ? null : () async {
                  final phoneText = accountCtrl.text.trim();
                  if (phoneText.length != 12 || minuteCtrl.text.isEmpty || totalTmt <= 0) return;
                  
                  setModalState(() => isProcessing = true);
                  try {
                    final dio = await ApiClient.client;
                    await dio.post('/services/purchase', data: {
                      'serviceId': service['id'],
                      'targetAccount': '00 $phoneText ($enteredMins Minut)',
                      'amount': totalTmt 
                    });
                    _onSuccessPurchase(ctx, 'payment_success'.tr() ?? 'Ödeme başarıyla gönderildi!');
                  } catch (e) {
                    setModalState(() => isProcessing = false);
                    _onErrorPurchase(ctx, e);
                  }
                },
                child: isProcessing ? SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : Text('confirm'.tr()),
              )
            ],
          );
        });
      }
    );
  }

  // ==========================================
  // 4. ALEMTV ÖZEL MENÜ (3 Seçenekli)
  // ==========================================
  void _showAlemTVMenu(dynamic service) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('payment_method_label'.tr() ?? 'Hangi yöntemi kullanıyorsunuz', style: const TextStyle(color: Colors.grey, fontSize: 14)),
              SizedBox(height: 16),
              
              _buildAlemTVOption(
                icon: Icons.credit_card, iconColor: Colors.black,
                title: 'alemtv_card'.tr() ?? 'ÄlemTV (Kart)', subtitle: 'alemtv_card_sub'.tr() ?? '2100****** ile başlayan kart numarasıyla ödeme yapın',
                onTap: () {
                  Navigator.pop(ctx);
                  _showAlemTVInput(service, 'alemtv_card'.tr() ?? 'ÄlemTV (Kart)', '2100', 6, 'card_number_label'.tr() ?? 'Kart Numarası', TextInputType.number, true);
                }
              ),
              SizedBox(height: 12),
              
              _buildAlemTVOption(
                icon: Icons.wifi, iconColor: Colors.blueAccent,
                title: 'alemtv_telecom'.tr() ?? 'Telekom ÄlemTV', subtitle: 'alemtv_telecom_sub'.tr() ?? 'Ev telefonu numarasıyla ödeme yapın',
                onTap: () {
                  Navigator.pop(ctx);
                  _showAlemTVInput(service, 'alemtv_telecom'.tr() ?? 'Telekom ÄlemTV', '+993 ', 8, 'phone_label'.tr() ?? 'Telefon Numarası', TextInputType.number, true);
                }
              ),
              SizedBox(height: 12),
              
              _buildAlemTVOption(
                icon: Icons.satellite_alt, iconColor: Colors.green,
                title: 'alemtv_dalem'.tr() ?? 'ÄlemTV (dalem-)', subtitle: 'alemtv_dalem_sub'.tr() ?? 'Giriş bilgileriniz "dalem-" ile başlıyorsa',
                onTap: () {
                  Navigator.pop(ctx);
                  _showAlemTVInput(service, 'alemtv_dalem'.tr() ?? 'ÄlemTV (dalem-)', 'dalem-', 15, 'account_label'.tr() ?? 'Hesap No', TextInputType.text, false);
                }
              ),
              SizedBox(height: 24), 
            ],
          ),
        );
      }
    );
  }

  Widget _buildAlemTVOption({required IconData icon, required Color iconColor, required String title, required String subtitle, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Theme.of(context).cardTheme.color,
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: iconColor, borderRadius: BorderRadius.circular(12)),
              child: Icon(icon, color: Colors.white),
            ),
            SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  SizedBox(height: 4),
                  Text(subtitle, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  void _showAlemTVInput(dynamic service, String title, String prefix, int maxLength, String label, TextInputType type, bool isDigitsOnly) {
    final accountCtrl = TextEditingController();
    final amountCtrl = TextEditingController();
    bool isProcessing = false;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(builder: (context, setModalState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: accountCtrl, 
                  keyboardType: type,
                  inputFormatters: [
                    if (isDigitsOnly) FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(maxLength),
                  ],
                  decoration: InputDecoration(
                    prefixText: prefix,
                    labelText: label
                  )
                ),
                SizedBox(height: 16),
                TextField(
                  controller: amountCtrl, 
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: InputDecoration(labelText: 'amount_tmt'.tr())
                ),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: Text('cancel'.tr() ?? 'İptal', style: const TextStyle(color: Colors.grey))),
              ElevatedButton(
                onPressed: isProcessing ? null : () async {
                  final phoneText = accountCtrl.text.trim();
                  if (phoneText.isEmpty || amountCtrl.text.isEmpty) return;
                  
                  setModalState(() => isProcessing = true);
                  try {
                    final dio = await ApiClient.client;
                    await dio.post('/services/purchase', data: {
                      'serviceId': service['id'],
                      'targetAccount': '$prefix$phoneText',
                      'amount': int.parse(amountCtrl.text.trim()) 
                    });
                    _onSuccessPurchase(ctx, 'payment_success'.tr() ?? 'Ödeme başarıyla gönderildi!');
                  } catch (e) {
                    setModalState(() => isProcessing = false);
                    _onErrorPurchase(ctx, e);
                  }
                },
                child: isProcessing ? SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : Text('confirm'.tr()),
              )
            ],
          );
        });
      }
    );
  }

  // ==========================================
  // 5. TELECOM INTERNET (BÖLGE SEÇİMLİ)
  // ==========================================
  void _showTelecomPurchaseDialog(dynamic service) {
    Map<String, String>? selectedRegion;
    final phoneCtrl = TextEditingController();
    final amountCtrl = TextEditingController();
    bool isProcessing = false;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(builder: (context, setModalState) {
          return Dialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('payment_info'.tr() ?? 'Ödeme Bilgileri', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                  SizedBox(height: 24),
                  
                  InkWell(
                    onTap: () {
                      showDialog(
                        context: context,
                        builder: (context) => Dialog.fullscreen(
                          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
                          child: Column(
                            children: [
                              AppBar(
                                backgroundColor: Colors.transparent, elevation: 0,
                                leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => Navigator.pop(context)),
                                title: Text('region_select'.tr() ?? 'Bölge Seçin', style: const TextStyle(fontWeight: FontWeight.bold)),
                              ),
                              Expanded(
                                child: ListView(
                                  children: telecomRegions.entries.map((regionGroup) {
                                    return Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Padding(
                                          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
                                          child: Text(regionGroup.key, style: TextStyle(color: Colors.grey.shade600, fontSize: 16)),
                                        ),
                                        ...regionGroup.value.map((region) {
                                          return InkWell(
                                            onTap: () {
                                              setModalState(() => selectedRegion = region);
                                              Navigator.pop(context);
                                            },
                                            child: Padding(
                                              padding: const EdgeInsets.symmetric(horizontal: 48.0, vertical: 16.0),
                                              child: Text('${region['name']} (${region['code']})', style: const TextStyle(fontSize: 16)),
                                            ),
                                          );
                                        })
                                      ],
                                    );
                                  }).toList(),
                                ),
                              ),
                            ],
                          ),
                        )
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                      decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade400), borderRadius: BorderRadius.circular(12)),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            selectedRegion == null ? 'region_not_selected'.tr() : '${selectedRegion!['name']} (${selectedRegion!['code']})',
                            style: TextStyle(fontSize: 16, color: selectedRegion == null ? Colors.grey : (Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black)),
                          ),
                          const Icon(Icons.keyboard_arrow_down, color: Colors.grey),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(height: 16),
                  
                  TextField(
                    controller: phoneCtrl,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(5)],
                    decoration: InputDecoration(labelText: 'receiver_phone_label'.tr() ?? 'Alıcının Telefon Numarası', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                  ),
                  SizedBox(height: 16),

                  TextField(
                    controller: amountCtrl,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: InputDecoration(labelText: 'amount_tmt_label'.tr() ?? 'Miktar (TMT)', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                  ),
                  SizedBox(height: 32),

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: isProcessing ? null : () async {
                        if (selectedRegion == null || phoneCtrl.text.isEmpty || amountCtrl.text.isEmpty) return;
                        if (phoneCtrl.text.length != 5) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('phone_must_5'.tr() ?? 'Telefon numarası tam 5 haneli olmalıdır.'), backgroundColor: Colors.red));
                          return;
                        }
                        setModalState(() => isProcessing = true);
                        try {
                          final dio = await ApiClient.client;
                          await dio.post('/services/purchase', data: {
                            'serviceId': service['id'],
                            'targetAccount': '${selectedRegion!['name']} (${selectedRegion!['code']}) - ${phoneCtrl.text.trim()}',
                            'amount': int.parse(amountCtrl.text.trim()),
                          });
                          _onSuccessPurchase(ctx, 'payment_success'.tr() ?? 'Ödeme başarıyla gönderildi!');
                        } catch (e) {
                          setModalState(() => isProcessing = false);
                          _onErrorPurchase(ctx, e);
                        }
                      },
                      child: isProcessing ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : Text('confirm'.tr(), style: TextStyle(fontSize: 16)),
                    ),
                  ),
                ],
              ),
            ),
          );
        });
      }
    );
  }

  // ==========================================
  // 6. GB (İNTERNET PAKETLERİ) İÇİN ÖZEL EKRAN
  // ==========================================
  void _showGBPurchaseDialog(dynamic service) {
    final phoneCtrl = TextEditingController();
    int? selectedPackageIndex;
    bool isProcessing = false;

    final packages = [
      {'label': '50 Mb', 'price': 4, 'note': null}, {'label': '100 Mb', 'price': 6, 'note': null},
      {'label': '250 Mb', 'price': 11, 'note': null}, {'label': '500 Mb', 'price': 16, 'note': 'gb_note_500'.tr()},
      {'label': '1.5 Gb', 'price': 62, 'note': null}, {'label': '4 Gb', 'price': 160, 'note': null},
      {'label': '20 Gb', 'price': 203, 'note': null},
    ];

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(builder: (context, setModalState) {
          return Dialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: phoneCtrl,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(8)],
                    decoration: InputDecoration(prefixText: '+993 ', labelText: 'receipt_phone'.tr()),
                  ),
                  SizedBox(height: 24),
                  Text('select_package'.tr(), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  SizedBox(height: 12),
                  
                  GridView.builder(
                    shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, childAspectRatio: 2.2, crossAxisSpacing: 12, mainAxisSpacing: 12),
                    itemCount: packages.length,
                    itemBuilder: (context, index) {
                      final pkg = packages[index];
                      final isSelected = selectedPackageIndex == index;
                      return GestureDetector(
                        onTap: () => setModalState(() => selectedPackageIndex = index),
                        child: Container(
                          decoration: BoxDecoration(
                            color: isSelected ? Theme.of(context).primaryColor : Colors.transparent,
                            border: Border.all(color: isSelected ? Theme.of(context).primaryColor : Colors.grey.shade400, width: 2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Stack(
                            children: [
                              Center(
                                child: Text(
                                  pkg['label'] as String,
                                  style: TextStyle(color: isSelected ? Colors.white : (Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black87), fontWeight: FontWeight.bold, fontSize: 16),
                                ),
                              ),
                              if (isSelected) const Positioned(top: 4, right: 6, child: Icon(Icons.check_circle, color: Colors.white, size: 16))
                            ],
                          ),
                        ),
                      );
                    },
                  ),

                  if (selectedPackageIndex != null && packages[selectedPackageIndex!]['note'] != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Text(packages[selectedPackageIndex!]['note'] as String, style: const TextStyle(color: Colors.red, fontStyle: FontStyle.italic, fontSize: 12, fontWeight: FontWeight.bold)),
                    ),

                  SizedBox(height: 24),

                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: Colors.orange.withOpacity(0.1), border: Border.all(color: Colors.orange, width: 1), borderRadius: BorderRadius.circular(12)),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 28),
                        SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('attention'.tr(), style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold, fontSize: 16)),
                              SizedBox(height: 4),
                              Text('gb_warning'.tr(), style: const TextStyle(fontSize: 13, height: 1.4)),
                            ],
                          ),
                        )
                      ],
                    ),
                  ),
                  SizedBox(height: 24),

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: isProcessing ? null : () async {
                        final phoneText = phoneCtrl.text.trim();
                        if (phoneText.length != 8 || selectedPackageIndex == null) return;
                        bool isValidPrefix = _validMobilePrefixes.any((prefix) => phoneText.startsWith(prefix));
                        if (!isValidPrefix) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('phone_prefix_error'.tr() ?? 'Geçersiz numara! Kod 61, 62, 63, 64, 65, 71 veya 72 ile başlamalıdır.'), backgroundColor: Colors.red));
                          return;
                        }
                        setModalState(() => isProcessing = true);
                        try {
                          final dio = await ApiClient.client;
                          await dio.post('/services/purchase', data: {
                            'serviceId': service['id'],
                            'targetAccount': '+993$phoneText (${packages[selectedPackageIndex!]['label']})',
                            'amount': packages[selectedPackageIndex!]['price'],
                          });
                          _onSuccessPurchase(ctx, 'package_request_sent'.tr() ?? 'Paket talebi başarıyla iletildi!');
                        } catch (e) {
                          setModalState(() => isProcessing = false);
                          _onErrorPurchase(ctx, e);
                        }
                      },
                      child: isProcessing ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : Text(selectedPackageIndex == null ? 'select_package_btn'.tr() ?? 'Paket Seçin' : 'confirm_with_price'.tr(namedArgs: {'price': '${packages[selectedPackageIndex!]['price']}'}), style: const TextStyle(fontSize: 16)),
                    ),
                  ),
                ],
              ),
            ),
          );
        });
      }
    );
  }

  Color _getServiceColor(String name) {
    final lowerName = name.toLowerCase();
    if (lowerName.contains('tmcell')) return Colors.green;
    if (lowerName.contains('telecom')) return Colors.blue;
    if (lowerName.contains('astu')) return Colors.cyan; 
    if (lowerName.contains('belet')) return Colors.redAccent;
    if (lowerName.contains('alemtv')) return Colors.purple;
    if (lowerName.contains('gb')) return Colors.orange;
    if (lowerName.contains('turkmenistanajan')) return Colors.indigo;
    return Theme.of(context).primaryColor;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text('services'.tr(), style: const TextStyle(fontWeight: FontWeight.bold)),
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: isLoading 
        ? const Center(child: CircularProgressIndicator())
        : CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                sliver: SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('what_do_you_want_to_pay'.tr() ?? 'Neyi ödemek istersiniz?', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                      SizedBox(height: 8),
                      Text('fast_secure_pay'.tr() ?? 'Hızlı, güvenli ve anında ödeme yapın.', style: TextStyle(color: Colors.grey.shade600, fontSize: 14)),
                      SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverGrid(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2, crossAxisSpacing: 16, mainAxisSpacing: 16, childAspectRatio: 0.95
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final srv = services[index];
                      final serviceColor = _getServiceColor(srv['name']);
                      
                      return GestureDetector(
                        onTap: () {
                          final srvName = srv['name'].toString().toLowerCase();
                          if (srvName.contains('gb')) {
                            _showGBPurchaseDialog(srv);
                          } else if (srvName.contains('telecom internet')) {
                            _showTelecomPurchaseDialog(srv);
                          } else if (srvName.contains('astu')) {
                            _showAstuDialog(srv);
                          } else if (srvName.contains('turkmenistanajan')) {
                            _showTurkmenistanaJanDialog(srv);
                          } else if (srvName.contains('alemtv')) {
                            _showAlemTVMenu(srv);
                          } else if (srvName.contains('tmcell') || srvName.contains('beletfilm')) {
                            _showDefaultPurchaseDialog(srv, true); 
                          } else {
                            _showDefaultPurchaseDialog(srv, false);
                          }
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF1E293B) : Colors.white,
                            borderRadius: BorderRadius.circular(24),
                            boxShadow: [
                              BoxShadow(
                                color: serviceColor.withOpacity(isDark ? 0.1 : 0.15),
                                blurRadius: 12,
                                offset: const Offset(0, 6),
                              )
                            ]
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(18),
                                decoration: BoxDecoration(
                                  color: serviceColor.withOpacity(0.15), 
                                  shape: BoxShape.circle
                                ),
                                child: FaIcon(_getServiceIcon(srv['name']), size: 32, color: serviceColor),
                              ),
                              SizedBox(height: 16),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                                child: Text(
                                  srv['name'], 
                                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15), 
                                  textAlign: TextAlign.center,
                                  maxLines: 2,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                    childCount: services.length,
                  ),
                ),
              )
            ],
          ),
    );
  }
}