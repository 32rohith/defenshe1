// ignore_for_file: deprecated_member_use

import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_phone_direct_caller/flutter_phone_direct_caller.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:sih_1/providers/contact_provider.dart';
import 'package:sms_advanced/sms_advanced.dart';
// import 'package:torch_light/torch_light.dart';
// // import 'package:firebase_database/firebase_database.dart';
// import 'package:connectivity_plus/connectivity_plus.dart';

import '../../providers/auth_provider.dart';

class SOS2 extends StatefulWidget {
  const SOS2({super.key});
  @override
  _SOS2State createState() => _SOS2State();
}

class _SOS2State extends State<SOS2> with SingleTickerProviderStateMixin{
  late AnimationController _controller;
  late Animation<double> _animation;
  int countdown = 3; // Countdown starts from 3 seconds
  late Timer _timer;
  final String morseCode = "... --- ..."; // Morse code for SOS
  final int dotDuration = 200; // Duration for '.' in milliseconds
  final int dashDuration = 600; // Duration for '-' in milliseconds
  final int gapDuration = 200; // Gap between signals in milliseconds
  final int charGapDuration = 600; // Gap between characters in milliseconds

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<ContactProvider>(context, listen: false).fetchContacts();
    });
    _controller = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    )..repeat(reverse: true);
    _animation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeInOut,
      ),
    );
    // Start the countdown timer
    _timer = Timer.periodic(const Duration(seconds: 1), (Timer timer) {
      if (countdown == 0) {
        timer.cancel();
        // Trigger emergency call or action
        handleSOS();
      } else {
        setState(() {
          countdown--;
        });
      }
    });
  }
  Future<void> _checkAndRequestPermission() async {
    // Check camera permission status
    PermissionStatus status = await Permission.camera.status;

    if (status.isDenied || status.isPermanentlyDenied) {
      // Request permission if not already granted
      status = await Permission.camera.request();
      if (status.isDenied || status.isPermanentlyDenied) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Camera permission is required to use the flashlight')),
        );
        return;
      }
    }
    
    // If permission is granted, proceed to flash Morse code
    // _flashMorseCode();
  }

  // Future<void> _turnOnFlashlight() async {
  //   try {
  //     await TorchLight.enableTorch();
  //   } catch (e) {
  //     print('Could not turn on flashlight: $e');
  //   }
  // }

  // Future<void> _turnOffFlashlight() async {
  //   try {
  //     await TorchLight.disableTorch();
  //   } catch (e) {
  //     print('Could not turn off flashlight: $e');
  //   }
  // }
  // Future<void> _flashMorseCode() async {
  //   for (int i = 0; i < morseCode.length; i++) {
  //     if (morseCode[i] == '.') {
  //       await _turnOnFlashlight();
  //       await Future.delayed(Duration(milliseconds: dotDuration));
  //     } else if (morseCode[i] == '-') {
  //       await _turnOnFlashlight();
  //       await Future.delayed(Duration(milliseconds: dashDuration));
  //     } else {
  //       await Future.delayed(Duration(milliseconds: charGapDuration));
  //       continue;
  //     }
  //     await _turnOffFlashlight();
  //     await Future.delayed(Duration(milliseconds: gapDuration));
  //   }
  // }

  Future<String> getCurrentLocation() async {
    try {
      Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      return 'Lat: ${position.latitude}, Long: ${position.longitude}\nhttps://www.google.com/maps?q=${position.latitude},${position.longitude}' ;
    } catch (error) {
      print("Error getting location: $error");
      return 'Location unavailable';
    }
  }

  Future<void> requestSmsPermission() async {
    final status = await Permission.sms.request();
    if (!status.isGranted) {
      print("SMS permission not granted");
    }
  }

Future<void> sendSMSToUsers(String message) async {
  try {
    // Check if user is authenticated first
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      print("User is not authenticated");
      return;
    }
    
    QuerySnapshot querySnapshot = await FirebaseFirestore.instance.collection('users').get();
    List<String> userNumbers = querySnapshot.docs.map((doc) {
      print("Fetched phone number: ${doc['phoneNumber']}");
      return doc['phoneNumber'].toString();
    }).toList();

    if (userNumbers.isNotEmpty) {
      await sendSOSMessage(userNumbers, message);
    } else {
      print("No user numbers found in Firestore.");
    }
  } catch (error) {
    print("Error fetching user numbers: $error");
    // Don't rethrow the error to prevent app crash
  }
}

  
Future<void> saveSOSToFirestore(BuildContext context, Map<String, dynamic> location) async {
  try {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      // Get user details from AuthProvider
      final authProvider = Provider.of<AutheProvider>(context, listen: false);
      final userName = authProvider.name;
      final userPhone = authProvider.phoneNumber;
      final locationData = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);

      // Log the location data
      print('Latitude: ${locationData.latitude}, Longitude: ${locationData.longitude}');

      await FirebaseFirestore.instance.collection('sos').add({
        'userId': user.uid,
        'name': userName,
        'phoneNumber': userPhone,
        'latitude': locationData.latitude,
        'longitude': locationData.longitude,
        'timestamp': DateTime.now(),
        'status': 'pending'
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('SOS signal saved successfully')),
      );
    } else {
      throw Exception('User not authenticated');
    }
  } catch (e) {
    print('Error saving SOS signal: $e');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Failed to save SOS signal: $e')),
    );
    // Don't rethrow errors here to prevent app crashes
  }
}

  Future<void> sendSOSMessage(List<String> recipients, String message) async {
    try {
      final SmsSender smsSender = SmsSender();
      for (final String recipient in recipients) {
        final SmsMessage sms = SmsMessage(recipient, message);
        smsSender.sendSms(sms);
      }
    } catch (error) {
      print("Error sending SMS: $error");
    }
  }

  Future<void> makeCall(String phoneNumber) async {
    try {
      await FlutterPhoneDirectCaller.callNumber(phoneNumber);
    } catch (error) {
      print("Error making call: $error");
    }
  }

Future<void> handleSOS() async {
  var locationPermission = await Permission.location.request();
  var callPermission = await Permission.phone.request();

  if (locationPermission.isGranted && callPermission.isGranted) {
    try {
      final provider = Provider.of<ContactProvider>(context, listen: false);
      final contacts = provider.contacts;
      final contactNumbers = contacts.map((c) => c.phoneNumber).toList();
      String policeStationNumber = '8610721331';
      String location = await getCurrentLocation();
      String sosMessage = 'SOS! I need help. My location is: $location';

      await _checkAndRequestPermission();

      // Try to send SMS messages
      try {
        await sendSOSMessage(contactNumbers, sosMessage);
        await sendSOSMessage([policeStationNumber], sosMessage);
      } catch (e) {
        print("Error sending SOS messages: $e");
      }
      
      // Try to make emergency call
      try {
        await makeCall(policeStationNumber);
      } catch (e) {
        print("Error making emergency call: $e");
      }
      
      // Try to send SMS to users from database
      try {
        await sendSMSToUsers(sosMessage);
      } catch (e) {
        print("Error sending SMS to users from database: $e");
      }

      // Try to save SOS to Firestore
      if (mounted) {
        try {
          await saveSOSToFirestore(context, {'location': location});
        } catch (e) {
          print("Error saving SOS to Firestore: $e");
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('SOS alert sent but could not be saved: $e')),
          );
        }
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('SOS alert sent and call made.')),
        );

        Future.delayed(const Duration(seconds: 1), () {
          if (mounted) {
            Navigator.of(context).pop();
          }
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error sending SOS: $e')),
        );
        Future.delayed(const Duration(seconds: 1), () {
          if (mounted) {
            Navigator.of(context).pop();
          }
        });
      }
    }
  } else {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Permissions denied. SOS cannot be sent.')),
      );

      Future.delayed(const Duration(seconds: 1), () {
        if (mounted) {
          Navigator.of(context).pop();
        }
      });
    }
  }
}



  @override
  void dispose() {
    _controller.dispose();
    _timer.cancel();
    // _turnOffFlashlight();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFFFF0F0), Color(0xFFFFDAB9)], // Gradient background colors
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 40),
              _buildTitle(),
              const SizedBox(height: 20),
              _buildSOSButton(),
              const Spacer(),
              _buildSafeButton(context),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTitle() {
    return const Column(
      children: [
        Text(
          'Calling emergency...',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black),
        ),
        SizedBox(height: 10),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 20.0),
          child: Text(
            'Please stand by, we are currently requesting for help. Your emergency contacts and nearby rescue services would see your call for help.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16, color: Colors.black54),
          ),
        ),
      ],
    );
  }

  Widget _buildSOSButton() {
    return Expanded(
      child: Center(
        child: Stack(
          alignment: Alignment.center,
          children: [
            ScaleTransition(
              scale: _animation,
              child: Container(
                width: 250,
                height: 250,
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
                child: Center(
                  child: Text(
                    countdown.toString().padLeft(2, '0'),
                    style: const TextStyle(
                      fontSize: 48,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSafeButton(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40.0),
      child: ElevatedButton(
        onPressed: () {
          // Stop the SOS process and go back
          _timer.cancel(); // Cancel the timer
          Navigator.of(context).pop(); // Navigate back to the previous page with animation
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFFF7E7B), // Background color
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          padding: const EdgeInsets.symmetric(vertical: 16),
        ),
        child: const Text(
          'I AM SAFE',
          style: TextStyle(fontSize: 18, color: Colors.white),
        ),
      ),
    );
  }
}