// lib/pages/login_page.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../widgets/top_banner.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _auth = FirebaseAuth.instance;
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController(); // فیلد جدید
  final _resetEmailController = TextEditingController();
  bool _isLogin = true;
  bool _loading = false;

  String? _passwordError; // خطای رمز فارسی

  Future<void> _submit() async {
    // validation رمز عبور
    if (!_isLogin) {
      if (_passwordController.text.length < 6) {
        showTopBanner(
          context,
          "رمز عبور باید حداقل 6 کاراکتر باشد",
          isError: true,
          duration: const Duration(seconds: 6),
        );
        return;
      }
      if (_passwordController.text != _confirmPasswordController.text) {
        showTopBanner(
          context,
          "رمزهای عبور مطابقت ندارند",
          isError: true,
          duration: const Duration(seconds: 6),
        );
        return;
      }
    }

    setState(() => _loading = true);
    try {
      if (_isLogin) {
        await _auth.signInWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );
        showTopBanner(
          context,
          "ورود موفق",
          isError: false,
          duration: const Duration(seconds: 6),
        );
        Navigator.pop(context);
      } else {
        // چک تکراری
        try {
          await _auth.signInWithEmailAndPassword(
            email: _emailController.text.trim(),
            password: _passwordController.text.trim(),
          );
          showTopBanner(
            context,
            "این ایمیل قبلاً ثبت شده است. از ورود استفاده کنید.",
            isError: true,
            duration: const Duration(seconds: 6),
          );
          setState(() => _isLogin = true);
          return;
        } catch (e) {
          await _auth.createUserWithEmailAndPassword(
            email: _emailController.text.trim(),
            password: _passwordController.text.trim(),
          );
          showTopBanner(
            context,
            "حساب با موفقیت ایجاد شد",
            isError: false,
            duration: const Duration(seconds: 6),
          );
          Navigator.pop(context);
        }
      }
    } on FirebaseAuthException catch (e) {
      String msg;
      switch (e.code) {
        case 'user-not-found':
          msg = 'کاربر یافت نشد';
          break;
        case 'wrong-password':
          msg = 'رمز عبور اشتباه است';
          break;
        case 'invalid-email':
          msg = 'ایمیل نامعتبر است';
          break;
        case 'email-already-in-use':
          msg = 'این ایمیل قبلاً استفاده شده';
          break;
        case 'weak-password':
          msg = 'رمز عبور ضعیف است';
          break;
        default:
          msg = e.message ?? 'خطای ناشناخته';
      }
      showTopBanner(
        context,
        msg,
        isError: true,
        duration: const Duration(seconds: 15),
      );
    } catch (e) {
      showTopBanner(
        context,
        "خطای غیرمنتظره: $e",
        isError: true,
        duration: const Duration(seconds: 15),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _resetPassword() async {
    if (_resetEmailController.text.trim().isEmpty) {
      showTopBanner(
        context,
        "لطفاً ایمیل خود را وارد کنید",
        isError: true,
        duration: const Duration(seconds: 6),
      );
      return;
    }
    setState(() => _loading = true);
    try {
      await _auth.sendPasswordResetEmail(
        email: _resetEmailController.text.trim(),
      );
      showTopBanner(
        context,
        "ایمیل بازنشانی رمز عبور ارسال شد",
        isError: false,
        duration: const Duration(seconds: 6),
      );
      Navigator.pop(context);
    } on FirebaseAuthException catch (e) {
      String msg;
      switch (e.code) {
        case 'invalid-email':
          msg = 'ایمیل نامعتبر است';
          break;
        default:
          msg = e.message ?? 'خطا در ارسال ایمیل';
      }
      showTopBanner(
        context,
        msg,
        isError: true,
        duration: const Duration(seconds: 15),
      );
    } catch (e) {
      showTopBanner(
        context,
        "خطای غیرمنتظره: $e",
        isError: true,
        duration: const Duration(seconds: 15),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showResetPasswordDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('بازنشانی رمز عبور'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _resetEmailController,
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.email),
                labelText: "ایمیل",
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('لغو'),
          ),
          ElevatedButton(
            onPressed: _resetPassword,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0F7CFF),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('ارسال ایمیل'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _resetEmailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0F7CFF), Color(0xFFEF476F)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Card(
                elevation: 12,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(22.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // back button
                      Align(
                        alignment: Alignment.topRight,
                        child: IconButton(
                          icon: const Icon(Icons.arrow_back),
                          onPressed: () => Navigator.pop(context),
                          tooltip: 'بازگشت',
                        ),
                      ),
                      // logo area
                      Image.asset('assets/uni.png', height: 76, width: 76),
                      const SizedBox(height: 8),
                      Text(
                        _isLogin
                            ? "به حساب خود وارد شوید"
                            : "یک حساب جدید بسازید",
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 18),

                      // email
                      TextField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: InputDecoration(
                          prefixIcon: const Icon(Icons.email),
                          labelText: "ایمیل",
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // password
                      TextField(
                        controller: _passwordController,
                        obscureText: true,
                        decoration: InputDecoration(
                          prefixIcon: const Icon(Icons.lock),
                          labelText: "رمز عبور",
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                      // confirm password (فقط در حالت ثبت‌نام)
                      if (!_isLogin) ...[
                        const SizedBox(height: 12),
                        TextField(
                          controller: _confirmPasswordController,
                          obscureText: true,
                          decoration: InputDecoration(
                            prefixIcon: const Icon(Icons.lock_outline),
                            labelText: "تکرار رمز عبور",
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 18),

                      // submit
                      SizedBox(
                        width: double.infinity,
                        child: _loading
                            ? const Center(child: CircularProgressIndicator())
                            : ElevatedButton(
                                onPressed: _submit,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF0F7CFF),
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 14,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: Text(
                                  _isLogin ? "ورود" : "ثبت‌نام",
                                  style: const TextStyle(fontSize: 16),
                                ),
                              ),
                      ),

                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          TextButton(
                            onPressed: () =>
                                setState(() => _isLogin = !_isLogin),
                            child: Text(
                              _isLogin
                                  ? "حساب نداری؟ ثبت‌نام کن"
                                  : "قبلاً حساب داری؟ وارد شو",
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      TextButton(
                        onPressed: _showResetPasswordDialog,
                        child: const Text("فراموشی رمز؟"),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
