/*
 * Copyright (c) 2021 CHANGLEI. All rights reserved.
 */

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

/// Signature for a function that builds a [Fling] placeholder widget given a
/// child and a [Size].
///
/// The child can optionally be part of the returned widget tree. The returned
/// widget should typically be constrained to [flingSize], if it doesn't do so
/// implicitly.
///
/// See also:
///
///  * [TransitionBuilder], which is similar but only takes a [BuildContext]
///    and a child widget.
typedef FlingPlaceholderBuilder = Widget Function(
  BuildContext context,
  Size flingSize,
  Widget child,
);

/// A function that lets [Fling]es self supply a [Widget] that is shown during the
/// fling's flight from one boundary to another instead of default (which is to
/// show the destination boundary's instance of the Fling).
typedef FlingFlightShuttleBuilder = Widget Function(
  BuildContext flightContext,
  Animation<double> animation,
  BuildContext fromFlingContext,
  BuildContext toFlingContext,
);

const _caretAnimationDuration = Duration(milliseconds: 100);
const _caretAnimationCurve = Curves.fastOutSlowIn;
const _rootBoundaryTag = _BoundaryTag();

class _BoundaryTag {
  const _BoundaryTag();

  @override
  String toString() {
    return 'rootBoundaryTag';
  }
}

/// Created by changlei on 2021/10/15.
///
/// 抛动画
class Fling extends StatefulWidget {
  /// Create a fling.
  ///
  /// The [tag] and [child] parameters must not be null.
  /// The [child] parameter and all of the its descendants must not be [Fling]es.
  const Fling({
    Key? key,
    required this.tag,
    this.createRectTween,
    this.flightShuttleBuilder,
    this.placeholderBuilder,
    required this.child,
    this.onStartFlight,
    this.onEndFlight,
  }) : super(key: key);

  /// The identifier for this particular fling. If the tag of this fling matches
  /// the tag of a fling on a [FlingBoundary] that we're navigating to or from, then
  /// a fling animation will be triggered.
  final Object tag;

  /// Defines how the destination fling's bounds change as it flies from the starting
  /// boundary to the destination boundary.
  ///
  /// A fling flight begins with the destination fling's [child] aligned with the
  /// starting fling's child. The [Tween<Rect>] returned by this callback is used
  /// to compute the fling's bounds as the flight animation's value goes from 0.0
  /// to 1.0.
  ///
  /// If this property is null, the default, then the value of
  /// [FlingController.createRectTween] is used. The [FlingController] created by
  /// [MaterialApp] creates a [MaterialRectArcTween].
  final CreateRectTween? createRectTween;

  /// The widget subtree that will "fly" from one boundary to another during a
  /// [Navigator] push or pop transition.
  ///
  /// The appearance of this subtree should be similar to the appearance of
  /// the subtrees of any other flings in the application with the same [tag].
  /// Changes in scale and aspect ratio work well in fling animations, changes
  /// in layout or composition do not.
  ///
  /// {@macro flutter.widgets.ProxyWidget.child}
  final Widget child;

  /// Optional override to supply a widget that's shown during the fling's flight.
  ///
  /// This in-flight widget can depend on the boundary transition's animation as
  /// well as the incoming and outgoing boundaries' [Fling] descendants' widgets and
  /// layout.
  ///
  /// When both the source and destination [Fling]es provide a [flightShuttleBuilder],
  /// the destination's [flightShuttleBuilder] takes precedence.
  ///
  /// If none is provided, the destination boundary's Fling child is shown in-flight
  /// by default.
  ///
  /// ## Limitations
  ///
  /// If a widget built by [flightShuttleBuilder] takes part in a [Navigator]
  /// push transition, that widget or its descendants must not have any
  /// [GlobalKey] that is used in the source Fling's descendant widgets. That is
  /// because both subtrees will be included in the widget tree during the Fling
  /// flight animation, and [GlobalKey]s must be unique across the entire widget
  /// tree.
  ///
  /// If the said [GlobalKey] is essential to your application, consider providing
  /// a custom [placeholderBuilder] for the source Fling, to avoid the [GlobalKey]
  /// collision, such as a builder that builds an empty [SizedBox], keeping the
  /// Fling [child]'s original size.
  final FlingFlightShuttleBuilder? flightShuttleBuilder;

  /// Placeholder widget left in place as the Fling's [child] once the flight takes
  /// off.
  ///
  /// By default the placeholder widget is an empty [SizedBox] keeping the Fling
  /// child's original size, unless this Fling is a source Fling of a [Navigator]
  /// push transition, in which case [child] will be a descendant of the placeholder
  /// and will be kept [Offstage] during the Fling's flight.
  final FlingPlaceholderBuilder? placeholderBuilder;

  /// The `shouldIncludeChildInPlaceholder` flag dictates if the child widget of
  /// this fling should be included in the placeholder widget as a descendant.
  ///
  /// When a new fling flight animation takes place, a placeholder widget
  /// needs to be built to replace the original fling widget. When
  /// `shouldIncludeChildInPlaceholder` is set to true and `widget.placeholderBuilder`
  /// is null, the placeholder widget will include the original fling's child
  /// widget as a descendant, allowing the original element tree to be preserved.
  ///
  /// It is typically set to true for the *from* fling in a push transition,
  /// and false otherwise.
  final ValueChanged<Size>? onStartFlight;

  /// When `keepPlaceholder` is true, the placeholder will continue to be shown
  /// after the flight ends. Otherwise the child of the Fling will become visible
  /// and its TickerMode will be re-enabled.
  ///
  /// This method can be safely called even when this [Fling] is currently not in
  /// a flight.
  final ValueChanged<Size>? onEndFlight;

  /// This method can be expensive (it walks the element tree).
  static FlingState of(BuildContext context) {
    // Handles the case where the input context is a fling element.
    FlingState? fling;
    if (context is StatefulElement && context.state is FlingState) {
      fling = context.state as FlingState;
    }
    fling = fling ?? context.findAncestorStateOfType<FlingState>();

    assert(() {
      if (fling == null) {
        throw FlutterError(
          'Fling operation requested with a context that does not include a Fling.\n'
          'The context used to push boundaries from the Fling must be that of a '
          'widget that is a descendant of a Fling widget.',
        );
      }
      return true;
    }());
    return fling!;
  }

  // Returns a map of all of the flings in `context` indexed by fling tag that
  // should be considered for animation when `navigator` transitions from one
  // FlingBoundary to another.
  static Map<Object, FlingState> _allFlingsFor(BuildContext context) {
    final result = <Object, FlingState>{};

    void inviteFling(StatefulElement fling, Object tag) {
      final flingState = fling.state as FlingState;
      if (flingState.boundary.context != context) {
        return;
      }
      assert(() {
        if (result.containsKey(tag)) {
          throw FlutterError.fromParts(<DiagnosticsNode>[
            ErrorSummary('There are multiple flings that share the same tag within a subtree.'),
            ErrorDescription(
              'Within each subtree for which flings are to be animated (i.e. a FlingBoundary subtree), '
              'each Fling must have a unique non-null tag.\n'
              'In this case, multiple flings had the following tag: $tag',
            ),
            DiagnosticsProperty<StatefulElement>('Here is the subtree for one of the offending flings', fling,
                linePrefix: '# ', style: DiagnosticsTreeStyle.dense),
          ]);
        }
        return true;
      }());
      result[tag] = flingState;
    }

    void visitor(Element element) {
      final widget = element.widget;
      if (widget is Fling) {
        final fling = element as StatefulElement;
        final tag = widget.tag;
        inviteFling(fling, tag);
      } else if (widget is FlingMode && !widget.enabled) {
        return;
      }
      element.visitChildren(visitor);
    }

    context.visitChildElements(visitor);
    return result;
  }

  /// push
  static void push(
    BuildContext context, {
    Object? boundaryTag,
    required Object tag,
  }) {
    Fling.of(context).push(
      boundary: FlingBoundary.of(context, tag: boundaryTag),
      tag: tag,
    );
  }

  @override
  State<Fling> createState() => FlingState();

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<Object>('tag', tag));
  }
}

/// The [Fling] widget displays different content based on whether it is in an
/// animated transition ("flight"), from/to another [Fling] with the same tag:
///   * When [_startFlight] is called, the real content of this [Fling] will be
///     replaced by a "placeholder" widget.
///   * When the flight ends, the "toFling"'s [_endFlight] method must be called
///     by the fling controller, so the real content of that [Fling] becomes
///     visible again when the animation completes.
class FlingState extends State<Fling> {
  final GlobalKey _key = GlobalKey();
  Size? _placeholderSize;

  // Whether the placeholder widget should wrap the fling's child widget as its
  // own child, when `_placeholderSize` is non-null (i.e. the fling is currently
  // in its flight animation). See `startFlight`.
  bool _shouldIncludeChild = true;

  /// boundary
  FlingBoundaryState get boundary => FlingBoundary.of(context);

  /// push
  void push({
    FlingBoundaryState? boundary,
    required Object tag,
  }) {
    FlingNavigator.of(context)._push(
      fromBoundary: this.boundary,
      toBoundary: boundary,
      fromTag: widget.tag,
      toTag: tag,
    );
  }

  // The `shouldIncludeChildInPlaceholder` flag dictates if the child widget of
  // this fling should be included in the placeholder widget as a descendant.
  //
  // When a new fling flight animation takes place, a placeholder widget
  // needs to be built to replace the original fling widget. When
  // `shouldIncludeChildInPlaceholder` is set to true and `widget.placeholderBuilder`
  // is null, the placeholder widget will include the original fling's child
  // widget as a descendant, allowing the original element tree to be preserved.
  //
  // It is typically set to true for the *from* fling in a push transition,
  // and false otherwise.
  void _startFlight({bool shouldIncludedChildInPlaceholder = false}) {
    _shouldIncludeChild = shouldIncludedChildInPlaceholder;
    assert(mounted);
    final box = context.findRenderObject()! as RenderBox;
    assert(box.hasSize);
    setState(() {
      _placeholderSize = box.size;
    });

    widget.onStartFlight?.call(_placeholderSize!);
  }

  // When `keepPlaceholder` is true, the placeholder will continue to be shown
  // after the flight ends. Otherwise the child of the Fling will become visible
  // and its TickerMode will be re-enabled.
  //
  // This method can be safely called even when this [Fling] is currently not in
  // a flight.
  void _endFlight({bool keepPlaceholder = false}) {
    if (keepPlaceholder || _placeholderSize == null) {
      return;
    }

    final size = _placeholderSize;
    _placeholderSize = null;
    if (mounted) {
      // Tell the widget to rebuild if it's mounted. _placeholderSize has already
      // been updated.
      setState(() {});
    }

    widget.onEndFlight?.call(size!);
  }

  @override
  Widget build(BuildContext context) {
    assert(
      context.findAncestorWidgetOfExactType<Fling>() == null,
      'A Fling widget cannot be the descendant of another Fling widget.',
    );

    final showPlaceholder = _placeholderSize != null;

    if (showPlaceholder && widget.placeholderBuilder != null) {
      return widget.placeholderBuilder!(context, _placeholderSize!, widget.child);
    }

    if (showPlaceholder && !_shouldIncludeChild) {
      return SizedBox(
        width: _placeholderSize!.width,
        height: _placeholderSize!.height,
      );
    }

    return SizedBox(
      width: _placeholderSize?.width,
      height: _placeholderSize?.height,
      child: Offstage(
        offstage: showPlaceholder,
        child: TickerMode(
          enabled: !showPlaceholder,
          child: KeyedSubtree(
            key: _key,
            child: widget.child,
          ),
        ),
      ),
    );
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(ObjectFlagProperty<FlingBoundaryState>('boundary', boundary, ifNull: 'not boundary'));
  }
}

// Everything known about a fling flight that's to be started or diverted.
@immutable
class _FlingFlightManifest {
  _FlingFlightManifest({
    required this.overlay,
    required this.navigatorSize,
    required this.fromFling,
    required this.toFling,
    required this.createRectTween,
    required this.shuttleBuilder,
    required Animation<double> animation,
  }) : _animation = animation;

  final OverlayState overlay;
  final Size navigatorSize;
  final FlingState fromFling;
  final FlingState toFling;
  final CreateRectTween? createRectTween;
  final FlingFlightShuttleBuilder shuttleBuilder;
  final Animation<double> _animation;

  Object get tag => fromFling.widget.tag;

  Animation<double> get animation {
    return CurvedAnimation(
      parent: _animation,
      curve: Curves.fastOutSlowIn,
      reverseCurve: Curves.fastOutSlowIn.flipped,
    );
  }

  Tween<Rect?> createFlingRectTween({required Rect? begin, required Rect? end}) {
    final createRectTween = toFling.widget.createRectTween ?? this.createRectTween;
    return createRectTween?.call(begin, end) ?? RectTween(begin: begin, end: end);
  }

  // The bounding box for `context`'s render object,  in `ancestorContext`'s
  // render object's coordinate space.
  static Rect _boundingBoxFor(BuildContext context, BuildContext? ancestorContext) {
    assert(ancestorContext != null);
    final box = context.findRenderObject()! as RenderBox;
    assert(box.hasSize && box.size.isFinite);
    return MatrixUtils.transformRect(
      box.getTransformTo(ancestorContext?.findRenderObject()),
      Offset.zero & box.size,
    );
  }

  /// The bounding box of [fromFling], in [fromBoundary]'s coordinate space.
  ///
  /// This property should only be accessed in [_FlingFlight.start].
  late final Rect fromFlingLocation = _boundingBoxFor(fromFling.context, overlay.context);

  /// The bounding box of [toFling], in [toBoundary]'s coordinate space.
  ///
  /// This property should only be accessed in [_FlingFlight.start] or
  /// [_FlingFlight.divert].
  late final Rect toFlingLocation = _boundingBoxFor(toFling.context, overlay.context);

  /// Whether this [_FlingFlightManifest] is valid and can be used to start or
  /// divert a [_FlingFlight].
  ///
  /// When starting or diverting a [_FlingFlight] with a brand new
  /// [_FlingFlightManifest], this flag must be checked to ensure the [RectTween]
  /// the [_FlingFlightManifest] produces does not contain coordinates that have
  /// [double.infinity] or [double.nan].
  late final bool isValid = toFlingLocation.isFinite && fromFlingLocation.isFinite;

  @override
  String toString() {
    return '_FlingFlightManifest(tag: $tag from fling: $fromFling to $toFling)${isValid ? '' : ', INVALID'}';
  }
}

// Builds the in-flight fling widget.
class _FlingFlight {
  _FlingFlight() {
    _proxyAnimation = ProxyAnimation()..addStatusListener(_handleAnimationUpdate);
  }

  late Tween<Rect?> flingRectTween;
  Widget? shuttle;

  Animation<double> _flingOpacity = kAlwaysCompleteAnimation;
  late ProxyAnimation _proxyAnimation;

  // The manifest will be available once `start` is called, throughout the
  // flight's lifecycle.
  late _FlingFlightManifest manifest;
  OverlayEntry? overlayEntry;
  bool _aborted = false;

  static final Animatable<double> _reverseTween = Tween<double>(begin: 1.0, end: 0.0);

  // The OverlayEntry WidgetBuilder callback for the fling's overlay.
  Widget _buildOverlay(BuildContext context) {
    shuttle ??= manifest.shuttleBuilder(
      context,
      manifest.animation,
      manifest.fromFling.context,
      manifest.toFling.context,
    );
    assert(shuttle != null);

    return AnimatedBuilder(
      animation: _proxyAnimation,
      child: shuttle,
      builder: (BuildContext context, Widget? child) {
        final rect = flingRectTween.evaluate(_proxyAnimation)!;
        final offsets = RelativeRect.fromSize(rect, manifest.navigatorSize);
        return Positioned(
          top: offsets.top,
          right: offsets.right,
          bottom: offsets.bottom,
          left: offsets.left,
          child: IgnorePointer(
            child: RepaintBoundary(
              child: Opacity(
                opacity: _flingOpacity.value,
                child: child,
              ),
            ),
          ),
        );
      },
    );
  }

  void _performAnimationUpdate(AnimationStatus status) {
    if (status == AnimationStatus.completed || status == AnimationStatus.dismissed) {
      _proxyAnimation.parent = null;

      assert(overlayEntry != null);
      overlayEntry!.remove();
      overlayEntry = null;
      // We want to keep the fling underneath the current page hidden. If
      // [AnimationStatus.completed], toFling will be the one on top and we keep
      // fromFling hidden. If [AnimationStatus.dismissed], the animation is
      // triggered but canceled before it finishes. In this case, we keep toFling
      // hidden instead.
      manifest.fromFling._endFlight(keepPlaceholder: status == AnimationStatus.completed);
      manifest.toFling._endFlight(keepPlaceholder: status == AnimationStatus.dismissed);
      _proxyAnimation.removeListener(onTick);
    }
  }

  void _handleAnimationUpdate(AnimationStatus status) {
    _performAnimationUpdate(status);
  }

  void onTick() {
    final RenderBox? fromFlingBox;
    if (!_aborted && manifest.fromFling.mounted) {
      fromFlingBox = manifest.fromFling.context.findRenderObject() as RenderBox?;
    } else {
      fromFlingBox = null;
    }

    // Try to find the new origin of the fromFling, if the flight isn't aborted.
    final Offset? fromFlingOrigin;
    if (fromFlingBox != null && fromFlingBox.attached && fromFlingBox.hasSize) {
      fromFlingBox.showOnScreen(
        duration: _caretAnimationDuration,
        curve: _caretAnimationCurve,
      );
      fromFlingOrigin = fromFlingBox.localToGlobal(
        Offset.zero,
        ancestor: manifest.overlay.context.findRenderObject() as RenderBox?,
      );
    } else {
      fromFlingOrigin = null;
    }

    final RenderBox? toFlingBox;
    if (!_aborted && manifest.toFling.mounted) {
      toFlingBox = manifest.toFling.context.findRenderObject() as RenderBox?;
    } else {
      toFlingBox = null;
    }

    // Try to find the new origin of the toFling, if the flight isn't aborted.
    final Offset? toFlingOrigin;
    if (toFlingBox != null && toFlingBox.attached && toFlingBox.hasSize) {
      toFlingBox.showOnScreen(
        duration: _caretAnimationDuration,
        curve: _caretAnimationCurve,
      );
      toFlingOrigin = toFlingBox.localToGlobal(
        Offset.zero,
        ancestor: manifest.overlay.context.findRenderObject() as RenderBox?,
      );
    } else {
      toFlingOrigin = null;
    }

    var originChanged = false;
    if (fromFlingOrigin != null && fromFlingOrigin.isFinite) {
      originChanged = true;
      // If the new origin of fromFling is available and also paintable, try to
      // update flingRectTween with it.
      if (fromFlingOrigin != flingRectTween.begin!.topLeft) {
        final flingRectBegin = fromFlingOrigin & flingRectTween.begin!.size;
        flingRectTween = manifest.createFlingRectTween(begin: flingRectBegin, end: flingRectTween.end);
      }
    }
    if (toFlingOrigin != null && toFlingOrigin.isFinite) {
      originChanged = true;
      // If the new origin of toFling is available and also paintable, try to
      // update flingRectTween with it.
      if (toFlingOrigin != flingRectTween.end!.topLeft) {
        final flingRectEnd = toFlingOrigin & flingRectTween.end!.size;
        flingRectTween = manifest.createFlingRectTween(begin: flingRectTween.begin, end: flingRectEnd);
      }
    }
    if (!originChanged && _flingOpacity.isCompleted) {
      // The toFling no longer exists or it's no longer the flight's destination.
      // Continue flying while fading out.
      _flingOpacity = _proxyAnimation.drive(
        _reverseTween.chain(CurveTween(curve: Interval(_proxyAnimation.value, 1.0))),
      );
    }
    // Update _aborted for the next animation tick.
    _aborted = toFlingOrigin == null || !toFlingOrigin.isFinite;
  }

  // The simple case: we're either starting a push or a pop animation.
  void start(_FlingFlightManifest initialManifest) {
    assert(!_aborted);
    assert(() {
      final initial = initialManifest.animation;
      return initial.value == 0.0 && initial.status == AnimationStatus.forward;
    }());

    manifest = initialManifest;

    _proxyAnimation.parent = manifest.animation;

    flingRectTween = manifest.createFlingRectTween(begin: manifest.fromFlingLocation, end: manifest.toFlingLocation);
    manifest.fromFling._startFlight(shouldIncludedChildInPlaceholder: true);
    manifest.toFling._startFlight();
    manifest.overlay.insert(overlayEntry = OverlayEntry(builder: _buildOverlay));
    _proxyAnimation.addListener(onTick);
  }

  void abort() {
    _aborted = true;
  }

  @override
  String toString() {
    final from = manifest.fromFling;
    final to = manifest.toFling;
    final tag = manifest.tag;
    return 'FlingFlight(for: $tag, from: $from, to: $to ${_proxyAnimation.parent})';
  }
}

/// An interface for observing the behavior of a [Navigator].
class FlingNavigatorObserver {
  /// The navigator that the observer is observing, if any.
  FlingNavigatorState? get navigator => _navigator;
  FlingNavigatorState? _navigator;

  /// The [Navigator] pushed `boundary`.
  ///
  /// The boundary immediately below that one, and thus the previously active
  /// boundary, is `previousBoundary`.
  void didPush(FlingBoundaryState fromBoundary, FlingBoundaryState toBoundary, Object fromTag, Object toTag) {}
}

/// 处理Fling
class FlingNavigator extends StatefulWidget {
  /// 创建[FlingNavigator]
  const FlingNavigator({
    Key? key,
    required this.child,
    this.duration = const Duration(milliseconds: 600),
    this.observers = const <FlingNavigatorObserver>[],
    this.rootOverlay = false,
  }) : super(key: key);

  /// child
  final Widget child;

  /// [AnimationController.duration]
  final Duration duration;

  /// A list of observers for this navigator.
  final List<FlingNavigatorObserver> observers;

  /// rootOverlay
  final bool rootOverlay;

  /// This method can be expensive (it walks the element tree).
  static FlingNavigatorState of(
    BuildContext context, {
    bool rootNavigator = false,
  }) {
    // Handles the case where the input context is a navigator element.
    FlingNavigatorState? navigator;
    if (context is StatefulElement && context.state is FlingNavigatorState) {
      navigator = context.state as FlingNavigatorState;
    }
    if (rootNavigator) {
      navigator = context.findRootAncestorStateOfType<FlingNavigatorState>() ?? navigator;
    } else {
      navigator = navigator ?? context.findAncestorStateOfType<FlingNavigatorState>();
    }

    assert(() {
      if (navigator == null) {
        throw FlutterError(
          'FlingNavigator operation requested with a context that does not include a FlingNavigator.\n'
          'The context used to push boundaries from the FlingNavigator must be that of a '
          'widget that is a descendant of a FlingNavigator widget.',
        );
      }
      return true;
    }());
    return navigator!;
  }

  /// push
  static void push(
    BuildContext context, {
    Object? fromBoundaryTag,
    Object? toBoundaryTag,
    required Object fromTag,
    required Object toTag,
  }) {
    FlingNavigator.of(context).push(
      fromBoundary: FlingBoundary.of(context, tag: fromBoundaryTag),
      toBoundary: FlingBoundary.of(context, tag: toBoundaryTag),
      fromTag: fromTag,
      toTag: toTag,
    );
  }

  @override
  FlingNavigatorState createState() => FlingNavigatorState();
}

/// [FlingNavigator]
class FlingNavigatorState extends State<FlingNavigator> with TickerProviderStateMixin {
  final _animations = <Duration, Iterable<AnimationController>>{};
  final _boundaryKey = GlobalKey<FlingBoundaryState>();
  final _controller = FlingController();

  late List<FlingNavigatorObserver> _effectiveObservers;

  /// animation
  Animation<double> get _animation {
    final nullableAnimations = <AnimationController?>[...?_animations[widget.duration]];
    var controller = nullableAnimations.firstWhere(
      (element) => element?.isCompleted == true,
      orElse: () => null,
    );
    if (controller == null) {
      controller = AnimationController(
        duration: widget.duration,
        vsync: this,
      );
      nullableAnimations.add(controller);
    }
    _animations[widget.duration] = nullableAnimations.whereType<AnimationController>();
    controller.forward(from: controller.lowerBound);
    return controller;
  }

  /// rootBoundary
  FlingBoundaryState get boundary => _boundaryKey.currentState!;

  /// overlay
  OverlayState get overlay {
    var overlay = Overlay.of(context, rootOverlay: widget.rootOverlay);
    if (overlay == null) {
      void visitor(Element element) {
        if (element.widget is Overlay) {
          overlay = (element as StatefulElement).state as OverlayState;
        } else {
          element.visitChildElements(visitor);
        }
      }

      context.visitChildElements(visitor);
    }
    return overlay!;
  }

  /// push
  void push({
    FlingBoundaryState? fromBoundary,
    FlingBoundaryState? toBoundary,
    required Object fromTag,
    required Object toTag,
  }) {
    _push(
      fromBoundary: fromBoundary,
      toBoundary: toBoundary,
      fromTag: fromTag,
      toTag: toTag,
    );
  }

  /// push
  void _push({
    FlingBoundaryState? fromBoundary,
    FlingBoundaryState? toBoundary,
    required Object fromTag,
    required Object toTag,
  }) {
    fromBoundary ??= boundary;
    toBoundary ??= boundary;
    for (var observer in _effectiveObservers) {
      observer.didPush(fromBoundary, toBoundary, fromTag, toTag);
    }
  }

  @override
  void initState() {
    for (final observer in widget.observers) {
      assert(observer.navigator == null);
      observer._navigator = this;
    }
    _controller._navigator = this;
    _effectiveObservers = widget.observers + <FlingNavigatorObserver>[_controller];
    super.initState();
  }

  @override
  void deactivate() {
    for (final observer in _effectiveObservers) {
      observer._navigator = null;
    }
    super.deactivate();
  }

  @override
  void activate() {
    super.activate();
    for (final observer in _effectiveObservers) {
      assert(observer.navigator == null);
      observer._navigator = this;
    }
  }

  @override
  void dispose() {
    assert(() {
      for (final observer in _effectiveObservers) {
        assert(observer._navigator != this);
      }
      return true;
    }());
    _controller._navigator = null;
    final animations = _animations.values.expand((element) => element);
    for (var animation in animations) {
      animation.dispose();
    }
    _animations.clear();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FlingControllerScope(
      controller: _controller,
      child: FlingBoundary(
        key: _boundaryKey,
        tag: _rootBoundaryTag,
        child: widget.child,
      ),
    );
  }
}

/// [Fling]边界
class FlingBoundary extends StatefulWidget {
  /// 创建一个[Fling]边界
  const FlingBoundary({
    Key? key,
    required this.child,
    required this.tag,
  }) : super(key: key);

  /// child
  final Widget child;

  /// tag
  final Object tag;

  /// This method can be expensive (it walks the element tree).
  static Object get rootBoundaryTag => _rootBoundaryTag;

  /// This method can be expensive (it walks the element tree).
  static FlingBoundaryState of(
    BuildContext context, {
    Object? tag,
  }) {
    // Handles the case where the input context is a boundary element.
    FlingBoundaryState? boundary;
    if (tag == rootBoundaryTag) {
      boundary = FlingNavigator.of(context).boundary;
    } else if (tag != null) {
      boundary = _allBoundariesFor(context)[tag];
    } else {
      if (boundary == null && context is StatefulElement && context.state is FlingBoundaryState) {
        boundary = context.state as FlingBoundaryState;
      }
      boundary = boundary ?? context.findAncestorStateOfType<FlingBoundaryState>();
    }

    final target = tag == null ? 'context' : 'tag: $tag';
    assert(() {
      if (boundary == null) {
        throw FlutterError(
          'FlingBoundary operation requested with a $target that does not include a FlingBoundary.\n'
          'The $target used to push boundaries from the FlingBoundary must be that of a '
          'widget that is a descendant of a FlingBoundary widget.',
        );
      }
      return true;
    }());
    return boundary!;
  }

  // Returns a map of all of the boundaries in `context` indexed by FlingBoundary tag that
  // should be considered for animation when `navigator` transitions from one
  // FlingBoundary to another.
  static Map<Object, FlingBoundaryState> _allBoundariesFor(BuildContext context) {
    final result = <Object, FlingBoundaryState>{};

    void inviteFling(StatefulElement boundary, Object tag) {
      assert(() {
        if (result.containsKey(tag)) {
          throw FlutterError.fromParts(<DiagnosticsNode>[
            ErrorSummary('There are multiple boundaries that share the same tag within a subtree.'),
            ErrorDescription(
              'Within each subtree for which boundaries are to be animated (i.e. a FlingNavigator subtree), '
              'each FlingBoundary must have a unique non-null tag.\n'
              'In this case, multiple boundaries had the following tag: $tag',
            ),
            DiagnosticsProperty<StatefulElement>(
              'Here is the subtree for one of the offending flings',
              boundary,
              linePrefix: '# ',
              style: DiagnosticsTreeStyle.dense,
            ),
          ]);
        }
        return true;
      }());
      result[tag] = boundary.state as FlingBoundaryState;
    }

    void visitor(Element element) {
      final widget = element.widget;
      if (widget is FlingBoundary) {
        final fling = element as StatefulElement;
        final tag = widget.tag;
        inviteFling(fling, tag);
      } else if (widget is FlingMode && !widget.enabled) {
        return;
      }
      element.visitChildren(visitor);
    }

    FlingNavigator.of(context).context.visitChildElements(visitor);
    return result;
  }

  /// push
  static void push(
    BuildContext context, {
    Object? boundaryTag,
    required Object fromTag,
    required Object toTag,
  }) {
    FlingBoundary.of(context).push(
      boundary: FlingBoundary.of(context, tag: boundaryTag),
      fromTag: fromTag,
      toTag: toTag,
    );
  }

  @override
  State<FlingBoundary> createState() => FlingBoundaryState();

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<Object>('tag', tag));
  }
}

/// [FlingBoundary]
class FlingBoundaryState extends State<FlingBoundary> with TickerProviderStateMixin {
  /// navigator
  FlingNavigatorState get navigator => FlingNavigator.of(context);

  /// push
  void push({
    FlingBoundaryState? boundary,
    required Object fromTag,
    required Object toTag,
  }) {
    navigator._push(
      fromBoundary: this,
      toBoundary: boundary,
      fromTag: fromTag,
      toTag: toTag,
    );
  }

  /// Whether this route is currently offstage.
  ///
  /// On the first frame of a route's entrance transition, the route is built
  /// [Offstage] using an animation progress of 1.0. The route is invisible and
  /// non-interactive, but each widget has its final size and position. This
  /// mechanism lets the [FlingController] determine the final local of any hero
  /// widgets being animated as part of the transition.
  final offstageNotifier = ValueNotifier<bool>(false);

  /// Whether this route is currently offstage.
  set offstage(bool value) {
    offstageNotifier.value = value;
  }

  @override
  Widget build(BuildContext context) {
    assert(
      context.findAncestorWidgetOfExactType<FlingBoundary>()?.tag != widget.tag,
      'A FlingBoundary widget cannot be the descendant of another FlingBoundary widget.',
    );

    return widget.child;
  }
}

/// A [Navigator] observer that manages [Fling] transitions.
///
/// An instance of [FlingController] should be used in [Navigator.observers].
/// This is done automatically by [MaterialApp].
class FlingController extends FlingNavigatorObserver {
  /// Creates a fling controller with the given [RectTween] constructor if any.
  ///
  /// The [createRectTween] argument is optional. If null, the controller uses a
  /// linear [Tween<Rect>].
  FlingController({this.createRectTween});

  /// Used to create [RectTween]s that interpolate the position of flings in flight.
  ///
  /// If null, the controller uses a linear [RectTween].
  final CreateRectTween? createRectTween;

  @override
  void didPush(
    FlingBoundaryState fromBoundary,
    FlingBoundaryState toBoundary,
    Object fromTag,
    Object toTag,
  ) {
    _maybeStartFlingTransition(navigator!._animation, fromBoundary, toBoundary, fromTag, toTag);
  }

  // If we're transitioning between different page boundaries, start a fling transition
  // after the toBoundary has been laid out with its animation's value at 1.0.
  void _maybeStartFlingTransition(
    Animation<double> animation,
    FlingBoundaryState fromBoundary,
    FlingBoundaryState toBoundary,
    Object fromTag,
    Object toTag,
  ) {
    final from = fromBoundary;
    final to = toBoundary;

    // A user gesture may have already completed the pop, or we might be the initial boundary
    if (animation.value == 1.0) {
      return;
    }

    // Putting a route offstage changes its animation value to 1.0. Once this
    // frame completes, we'll know where the heroes in the `to` route are
    // going to end up, and the `to` route will go back onstage.
    to.offstage = animation.value == 0.0;

    WidgetsBinding.instance!.addPostFrameCallback((Duration value) {
      _startFlingTransition(animation, from, to, fromTag, toTag);
    });
  }

  // Find the matching pairs of flings in from and to and either start or a new
  // fling flight, or divert an existing one.
  void _startFlingTransition(
    Animation<double> animation,
    FlingBoundaryState from,
    FlingBoundaryState to,
    Object fromTag,
    Object toTag,
  ) {
    // If the `to` route was offstage, then we're implicitly restoring its
    // animation value back to what it was before it was "moved" offstage.
    to.offstage = false;

    final navigator = this.navigator;
    final overlay = navigator?.overlay;
    // If the navigator or the overlay was removed before this end-of-frame
    // callback was called, then don't actually start a transition, and we don'
    // t have to worry about any Fling widget we might have hidden in a previous
    // flight, or ongoing flights.
    if (navigator == null || overlay == null) {
      return;
    }

    final navigatorRenderObject = navigator.context.findRenderObject();

    if (navigatorRenderObject is! RenderBox) {
      assert(
        false,
        'FlingNavigator $navigator has an invalid RenderObject type ${navigatorRenderObject.runtimeType}.',
      );
      return;
    }
    assert(navigatorRenderObject.hasSize);

    // At this point, the toFlings may have been built and laid out for the first time.
    //
    // If `fromSubtreeContext` is null, call endFlight on all toFlings, for good measure.
    // If `toSubtreeContext` is null abort existingFlights.
    final fromFlings = Fling._allFlingsFor(from.context);
    if (!fromFlings.containsKey(fromTag) && from.widget.tag != _rootBoundaryTag) {
      fromFlings.addAll(Fling._allFlingsFor(navigator.boundary.context));
    }
    final toFlings = Fling._allFlingsFor(to.context);
    if (!toFlings.containsKey(toTag) && to.widget.tag != _rootBoundaryTag) {
      toFlings.addAll(Fling._allFlingsFor(navigator.boundary.context));
    }

    void flight(FlingState? fromFling, FlingState? toFling) {
      if (fromFling == null) {
        return;
      }
      _FlingFlightManifest? manifest;
      if (toFling != null) {
        var shuttleBuilder = toFling.widget.flightShuttleBuilder;
        shuttleBuilder ??= fromFling.widget.flightShuttleBuilder;
        shuttleBuilder ??= _defaultFlingFlightShuttleBuilder;
        manifest = _FlingFlightManifest(
          overlay: overlay,
          navigatorSize: navigatorRenderObject.size,
          fromFling: fromFling,
          toFling: toFling,
          createRectTween: createRectTween,
          shuttleBuilder: shuttleBuilder,
          animation: animation,
        );
      }

      // Only proceed with a valid manifest. Otherwise abort the existing
      // flight, and call endFlight when this for loop finishes.
      if (manifest != null && manifest.isValid) {
        toFlings.remove(toTag);
        _FlingFlight().start(manifest);
      }
    }

    flight(fromFlings[fromTag], toFlings[toTag]);

    for (final toFling in toFlings.values) {
      toFling._endFlight();
    }
  }

  Widget _defaultFlingFlightShuttleBuilder(
    BuildContext flightContext,
    Animation<double> animation,
    BuildContext fromFlingContext,
    BuildContext toFlingContext,
  ) {
    final toFling = toFlingContext.widget as Fling;
    return toFling.child;
  }
}

/// Enables or disables [Hero]es in the widget subtree.
///
/// When [enabled] is false, all [Hero] widgets in this subtree will not be
/// involved in hero animations.
///
/// When [enabled] is true (the default), [Hero] widgets may be involved in
/// hero animations, as usual.
class FlingMode extends StatelessWidget {
  /// Creates a widget that enables or disables [Hero]es.
  ///
  /// The [child] and [enabled] arguments must not be null.
  const FlingMode({
    Key? key,
    required this.child,
    this.enabled = true,
  }) : super(key: key);

  /// The subtree to place inside the [FlingMode].
  final Widget child;

  /// Whether or not [Hero]es are enabled in this subtree.
  ///
  /// If this property is false, the [Hero]es in this subtree will not animate
  /// on boundary changes. Otherwise, they will animate as usual.
  ///
  /// Defaults to true and must not be null.
  final bool enabled;

  @override
  Widget build(BuildContext context) => child;

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(FlagProperty('mode', value: enabled, ifTrue: 'enabled', ifFalse: 'disabled', showName: true));
  }
}

/// An inherited widget to host a hero controller.
///
/// The hosted hero controller will be picked up by the navigator in the
/// [child] subtree. Once a navigator picks up this controller, the navigator
/// will bar any navigator below its subtree from receiving this controller.
///
/// The hero controller inside the [FlingControllerScope] can only subscribe to
/// one navigator at a time. An assertion will be thrown if the hero controller
/// subscribes to more than one navigators. This can happen when there are
/// multiple navigators under the same [FlingControllerScope] in parallel.
class FlingControllerScope extends InheritedWidget {
  /// Creates a widget to host the input [controller].
  const FlingControllerScope({
    Key? key,
    required FlingController this.controller,
    required Widget child,
  }) : super(key: key, child: child);

  /// Creates a widget to prevent the subtree from receiving the hero controller
  /// above.
  const FlingControllerScope.none({
    Key? key,
    required Widget child,
  })  : controller = null,
        super(key: key, child: child);

  /// The hero controller that is hosted inside this widget.
  final FlingController? controller;

  /// Retrieves the [FlingController] from the closest [FlingControllerScope]
  /// ancestor.
  static FlingController? of(BuildContext context) {
    final host = context.dependOnInheritedWidgetOfExactType<FlingControllerScope>();
    return host?.controller;
  }

  @override
  bool updateShouldNotify(FlingControllerScope oldWidget) {
    return oldWidget.controller != controller;
  }
}
