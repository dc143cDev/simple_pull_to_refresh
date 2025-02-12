import 'dart:async';
import 'package:example/custom_progress.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class PullToRefreshField extends StatefulWidget {
  final ScrollController scrollController;
  final Widget child;
  final Future<void> Function() onRefresh;
  final Color? progressColor;
  final double progressSize;

  const PullToRefreshField({
    required this.scrollController,
    required this.child,
    required this.onRefresh,
    this.progressColor = Colors.black,
    this.progressSize = 36, // 기본 크기
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
      // 속도 계산
      final now = DateTime.now();
      if (_lastDragTime != null) {
        final duration = now.difference(_lastDragTime!).inMilliseconds;
        if (duration > 0) {
          _scrollVelocity = (delta - _lastDragOffset) / duration * 1000;
        }
      }
      _lastDragTime = now;
      _lastDragOffset = delta;

      _isDragging = true;
      _showLoadingAnimation = true;
      final resistedDelta = delta / _dragResistance;
      _dragOffset =
          (_dragOffset + resistedDelta).clamp(0.0, _refreshHeight * 1.5);
      _dragProgress = (_dragOffset / _refreshHeight).clamp(0.0, 1.2);
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
        _resetAllStates();
        return;
      }

      _isDragging = false;

      // 역방향 애니메이션을 위한 초기 설정
      double initialProgress = _dragProgress;
      double initialOffset = _dragOffset;
      const animationDuration = Duration(milliseconds: 300); // 전체 애니메이션 시간
      final startTime = DateTime.now();

      _resetTimer = Timer.periodic(const Duration(milliseconds: 16), (timer) {
        final elapsedTime = DateTime.now().difference(startTime);
        final progress =
            (elapsedTime.inMilliseconds / animationDuration.inMilliseconds)
                .clamp(0.0, 1.0);

        if (progress >= 1.0) {
          timer.cancel();
          _resetAllStates();
          return;
        }

        // easeOut 커브를 사용한 감속 애니메이션
        final curve = Curves.easeOut.transform(progress);
        _dragOffset = initialOffset * (1 - curve);
        _dragProgress = initialProgress * (1 - curve);

        // 프로그레스가 거의 끝나갈 때 로딩 애니메이션 중지
        if (progress > 0.8) {
          _showLoadingAnimation = false;
        }
      });
    }
  }

  Future<void> _handleRefresh() async {
    try {
      _showLoadingAnimation = true;
      await widget.onRefresh();
    } finally {
      _isRefreshing = false;
      // 새로고침이 끝난 후 역방향 애니메이션 시작
      _resetDragProgressWithAnimation();
    }
  }

  void _onPointerUp(double progress) async {
    if (!_isRefreshing && progress >= 1.0) {
      HapticFeedback.mediumImpact();
      _isRefreshing = true;
      _showLoadingAnimation = true;
      _isIndeterminateLoading = false;

      _resetTimer?.cancel();
      _resetTimer = Timer.periodic(const Duration(milliseconds: 16), (timer) {
        final diff = _dragOffset - _maintainedHeight;
        if (diff.abs() < 0.5) {
          timer.cancel();
          _dragOffset = _maintainedHeight;
          _dragProgress = _maintainedHeight / _refreshHeight;
          _showLoadingAnimation = true;
          _isIndeterminateLoading = true;
          _handleRefresh();
          return;
        }
        final newOffset = _dragOffset - (diff * 0.3);
        _dragOffset = newOffset;
        _dragProgress = newOffset / _refreshHeight;
      });
    } else if (!_isRefreshing) {
      _resetDragProgressWithAnimation();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: Container(
            height: _dragOffset,
            color: Colors.transparent,
            child: Center(
              child: _showLoadingAnimation
                  ? SizedBox(
                      height: widget.progressSize,
                      width: widget.progressSize,
                      child: CustomProgressor(
                        progress: _dragProgress,
                        isLoading: _isRefreshing,
                        color: widget.progressColor!,
                        size: widget.progressSize,
                        velocity: _scrollVelocity,
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
          ),
        ),
        Listener(
          onPointerDown: (_) {
            if (_canStartDrag) {
              _resetDragProgress();
              if (widget.scrollController.hasClients) {
                widget.scrollController.animateTo(
                  0,
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
                if (notification.metrics.pixels <= _scrollThreshold) {
                  _canStartDrag = true;
                } else {
                  _canStartDrag = false;
                }
              }
              return false;
            },
            child: Padding(
              padding: EdgeInsets.only(top: _dragOffset),
              child: widget.child,
            ),
          ),
        ),
      ],
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
