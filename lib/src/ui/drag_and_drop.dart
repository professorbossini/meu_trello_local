import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import 'theme.dart';

/// Payload carried while dragging a card.
@immutable
class CardDragData {
  const CardDragData(this.cardId);

  final String cardId;
}

/// Payload carried while dragging a whole list.
@immutable
class ListDragData {
  const ListDragData(this.listId);

  final String listId;
}

/// A [Draggable] that starts as soon as the pointer travels [slop] pixels.
///
/// The stock [Draggable] kicks in after a single pixel with a mouse, so a
/// slightly shaky click would start a drag instead of opening the card.
class BoardDraggable<T extends Object> extends Draggable<T> {
  const BoardDraggable({
    super.key,
    required super.child,
    required super.feedback,
    super.data,
    super.childWhenDragging,
    super.dragAnchorStrategy,
    super.onDragStarted,
    super.onDragUpdate,
    super.onDragEnd,
    this.slop = 4,
  });

  final double slop;

  @override
  MultiDragGestureRecognizer createRecognizer(
    GestureMultiDragStartCallback onStart,
  ) => _SlopMultiDragGestureRecognizer(slop)..onStart = onStart;
}

class _SlopMultiDragGestureRecognizer extends MultiDragGestureRecognizer {
  _SlopMultiDragGestureRecognizer(this.slop) : super(debugOwner: null);

  final double slop;

  @override
  MultiDragPointerState createNewPointerState(PointerDownEvent event) =>
      _SlopPointerState(event.position, event.kind, gestureSettings, slop);

  @override
  String get debugDescription => 'board drag';
}

class _SlopPointerState extends MultiDragPointerState {
  _SlopPointerState(
    super.initialPosition,
    super.kind,
    super.gestureSettings,
    this.slop,
  );

  final double slop;

  @override
  void checkForResolutionAfterMove() {
    if (pendingDelta!.distance > slop) {
      resolve(GestureDisposition.accepted);
    }
  }

  @override
  void accepted(GestureMultiDragStartCallback starter) {
    starter(initialPosition);
  }
}

/// Tracks whether a board drag is in progress and where the pointer is, so
/// scrollable areas can auto-scroll when the pointer nears their edges.
class BoardDragActivity extends ChangeNotifier {
  bool get active => _payload != null;

  /// What is being dragged: a [CardDragData] or a [ListDragData].
  Object? get payload => _payload;
  Object? _payload;

  Offset? _pointer;
  Offset? get pointer => _pointer;

  void start(Object payload) {
    _payload = payload;
    notifyListeners();
  }

  void update(Offset globalPosition) => _pointer = globalPosition;

  void end() {
    _payload = null;
    _pointer = null;
    notifyListeners();
  }

  /// Looks up the activity without subscribing to it; listeners attach
  /// explicitly where they care about changes.
  static BoardDragActivity of(BuildContext context) =>
      context.getInheritedWidgetOfExactType<BoardDragScope>()!.activity;
}

class BoardDragScope extends InheritedWidget {
  const BoardDragScope({
    super.key,
    required this.activity,
    required super.child,
  });

  final BoardDragActivity activity;

  @override
  bool updateShouldNotify(BoardDragScope oldWidget) =>
      activity != oldWidget.activity;
}

/// Wires a [Draggable]'s lifecycle callbacks into the [BoardDragActivity].
mixin BoardDragCallbacks<T extends StatefulWidget> on State<T> {
  BoardDragActivity get _activity => BoardDragActivity.of(context);

  void onBoardDragStarted(Object payload) => _activity.start(payload);

  void onBoardDragUpdate(DragUpdateDetails details) =>
      _activity.update(details.globalPosition);

  void onBoardDragEnd() => _activity.end();
}

/// Where a dragged item will land relative to the hovered one.
enum DropSide {
  before,
  after;

  static DropSide fromPosition(double position, double extent) =>
      position < extent / 2 ? before : after;
}

/// The accent line showing where a dragged item will land: the gradient
/// with a soft glow, growing from its center as it appears.
class DropIndicator extends StatelessWidget {
  const DropIndicator({super.key, this.axis = Axis.horizontal});

  /// Direction the line extends in.
  final Axis axis;

  static const thickness = 4.0;

  @override
  Widget build(BuildContext context) {
    final horizontal = axis == Axis.horizontal;
    final line = DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: horizontal ? Alignment.centerLeft : Alignment.topCenter,
          end: horizontal ? Alignment.centerRight : Alignment.bottomCenter,
          colors: AppTheme.gradientColors,
        ),
        borderRadius: BorderRadius.circular(thickness),
        boxShadow: [
          BoxShadow(
            color: AppTheme.gradientColors[1].withValues(alpha: 0.55),
            blurRadius: 10,
          ),
        ],
      ),
    );
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.2, end: 1),
      duration: Motion.short,
      curve: Motion.emphasized,
      builder: (context, t, child) => Opacity(
        opacity: t.clamp(0, 1),
        child: Transform.scale(
          scaleX: horizontal ? t : 1,
          scaleY: horizontal ? 1 : t,
          child: child,
        ),
      ),
      child: horizontal
          ? SizedBox(height: thickness, width: double.infinity, child: line)
          : SizedBox(width: thickness, height: double.infinity, child: line),
    );
  }
}

/// Scrolls [controller] while a board drag hovers near the edges of [child].
///
/// The speed grows the closer the pointer gets to the edge, which gives a
/// precise feel for short hops and a quick ride across long boards.
class DragAutoScroller extends StatefulWidget {
  const DragAutoScroller({
    super.key,
    required this.controller,
    required this.axis,
    required this.child,
  });

  final ScrollController controller;
  final Axis axis;
  final Widget child;

  @override
  State<DragAutoScroller> createState() => _DragAutoScrollerState();
}

class _DragAutoScrollerState extends State<DragAutoScroller> {
  static const _edgeExtent = 64.0;
  static const _maxStep = 20.0;
  static const _tick = Duration(milliseconds: 16);

  BoardDragActivity? _activity;
  Timer? _timer;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final activity = BoardDragActivity.of(context);
    if (activity == _activity) return;
    _activity?.removeListener(_onActivityChanged);
    _activity = activity..addListener(_onActivityChanged);
  }

  void _onActivityChanged() {
    if (_activity!.active) {
      _timer ??= Timer.periodic(_tick, (_) => _step());
    } else {
      _timer?.cancel();
      _timer = null;
    }
  }

  void _step() {
    final pointer = _activity?.pointer;
    final box = context.findRenderObject() as RenderBox?;
    final controller = widget.controller;
    if (pointer == null || box == null || !box.attached) return;
    if (!controller.hasClients) return;

    final rect = box.localToGlobal(Offset.zero) & box.size;
    if (!rect.contains(pointer)) return;

    final horizontal = widget.axis == Axis.horizontal;
    final position = horizontal ? pointer.dx : pointer.dy;
    final start = horizontal ? rect.left : rect.top;
    final end = horizontal ? rect.right : rect.bottom;

    double step = 0;
    if (position < start + _edgeExtent) {
      step = -_maxStep * (1 - (position - start) / _edgeExtent);
    } else if (position > end - _edgeExtent) {
      step = _maxStep * (1 - (end - position) / _edgeExtent);
    }
    if (step == 0) return;

    final metrics = controller.position;
    final target = (metrics.pixels + step).clamp(
      metrics.minScrollExtent,
      metrics.maxScrollExtent,
    );
    if (target != metrics.pixels) controller.jumpTo(target);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _activity?.removeListener(_onActivityChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
