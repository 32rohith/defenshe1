import 'package:flutter/material.dart';

class SOSProvider with ChangeNotifier {
  late AnimationController _controller;
  late Animation<double> _animation;
  Animation<double> get animation => _animation;

  void initializeController(TickerProvider vsync) {
    _controller = AnimationController(
      duration: const Duration(seconds: 1),
      vsync: vsync,
    )..repeat(reverse: true);

    _animation = Tween<double>(begin: 0.2, end: 1.0).animate(_controller);
  }

  void disposeController() {
    _controller.dispose();
  }
}
