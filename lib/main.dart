import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
// import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:provider/provider.dart';
import 'package:permission_handler/permission_handler.dart' as permissionHandler;
import 'package:sih_1/pages/home_page.dart';
// import 'package:sih_1/pages/login_page.dart';
import 'package:sih_1/pages/welcome/introduction_animation_screen.dart';
// import 'package:sih_1/providers/auth_provider.dart' as customAuthProvider;
import 'package:sih_1/providers/theme_provider.dart';
import 'package:sih_1/providers/sos_provider.dart';
import 'package:sih_1/providers/contact_provider.dart';
import 'package:sih_1/providers/report_provider.dart';
import 'package:sih_1/providers/tracking_provider.dart';
import 'package:sih_1/providers/profile_provider.dart';
import 'package:sih_1/scripts/populate_safety_locations.dart'; // Import the script

import 'providers/auth_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  
  // Uncomment to populate safety locations (run once, then comment back)
  // await PopulateSafetyLocations.run();
  
  // Request permissions
  await _requestPermissions();
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (context) => ThemeProvider()),
        ChangeNotifierProvider(create: (context) => SOSProvider()),
        ChangeNotifierProvider(create: (context) => ContactProvider()),
        ChangeNotifierProvider(create: (context) => ReportIssueProvider()),
        ChangeNotifierProvider(create: (context) => TrackingProvider()),
        ChangeNotifierProvider(create: (context) => UserProfileProvider()),
        ChangeNotifierProvider(create: (context) => AutheProvider())
      ],
      child: const MyApp(),
    ),
  );
} 

Future<void> _requestPermissions() async {
  await [
    permissionHandler.Permission.camera,
    permissionHandler.Permission.location,
    permissionHandler.Permission.storage,
    permissionHandler.Permission.microphone,
    permissionHandler.Permission.contacts,
    permissionHandler.Permission.sms,
    permissionHandler.Permission.phone,
    permissionHandler.Permission.photos,
    permissionHandler.Permission.notification,
  ].request();
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: Provider.of<ThemeProvider>(context).themeData,
      home: const AuthWrapper(),
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasData) {
          return HomePage();
        }
        return const IntroductionAnimationScreen();
      },
    );
  }
}