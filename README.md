<!-- 
This README describes the package. If you publish this package to pub.dev,
this README's contents appear on the landing page for your package.

For information about how to write a good package README, see the guide for
[writing package pages](https://dart.dev/guides/libraries/writing-package-pages). 

For general information about developing packages, see the Dart guide for
[creating packages](https://dart.dev/guides/libraries/create-library-packages)
and the Flutter guide for
[developing packages and plugins](https://flutter.dev/developing-packages). 
-->

模拟系统`Hero`实现的购物车抛物线动画

## Features

轻松实现购物车抛物线动画

## Getting started

```ymal
  fling:
    git: https://github.com/changleibox/fling.git
```

## Usage

实现抛物线动画`flightShuttleBuilder`. 

```dart
FlightShuttleTransition(
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
```

