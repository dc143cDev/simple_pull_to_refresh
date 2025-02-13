import 'package:flutter/material.dart';

abstract class PullProgressor extends StatefulWidget {
  final double progress; // 0.0 ~ 1.0
  final bool isLoading;
  final Color color;
  final double width;
  final double height;
  final double? velocity;

  const PullProgressor({
    super.key,
    required this.progress,
    this.isLoading = false,
    required this.color,
    required this.width,
    required this.height,
    this.velocity,
  });

  // copyWith 메서드 추가
  PullProgressor copyWith({
    double? progress,
    bool? isLoading,
    Color? color,
    double? width,
    double? height,
    double? velocity,
  });
}

// 프로그레스 상태를 정의하는 enum
enum ProgressState {
  idle, // 초기 상태
  drawing, // 드래그에 따라 그려지는 상태
  complete, // 모든 프로그레스가 완료된 상태
  loading // 로딩 애니메이션 상태
}

// 프로그레스 위젯의 기본 기능을 정의하는 mixin
mixin ProgressStateMixin<T extends PullProgressor> on State<T> {
  ProgressState _currentState = ProgressState.idle;
  ProgressState get currentState => _currentState;

  @protected
  void updateProgressState() {
    if (widget.isLoading) {
      _currentState = ProgressState.loading;
      onLoadingStateEntered();
    } else if (widget.progress >= 1.0) {
      _currentState = ProgressState.complete;
      onCompleteStateEntered();
    } else if (widget.progress > 0) {
      _currentState = ProgressState.drawing;
      onDrawingStateEntered();
    } else {
      _currentState = ProgressState.idle;
      onIdleStateEntered();
    }
  }

  // 상태 변경 시 호출되는 콜백 메서드들
  @protected
  void onIdleStateEntered() {}

  @protected
  void onDrawingStateEntered() {}

  @protected
  void onCompleteStateEntered() {}

  @protected
  void onLoadingStateEntered() {}

  @override
  void didUpdateWidget(T oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.progress != oldWidget.progress ||
        widget.isLoading != oldWidget.isLoading ||
        widget.velocity != oldWidget.velocity) {
      updateProgressState();
    }
  }
}
