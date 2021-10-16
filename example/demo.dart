/*
 * Copyright (c) 2021 CHANGLEI. All rights reserved.
 */

import 'dart:math' as math;

import 'package:fling/fling.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

const _flightShuttleSize = Size.square(40);
const _flightShuttleRadius = Radius.circular(20);
const _flightShuttleColor = Colors.indigo;
const _flightShuttleChild = FlutterLogo(
  size: 40,
  textColor: Colors.white,
);

/// 自定义的[FlightShuttle]动画
typedef FlightShuttleBuilder = Widget Function(
  BuildContext context,
  Rect bounds,
  double edgeValue,
  double middleValue,
  Fling fling,
);

/// 插值器
typedef FlightShuttleInterpolator = Offset Function(Offset end, double t);

/// Created by changlei on 2020/7/6.
///
/// 测试
class MainPage extends StatefulWidget {
  /// 创建
  const MainPage({Key? key}) : super(key: key);

  @override
  _MainPageState createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(
        middle: Text('测试'),
      ),
      child: FlingWidgetsApp(
        duration: const Duration(
          seconds: 3,
        ),
        child: Row(
          children: [
            Expanded(
              child: FlingBoundary(
                tag: 1,
                child: _FlingBlock(
                  tag: 1,
                  color: Colors.pink,
                  onPressed: (context) {
                    Fling.push(context, boundaryTag: 2, tag: 1);
                    Fling.push(context, boundaryTag: 2, tag: 2);
                    Fling.push(context, boundaryTag: 2, tag: 3);
                  },
                ),
              ),
            ),
            Expanded(
              child: FlingBoundary(
                tag: 2,
                child: Column(
                  children: [
                    Expanded(
                      child: _FlingBlock(
                        tag: 1,
                        color: Colors.deepPurple,
                        width: 200,
                        height: 100,
                        onPressed: (context) {
                          Fling.push(context, boundaryTag: 1, tag: 1);
                          Fling.push(context, tag: 2);
                        },
                      ),
                    ),
                    Expanded(
                      child: _FlingBlock(
                        tag: 2,
                        color: Colors.teal,
                        width: 200,
                        height: 200,
                        onPressed: (context) {
                          Fling.push(context, tag: 1);
                          Fling.push(context, boundaryTag: 1, tag: 1);
                          Fling.push(context, tag: 3);
                        },
                      ),
                    ),
                    Expanded(
                      child: _FlingBlock(
                        tag: 3,
                        color: Colors.orange,
                        width: 100,
                        height: 200,
                        onPressed: (context) {
                          Fling.push(context, tag: 2);
                          Fling.push(context, boundaryTag: 1, tag: 1);
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FlingBlock extends StatelessWidget {
  const _FlingBlock({
    Key? key,
    required this.tag,
    required this.color,
    this.width,
    this.height,
    required this.onPressed,
  }) : super(key: key);

  final Object tag;

  final Color color;

  final double? width;

  final double? height;

  final ValueChanged<BuildContext>? onPressed;

  static Widget _buildFlightShuttle(
    BuildContext flightContext,
    Animation<double> animation,
    BuildContext fromFlingContext,
    BuildContext toFlingContext,
    Rect fromFlingLocation,
    Rect toFlingLocation,
  ) {
    return FlightShuttleTransition(
      fromFlingContext: fromFlingContext,
      toFlingContext: toFlingContext,
      fromFlingLocation: fromFlingLocation,
      toFlingLocation: toFlingLocation,
      factor: animation,
      interpolator: (end, t) {
        // 二阶贝塞尔曲线
        final Offset control;
        if (end.dx == 0 || end.dy == 0) {
          control = Offset.zero;
        } else if (end.dy < 0) {
          control = Offset(0, end.dy);
        } else {
          control = Offset(end.dx, 0);
        }
        return control * 2 * t * (1 - t) + end * math.pow(t, 2).toDouble();
      },
      builder: (context, bounds, edgeValue, middleValue, fling) {
        final child = (fling.child as _ContextBuilder).child as _ColorBlock;
        return _ColorBlock.fromSize(
          size: Size.lerp(_flightShuttleSize, bounds.size, edgeValue),
          color: Color.lerp(_flightShuttleColor, child.color, edgeValue),
          radius: Radius.lerp(_flightShuttleRadius, child.radius, edgeValue),
          child: edgeValue == 0 ? _flightShuttleChild : child.child,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Fling(
        tag: tag,
        placeholderBuilder: (context, flingSize, child) {
          return child;
        },
        flightShuttleBuilder: _buildFlightShuttle,
        child: _ContextBuilder(
          onPressed: onPressed,
          child: _ColorBlock(
            width: width ?? 100,
            height: height ?? 100,
            color: color,
          ),
        ),
      ),
    );
  }
}

class _ContextBuilder extends StatelessWidget {
  const _ContextBuilder({
    Key? key,
    required this.child,
    this.onPressed,
  }) : super(key: key);

  final Widget child;
  final ValueChanged<BuildContext>? onPressed;

  @override
  Widget build(BuildContext context) {
    return CupertinoButton(
      padding: EdgeInsets.zero,
      minSize: 0,
      onPressed: () => onPressed?.call(context),
      child: child,
    );
  }
}

class _ColorBlock extends StatelessWidget {
  const _ColorBlock({
    Key? key,
    this.width,
    this.height,
    this.color,
    this.radius = const Radius.circular(10),
    this.child,
  }) : super(key: key);

  _ColorBlock.fromSize({
    Key? key,
    Size? size,
    this.color,
    this.radius = const Radius.circular(10),
    this.child,
  })  : width = size?.width,
        height = size?.height,
        super(key: key);

  final double? width;
  final double? height;
  final Color? color;
  final Radius? radius;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final borderRadius = BorderRadius.all(radius ?? Radius.zero);
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        color: color,
      ),
      foregroundDecoration: BoxDecoration(
        borderRadius: borderRadius,
        border: Border.all(
          color: Colors.black,
          width: 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: child,
    );
  }
}

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
    this.interpolator,
  })  : fromFling = fromFlingContext.widget as Fling,
        toFling = toFlingContext.widget as Fling,
        startAnimation = CurveTween(
          curve: const Interval(0.0, 0.2, curve: Curves.easeInOut),
        ).animate(factor),
        middleAnimation = CurveTween(
          curve: const Interval(0.2, 0.7, curve: Curves.linear),
        ).animate(factor),
        endAnimation = CurveTween(
          curve: const Interval(0.7, 1.0, curve: Curves.easeOut),
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
    final transformed = interpolator?.call(endOffset, middleValue) ?? endOffset;

    return Center(
      child: Transform.translate(
        offset: transformed - endOffset * factor.value,
        child: Transform.rotate(
          angle: middleAnimation.value * math.pi * 2.0,
          child: builder(context, bounds, edgeValue, middleValue, fling),
        ),
      ),
    );
  }
}
