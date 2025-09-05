// ignore_for_file: avoid_unnecessary_containers

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
// import 'package:sih_1/components/report_button.dart';
import 'package:sih_1/pages/dashboard/sos_page2.dart';

import '../../providers/auth_provider.dart';
// import 'package:sih_1/pages/settings/settings_page.dart';

class SOSPage extends StatefulWidget {
  const SOSPage({super.key});

  @override
  _SOSPageState createState() => _SOSPageState();
}

class _SOSPageState extends State<SOSPage> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);
    _animation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeInOut,
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            const SizedBox(height: 10),
            _buildEmergencyText(),
            const SizedBox(height: 10),
            _buildSOSButton(),
          ],
        ),
      );
  }

  Widget _buildHeader() {
    final authProvider = Provider.of<AutheProvider>(context);
    final address = authProvider.address;
    return Container(
      padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Icon(Icons.location_on, color: Theme.of(context).colorScheme.inversePrimary),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Current location', style: TextStyle(color: Theme.of(context).colorScheme.inversePrimary)),
                  Text(address, style: TextStyle(color: Theme.of(context).colorScheme.inversePrimary)),
                ],
              ),
            ],
          ),
      
    );
  }

Widget _buildEmergencyText() {
  return Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16.0),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Are you in an emergency?',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.inversePrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Press the SOS button, your live location will be shared with the nearest help centre and your emergency contacts.',
                style: TextStyle(
                  fontSize: 16,
                  color: Theme.of(context).colorScheme.inversePrimary,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 16), // Space between text and image
        Image.asset(
          'assets/images/sos.png', // Replace with your image asset path
          width: 150, // Adjust width as needed
          height: 200, // Adjust height as needed
          fit: BoxFit.cover, // Adjust fit as needed
        ),
      ],
    ),
  );
}


  Widget _buildSOSButton() {
    return Expanded(
      child: Center(
        child: ScaleTransition(
          scale: _animation,
          child: GestureDetector(
            onTap: () {
                    Navigator.of(context).push(_createRoute());
                  }, 
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  colors: [Color(0xFFFF7E7B), Color(0xFFFFAD59)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.red.withOpacity(0.4),
                    blurRadius: 20,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'SOS',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
  Route _createRoute() {
    return PageRouteBuilder(
      pageBuilder: (context, animation, secondaryAnimation) => const SOS2(),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        const begin = Offset(1.0, 0.0); // Slide from right to left
        const end = Offset.zero;
        const curve = Curves.ease;

        var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
        var offsetAnimation = animation.drive(tween);

        return SlideTransition(
          position: offsetAnimation,
          child: child,
        );
      },
    );
  }
}
