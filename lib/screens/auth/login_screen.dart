import 'package:flutter/material.dart';
import 'package:sign_in_button/sign_in_button.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ezinvoice/screens/app_scaffold.dart';
import 'package:ezinvoice/screens/setup/first_time_setup_screen.dart';
import 'package:ezinvoice/providers/company_provider.dart';
import 'package:ezinvoice/providers/client_provider.dart';
import 'package:ezinvoice/providers/invoice_provider.dart';

const _blue = Color(0xFF1877F2);

class _AppEntry extends ConsumerWidget {
  const _AppEntry();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ref.watch(companyListProvider).when(
      loading: () => Scaffold(
        backgroundColor: isDark ? const Color(0xFF0A0A0A) : Colors.white,
        body: const Center(child: CircularProgressIndicator(color: _blue)),
      ),
      error: (e, _) => Scaffold(body: Center(child: Text('Error: $e'))),
      data: (companies) => companies.isNotEmpty ? const AppScaffold() : const FirstTimeSetupScreen(),
    );
  }
}

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});
  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> with SingleTickerProviderStateMixin {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  bool loading = false;
  bool isLogin = true;
  bool obscurePassword = true;

  late AnimationController _controller;
  late Animation<double> _fadeIn;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _fadeIn = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  void _navigateToApp() {
    if (!mounted) return;
    ref.invalidate(companyListProvider);
    ref.invalidate(clientListProvider);
    ref.invalidate(invoiceListProvider);
    Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const _AppEntry()), (route) => false);
  }

  String? _validatePassword(String password) {
    if (password.length < 8) return 'Password must be at least 8 characters';
    if (!password.contains(RegExp(r'[A-Z]'))) return 'Password must contain at least one uppercase letter';
    if (!password.contains(RegExp(r'[0-9]'))) return 'Password must contain at least one number';
    if (!password.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>_\-+=\[\]\\;'+"'"+r'/`~]'))) return 'Password must contain at least one symbol';
    return null;
  }

  Future<void> handleEmailAuth() async {
    if (emailController.text.trim().isEmpty || passwordController.text.trim().isEmpty) {
      _showError('Please enter email and password'); return;
    }

    // Only validate password strength on signup
    if (!isLogin) {
      final passwordError = _validatePassword(passwordController.text.trim());
      if (passwordError != null) {
        _showError(passwordError); return;
      }
    }

    setState(() => loading = true);
    try {
      if (isLogin) {
        await FirebaseAuth.instance.signInWithEmailAndPassword(
            email: emailController.text.trim(), password: passwordController.text.trim());
      } else {
        await FirebaseAuth.instance.createUserWithEmailAndPassword(
            email: emailController.text.trim(), password: passwordController.text.trim());
      }
      _navigateToApp();
    } on FirebaseAuthException catch (e) {
      _showError(e.message ?? 'Authentication failed');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> loginWithGoogle() async {
    setState(() => loading = true);
    try {
      final googleSignIn = GoogleSignIn();
      await googleSignIn.signOut();
      final googleUser = await googleSignIn.signIn();
      if (googleUser == null) { setState(() => loading = false); return; }
      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken, idToken: googleAuth.idToken);
      await FirebaseAuth.instance.signInWithCredential(credential);
      _navigateToApp();
    } catch (e) {
      _showError('Google sign-in failed. Try again.');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg), backgroundColor: Colors.red,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF0A0A0A) : Colors.white;
    final textPrimary = isDark ? Colors.white : const Color(0xFF0D0D0D);
    final textSub = isDark ? Colors.white.withValues(alpha: 0.4) : Colors.black.withValues(alpha: 0.45);
    final fieldBg = isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.04);
    final fieldBorder = isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.10);
    final iconColor = isDark ? Colors.white.withValues(alpha: 0.3) : Colors.black.withValues(alpha: 0.3);
    final hintColor = isDark ? Colors.white.withValues(alpha: 0.25) : Colors.black.withValues(alpha: 0.3);
    final inputText = isDark ? Colors.white : const Color(0xFF0D0D0D);
    final dividerColor = isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.1);
    final orText = isDark ? Colors.white.withValues(alpha: 0.3) : Colors.black.withValues(alpha: 0.35);
    final backBg = isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.05);
    final backIcon = isDark ? Colors.white : Colors.black;
    final labelColor = isDark ? Colors.white.withValues(alpha: 0.5) : Colors.black.withValues(alpha: 0.5);

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeIn,
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 40),

                // Back button
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    width: 42, height: 42,
                    decoration: BoxDecoration(color: backBg, borderRadius: BorderRadius.circular(12)),
                    child: Icon(Icons.arrow_back_rounded, color: backIcon, size: 20),
                  ),
                ),

                const SizedBox(height: 36),

                Text(
                  isLogin ? 'Welcome\nback 👋' : 'Create your\naccount ✨',
                  style: TextStyle(fontSize: 36, fontWeight: FontWeight.w800, color: textPrimary, height: 1.15, letterSpacing: -1.2),
                ),

                const SizedBox(height: 10),

                Text(
                  isLogin ? 'Sign in to continue to Origin' : 'Start creating invoices for free',
                  style: TextStyle(color: textSub, fontSize: 15),
                ),

                const SizedBox(height: 40),

                _label('Email', labelColor),
                const SizedBox(height: 8),
                _field(controller: emailController, hint: 'you@example.com', icon: Icons.mail_outline_rounded,
                    keyboardType: TextInputType.emailAddress, fieldBg: fieldBg, fieldBorder: fieldBorder,
                    iconColor: iconColor, hintColor: hintColor, inputText: inputText),

                const SizedBox(height: 20),

                _label('Password', labelColor),
                const SizedBox(height: 8),
                _field(
                  controller: passwordController, hint: '••••••••', icon: Icons.lock_outline_rounded,
                  obscure: obscurePassword, fieldBg: fieldBg, fieldBorder: fieldBorder,
                  iconColor: iconColor, hintColor: hintColor, inputText: inputText,
                  suffixIcon: IconButton(
                    icon: Icon(obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                        color: iconColor, size: 20),
                    onPressed: () => setState(() => obscurePassword = !obscurePassword),
                  ),
                ),

                // Password requirements hint shown only on signup
                if (!isLogin) ...[
                  const SizedBox(height: 10),
                  Text(
                    '• At least 8 characters  • One uppercase letter\n• One number  • One symbol',
                    style: TextStyle(fontSize: 12, color: textSub, height: 1.6),
                  ),
                ],

                const SizedBox(height: 32),

                SizedBox(
                  width: double.infinity, height: 56,
                  child: ElevatedButton(
                    onPressed: loading ? null : handleEmailAuth,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _blue, foregroundColor: Colors.white,
                      disabledBackgroundColor: _blue.withValues(alpha: 0.5),
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: loading
                        ? const SizedBox(width: 22, height: 22,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                        : Text(isLogin ? 'Sign In' : 'Create Account',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, letterSpacing: 0.3)),
                  ),
                ),

                const SizedBox(height: 16),

                Center(
                  child: GestureDetector(
                    onTap: () => setState(() => isLogin = !isLogin),
                    child: RichText(
                      text: TextSpan(
                        style: TextStyle(color: textSub, fontSize: 14),
                        children: [
                          TextSpan(text: isLogin ? "Don't have an account? " : 'Already have an account? '),
                          TextSpan(text: isLogin ? 'Sign Up' : 'Sign In',
                              style: const TextStyle(color: _blue, fontWeight: FontWeight.w700)),
                        ],
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 32),

                Row(children: [
                  Expanded(child: Divider(color: dividerColor, thickness: 1)),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text('or continue with', style: TextStyle(color: orText, fontSize: 13)),
                  ),
                  Expanded(child: Divider(color: dividerColor, thickness: 1)),
                ]),

                const SizedBox(height: 24),

                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: SignInButton(
                    Buttons.google,
                    text: 'Continue with Google',
                    onPressed: loading ? () {} : loginWithGoogle,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                  ),
                ),

                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _label(String text, Color color) => Text(text,
      style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w600, letterSpacing: 0.5));

  Widget _field({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    required Color fieldBg,
    required Color fieldBorder,
    required Color iconColor,
    required Color hintColor,
    required Color inputText,
    bool obscure = false,
    TextInputType? keyboardType,
    Widget? suffixIcon,
  }) {
    return Container(
      decoration: BoxDecoration(
          color: fieldBg, borderRadius: BorderRadius.circular(14),
          border: Border.all(color: fieldBorder)),
      child: TextField(
        controller: controller, obscureText: obscure, keyboardType: keyboardType,
        style: TextStyle(color: inputText, fontSize: 15),
        decoration: InputDecoration(
          hintText: hint, hintStyle: TextStyle(color: hintColor, fontSize: 15),
          prefixIcon: Icon(icon, color: iconColor, size: 20),
          suffixIcon: suffixIcon, border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
      ),
    );
  }
}
