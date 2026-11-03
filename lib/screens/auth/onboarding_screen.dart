import 'package:flutter/material.dart';
import 'login_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeIn;
  late Animation<Offset> _slideUp;

  static const _blue = Color(0xFF1877F2);

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200));
    _fadeIn = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _slideUp = Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero)
        .animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF0A0A0A) : Colors.white;
    final textPrimary = isDark ? Colors.white : const Color(0xFF0D0D0D);
    final textSub = isDark ? Colors.white.withValues(alpha: 0.45) : Colors.black.withValues(alpha: 0.45);
    final pillBg = isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.05);
    final pillBorder = isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.10);
    final pillText = isDark ? Colors.white.withValues(alpha: 0.7) : Colors.black.withValues(alpha: 0.6);
    final madeBy = isDark ? Colors.white.withValues(alpha: 0.35) : Colors.black.withValues(alpha: 0.75);

    return Scaffold(
      backgroundColor: bg,
      body: Stack(
        children: [
          Positioned(
            top: -100, right: -100,
            child: Container(
              width: 350, height: 350,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(colors: [_blue.withValues(alpha: 0.12), Colors.transparent]),
              ),
            ),
          ),
          Positioned(
            bottom: 100, left: -80,
            child: Container(
              width: 250, height: 250,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(colors: [_blue.withValues(alpha: 0.07), Colors.transparent]),
              ),
            ),
          ),
          SafeArea(
            child: FadeTransition(
              opacity: _fadeIn,
              child: SlideTransition(
                position: _slideUp,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 28),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 60),

                      // ✅ Bigger icon — 90x90 with less padding so logo fills more space
                      Container(
                        width: 90,
                        height: 90,
                        decoration: BoxDecoration(
                          color: _blue,
                          borderRadius: BorderRadius.circular(22),
                          boxShadow: [BoxShadow(color: _blue.withValues(alpha: 0.35), blurRadius: 20, offset: const Offset(0, 8))],
                        ),
                        padding: const EdgeInsets.all(6),
                        child: Image.asset('assets/icons/ezinvoice.png', fit: BoxFit.contain),
                      ),

                      const SizedBox(height: 40),

                      Text('Invoicing,\nMade Simple.',
                          style: TextStyle(fontSize: 42, fontWeight: FontWeight.w800, color: textPrimary, height: 1.1, letterSpacing: -1.5)),

                      const SizedBox(height: 20),

                      Text('Create GST invoices, manage clients\n— all in one place.',
                          style: TextStyle(fontSize: 16, color: textSub, height: 1.6, letterSpacing: 0.1)),

                      const Spacer(),

                      Row(
                        children: [
                          _pill(Icons.bolt_rounded, 'Fast', pillBg, pillBorder, pillText),
                          const SizedBox(width: 10),
                          _pill(Icons.cloud_done_rounded, 'Cloud Sync', pillBg, pillBorder, pillText),
                          const SizedBox(width: 10),
                          _pill(Icons.picture_as_pdf_rounded, 'PDF', pillBg, pillBorder, pillText),
                        ],
                      ),

                      const SizedBox(height: 32),

                      SizedBox(
                        width: double.infinity,
                        height: 58,
                        child: ElevatedButton(
                          onPressed: () => Navigator.push(context,
                              PageRouteBuilder(
                                pageBuilder: (_, a, b) => const LoginScreen(),
                                transitionsBuilder: (_, anim, __, child) => FadeTransition(opacity: anim, child: child),
                                transitionDuration: const Duration(milliseconds: 400),
                              )),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _blue, foregroundColor: Colors.white, elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text('Get Started', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, letterSpacing: 0.3)),
                              SizedBox(width: 8),
                              Icon(Icons.arrow_forward_rounded, size: 20),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 20),
                      Center(child: Text('Made with ❤️ by Dheeraj', style: TextStyle(color: madeBy, fontSize: 13))),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _pill(IconData icon, String label, Color bg, Color border, Color textColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(30), border: Border.all(color: border)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 15, color: _blue),
        const SizedBox(width: 6),
        Text(label, style: TextStyle(color: textColor, fontSize: 13, fontWeight: FontWeight.w500)),
      ]),
    );
  }
}
