import 'package:flutter/material.dart';

class SettingsButton extends StatelessWidget {
  const SettingsButton({super.key});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: () async {
        // Navigator.of(context).push(
          // PageRouteBuilder(
          //   pageBuilder: (context, animation, secondaryAnimation) => const SettingsPage(),
          //   transitionsBuilder: (context, animation, secondaryAnimation, child) {
          //     const begin = Offset(1.0, 0.0);
          //     const end = Offset.zero;
          //     const curve = Curves.easeInOut;

          //     var tween = Tween<Offset>(begin: begin, end: end);
          //     var offsetAnimation = animation.drive(tween.chain(CurveTween(curve: curve)));
          //     return SlideTransition(position: offsetAnimation, child: child);
          //   },
          // ),
        // );
      },
      icon: const Icon(Icons.settings),
    );
  }
}