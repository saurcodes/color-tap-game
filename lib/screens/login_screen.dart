import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/auth_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with TickerProviderStateMixin {
  final AuthService _authService = AuthService();
  bool _isLoading = false;
  String? _errorMessage;

  late AnimationController _floatingController;
  late AnimationController _pulseController;
  late List<FloatingCircle> _floatingCircles;

  @override
  void initState() {
    super.initState();

    _floatingController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    )..repeat();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _floatingCircles = List.generate(15, (index) => FloatingCircle.random());
  }

  @override
  void dispose() {
    _floatingController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _handleGoogleSignIn() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await _authService.signInWithGoogle();
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to sign in. Please try again.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isWide = size.width > 600;

    return Scaffold(
      body: Stack(
        children: [
          // Background gradient
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF0A0E21),
                  Color(0xFF1D1E33),
                  Color(0xFF0A0E21),
                ],
                stops: [0.0, 0.5, 1.0],
              ),
            ),
          ),

          // Floating animated circles
          AnimatedBuilder(
            animation: _floatingController,
            builder: (context, child) {
              return CustomPaint(
                size: size,
                painter: FloatingCirclesPainter(
                  circles: _floatingCircles,
                  animationValue: _floatingController.value,
                ),
              );
            },
          ),

          // Main content
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(
                  horizontal: isWide ? size.width * 0.2 : 32,
                  vertical: 32,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Animated logo/icon
                    AnimatedBuilder(
                      animation: _pulseController,
                      builder: (context, child) {
                        return Transform.scale(
                          scale: 1.0 + (_pulseController.value * 0.05),
                          child: Container(
                            width: 120,
                            height: 120,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: const LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  Color(0xFF6C63FF),
                                  Color(0xFFFF6584),
                                ],
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF6C63FF).withAlpha(
                                    (100 + _pulseController.value * 50).toInt(),
                                  ),
                                  blurRadius: 30,
                                  spreadRadius: 5,
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.touch_app_rounded,
                              size: 60,
                              color: Colors.white,
                            ),
                          ),
                        );
                      },
                    ),

                    const SizedBox(height: 40),

                    // Game title
                    ShaderMask(
                      shaderCallback: (bounds) => const LinearGradient(
                        colors: [
                          Color(0xFF6C63FF),
                          Color(0xFFFF6584),
                          Color(0xFFFFBE0B),
                        ],
                      ).createShader(bounds),
                      child: Text(
                        'COLOR TAP',
                        style: GoogleFonts.poppins(
                          fontSize: isWide ? 56 : 42,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: 4,
                        ),
                      ),
                    ),

                    const SizedBox(height: 8),

                    Text(
                      'Test your reflexes!',
                      style: GoogleFonts.poppins(
                        fontSize: isWide ? 20 : 16,
                        color: Colors.white60,
                        letterSpacing: 2,
                      ),
                    ),

                    const SizedBox(height: 60),

                    // Feature cards
                    Wrap(
                      spacing: 16,
                      runSpacing: 16,
                      alignment: WrapAlignment.center,
                      children: [
                        _buildFeatureChip(
                          Icons.speed_rounded,
                          'Fast Paced',
                          const Color(0xFF6C63FF),
                        ),
                        _buildFeatureChip(
                          Icons.leaderboard_rounded,
                          'Leaderboard',
                          const Color(0xFFFF6584),
                        ),
                        _buildFeatureChip(
                          Icons.trending_up_rounded,
                          'Level Up',
                          const Color(0xFFFFBE0B),
                        ),
                      ],
                    ),

                    const SizedBox(height: 60),

                    // Google Sign In Button
                    _buildSignInButton(),

                    if (_errorMessage != null) ...[
                      const SizedBox(height: 20),
                      _buildErrorMessage(),
                    ],

                    const SizedBox(height: 40),

                    // Footer
                    Text(
                      'Sign in to save your scores',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: Colors.white38,
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

  Widget _buildFeatureChip(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: color.withAlpha(30),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: color.withAlpha(100), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 8),
          Text(
            label,
            style: GoogleFonts.poppins(
              color: color,
              fontWeight: FontWeight.w500,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSignInButton() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _isLoading ? null : _handleGoogleSignIn,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 18),
            decoration: BoxDecoration(
              gradient: _isLoading
                  ? null
                  : const LinearGradient(
                      colors: [Color(0xFF6C63FF), Color(0xFF5A52E0)],
                    ),
              color: _isLoading ? const Color(0xFF1D1E33) : null,
              borderRadius: BorderRadius.circular(16),
              boxShadow: _isLoading
                  ? null
                  : [
                      BoxShadow(
                        color: const Color(0xFF6C63FF).withAlpha(100),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_isLoading)
                  const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Color(0xFF6C63FF),
                    ),
                  )
                else
                  Image.network(
                    'https://www.google.com/favicon.ico',
                    width: 24,
                    height: 24,
                    errorBuilder: (context, error, stackTrace) =>
                        const Icon(Icons.login, color: Colors.white),
                  ),
                const SizedBox(width: 16),
                Text(
                  _isLoading ? 'Signing in...' : 'Continue with Google',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildErrorMessage() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFF4757).withAlpha(30),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFFFF4757).withAlpha(100),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.error_outline,
            color: Color(0xFFFF4757),
            size: 20,
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              _errorMessage!,
              style: GoogleFonts.poppins(
                color: const Color(0xFFFF4757),
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Floating circle model
class FloatingCircle {
  final double x;
  final double y;
  final double radius;
  final Color color;
  final double speed;
  final double phase;

  FloatingCircle({
    required this.x,
    required this.y,
    required this.radius,
    required this.color,
    required this.speed,
    required this.phase,
  });

  factory FloatingCircle.random() {
    final random = Random();
    final colors = [
      const Color(0xFF6C63FF),
      const Color(0xFFFF6584),
      const Color(0xFFFFBE0B),
      const Color(0xFF00D9FF),
      const Color(0xFF00FF88),
    ];
    return FloatingCircle(
      x: random.nextDouble(),
      y: random.nextDouble(),
      radius: 20 + random.nextDouble() * 60,
      color: colors[random.nextInt(colors.length)].withAlpha(40),
      speed: 0.2 + random.nextDouble() * 0.5,
      phase: random.nextDouble() * 2 * pi,
    );
  }
}

// Painter for floating circles
class FloatingCirclesPainter extends CustomPainter {
  final List<FloatingCircle> circles;
  final double animationValue;

  FloatingCirclesPainter({
    required this.circles,
    required this.animationValue,
  });

  @override
  void paint(Canvas canvas, Size size) {
    for (final circle in circles) {
      final progress = (animationValue * circle.speed + circle.phase) % 1.0;
      final x = circle.x * size.width +
          sin(progress * 2 * pi) * 30;
      final y = (circle.y + progress) % 1.0 * size.height;

      final paint = Paint()
        ..color = circle.color
        ..style = PaintingStyle.fill;

      canvas.drawCircle(Offset(x, y), circle.radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant FloatingCirclesPainter oldDelegate) =>
      animationValue != oldDelegate.animationValue;
}
