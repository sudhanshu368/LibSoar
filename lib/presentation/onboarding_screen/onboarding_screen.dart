import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../routes/app_routes.dart';
import '../../theme/app_theme.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animController;

  // Total duration of the animation sequence: 4850ms (~4.85s)
  static const int _totalDurationMs = 4850;

  // 1. Logo animation: 0ms to 450ms (Slide in from left to right + fade)
  static const int _logoStartMs = 0;
  static const int _logoEndMs = 450;
  late final Animation<double> _logoFadeAnimation;
  late final Animation<Offset> _logoSlideAnimation;

  // 2. LibSoar Brand letters (below logo): 450ms to 1850ms (~200ms per character)
  // Sequence: L -> Li -> Lib -> LibS -> LibSo -> LibSoa -> LibSoar
  static const List<String> _brandLetters = ['L', 'i', 'b', 'S', 'o', 'a', 'r'];
  static const int _brandStartMs = 450;
  static const int _brandLetterIntervalMs = 200;
  static const int _brandLetterDurationMs = 240;
  late final List<Animation<double>> _brandFadeAnimations;
  late final List<Animation<Offset>> _brandSlideAnimations;

  // 3. Main Heading: "Everything Your Library Needs in One Smart Platform" (below brand)
  // Progressive word-by-word animation from left to right
  static const String headingText =
      'Everything Your Library Needs in One Smart Platform';
  static final List<String> _headingWords = headingText.split(' ');
  static const int _headingStartMs = 1950;
  static const int _headingWordIntervalMs = 150;
  static const int _headingWordDurationMs = 240;

  // 4. Supporting Description: "Manage students, seats, attendance, billing, memberships and branches with LibSoar." (below heading)
  // Progressive word-by-word animation from left to right starting after heading
  static const String descriptionText =
      'Manage students, seats, attendance, billing, memberships and branches with LibSoar.';
  static final List<String> _descWords = descriptionText.split(' ');
  static const int _descStartMs = 3350;
  static const int _descWordIntervalMs = 130;
  static const int _descWordDurationMs = 220;

  Timer? _navigationTimer;
  bool _hasNavigated = false;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: _totalDurationMs),
    );

    // 1. Logo enters first from LEFT -> RIGHT with gentle fade-in (0ms - 450ms)
    final logoStartFrac = _logoStartMs / _totalDurationMs;
    final logoEndFrac = _logoEndMs / _totalDurationMs;
    _logoFadeAnimation = CurvedAnimation(
      parent: _animController,
      curve: Interval(logoStartFrac, logoEndFrac, curve: Curves.easeOut),
    );
    _logoSlideAnimation =
        Tween<Offset>(
          begin: const Offset(-0.35, 0.0),
          end: Offset.zero,
        ).animate(
          CurvedAnimation(
            parent: _animController,
            curve: Interval(
              logoStartFrac,
              logoEndFrac,
              curve: Curves.easeOutCubic,
            ),
          ),
        );

    // 2. Brand letters appear letter-by-letter below the logo (L -> Li -> Lib -> LibS -> LibSo -> LibSoa -> LibSoar)
    _brandFadeAnimations = [];
    _brandSlideAnimations = [];

    for (int i = 0; i < _brandLetters.length; i++) {
      final startMs = _brandStartMs + (i * _brandLetterIntervalMs);
      final endMs = startMs + _brandLetterDurationMs;
      final startFrac = (startMs / _totalDurationMs).clamp(0.0, 1.0);
      final endFrac = (endMs / _totalDurationMs).clamp(0.0, 1.0);

      _brandFadeAnimations.add(
        CurvedAnimation(
          parent: _animController,
          curve: Interval(startFrac, endFrac, curve: Curves.easeOut),
        ),
      );

      _brandSlideAnimations.add(
        Tween<Offset>(
          begin: const Offset(-0.25, 0.0),
          end: Offset.zero,
        ).animate(
          CurvedAnimation(
            parent: _animController,
            curve: Interval(startFrac, endFrac, curve: Curves.easeOutCubic),
          ),
        ),
      );
    }

    // 5. On completion: hold complete content for ~1 second, then auto-navigate to Login
    _animController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _navigationTimer?.cancel();
        _navigationTimer = Timer(const Duration(milliseconds: 1000), () {
          _navigateToLogin();
        });
      }
    });

    _animController.forward();
  }

  void _navigateToLogin() {
    if (!mounted || _hasNavigated) return;
    _hasNavigated = true;
    Navigator.pushReplacementNamed(context, AppRoutes.loginScreen);
  }

  @override
  void dispose() {
    _navigationTimer?.cancel();
    _animController.dispose();
    super.dispose();
  }

  Widget _buildAnimatedWords({
    required List<String> words,
    required String fullText,
    required TextStyle style,
    required int startMs,
    required int wordIntervalMs,
    required int wordDurationMs,
    required String semanticKey,
    double wordSpacing = 6.0,
    double runSpacing = 6.0,
  }) {
    return Semantics(
      label: fullText,
      container: true,
      child: Wrap(
        key: ValueKey(semanticKey),
        alignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: wordSpacing,
        runSpacing: runSpacing,
        children: List.generate(words.length, (index) {
          final wStartMs = startMs + (index * wordIntervalMs);
          final wEndMs = wStartMs + wordDurationMs;

          return AnimatedBuilder(
            animation: _animController,
            builder: (context, _) {
              final currentMs = _animController.value * _totalDurationMs;
              double progress = 0.0;
              if (currentMs >= wEndMs) {
                progress = 1.0;
              } else if (currentMs > wStartMs) {
                progress = ((currentMs - wStartMs) / wordDurationMs).clamp(
                  0.0,
                  1.0,
                );
              }
              final curved = Curves.easeOutCubic.transform(progress);
              return Opacity(
                opacity: curved,
                child: Transform.translate(
                  offset: Offset(-8.0 * (1.0 - curved), 0.0),
                  child: Text(words[index], style: style),
                ),
              );
            },
          );
        }),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final screenWidth = media.size.width;
    final isNarrow = screenWidth < 360;

    final double logoHeight = isNarrow ? 48.0 : 56.0;
    final double brandFontSize = isNarrow ? 32.0 : 38.0;
    final double headingFontSize = isNarrow ? 22.0 : 26.0;
    final double descFontSize = isNarrow ? 13.5 : 15.0;

    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            physics: const ClampingScrollPhysics(),
            padding: EdgeInsets.symmetric(
              horizontal: isNarrow ? 20.0 : 32.0,
              vertical: 24.0,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // ─── Step 1: LibSoar Logo (Top of content) ───
                FadeTransition(
                  opacity: _logoFadeAnimation,
                  child: SlideTransition(
                    position: _logoSlideAnimation,
                    child: Image.asset(
                      'assets/images/logo_bars.png',
                      height: logoHeight,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
                SizedBox(height: isNarrow ? 14.0 : 18.0),

                // ─── Step 2: LibSoar Brand Name (Directly Below Logo) ───
                // Letter-by-letter reveal: L -> Li -> Lib -> LibS -> LibSo -> LibSoa -> LibSoar
                Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: List.generate(_brandLetters.length, (index) {
                    return FadeTransition(
                      opacity: _brandFadeAnimations[index],
                      child: SlideTransition(
                        position: _brandSlideAnimations[index],
                        child: Text(
                          _brandLetters[index],
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: brandFontSize,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.5,
                            color: AppTheme.primary,
                          ),
                        ),
                      ),
                    );
                  }),
                ),
                SizedBox(height: isNarrow ? 26.0 : 34.0),

                // ─── Step 3: Main Heading (Below Brand Name, Word-by-Word Reveal) ───
                _buildAnimatedWords(
                  words: _headingWords,
                  fullText: headingText,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: headingFontSize,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.4,
                    height: 1.35,
                    color: AppTheme.onSurfaceLight,
                  ),
                  startMs: _headingStartMs,
                  wordIntervalMs: _headingWordIntervalMs,
                  wordDurationMs: _headingWordDurationMs,
                  semanticKey: 'onboarding_heading',
                  wordSpacing: 6.0,
                  runSpacing: 6.0,
                ),
                SizedBox(height: isNarrow ? 14.0 : 18.0),

                // ─── Step 4: Supporting Description (Below Heading, Word-by-Word Reveal) ───
                _buildAnimatedWords(
                  words: _descWords,
                  fullText: descriptionText,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: descFontSize,
                    fontWeight: FontWeight.w500,
                    height: 1.55,
                    color: AppTheme.mutedLight,
                  ),
                  startMs: _descStartMs,
                  wordIntervalMs: _descWordIntervalMs,
                  wordDurationMs: _descWordDurationMs,
                  semanticKey: 'onboarding_description',
                  wordSpacing: 5.0,
                  runSpacing: 5.0,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
