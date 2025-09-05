// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:sih_1/services/offline_database/report_database.dart';

class ReportIssueProvider with ChangeNotifier {
  String? _location;

  String? get location => _location;

  Future<void> fetchCurrentLocation(BuildContext context) async {
    PermissionStatus permissionStatus = await Permission.location.status;

    if (permissionStatus.isGranted) {
      // Permission is already granted, fetch the location
      try {
        Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
        );
        _location = 'Lat: ${position.latitude}, Lon: ${position.longitude}';
        notifyListeners();
      } catch (e) {
        Fluttertoast.showToast(
          msg: "Error fetching location: $e",
          toastLength: Toast.LENGTH_LONG,
          gravity: ToastGravity.BOTTOM,
          backgroundColor: Colors.red,
          textColor: Colors.white,
        );
      }
    } else if (permissionStatus.isDenied) {
      // Show the permission dialog
      await _requestLocationPermission(context);
    } else if (permissionStatus.isPermanentlyDenied) {
      // Open app settings if permission is permanently denied
      await openAppSettings();
      Fluttertoast.showToast(
        msg: "Location permission permanently denied. Please enable it in settings.",
        toastLength: Toast.LENGTH_LONG,
        gravity: ToastGravity.BOTTOM,
        backgroundColor: Colors.orange,
        textColor: Colors.white,
      );
    }
  }

  Future<void> _requestLocationPermission(BuildContext context) async {
    // Request permission
    PermissionStatus status = await Permission.location.request();

    if (status.isGranted) {
      await fetchCurrentLocation(context); // Retry fetching location
    } else if (status.isDenied) {
      Fluttertoast.showToast(
        msg: "Location permission denied",
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
        backgroundColor: Colors.red,
        textColor: Colors.white,
      );
    } else if (status.isPermanentlyDenied) {
      // Open app settings if permission is permanently denied
      await openAppSettings();
      Fluttertoast.showToast(
        msg: "Location permission permanently denied. Please enable it in settings.",
        toastLength: Toast.LENGTH_LONG,
        gravity: ToastGravity.BOTTOM,
        backgroundColor: Colors.orange,
        textColor: Colors.white,
      );
    }
  }
  Future<void> saveIssue(String description, String location) async {
    if (description.isEmpty || location.isEmpty) {
      Fluttertoast.showToast(
        msg: "Please fill in all fields.",
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
        backgroundColor: Colors.orange,
        textColor: Colors.white,
      );
      return;
    }

    try {
      await DatabaseHelper().insertIssue(description, location);
      Fluttertoast.showToast(
        msg: "Thank you for reporting the issue.",
        toastLength: Toast.LENGTH_LONG,
        gravity: ToastGravity.BOTTOM,
        backgroundColor: Colors.green,
        textColor: Colors.white,
      );
    } catch (e, stackTrace) {
      print('Error: $e');
      print('StackTrace: $stackTrace');
      Fluttertoast.showToast(
        msg: "Failed to report the issue. Check logs for details.",
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
        backgroundColor: Colors.red,
        textColor: Colors.white,
      );
    }
  }
}
