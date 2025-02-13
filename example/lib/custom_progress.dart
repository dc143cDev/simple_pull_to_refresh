import 'dart:math' as math;
import 'package:example/pull_progressor.dart';
import 'package:flutter/material.dart';

class CoccoProgress extends PullProgressor {
  const CoccoProgress({
    super.key,
    required super.progress,
    super.isLoading = false,
    required super.color,
    required double size,
    super.velocity,
  }) : super(width: size, height: size);

  @override
  State<CoccoProgress> createState() => _CoccoProgressState();

  @override
  PullProgressor copyWith({
    double? progress,
    bool? isLoading,
    Color? color,
    double? width,
    double? height,
    double? velocity,
  }) {
    final size = width ?? height ?? this.width;
    return CoccoProgress(
      progress: progress ?? this.progress,
      isLoading: isLoading ?? this.isLoading,
      color: color ?? this.color,
      size: size,
      velocity: velocity ?? this.velocity,
    );
  }
}

class _CoccoProgressState extends State<CoccoProgress>
    with TickerProviderStateMixin, ProgressStateMixin<CoccoProgress> {
  late final List<AnimationController> _rotationControllers;
  late final List<Animation<double>> _rotationAnimations;
  final List<double> _baseRotationSpeeds = [1.2, 1.4, 1.0, 1.6, 1.1];

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
  }

  void _initializeAnimations() {
    _rotationControllers = List.generate(
      5,
      (index) => AnimationController(
        duration:
            Duration(milliseconds: (1000 * _baseRotationSpeeds[index]).toInt()),
        vsync: this,
      ),
    );

    _rotationAnimations = _rotationControllers.map((controller) {
      return Tween<double>(begin: 0, end: 2 * math.pi).animate(
        CurvedAnimation(parent: controller, curve: Curves.linear),
      );
    }).toList();

    updateProgressState();
  }

  @override
  void onLoadingStateEntered() {
    _startRotation();
  }

  @override
  void onCompleteStateEntered() {
    _stopRotation();
  }

  @override
  void onDrawingStateEntered() {
    _stopRotation();
  }

  @override
  void onIdleStateEntered() {
    _stopRotation();
  }

  void _startRotation() {
    double speedMultiplier = widget.isLoading ? 1.5 : 1.0;

    if (widget.velocity != null) {
      speedMultiplier = (widget.velocity!.abs() / 300).clamp(0.8, 2.0);
    }

    for (var i = 0; i < _rotationControllers.length; i++) {
      final controller = _rotationControllers[i];
      final newDuration = Duration(
        milliseconds: (1000 * _baseRotationSpeeds[i] / speedMultiplier).toInt(),
      );

      controller.duration = newDuration;

      if (widget.velocity != null && widget.velocity! < 0) {
        controller.repeat(reverse: true);
      } else {
        controller.repeat(reverse: false);
      }
    }
  }

  void _stopRotation() {
    for (var controller in _rotationControllers) {
      if (controller.isAnimating) {
        controller.stop();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(widget.width, widget.height),
      painter: CoccoProgressPainter(
        progress: widget.progress,
        color: widget.color,
        rotationAnimations: _rotationAnimations,
        state: currentState,
      ),
    );
  }

  @override
  void dispose() {
    for (var controller in _rotationControllers) {
      controller.dispose();
    }
    super.dispose();
  }
}

class CoccoProgressPainter extends CustomPainter {
  final double progress;
  final Color color;
  final List<Animation<double>> rotationAnimations;
  final ProgressState state;

  CoccoProgressPainter({
    required this.progress,
    required this.color,
    required this.rotationAnimations,
    required this.state,
  }) : super(repaint: Listenable.merge(rotationAnimations));

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.05
      ..strokeCap = StrokeCap.round;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width * 0.35;

    // 위아래 간격을 2픽셀 늘림
    final verticalGap = 0.8;
    final bgCircleCenters = [
      Offset(center.dx - radius * 0.65,
          center.dy - radius * 0.65 - verticalGap), // 좌상단
      Offset(center.dx + radius * 0.65,
          center.dy - radius * 0.65 - verticalGap), // 우상단
      Offset(center.dx + radius * 0.65,
          center.dy + radius * 0.65 + verticalGap), // 우하단
      Offset(center.dx - radius * 0.65,
          center.dy + radius * 0.65 + verticalGap), // 좌하단
    ];

    final startAngle = -3 * math.pi / 12;

    if (state == ProgressState.loading) {
      for (var i = 0; i < 4; i++) {
        canvas.save();
        canvas.translate(bgCircleCenters[i].dx, bgCircleCenters[i].dy);
        canvas.rotate(rotationAnimations[i].value);
        canvas.translate(-bgCircleCenters[i].dx, -bgCircleCenters[i].dy);

        if (i == 0 || i == 3) {
          // 좌측 원들 (C 형상)
          canvas.drawArc(
            Rect.fromCircle(center: bgCircleCenters[i], radius: radius * 0.7),
            startAngle, // -67.5도에서 시작
            -1.5 * math.pi, // 시계 방향으로 270도
            false,
            paint,
          );
        } else {
          // 우측 원들 (완전한 원)
          canvas.drawArc(
            Rect.fromCircle(center: bgCircleCenters[i], radius: radius * 0.7),
            0,
            2 * math.pi,
            false,
            paint,
          );
        }
        canvas.restore();
      }

      // 중앙 원 (C 형상)
      canvas.save();
      canvas.translate(center.dx, center.dy);
      canvas.rotate(rotationAnimations[4].value);
      canvas.translate(-center.dx, -center.dy);
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius * 0.7),
        startAngle, // -67.5도에서 시작
        -1.5 * math.pi, // 시계 방향으로 270도
        false,
        paint,
      );
      canvas.restore();
    } else {
      for (var i = 0; i < 4; i++) {
        final circleProgress = (progress * 5 - i).clamp(0.0, 1.0);
        if (circleProgress > 0) {
          if (i == 0 || i == 3) {
            // 좌측 원들 (C 형상)
            canvas.drawArc(
              Rect.fromCircle(center: bgCircleCenters[i], radius: radius * 0.7),
              startAngle,
              -1.5 * math.pi * circleProgress,
              false,
              paint,
            );
          } else {
            // 우측 원들 (완전한 원)
            canvas.drawArc(
              Rect.fromCircle(center: bgCircleCenters[i], radius: radius * 0.7),
              0,
              2 * math.pi * circleProgress,
              false,
              paint,
            );
          }
        }
      }

      // 중앙 원 (C 형상)
      final centerCircleProgress = (progress * 5 - 4).clamp(0.0, 1.0);
      if (centerCircleProgress > 0) {
        canvas.drawArc(
          Rect.fromCircle(center: center, radius: radius * 0.7),
          startAngle,
          -1.5 * math.pi * centerCircleProgress,
          false,
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant CoccoProgressPainter oldDelegate) {
    return progress != oldDelegate.progress ||
        color != oldDelegate.color ||
        rotationAnimations != oldDelegate.rotationAnimations ||
        state != oldDelegate.state;
  }
}
