/*
 * Copyright (c) 2021 CHANGLEI. All rights reserved.
 */

import 'dart:math' as math;

import 'package:fling/fling.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

const _flightShuttleSize = Size.square(40);
const _flightShuttleRadius = Radius.circular(20);
const _flightShuttleColor = Colors.red;
const _flightShuttleChild = Icon(
  Icons.flight,
  size: 30,
  color: Colors.white,
);
const _beginInterval = Interval(0.0, 0.2, curve: Curves.easeInOut);
const _middleInterval = Interval(0.2, 0.7, curve: Curves.linear);
const _endInterval = Interval(0.7, 1.0, curve: Curves.easeOut);

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
      child: FlingNavigator(
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

  @override
  Widget build(BuildContext context) {
    return Center(
      child: BesselFling(
        tag: tag,
        beginCurve: _beginInterval,
        middleCurve: _middleInterval,
        endCurve: _endInterval,
        flightSize: _flightShuttleSize,
        flightShuttleBuilder: (
          context,
          value,
          edgeValue,
          middleValue,
          fromFling,
          toFling,
          fromFlingLocation,
          toFlingLocation,
        ) {
          final fling = middleValue == 1 ? toFling : fromFling;
          final child = (fling.child as _ContextBuilder).child as _ColorBlock;
          return Transform.rotate(
            angle: middleValue * math.pi * 2.0,
            child: _ColorBlock.fromSize(
              size: Size.infinite,
              color: Color.lerp(_flightShuttleColor, child.color, edgeValue),
              radius: Radius.lerp(_flightShuttleRadius, child.radius, edgeValue),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 100),
                child: edgeValue == 0 ? _flightShuttleChild : child.child,
              ),
            ),
          );
        },
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
