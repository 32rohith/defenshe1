// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:sih_1/components/report_button.dart';
import 'package:sih_1/components/settings_button.dart';
import 'package:sih_1/pages/dashboard/sos_page1.dart';
// import 'package:permission_handler/permission_handler.dart';
// import 'package:provider/provider.dart';
// import 'package:sih_1/components/report_button.dart';
// import 'package:sih_1/pages/dashboard/sos_page1.dart';
// // import 'package:sih_1/models/contact.dart';
// import 'package:sih_1/providers/contact_provider.dart';
// import 'package:sih_1/providers/sos_provider.dart';
// // import 'package:flutter_tts/flutter_tts.dart';
// import 'package:flutter_phone_direct_caller/flutter_phone_direct_caller.dart';
// import 'package:geolocator/geolocator.dart';
// import 'package:telephony/telephony.dart';
// import 'package:speech_to_text/speech_to_text.dart' as stt;

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  _DashboardPageState createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> with SingleTickerProviderStateMixin {
  // late SOSProvider _sosProvider;
  // final stt.SpeechToText _speech = stt.SpeechToText();
  // bool _isListening = false;
  // String _lastWords = '';

  
  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Scaffold(
        appBar: AppBar(
          leading: const SettingsButton(),
          actions: const [
            ReportButton(),
          ],
          title: const Text("Defenshe"),
          centerTitle: true,
        ),
        body: const SOSPage(),
        
      ),
    );
  }
}
