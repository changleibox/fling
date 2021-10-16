/*
 * Copyright (c) 2021 CHANGLEI. All rights reserved.
 */

import 'package:fling/src/flings.dart';
import 'package:flutter/material.dart';

/// 自定义的[FlightShuttle]动画
typedef FlightShuttleBuilder = Widget Function(
  BuildContext context,
  Rect bounds,
  double value,
  double edgeValue,
  double middleValue,
  Fling fling,
);

/// 插值器
typedef FlightShuttleInterpolator = Offset Function(Offset end, double t);

/// Created by box on 2021/10/16.
///
/// 构造[FlightShuttle]动画
class FlightShuttleTransition extends AnimatedWidget {
  /// 构造[FlightShuttle]动画
  FlightShuttleTransition({
    Key? key,
    required BuildContext fromFlingContext,
    required BuildContext toFlingContext,
    required this.fromFlingLocation,
    required this.toFlingLocation,
    required this.builder,
    required Animation<double> factor,
    Interval startInterval = const Interval(0, 0),
    Interval middleInterval = const Interval(0, 1),
    Interval endInterval = const Interval(0, 0),
    this.interpolator,
  })  : fromFling = fromFlingContext.widget as Fling,
        toFling = toFlingContext.widget as Fling,
        startAnimation = CurveTween(
          curve: startInterval,
        ).animate(factor),
        middleAnimation = CurveTween(
          curve: middleInterval,
        ).animate(factor),
        endAnimation = CurveTween(
          curve: endInterval,
        ).animate(factor),
        super(key: key, listenable: factor);

  /// fromChild
  final Fling fromFling;

  /// toChild
  final Fling toFling;

  /// fromLocation
  final Rect fromFlingLocation;

  /// toLocation
  final Rect toFlingLocation;

  /// 开始
  final Animation<double> startAnimation;

  /// 转场
  final Animation<double> middleAnimation;

  /// 结束
  final Animation<double> endAnimation;

  /// 构建child
  final FlightShuttleBuilder builder;

  /// 插值器
  final FlightShuttleInterpolator? interpolator;

  /// The animation that controls the (clipped) [FlightShuttle] of the child.
  Animation<double> get factor => listenable as Animation<double>;

  @override
  Widget build(BuildContext context) {
    final startValue = startAnimation.value;
    final endValue = endAnimation.value;
    final edgeValue = endValue > 0 ? endValue : 1 - startValue;
    final bounds = endValue > 0 ? toFlingLocation : fromFlingLocation;
    final fling = endValue > 0 ? toFling : fromFling;

    final middleValue = middleAnimation.value;
    final endOffset = toFlingLocation.center - fromFlingLocation.center;
    final transformed = interpolator?.call(endOffset, middleValue) ?? endOffset * middleValue;

    final value = factor.value;
    return Center(
      child: Transform.translate(
        offset: transformed - endOffset * value,
        child: builder(context, bounds, value, edgeValue, middleValue, fling),
      ),
    );
  }
}
