// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:sms_advanced/sms_advanced.dart';
import 'contact_provider.dart'; // Import your ContactProvider

class TrackingProvider with ChangeNotifier {
  bool _isTrackingEnabled = false;
  bool get isTrackingEnabled => _isTrackingEnabled;

  final SmsSender smsSender = SmsSender();

  void toggleTracking(BuildContext context) async {
    _isTrackingEnabled = !_isTrackingEnabled;
    notifyListeners();

    if (_isTrackingEnabled) {
      final provider = Provider.of<ContactProvider>(context, listen: false);
      final contacts = provider.contacts;
      final contactNumbers = contacts.map((c) => c.phoneNumber).toList();
      String location = await getCurrentLocation();
      String message = 'Tracking enabled. Current location: $location';
      await sendSms(contactNumbers,message);
    }
  }

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
      // Handle the case where the permission is not granted
      print("SMS permission not granted");
    }
  }

  Future<void> sendSms(List<String> recipients, String message) async {
    try {
      for (final String recipient in recipients) {
        final SmsMessage sms = SmsMessage(recipient, message);
        smsSender.sendSms(sms);
      }
    } catch (error) {
      print("Error sending SMS: $error");
    }
  }
}
