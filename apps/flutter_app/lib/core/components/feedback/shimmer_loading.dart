import 'package:flutter/material.dart';
import '../../theme/app_tokens.dart';

class ShimmerLoading extends StatefulWidget {
  const ShimmerLoading({super.key, required this.child});
  final Widget child;
  @override
  State<ShimmerLoading> createState() => _ShimmerLoadingState();
}

class _ShimmerLoadingState extends State<ShimmerLoading> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500))..repeat();
    _animation = Tween<double>(begin: -2, end: 2).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOutSine));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final baseColor = isDark ? Colors.grey[800]! : Colors.grey[300]!;
    final highlightColor = isDark ? Colors.grey[700]! : Colors.grey[100]!;
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return ShaderMask(
          shaderCallback: (bounds) {
            return LinearGradient(begin: Alignment.centerLeft, end: Alignment.centerRight, colors: [baseColor, highlightColor, baseColor], stops: [0.0, 0.5 + _animation.value * 0.25, 1.0]).createShader(bounds);
          },
          child: widget.child,
        );
      },
    );
  }
}

class ShimmerBox extends StatelessWidget {
  const ShimmerBox({super.key, this.width, this.height = 20, this.borderRadius});
  final double? width;
  final double height;
  final double? borderRadius;

  @override
  Widget build(BuildContext context) {
    return ShimmerLoading(
      child: Container(width: width, height: height, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(borderRadius ?? AppRadius.md))),
    );
  }
}
