import 'dart:async';
import 'package:example/pull_progressor.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

enum ProgressPosition {
  topPullToDown,
  bottomPullToUp,
}

class PullToRefreshField extends StatefulWidget {
  final ScrollController scrollController;
  final Widget child;
  final PullProgressor pullProgressor;
  final Future<void> Function() onPullDone;
  final Color? progressColor;
  final double progressWidth;
  final double progressHeight;
  final ProgressPosition progressPosition;
  final bool enableSplash;
  final Color? splashColor;

  const PullToRefreshField({
    required this.scrollController,
    required this.child,
    required this.pullProgressor,
    required this.onPullDone,
    this.progressColor = Colors.black,
    this.progressWidth = 36,
    this.progressHeight = 36,
    this.progressPosition = ProgressPosition.topPullToDown,
    this.enableSplash = false,
    this.splashColor,
    super.key,
  });

  @override
  State<PullToRefreshField> createState() => _PullToRefreshFieldState();
}

class _PullToRefreshFieldState extends State<PullToRefreshField> {
  static const double _dragResistance = 2.5;
  static const double _scrollThreshold = 1.0;
  static const double _refreshHeight = 100.0;
  static const double _maintainedHeight = 50.0;

  double _dragOffset = 0.0;
  double _dragProgress = 0.0;
  bool _canStartDrag = true;
  bool _isDragging = false;
  bool _showLoadingAnimation = true;
  bool _isRefreshing = false;
  bool _isIndeterminateLoading = false;
  double _scrollVelocity = 0.0;

  late final ScrollController _internalScrollController;
  Timer? _resetTimer;
  DateTime? _lastDragTime;
  double _lastDragOffset = 0.0;

  @override
  void initState() {
    super.initState();
    _internalScrollController = ScrollController();
    _internalScrollController.addListener(_scrollListener);

    // 외부 컨트롤러의 위치를 내부 컨트롤러와 동기화
    widget.scrollController.addListener(() {
      if (widget.scrollController.hasClients &&
          _internalScrollController.hasClients) {
        _internalScrollController
            .jumpTo(widget.scrollController.position.pixels);
      }
    });
  }

  void _scrollListener() {
    if (widget.scrollController.hasClients) {
      final position = widget.scrollController.position.pixels;
      print('Scroll state changed:');
      print('- canStartDrag: $_canStartDrag');
      print('- scroll position: $position');
      print('- isDragging: $_isDragging');

      if (!_isDragging) {
        _canStartDrag = position <= _scrollThreshold;
      }
    }
  }

  void _resetDragProgress() {
    if (!_isRefreshing) {
      _dragProgress = 0.0;
      _scrollVelocity = 0.0;
      _lastDragTime = null;
      _lastDragOffset = 0.0;
    }
  }

  void _updateDragProgress(double delta) {
    if (!_isRefreshing && (_canStartDrag || _isDragging)) {
      final adjustedDelta =
          widget.progressPosition == ProgressPosition.bottomPullToUp
              ? -delta
              : delta;

      final now = DateTime.now();
      if (_lastDragTime != null) {
        final duration = now.difference(_lastDragTime!).inMilliseconds;
        if (duration > 0) {
          setState(() {
            _scrollVelocity =
                (adjustedDelta - _lastDragOffset) / duration * 1000;
          });
        }
      }
      _lastDragTime = now;
      _lastDragOffset = adjustedDelta;

      setState(() {
        _isDragging = true;
        _showLoadingAnimation = true;
        final resistedDelta = adjustedDelta / _dragResistance;
        _dragOffset =
            (_dragOffset + resistedDelta).clamp(0.0, _refreshHeight * 1.5);
        _dragProgress = (_dragOffset / _refreshHeight).clamp(0.0, 1.2);
      });
    }
  }

  void _resetAllStates() {
    _isDragging = false;
    _isRefreshing = false;
    _dragOffset = 0.0;
    _dragProgress = 0.0;
    _showLoadingAnimation = false;
    _isIndeterminateLoading = false;
    _resetTimer = null;
  }

  void _resetDragProgressWithAnimation() {
    if (!_isRefreshing) {
      _resetTimer?.cancel();

      if (_dragOffset <= 0) {
        setState(() {
          _resetAllStates();
        });
        return;
      }

      setState(() {
        _isDragging = false;
      });

      double initialProgress = _dragProgress;
      double initialOffset = _dragOffset;
      const animationDuration = Duration(milliseconds: 300);
      final startTime = DateTime.now();

      _resetTimer = Timer.periodic(const Duration(milliseconds: 16), (timer) {
        final elapsedTime = DateTime.now().difference(startTime);
        final progress =
            (elapsedTime.inMilliseconds / animationDuration.inMilliseconds)
                .clamp(0.0, 1.0);

        if (progress >= 1.0) {
          timer.cancel();
          setState(() {
            _resetAllStates();
          });
          return;
        }

        setState(() {
          final curve = Curves.easeOut.transform(progress);
          _dragOffset = initialOffset * (1 - curve);
          _dragProgress = initialProgress * (1 - curve);

          if (progress > 0.8) {
            _showLoadingAnimation = false;
          }
        });
      });
    }
  }

  Future<void> _handleRefresh() async {
    try {
      _showLoadingAnimation = true;
      await widget.onPullDone();
    } finally {
      _isRefreshing = false;
      // 새로고침이 끝난 후 역방향 애니메이션 시작
      _resetDragProgressWithAnimation();
    }
  }

  void _onPointerUp(double progress) async {
    if (!_isRefreshing && progress >= 1.0) {
      HapticFeedback.mediumImpact();
      setState(() {
        _isRefreshing = true;
        _showLoadingAnimation = true;
        _isIndeterminateLoading = false;
      });

      _resetTimer?.cancel();
      _resetTimer = Timer.periodic(const Duration(milliseconds: 16), (timer) {
        final diff = _dragOffset - _maintainedHeight;
        if (diff.abs() < 0.5) {
          timer.cancel();
          setState(() {
            _dragOffset = _maintainedHeight;
            _dragProgress = _maintainedHeight / _refreshHeight;
            _showLoadingAnimation = true;
            _isIndeterminateLoading = true;
          });
          _handleRefresh();
          return;
        }
        setState(() {
          final newOffset = _dragOffset - (diff * 0.3);
          _dragOffset = newOffset;
          _dragProgress = newOffset / _refreshHeight;
        });
      });
    } else if (!_isRefreshing) {
      _resetDragProgressWithAnimation();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Listener(
          onPointerDown: (_) {
            if (_canStartDrag) {
              _resetDragProgress();
              if (widget.scrollController.hasClients) {
                // bottomPullToUp인 경우 스크롤을 맨 아래로
                final targetPosition =
                    widget.progressPosition == ProgressPosition.bottomPullToUp
                        ? widget.scrollController.position.maxScrollExtent
                        : 0.0;
                widget.scrollController.animateTo(
                  targetPosition,
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOut,
                );
              }
            }
          },
          onPointerMove: (event) {
            if (_canStartDrag || _isDragging) {
              _updateDragProgress(event.delta.dy);
            }
          },
          onPointerUp: (_) => _onPointerUp(_dragProgress),
          child: NotificationListener<ScrollNotification>(
            onNotification: (notification) {
              if (_isDragging || _isRefreshing) {
                return true;
              }
              if (notification is ScrollUpdateNotification) {
                if (widget.progressPosition ==
                    ProgressPosition.bottomPullToUp) {
                  // 하단 드래그의 경우 맨 아래에 도달했을 때 활성화
                  _canStartDrag = notification.metrics.pixels >=
                      notification.metrics.maxScrollExtent - _scrollThreshold;
                } else {
                  // 상단 드래그의 경우 맨 위에 도달했을 때 활성화
                  _canStartDrag =
                      notification.metrics.pixels <= _scrollThreshold;
                }
              }
              return false;
            },
            child: Padding(
              padding:
                  widget.progressPosition == ProgressPosition.bottomPullToUp
                      ? EdgeInsets.only(bottom: _dragOffset)
                      : EdgeInsets.only(top: _dragOffset),
              child: widget.child,
            ),
          ),
        ),
        if (widget.progressPosition == ProgressPosition.topPullToDown)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: _buildProgressIndicator(),
          ),
        if (widget.progressPosition == ProgressPosition.bottomPullToUp)
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: _buildProgressIndicator(),
          ),
      ],
    );
  }

  Widget _buildProgressIndicator() {
    return SizedBox(
      width: double.infinity,
      height: _dragOffset,
      child: Stack(
        children: [
          if (widget.enableSplash)
            CustomPaint(
              painter: SplashPainter(
                progress: _dragProgress,
                position: widget.progressPosition,
                color: widget.splashColor ??
                    widget.progressColor?.withOpacity(0.05) ??
                    Colors.black.withOpacity(0.05),
              ),
              size: Size(double.infinity, _dragOffset),
            ),
          if (_showLoadingAnimation)
            Center(
              child: SizedBox(
                width: widget.progressWidth,
                height: widget.progressHeight,
                child: widget.pullProgressor.copyWith(
                  progress: _dragProgress,
                  isLoading: _isRefreshing,
                  velocity: _scrollVelocity,
                  width: widget.progressWidth,
                  height: widget.progressHeight,
                ),
              ),
            ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _resetTimer?.cancel();
    _internalScrollController.removeListener(_scrollListener);
    _internalScrollController.dispose();
    super.dispose();
  }
}

class SplashPainter extends CustomPainter {
  final double progress;
  final ProgressPosition position;
  final Color color;

  SplashPainter({
    required this.progress,
    required this.position,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0 || size.height <= 0) return;

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final path = Path();
    final height = size.height;

    if (position == ProgressPosition.topPullToDown) {
      path.moveTo(0, 0);
      path.lineTo(size.width, 0);
      path.lineTo(size.width, height);
      path.quadraticBezierTo(
        size.width / 2,
        height - (height * 0.2),
        0,
        height,
      );
    } else {
      path.moveTo(0, size.height);
      path.lineTo(size.width, size.height);
      path.lineTo(size.width, size.height - height);
      path.quadraticBezierTo(
        size.width / 2,
        size.height - height + (height * 0.2),
        0,
        size.height - height,
      );
    }
    path.close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant SplashPainter oldDelegate) {
    return progress != oldDelegate.progress || color != oldDelegate.color;
  }
}
