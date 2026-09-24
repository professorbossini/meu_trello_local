import 'package:flutter/material.dart';

import 'theme.dart';

/// Fades and slides [child] in the first time it is built, so new or moved
/// items visibly land in place.
class Appear extends StatelessWidget {
  const Appear({super.key, required this.child, this.offset = 12});

  final Widget child;

  /// Vertical distance, in pixels, the child slides up from.
  final double offset;

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    tween: Tween(begin: 0, end: 1),
    duration: Motion.long,
    curve: Motion.emphasized,
    builder: (context, t, child) => Opacity(
      opacity: t,
      child: Transform.translate(
        offset: Offset(0, (1 - t) * offset),
        child: child,
      ),
    ),
    child: child,
  );
}

/// Animates [child] into a "picked up" pose: slightly bigger and tilted.
class Lift extends StatelessWidget {
  const Lift({super.key, required this.child, this.angle = 0.035});

  final Widget child;
  final double angle;

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    tween: Tween(begin: 0, end: 1),
    duration: Motion.medium,
    curve: Motion.emphasized,
    builder: (context, t, child) => Transform.rotate(
      angle: angle * t,
      child: Transform.scale(scale: 1 + 0.04 * t, child: child),
    ),
    child: child,
  );
}

/// Confirms a destructive action and offers to revert it.
void showUndoSnackBar(
  ScaffoldMessengerState messenger, {
  required String message,
  required VoidCallback onUndo,
}) {
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 6),
        action: SnackBarAction(label: 'Desfazer', onPressed: onUndo),
      ),
    );
}
