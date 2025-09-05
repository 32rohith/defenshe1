import 'package:flutter/material.dart';
import 'package:sih_1/theme/dark_mode.dart';
import 'package:sih_1/theme/light_mode.dart';

class ThemeProvider with ChangeNotifier{
  ThemeData _themeData = lightmode;

  ThemeData get themeData => _themeData;

  bool get isDarkMode => _themeData == darkmode;

  set themeData(ThemeData themeData){
    _themeData = themeData;
    notifyListeners();
  }

  void toggleTheme(bool value){
    if(_themeData == lightmode) {
      themeData = darkmode;
    } else{
      themeData = lightmode;
    }
  }
}

// import 'package:flutter/material.dart';
// import 'package:sih_1/theme/dark_mode.dart';
// import 'package:sih_1/theme/light_mode.dart';
// import 'package:flutter/material.dart';

// class ThemeProvider with ChangeNotifier {
//   ThemeData _themeData = ThemeData.light;

//   ThemeData get themeData => _themeData;

//   void toggleTheme(bool isDarkData) {
//     _themeData = isDarkData ? ThemeData.dark : ThemeData.light;
//     notifyListeners();
//   }


//   set themeData(ThemeData themeData){
//     _themeData = themeData;
//     notifyListeners();
//   }


// }