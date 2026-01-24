import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/game_circle.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';

class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> with TickerProviderStateMixin {
  final AuthService _authService = AuthService();
  final FirestoreService _firestoreService = FirestoreService();
  final Random _random = Random();

  // Game state
  List<GameCircle> circles = [];
  Color targetColor = Colors.red;
  int score = 0;
  int level = 1;
  int timeRemaining = 60;
  bool isGameActive = false;
  int personalBest = 0;
  int combo = 0;
  int maxCombo = 0;

  Timer? gameTimer;
  Timer? spawnTimer;

  // Animation controllers
  late AnimationController _scoreAnimController;
  late AnimationController _pulseController;
  late Animation<double> _scoreAnimation;

  // Available colors with modern palette
  final List<Color> availableColors = [
    const Color(0xFFFF6B6B), // Red
    const Color(0xFF4ECDC4), // Teal
    const Color(0xFFFFE66D), // Yellow
    const Color(0xFF6C63FF), // Purple
    const Color(0xFFFF6584), // Pink
    const Color(0xFF00D9FF), // Cyan
    const Color(0xFF00FF88), // Green
  ];

  @override
  void initState() {
    super.initState();
    _loadPersonalBest();

    _scoreAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _scoreAnimation = Tween<double>(begin: 1.0, end: 1.3).animate(
      CurvedAnimation(parent: _scoreAnimController, curve: Curves.elasticOut),
    );

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);
  }

  Future<void> _loadPersonalBest() async {
    final user = _authService.currentUser;
    if (user != null) {
      final best = await _firestoreService.getUserBestScore(user.uid);
      setState(() {
        personalBest = best;
      });
    }
  }

  void startGame() {
    setState(() {
      circles.clear();
      score = 0;
      level = 1;
      timeRemaining = 60;
      isGameActive = true;
      combo = 0;
      maxCombo = 0;
      targetColor = availableColors[_random.nextInt(availableColors.length)];
    });

    gameTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        timeRemaining--;
        if (timeRemaining <= 0) {
          endGame();
        }
      });
    });

    _scheduleNextSpawn();
  }

  void _scheduleNextSpawn() {
    if (!isGameActive) return;

    final spawnDelay = max(300, 1500 - (level * 100));

    spawnTimer = Timer(Duration(milliseconds: spawnDelay), () {
      if (isGameActive) {
        spawnCircle();
        _scheduleNextSpawn();
      }
    });
  }

  void spawnCircle() {
    final size = MediaQuery.of(context).size;
    final isWide = size.width > 600;
    final gameAreaTop = isWide ? 120.0 : 180.0;
    final padding = 60.0;

    final x = padding + _random.nextDouble() * (size.width - padding * 2);
    final y = gameAreaTop +
        padding +
        _random.nextDouble() * (size.height - gameAreaTop - padding * 2 - 100);

    final color = availableColors[_random.nextInt(availableColors.length)];
    final circleRadius = isWide ? 35.0 : 28.0;

    final circle = GameCircle(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      position: Offset(x, y),
      color: color,
      radius: circleRadius,
      spawnTime: DateTime.now(),
    );

    setState(() {
      circles.add(circle);

      Timer(const Duration(seconds: 3), () {
        setState(() {
          circles.removeWhere((c) => c.id == circle.id);
        });
      });
    });
  }

  void onCircleTap(GameCircle circle) {
    if (circle.color == targetColor) {
      _scoreAnimController.forward().then((_) {
        _scoreAnimController.reverse();
      });

      setState(() {
        circles.removeWhere((c) => c.id == circle.id);
        combo++;
        if (combo > maxCombo) maxCombo = combo;

        // Bonus points for combo
        final comboBonus = (combo ~/ 5) * 5;
        final oldScore = score;
        score += 10 + comboBonus;

        // Check if we crossed a level threshold (every 50 points)
        final oldLevel = (oldScore / 50).floor() + 1;
        final newLevel = (score / 50).floor() + 1;

        if (newLevel > level) {
          level = newLevel;
          targetColor = availableColors[_random.nextInt(availableColors.length)];

          // Reset timer for new level
          timeRemaining = 60;

          // Show level complete celebration
          _showLevelCompleteDialog(oldLevel);
        }
      });
    } else {
      setState(() {
        circles.removeWhere((c) => c.id == circle.id);
        score = max(0, score - 5);
        combo = 0;
      });
    }
  }

  void endGame() async {
    setState(() {
      isGameActive = false;
    });

    gameTimer?.cancel();
    spawnTimer?.cancel();

    final user = _authService.currentUser;
    if (user != null) {
      await _firestoreService.saveScore(
        userId: user.uid,
        userName: user.displayName ?? 'Anonymous',
        score: score,
        level: level,
      );

      if (score > personalBest) {
        setState(() {
          personalBest = score;
        });
      }
    }

    if (mounted) {
      _showGameOverDialog();
    }
  }

  void _showLevelCompleteDialog(int completedLevel) {
    showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, anim1, anim2) {
        return ScaleTransition(
          scale: CurvedAnimation(parent: anim1, curve: Curves.elasticOut),
          child: AlertDialog(
            backgroundColor: const Color(0xFF1D1E33),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            content: Container(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Trophy icon
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        colors: [Color(0xFFFFBE0B), Color(0xFFFF6584)],
                      ),
                    ),
                    child: const Icon(
                      Icons.star_rounded,
                      size: 50,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'LEVEL $completedLevel',
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.white60,
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'COMPLETE!',
                    style: GoogleFonts.poppins(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Level $level Unlocked',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      color: const Color(0xFFFFBE0B),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Timer Reset: 60s',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: const Color(0xFF00D9FF),
                    ),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6C63FF),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 40, vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      'Continue',
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _showGameOverDialog() {
    final isNewBest = score >= personalBest && score > 0;

    showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black87,
      transitionDuration: const Duration(milliseconds: 400),
      pageBuilder: (context, anim1, anim2) {
        return ScaleTransition(
          scale: CurvedAnimation(parent: anim1, curve: Curves.elasticOut),
          child: AlertDialog(
            backgroundColor: const Color(0xFF1D1E33),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            content: Container(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Trophy or result icon
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: isNewBest
                            ? [const Color(0xFFFFBE0B), const Color(0xFFFF6B6B)]
                            : [
                                const Color(0xFF6C63FF),
                                const Color(0xFFFF6584)
                              ],
                      ),
                    ),
                    child: Icon(
                      isNewBest ? Icons.emoji_events : Icons.sports_score,
                      size: 40,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    isNewBest ? 'NEW RECORD!' : 'GAME OVER',
                    style: GoogleFonts.poppins(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 24),
                  _buildStatRow('Score', '$score', const Color(0xFF6C63FF)),
                  const SizedBox(height: 12),
                  _buildStatRow('Level', '$level', const Color(0xFFFF6584)),
                  const SizedBox(height: 12),
                  _buildStatRow(
                      'Max Combo', '${maxCombo}x', const Color(0xFFFFBE0B)),
                  const SizedBox(height: 32),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            Navigator.pop(context);
                          },
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white70,
                            side: const BorderSide(color: Colors.white30),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(
                            'Menu',
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        flex: 2,
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.pop(context);
                            startGame();
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF6C63FF),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(
                            'Play Again',
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatRow(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: color.withAlpha(30),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.poppins(
              color: Colors.white70,
              fontSize: 16,
            ),
          ),
          Text(
            value,
            style: GoogleFonts.poppins(
              color: color,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    gameTimer?.cancel();
    spawnTimer?.cancel();
    _scoreAnimController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isWide = size.width > 600;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF0A0E21),
              Color(0xFF1D1E33),
            ],
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              // Background pattern
              _buildBackgroundPattern(size),

              // Game info panel
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: _buildGameHeader(isWide),
              ),

              // Game circles
              if (isGameActive)
                ...circles.map((circle) => _buildGameCircle(circle)),

              // Start game overlay
              if (!isGameActive) _buildStartOverlay(isWide),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBackgroundPattern(Size size) {
    return CustomPaint(
      size: size,
      painter: GridPatternPainter(),
    );
  }

  Widget _buildGameHeader(bool isWide) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1D1E33).withAlpha(230),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: Colors.white.withAlpha(25),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(50),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          // Stats row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatCard(
                'SCORE',
                '$score',
                const Color(0xFF6C63FF),
                animate: true,
              ),
              _buildStatCard(
                'LEVEL',
                '$level',
                const Color(0xFFFF6584),
              ),
              _buildStatCard(
                'TIME',
                '$timeRemaining',
                timeRemaining <= 10
                    ? const Color(0xFFFF4757)
                    : const Color(0xFF00D9FF),
                critical: timeRemaining <= 10,
              ),
              _buildStatCard(
                'COMBO',
                '${combo}x',
                const Color(0xFFFFBE0B),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Target color indicator
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'TAP',
                style: GoogleFonts.poppins(
                  color: Colors.white60,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(width: 12),
              AnimatedBuilder(
                animation: _pulseController,
                builder: (context, child) {
                  return Transform.scale(
                    scale: isGameActive
                        ? 1.0 + (_pulseController.value * 0.1)
                        : 1.0,
                    child: Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: targetColor,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 3),
                        boxShadow: [
                          BoxShadow(
                            color: targetColor.withAlpha(150),
                            blurRadius: 15,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(width: 12),
              Text(
                'ONLY',
                style: GoogleFonts.poppins(
                  color: Colors.white60,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 2,
                ),
              ),
            ],
          ),
          // Logout button
          Align(
            alignment: Alignment.topRight,
            child: IconButton(
              onPressed: () async {
                await _authService.signOut();
              },
              icon: const Icon(
                Icons.logout_rounded,
                color: Colors.white38,
              ),
              tooltip: 'Sign out',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String label, String value, Color color,
      {bool animate = false, bool critical = false}) {
    Widget content = Column(
      children: [
        Text(
          label,
          style: GoogleFonts.poppins(
            color: Colors.white38,
            fontSize: 11,
            fontWeight: FontWeight.w500,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: GoogleFonts.poppins(
            color: color,
            fontSize: 28,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );

    if (animate) {
      return AnimatedBuilder(
        animation: _scoreAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _scoreAnimation.value,
            child: content,
          );
        },
      );
    }

    if (critical && isGameActive) {
      return AnimatedBuilder(
        animation: _pulseController,
        builder: (context, child) {
          return Opacity(
            opacity: 0.5 + (_pulseController.value * 0.5),
            child: content,
          );
        },
      );
    }

    return content;
  }

  Widget _buildGameCircle(GameCircle circle) {
    return Positioned(
      left: circle.position.dx - circle.radius,
      top: circle.position.dy - circle.radius,
      child: GestureDetector(
        onTap: () => onCircleTap(circle),
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.0, end: 1.0),
          duration: const Duration(milliseconds: 200),
          curve: Curves.elasticOut,
          builder: (context, value, child) {
            return Transform.scale(
              scale: value,
              child: Container(
                width: circle.radius * 2,
                height: circle.radius * 2,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      circle.color,
                      circle.color.withAlpha(200),
                    ],
                    center: const Alignment(-0.3, -0.3),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: circle.color.withAlpha(150),
                      blurRadius: 15,
                      spreadRadius: 2,
                    ),
                    BoxShadow(
                      color: circle.color.withAlpha(50),
                      blurRadius: 30,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: Center(
                  child: Container(
                    width: circle.radius * 0.4,
                    height: circle.radius * 0.4,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withAlpha(80),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildStartOverlay(bool isWide) {
    return Center(
      child: SingleChildScrollView(
        padding: EdgeInsets.only(
          top: isWide ? 150 : 220,
          left: 32,
          right: 32,
          bottom: 32,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Personal best
            if (personalBest > 0) ...[
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFFFFBE0B).withAlpha(30),
                      const Color(0xFFFF6B6B).withAlpha(30),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(
                    color: const Color(0xFFFFBE0B).withAlpha(100),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.emoji_events,
                      color: Color(0xFFFFBE0B),
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Best: $personalBest',
                      style: GoogleFonts.poppins(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFFFFBE0B),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 40),
            ],

            // Start button
            GestureDetector(
              onTap: startGame,
              child: AnimatedBuilder(
                animation: _pulseController,
                builder: (context, child) {
                  return Transform.scale(
                    scale: 1.0 + (_pulseController.value * 0.05),
                    child: Container(
                      width: isWide ? 200 : 160,
                      height: isWide ? 200 : 160,
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
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.play_arrow_rounded,
                            size: 60,
                            color: Colors.white,
                          ),
                          Text(
                            'PLAY',
                            style: GoogleFonts.poppins(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              letterSpacing: 3,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),

            const SizedBox(height: 40),

            // Instructions
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFF1D1E33).withAlpha(180),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: Colors.white.withAlpha(25),
                ),
              ),
              child: Column(
                children: [
                  Text(
                    'HOW TO PLAY',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.white60,
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildInstructionRow(
                    Icons.touch_app_rounded,
                    'Tap circles matching the target color',
                    const Color(0xFF6C63FF),
                  ),
                  const SizedBox(height: 12),
                  _buildInstructionRow(
                    Icons.timer_outlined,
                    '60 seconds to get the highest score',
                    const Color(0xFF00D9FF),
                  ),
                  const SizedBox(height: 12),
                  _buildInstructionRow(
                    Icons.trending_up,
                    'Build combos for bonus points',
                    const Color(0xFFFFBE0B),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInstructionRow(IconData icon, String text, Color color) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withAlpha(30),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Text(
            text,
            style: GoogleFonts.poppins(
              color: Colors.white70,
              fontSize: 13,
            ),
          ),
        ),
      ],
    );
  }
}

// Background grid pattern painter
class GridPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withAlpha(8)
      ..strokeWidth = 1;

    const spacing = 40.0;

    for (double x = 0; x < size.width; x += spacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }

    for (double y = 0; y < size.height; y += spacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
