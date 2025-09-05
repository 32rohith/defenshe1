
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:sih_1/pages/welcome/components/care_view.dart';
import 'package:sih_1/pages/welcome/components/center_next_button.dart';
import 'package:sih_1/pages/welcome/components/mood_diary_vew.dart';
import 'package:sih_1/pages/welcome/components/relax_view.dart';
import 'package:sih_1/pages/welcome/components/splash_view.dart';
import 'package:sih_1/pages/welcome/components/top_back_skip_view.dart';
import 'package:sih_1/pages/welcome/components/welcome_view.dart';

class IntroductionAnimationScreen extends StatefulWidget {
  const IntroductionAnimationScreen({super.key});

  @override
  _IntroductionAnimationScreenState createState() =>
      _IntroductionAnimationScreenState();
}

class _IntroductionAnimationScreenState
    extends State<IntroductionAnimationScreen> with TickerProviderStateMixin {
  AnimationController? _animationController;
  Future<void> requestPermissions() async {
    // Request multiple permissions at once
    Map<Permission, PermissionStatus> statuses = await [
      // Permission.internet,
      Permission.phone,
      Permission.contacts,
      Permission.location,
      Permission.locationAlways,
      Permission.sms,
      Permission.storage,
      Permission.microphone,
      Permission.camera,
      // Permission.flashlight,
    ].request();

    // Check the statuses
    statuses.forEach((permission, status) {
      if (status.isDenied) {
        // If the permission is denied, handle accordingly
        print('$permission is denied.');
      } else if (status.isPermanentlyDenied) {
        // Open app settings if the permission is permanently denied
        openAppSettings();
      }
    });
  }
  @override
  void initState() {
    // WidgetsBinding.instance.addPostFrameCallback((_) {
    //   // requestPermissions();
    // });
    _animationController =
        AnimationController(vsync: this, duration: const Duration(seconds: 8));
    _animationController?.animateTo(0.0);
    super.initState();
  }

  @override
  void dispose() {
    _animationController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    print(_animationController?.value);
    return Scaffold(
      backgroundColor: const Color(0xffF7EBE1),
      body: ClipRect(
        child: Stack(
          children: [
            const SizedBox(height: 500,),
            SplashView(
              animationController: _animationController!,
            ),
            RelaxView(
              animationController: _animationController!,
            ),
            CareView(
              animationController: _animationController!,
            ),
            MoodDiaryVew(
              animationController: _animationController!,
            ),
            WelcomeView(
              animationController: _animationController!,
            ),
            TopBackSkipView(
              onBackClick: _onBackClick,
              onSkipClick: _onSkipClick,
              animationController: _animationController!,
            ),
            CenterNextButton(
              animationController: _animationController!,
              onNextClick: _onNextClick,
            ),
          ],
        ),
      ),
    );
  }

  void _onSkipClick() {
    _animationController?.animateTo(0.8,
        duration: const Duration(milliseconds: 1200));
  }

  void _onBackClick() {
    if (_animationController!.value >= 0 &&
        _animationController!.value <= 0.2) {
      _animationController?.animateTo(0.0);
    } else if (_animationController!.value > 0.2 &&
        _animationController!.value <= 0.4) {
      _animationController?.animateTo(0.2);
    } else if (_animationController!.value > 0.4 &&
        _animationController!.value <= 0.6) {
      _animationController?.animateTo(0.4);
    } else if (_animationController!.value > 0.6 &&
        _animationController!.value <= 0.8) {
      _animationController?.animateTo(0.6);
    } else if (_animationController!.value > 0.8 &&
        _animationController!.value <= 1.0) {
      _animationController?.animateTo(0.8);
    }
  }

  void _onNextClick() {
    if (_animationController!.value >= 0 &&
        _animationController!.value <= 0.2) {
      _animationController?.animateTo(0.4);
    } else if (_animationController!.value > 0.2 &&
        _animationController!.value <= 0.4) {
      _animationController?.animateTo(0.6);
    } else if (_animationController!.value > 0.4 &&
        _animationController!.value <= 0.6) {
      _animationController?.animateTo(0.8);
    } else if (_animationController!.value > 0.6 &&
        _animationController!.value <= 0.8) {
      _signUpClick();
    }
  }

  void _signUpClick() {
    Navigator.pop(context);
  }
}
