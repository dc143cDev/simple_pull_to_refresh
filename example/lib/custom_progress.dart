import 'dart:math' as math;
import 'package:flutter/material.dart';

enum CustomProgressorState {
  idle, // 초기 상태
  drawing, // 드래그에 따라 그려지는 상태
  complete, // 모든 원이 그려진 상태
  loading // 로딩 애니메이션 상태
}

// 코코스퀘어 로고 형태로 디자인된 로딩 프로그레스 애니메이션.
// 상태값에 따라 각기 다른 애니메이션 형태로 작동합니다.
class CustomProgressor extends StatefulWidget {
  final double progress; // 0.0 ~ 1.0
  final bool isLoading;
  final Color color;
  final double size;
  final double? velocity; // 스크롤 속도 추가

  const CustomProgressor({
    super.key,
    required this.progress,
    this.isLoading = false,
    required this.color,
    required this.size,
    this.velocity, // 스크롤 속도를 받을 수 있도록 추가
  });

  @override
  State<CustomProgressor> createState() => _CustomProgressorState();
}

class _CustomProgressorState extends State<CustomProgressor>
    with TickerProviderStateMixin {
  late final List<AnimationController> _rotationControllers;
  late final List<Animation<double>> _rotationAnimations;
  final List<double> _baseRotationSpeeds = [1.2, 1.4, 1.0, 1.6, 1.1];

  CustomProgressorState _currentState = CustomProgressorState.idle;

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

    _updateState();
  }

  void _updateState() {
    if (widget.isLoading) {
      _currentState = CustomProgressorState.loading;
      _startRotation();
    } else if (widget.progress >= 1.0) {
      _currentState = CustomProgressorState.complete;
      _stopRotation();
    } else if (widget.progress > 0) {
      _currentState = CustomProgressorState.drawing;
      _stopRotation();
    } else {
      _currentState = CustomProgressorState.idle;
      _stopRotation();
    }
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
      size: Size(widget.size, widget.size),
      painter: CustomProgressorPainter(
        progress: widget.progress,
        color: widget.color,
        rotationAnimations: _rotationAnimations,
        state: _currentState,
      ),
    );
  }

  @override
  void didUpdateWidget(CustomProgressor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.progress != oldWidget.progress ||
        widget.isLoading != oldWidget.isLoading ||
        widget.velocity != oldWidget.velocity) {
      _updateState();
    }
  }

  @override
  void dispose() {
    for (var controller in _rotationControllers) {
      controller.dispose();
    }
    super.dispose();
  }
}

class CustomProgressorPainter extends CustomPainter {
  final double progress;
  final Color color;
  final List<Animation<double>> rotationAnimations;
  final CustomProgressorState state;

  CustomProgressorPainter({
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

    if (state == CustomProgressorState.loading) {
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
  bool shouldRepaint(covariant CustomProgressorPainter oldDelegate) {
    return progress != oldDelegate.progress ||
        color != oldDelegate.color ||
        rotationAnimations != oldDelegate.rotationAnimations ||
        state != oldDelegate.state;
  }
}
