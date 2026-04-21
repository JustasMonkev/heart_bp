import 'package:flutter/material.dart';

final _slideTween = Tween<Offset>(
  begin: const Offset(0, 0.035),
  end: Offset.zero,
);
final _scaleTween = Tween<double>(begin: 0.985, end: 1);

Route<T> buildHeartRoute<T>({
  required WidgetBuilder builder,
  bool fullscreenDialog = false,
  RouteSettings? settings,
}) {
  return PageRouteBuilder<T>(
    settings: settings,
    fullscreenDialog: fullscreenDialog,
    transitionDuration: const Duration(milliseconds: 420),
    reverseTransitionDuration: const Duration(milliseconds: 280),
    pageBuilder: (context, animation, secondaryAnimation) => builder(context),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final fade = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );

      return FadeTransition(
        opacity: fade,
        child: SlideTransition(
          position: _slideTween.animate(fade),
          child: ScaleTransition(
            scale: _scaleTween.animate(fade),
            child: child,
          ),
        ),
      );
    },
  );
}
