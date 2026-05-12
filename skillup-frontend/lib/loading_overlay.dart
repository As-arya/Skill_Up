import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:dotlottie_loader/dotlottie_loader.dart';
import 'package:lottie/lottie.dart';

/// Reusable loading overlay widget.
///
/// Must be used as a direct child inside a Scaffold's body
/// wrapped with a Stack. Example:
///
/// ```dart
/// Scaffold(
///   body: Stack(
///     children: [
///       // your actual page content here
///       YourPageContent(),
///       // loading overlay on top
///       if (_isLoading) const LoadingOverlay(),
///     ],
///   ),
/// )
/// ```
class LoadingOverlay extends StatelessWidget {
  const LoadingOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
          child: Container(
            color: Colors.black54,
            alignment: Alignment.center,
            child: SizedBox(
              width: 160,
              height: 160,
              child: DotLottieLoader.fromAsset(
                'assets/Loading animation blue.lottie',
                frameBuilder: (BuildContext ctx, DotLottie? dotlottie) {
                  if (dotlottie != null) {
                    return Lottie.memory(
                      dotlottie.animations.values.single,
                      repeat: true,
                    );
                  }
                  // Fallback saat dotlottie sedang parsing
                  return const Center(
                    child: CircularProgressIndicator(
                      color: Color(0xFF13B5EA),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}
