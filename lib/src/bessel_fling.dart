/*
 * Copyright (c) 2021 CHANGLEI. All rights reserved.
 */

import 'dart:math' as math;

import 'package:fling/fling.dart';
import 'package:flutter/material.dart';

/// 自定义的[BesselRectTween]动画
typedef BesselFlightShuttleBuilder = Widget Function(
  BuildContext context,
  double value,
  double edgeValue,
  double middleValue,
  Fling fromFling,
  Fling toFling,
  Rect fromFlingLocation,
  Rect toFlingLocation,
);

/// Created by box on 2021/10/17.
///
/// 贝塞尔曲线
class BesselFling extends StatelessWidget {
  /// 构建贝塞尔曲线[Fling]
  const BesselFling({
    Key? key,
    required this.tag,
    required this.child,
    required this.beginCurve,
    required this.middleCurve,
    required this.endCurve,
    this.flightSize,
    this.flightShuttleBuilder,
    this.placeholderBuilder,
    this.onStartFlight,
    this.onEndFlight,
  }) : super(key: key);

  /// [Fling.tag]
  final Object tag;

  /// [Fling.child]
  final Widget child;

  /// 开始
  final Curve beginCurve;

  /// 中间
  final Curve middleCurve;

  /// 结束
  final Curve endCurve;

  /// flightSize
  final Size? flightSize;

  /// [Fling.flightShuttleBuilder]
  final BesselFlightShuttleBuilder? flightShuttleBuilder;

  /// [Fling.placeholderBuilder]
  final FlingPlaceholderBuilder? placeholderBuilder;

  /// [Fling.onStatFlight]
  final ValueChanged<Size>? onStartFlight;

  /// [Fling.onEndFlight]
  final ValueChanged<Size>? onEndFlight;

  // The bounding box for `context`'s render object,  in `ancestorContext`'s
  // render object's coordinate space.
  static Rect _boundingBoxFor(BuildContext context) {
    final flingState = (context as StatefulElement).state as FlingState;
    final ancestorContext = flingState.boundary.navigator.context;
    final box = context.findRenderObject()! as RenderBox;
    assert(box.hasSize && box.size.isFinite);
    return MatrixUtils.transformRect(
      box.getTransformTo(ancestorContext.findRenderObject()),
      Offset.zero & box.size,
    );
  }

  Widget _buildFlightShuttle(
    BuildContext flightContext,
    Animation<double> animation,
    BuildContext fromFlingContext,
    BuildContext toFlingContext,
  ) {
    final fromFling = fromFlingContext.widget as Fling;
    final toFling = toFlingContext.widget as Fling;
    final fromFlingLocation = _boundingBoxFor(fromFlingContext);
    final toFlingLocation = _boundingBoxFor(toFlingContext);
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        final t = animation.value;
        final beginValue = beginCurve.transform(t);
        final middleValue = middleCurve.transform(t);
        final endValue = endCurve.transform(t);
        final edgeValue = endValue > 0 ? endValue : 1 - beginValue;

        return flightShuttleBuilder!(
          context,
          t,
          edgeValue,
          middleValue,
          fromFling,
          toFling,
          fromFlingLocation,
          toFlingLocation,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Fling(
      tag: tag,
      placeholderBuilder: (context, flingSize, child) {
        return placeholderBuilder?.call(context, flingSize, child) ?? child;
      },
      flightShuttleBuilder: flightShuttleBuilder == null ? null : _buildFlightShuttle,
      createRectTween: (begin, end) {
        return BesselRectTween(
          begin: begin,
          end: end,
          beginCurve: beginCurve,
          middleCurve: middleCurve,
          endCurve: endCurve,
          flightSize: flightSize,
        );
      },
      child: child,
    );
  }
}

/// 贝塞尔曲线
class BesselRectTween extends RectTween {
  /// 构建贝塞曲线[RectTween]
  BesselRectTween({
    Rect? begin,
    Rect? end,
    required this.beginCurve,
    required this.middleCurve,
    required this.endCurve,
    required this.flightSize,
  }) : super(begin: begin, end: end);

  /// 开始
  final Curve beginCurve;

  /// 中间
  final Curve middleCurve;

  /// 结束
  final Curve endCurve;

  /// flightSize
  final Size? flightSize;

  @override
  Rect? lerp(double t) {
    final beginValue = beginCurve.transform(t);
    final middleValue = middleCurve.transform(t);
    final endValue = endCurve.transform(t);
    final edgeValue = endValue > 0 ? endValue : 1 - beginValue;
    final bounds = endValue > 0 ? end : begin;
    final size = Size.lerp(flightSize ?? begin?.size, bounds?.size, edgeValue);
    final center = size?.center(Offset.zero);
    final beginCenter = begin?.center;
    final endCenter = end?.center;
    final beginOffset = beginCenter == null || center == null ? null : (beginCenter - center);
    final endOffset = endCenter == null || center == null ? null : (endCenter - center);
    final offset = bessel(beginOffset, endOffset, middleValue);
    return offset == null || size == null ? super.lerp(t) : (offset & size);
  }

  /// 构建贝塞尔曲线
  static Offset? bessel(Offset? a, Offset? b, double t) {
    if (a == null || b == null) {
      return Offset.lerp(a, b, t);
    } else {
      final offset = b - a;
      // 二阶贝塞尔曲线
      final Offset control;
      if (offset.dx == 0 || offset.dy == 0) {
        control = Offset.zero;
      } else if (offset.dy < 0) {
        control = Offset(0, offset.dy);
      } else {
        control = Offset(offset.dx, 0);
      }
      final vertex = a + control;
      return a * math.pow(1 - t, 2).toDouble() + vertex * 2 * t * (1 - t) + b * math.pow(t, 2).toDouble();
    }
  }
}
