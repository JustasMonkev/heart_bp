import 'package:flutter/material.dart';

final _slideTween = Tween<Offset>(
  begin: const Offset(0, 0.018),
  end: Offset.zero,
);

Route<T> buildHeartRoute<T>({
  required WidgetBuilder builder,
  bool fullscreenDialog = false,
  RouteSettings? settings,
}) {
  return PageRouteBuilder<T>(
    settings: settings,
    fullscreenDialog: fullscreenDialog,
    transitionDuration: const Duration(milliseconds: 260),
    reverseTransitionDuration: const Duration(milliseconds: 200),
    pageBuilder: (context, animation, secondaryAnimation) => builder(context),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final fade = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOut,
        reverseCurve: Curves.easeIn,
      );

      return FadeTransition(
        opacity: fade,
        child: SlideTransition(
          position: _slideTween.animate(fade),
          child: RepaintBoundary(child: child),
        ),
      );
    },
  );
}
