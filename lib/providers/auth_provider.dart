import 'package:flutter/material.dart';

class AutheProvider with ChangeNotifier {
  String _name = '';
  String _age = '';
  String _phoneNumber = '';
  String _address = '';

  String get name => _name;
  String get age => _age;
  String get phoneNumber => _phoneNumber;
  String get address => _address;

  void setName(String name) {
    _name = name;
    notifyListeners();
  }

  void setAge(String age) {
    _age = age;
    notifyListeners();
  }

  void setPhoneNumber(String phoneNumber) {
    _phoneNumber = phoneNumber;
    notifyListeners();
  }

  void setAddress(String address) {
    _address = address;
    notifyListeners();
  }

  void setUserInfo(String name, String age, String phoneNumber, String address) {
    _name = name;
    _age = age;
    _phoneNumber = phoneNumber;
    _address = address;
    notifyListeners();
  }
}