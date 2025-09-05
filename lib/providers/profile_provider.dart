import 'package:flutter/material.dart';

class UserProfileProvider with ChangeNotifier {
  String _userName = "User";
  String _phoneNumber = "123456789";
  // String _profilePictureUrl = "";

  String get userName => _userName;
  String get phoneNumber => _phoneNumber;
  // String get profilePictureUrl => _profilePictureUrl;
// , String profilePictureUrl - add to function later
  void updateUserProfile(String name, String phoneNumber) {
    _userName = name;
    _phoneNumber = phoneNumber;
    // _profilePictureUrl = profilePictureUrl;
    notifyListeners();
  }
}
