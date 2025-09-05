// import 'dart:io';

// import 'package:babstrap_settings_screen/babstrap_settings_screen.dart';
// import 'package:firebase_auth/firebase_auth.dart';
// import 'package:flutter/material.dart';
// import 'package:provider/provider.dart';
// import 'package:sih_1/pages/help/help_page.dart';
// // import 'package:sih_1/pages/login_register/login_page.dart';
// import 'package:sih_1/pages/settings/profile_settings.dart';
// import 'package:sih_1/pages/welcome/introduction_animation_screen.dart';
// import 'package:sih_1/providers/theme_provider.dart';
// import 'package:sih_1/providers/tracking_provider.dart';

// import '../../providers/auth_provider.dart';


// class SettingsPage extends StatefulWidget {
//   const SettingsPage({super.key});

//   @override
//   _SettingsPageState createState() => _SettingsPageState();
// }

// class _SettingsPageState extends State<SettingsPage> {
//   // String _userName = 'Current Name'; 
//   // String _userPhone = 'Current Phone Number';
//   String _profilePictureUrl = ''; 
//   bool _isLoading = false;

//   Future<void> _signOut() async {
//   setState(() {
//     _isLoading = true; // Show loading indicator
//   });

//   try {
//     // Sign out the user using Firebase Auth
//     await FirebaseAuth.instance.signOut();
//   } catch (e) {
//     print("Error signing out: $e");
//   } finally {
//     setState(() {
//       _isLoading = false; // Hide loading indicator
//     });

//     // Navigate back to the LoginPage with animation
//     Navigator.of(context).pushReplacement(
//       PageRouteBuilder(
//         pageBuilder: (context, animation, secondaryAnimation) => const IntroductionAnimationScreen(),
//         transitionsBuilder: (context, animation, secondaryAnimation, child) {
//           const begin = Offset(-1.0, 0.0); // Slide from left
//           const end = Offset.zero;
//           const curve = Curves.easeInOut;

//           var tween = Tween<Offset>(begin: begin, end: end);
//           var offsetAnimation = animation.drive(tween.chain(CurveTween(curve: curve)));
//           return SlideTransition(position: offsetAnimation, child: child);
//         },
//       ),
//     );
//   }
// }



//   @override
//   Widget build(BuildContext context) {
//     final themeProvider = Provider.of<ThemeProvider>(context);
//     final trackingProvider = Provider.of<TrackingProvider>(context);
//     final authProvider = Provider.of<AutheProvider>(context);
//     final name = authProvider.name;
//     final phone = authProvider.phoneNumber;

//     return Scaffold(
//       appBar: AppBar(
//         title: const Text("Settings Page"),
//         ),
//       body: Stack(
//         children: [
//           Padding(
//             padding: const EdgeInsets.all(10),
//             child: ListView(
//               children: [
//                 // User card
//                 BigUserCard(
//                   backgroundColor:  const Color(0xff132137),
//                   userName: name,
//                   userProfilePic: _profilePictureUrl.isNotEmpty
//                             ? FileImage(File(_profilePictureUrl))
//                             : const AssetImage('assets/images/pfp.png') as ImageProvider,
//                   cardActionWidget: SettingsItem(
//                     icons: Icons.edit,
//                     iconStyle: IconStyle(
//                       withBackground: true,
//                       borderRadius: 50,
//                       backgroundColor: Colors.yellow[600],
//                     ),
//                     title: "Modify",
//                     subtitle: "Tap to change your data",
//                     onTap: () async {
//                         final result = await Navigator.of(context).push(
//                           PageRouteBuilder(
//                             pageBuilder: (context, animation, secondaryAnimation) => ProfileSettingsScreen(
//                               initialName: name,
//                               initialPhoneNumber: phone,
//                               initialProfilePicture: _profilePictureUrl,
//                             ),
//                             transitionsBuilder: (context, animation, secondaryAnimation, child) {
//                               const begin = Offset(1.0, 0.0);
//                               const end = Offset.zero;
//                               const curve = Curves.easeInOut;

//                               var tween = Tween<Offset>(begin: begin, end: end);
//                               var offsetAnimation = animation.drive(tween.chain(CurveTween(curve: curve)));
//                               return SlideTransition(position: offsetAnimation, child: child);
//                             },
//                           ),
//                         );

//                         if (result != null) {
//                           setState(() {
//                             // name = result['name'];
//                             // phone = result['phone'];
//                             _profilePictureUrl = result['profilePicture'];
//                           });
//                         }
//                       },
//                   ),
//                 ),
                
//                 SettingsGroup(
//                   items: [
//                     SettingsItem(
//                       title: 'Dark mode',
//                       icons: themeProvider.isDarkMode ? Icons.nightlight_round : Icons.wb_sunny,
//                       iconStyle: IconStyle(
//                         iconsColor: Colors.white,
//                         withBackground: true,
//                         backgroundColor: Colors.red,
//                       ),
//                       trailing: AnimatedSwitcher(
//                         duration: const Duration(milliseconds: 300),
//                         child: Switch.adaptive(
//                           key: ValueKey<bool>(themeProvider.isDarkMode),
//                           value: themeProvider.isDarkMode,
//                           onChanged: (value) {
//                             themeProvider.toggleTheme(value);
//                           },
//                         ),
//                       ),
//                     ),
    
//                     SettingsItem(
//                       icons: trackingProvider.isTrackingEnabled ? Icons.location_on : Icons.location_off,
//                       title: 'Enable Tracking',
//                       iconStyle: IconStyle(
//                         iconsColor: Colors.white,
//                         withBackground: true,
//                         backgroundColor: Colors.green,
//                       ),
//                       trailing: AnimatedSwitcher(
//                         duration: const Duration(milliseconds: 300),
//                         child: Switch.adaptive(
//                           key: ValueKey<bool>(trackingProvider.isTrackingEnabled),
//                           value: trackingProvider.isTrackingEnabled,
//                           onChanged: (value) {
//                             trackingProvider.toggleTracking(context);
//                           },
//                         ),
//                       ),
//                     ),
    
//                     SettingsItem(
//                       onTap: () async {
//                         Navigator.of(context).push(
//                           PageRouteBuilder(
//                             pageBuilder: (context, animation, secondaryAnimation) => const HelpPage(),
//                             transitionsBuilder: (context, animation, secondaryAnimation, child) {
//                               const begin = Offset(1.0, 0.0);
//                               const end = Offset.zero;
//                               const curve = Curves.easeInOut;

//                               var tween = Tween<Offset>(begin: begin, end: end);
//                               var offsetAnimation = animation.drive(tween.chain(CurveTween(curve: curve)));
//                               return SlideTransition(position: offsetAnimation, child: child);
//                             },
//                           ),
//                         );
//                       },
//                       icons: Icons.help_outline_rounded,
//                       iconStyle: IconStyle(
//                         backgroundColor: Colors.black,
//                       ),
//                       title: 'Help & Support',
//                     ),
                
//                     SettingsItem(
//                       onTap: () {},
//                       icons: Icons.info_rounded,
//                       iconStyle: IconStyle(
//                         backgroundColor: Colors.purple,
//                       ),
//                       title: 'About',
//                     ),
//                   ],
                  
//                 ),
//                 SettingsGroup(
//                   settingsGroupTitle: "Account",
//                   items: [
//                     SettingsItem(
//                       onTap: _signOut, // Call sign-out function
//                       icons: Icons.exit_to_app_rounded,
//                       title: "Sign Out",
//                     ),
//                   ],
//                 ),
//               ],
//             ),
//           ),
//           if (_isLoading) // Show loading indicator if _isLoading is true
//             const Center(
//               child: CircularProgressIndicator(),
//             ),
//         ],
//       ),
//     );
//   }
// }