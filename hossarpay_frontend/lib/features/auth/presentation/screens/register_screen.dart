import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../providers/auth_provider.dart';
import '../../../../core/network/api_client.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final fnameCtrl = TextEditingController();
  final lnameCtrl = TextEditingController();
  final passCtrl = TextEditingController();
  final emailCtrl = TextEditingController();
  final refCtrl = TextEditingController();
  final codeCtrl = TextEditingController();

  bool _isPasswordVisible = false;
  bool _showRefCode = false;
  
  bool _isCodeSent = false;
  bool _isSendingCode = false;
  int _countdown = 120;
  
  void _startTimer() {
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted) return false;
      setState(() {
        if (_countdown > 0) {
          _countdown--;
        }
      });
      return _countdown > 0;
    });
  }
  
  Future<void> _sendCode() async {
    final email = emailCtrl.text.trim();
    if (!email.contains('@')) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('invalid_email'.tr() ?? 'Lütfen geçerli bir e-posta girin.'), backgroundColor: Colors.redAccent));
      return;
    }
    
    setState(() { _isSendingCode = true; });
    try {
      final dio = await ApiClient.client;
      await dio.post('/auth/email-code', data: {'email': email});
      setState(() {
        _isCodeSent = true;
        _countdown = 120;
        _isSendingCode = false;
      });
      _startTimer();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('code_sent'.tr() ?? 'Doğrulama kodu e-postanıza gönderildi.'), backgroundColor: Colors.green));
    } catch (e) {
      setState(() { _isSendingCode = false; });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('code_failed'.tr() ?? 'Kod gönderilemedi. Bu e-posta kullanımda olabilir.'), backgroundColor: Colors.redAccent));
    }
  }

  void _register() {
    final fname = fnameCtrl.text.trim();
    final lname = lnameCtrl.text.trim();
    final email = emailCtrl.text.trim();
    final pass = passCtrl.text.trim();
    final refCode = refCtrl.text.trim();
    final code = codeCtrl.text.trim();

    if (fname.isEmpty || lname.isEmpty || email.isEmpty || pass.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('fill_all_fields'.tr()), backgroundColor: Colors.redAccent));
      return;
    }
    
    if (!_isCodeSent) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('verify_email'.tr() ?? 'Lütfen e-postanızı doğrulayın!'), backgroundColor: Colors.redAccent));
      return;
    }
    
    if (code.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('enter_code'.tr() ?? 'Lütfen size gönderilen kodu girin.'), backgroundColor: Colors.redAccent));
      return;
    }

    if (pass.length < 8) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('pass_min_8'.tr()), backgroundColor: Colors.redAccent));
      return;
    }

    final nameRegex = RegExp(r"^[a-zA-ZğüşıöçĞÜŞİÖÇÄäŽžŇňÝýА-Яа-я\s]{2,50}$");
    if (!nameRegex.hasMatch(fname) || !nameRegex.hasMatch(lname)) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('invalid_name'.tr()), backgroundColor: Colors.redAccent));
      return;
    }

    // Takma ad kayıtta istenmez; profilden eklenecek. Telefon numarasi bos gidiyor, profil kismindan guncellenecek.
    ref.read(authProvider.notifier).registerAdvanced(fname, lname, null, pass, email, refCode, code);
  }

  void _googleSignIn() {
    ref.read(authProvider.notifier).googleLogin();
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    ref.listen<AuthState>(authProvider, (previous, next) {
      if (next.isAuthenticated) context.go('/home');
      if (next.error != null) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(next.error!), backgroundColor: Colors.redAccent));
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: Text('register'.tr() ?? 'Kayıt Ol', style: const TextStyle(fontWeight: FontWeight.bold)),
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: Stack(
        children: [
          Positioned(
            top: -50, right: -50,
            child: Container(width: 200, height: 200, decoration: BoxDecoration(shape: BoxShape.circle, color: Theme.of(context).primaryColor.withOpacity(0.1))),
          ),
          Positioned(
            bottom: -50, left: -50,
            child: Container(width: 200, height: 200, decoration: BoxDecoration(shape: BoxShape.circle, color: Theme.of(context).colorScheme.secondary.withOpacity(0.1))),
          ),
          
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 16.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(color: Theme.of(context).primaryColor.withOpacity(0.1), shape: BoxShape.circle),
                      child: Icon(Icons.person_add_alt_1, size: 48, color: Theme.of(context).primaryColor),
                    ),
                    const SizedBox(height: 24),
                    Text('join_us'.tr(), style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, letterSpacing: -0.5), textAlign: TextAlign.center),
                    const SizedBox(height: 8),
                    Text('financial_freedom'.tr(), style: TextStyle(fontSize: 14, color: Colors.grey.shade600, fontWeight: FontWeight.w500), textAlign: TextAlign.center),
                    const SizedBox(height: 32),
                    
                    Container(
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E293B) : Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20, offset: const Offset(0, 10))]
                      ),
                      child: Column(
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                            child: TextField(
                              controller: fnameCtrl,
                              textCapitalization: TextCapitalization.words,
                              decoration: InputDecoration(
                                labelText: 'first_name'.tr() ?? 'Ad',
                                prefixIcon: Icon(Icons.person_outline, color: Theme.of(context).primaryColor),
                                border: InputBorder.none, enabledBorder: InputBorder.none, focusedBorder: InputBorder.none,
                              ),
                            ),
                          ),
                          Divider(height: 1, color: Colors.grey.withOpacity(0.2), indent: 16, endIndent: 16),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                            child: TextField(
                              controller: lnameCtrl,
                              textCapitalization: TextCapitalization.words,
                              decoration: InputDecoration(
                                labelText: 'last_name'.tr() ?? 'Soyad',
                                prefixIcon: Icon(Icons.badge_outlined, color: Theme.of(context).primaryColor),
                                border: InputBorder.none, enabledBorder: InputBorder.none, focusedBorder: InputBorder.none,
                              ),
                            ),
                          ),
                          Divider(height: 1, color: Colors.grey.withOpacity(0.2), indent: 16, endIndent: 16),
                          
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                            child: Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: emailCtrl,
                                    keyboardType: TextInputType.emailAddress,
                                    decoration: InputDecoration(
                                      labelText: 'email_label'.tr() ?? 'E-posta',
                                      prefixIcon: Icon(Icons.email_outlined, color: Theme.of(context).primaryColor),
                                      border: InputBorder.none, enabledBorder: InputBorder.none, focusedBorder: InputBorder.none,
                                    ),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.only(right: 8.0),
                                  child: TextButton(
                                    onPressed: (_isCodeSent && _countdown > 0) || _isSendingCode ? null : _sendCode,
                                    child: _isSendingCode 
                                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                                      : Text((_isCodeSent && _countdown > 0) ? 'countdown_s'.tr(namedArgs: {'s': '$_countdown'}) : 'code_send'.tr() ?? 'Kod Gönder'),
                                  ),
                                )
                              ],
                            ),
                          ),
                          Divider(height: 1, color: Colors.grey.withOpacity(0.2), indent: 16, endIndent: 16),
                          
                          if (_isCodeSent) ...[
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                              child: TextField(
                                controller: codeCtrl,
                                keyboardType: TextInputType.number,
                                decoration: InputDecoration(
                                  labelText: 'code_label'.tr() ?? 'Doğrulama Kodu',
                                  prefixIcon: Icon(Icons.verified_user_outlined, color: Theme.of(context).primaryColor),
                                  border: InputBorder.none, enabledBorder: InputBorder.none, focusedBorder: InputBorder.none,
                                ),
                              ),
                            ),
                            Divider(height: 1, color: Colors.grey.withOpacity(0.2), indent: 16, endIndent: 16),
                          ],
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                            child: TextField(
                              controller: passCtrl,
                              obscureText: !_isPasswordVisible,
                              decoration: InputDecoration(
                                labelText: 'password'.tr() ?? 'Şifre (En az 8 karakter)',
                                prefixIcon: Icon(Icons.lock_outline, color: Theme.of(context).primaryColor),
                                suffixIcon: IconButton(
                                  icon: Icon(_isPasswordVisible ? Icons.visibility : Icons.visibility_off, color: Colors.grey),
                                  onPressed: () => setState(() => _isPasswordVisible = !_isPasswordVisible),
                                ),
                                border: InputBorder.none, enabledBorder: InputBorder.none, focusedBorder: InputBorder.none,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // Katlanabilir Davet Kodu Alanı (İsteğe Bağlı)
                    GestureDetector(
                      onTap: () => setState(() => _showRefCode = !_showRefCode),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(_showRefCode ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down, size: 16, color: Colors.grey.shade600),
                          const SizedBox(width: 4),
                          Text('referral_title'.tr() ?? 'Davet Kodunuz Var mı? (İsteğe Bağlı)', style: TextStyle(color: Colors.grey.shade600, fontSize: 13, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                    
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                      height: _showRefCode ? 60 : 0,
                      margin: EdgeInsets.only(top: _showRefCode ? 12 : 0),
                      child: ClipRect(
                        child: TextField(
                          controller: refCtrl,
                          decoration: InputDecoration(
                            hintText: 'referral_hint'.tr() ?? 'Kodu buraya girin',
                            filled: true,
                            fillColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                          ),
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 24),
                    
                    SizedBox(
                      height: 56,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                          elevation: 8,
                          shadowColor: Theme.of(context).primaryColor.withOpacity(0.5)
                        ),
                        onPressed: authState.isLoading ? null : _register,
                        child: authState.isLoading 
                            ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(strokeWidth: 3, color: Colors.white))
                            : Text('register'.tr() ?? 'Kayıt Ol', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      ),
                    ),
                    
                    const SizedBox(height: 20),
                    
                    // GOOGLE İLE GİRİŞ BUTONU
                    SizedBox(
                      height: 56,
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                          side: BorderSide(color: Colors.grey.withOpacity(0.3)),
                        ),
                        onPressed: _googleSignIn,
                        icon: Image.asset('assets/images/google_g.png', width: 20, height: 20),
                        label: Text('google_continue'.tr() ?? 'Google ile Devam Et', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Theme.of(context).textTheme.bodyMedium?.color)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}