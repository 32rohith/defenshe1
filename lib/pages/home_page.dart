// ignore_for_file: unused_import, prefer_const_constructors, prefer_const_literals_to_create_immutables, library_private_types_in_public_api, use_key_in_widget_constructors

import 'package:flutter/material.dart';
import 'package:google_nav_bar/google_nav_bar.dart';
import 'package:provider/provider.dart';
import 'package:sih_1/pages/contact/contact_page.dart';
import 'package:sih_1/pages/dashboard/dashboard_page.dart';
import 'package:sih_1/pages/help/help_page.dart';
import 'package:sih_1/providers/auth_provider.dart';
import 'package:sih_1/pages/maps/map_page.dart';
import 'package:sih_1/pages/settings/settings_page.dart';

class HomePage extends StatefulWidget {
  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedIndex = 1; // Start with Dashboard selected

  // List of pages to navigate to
  final List<Widget> _pages = [
    MapPage(),
    DashboardPage(),
    ContactPage(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: _pages,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: const Color(0xFFFFF0F0), // Matching the app's warm background
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 25,
              offset: const Offset(0, -3),
            ),
          ],
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12),
            child: GNav(
              gap: 8,
              activeColor: const Color(0xff132137), // Dark blue from your app
              color: Colors.grey.shade600,
              iconSize: 24,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              duration: const Duration(milliseconds: 300),
              tabBackgroundColor: const Color(0xFFFFDAB9).withOpacity(0.3), // Peach color from your gradient
              backgroundColor: Colors.transparent,
              rippleColor: const Color(0xFFFFDAB9).withOpacity(0.2), // Subtle ripple effect
              hoverColor: const Color(0xFFFFDAB9).withOpacity(0.1), // Subtle hover effect
              curve: Curves.easeInOut, // Smooth animation curve
              tabs: [
                GButton(
                  icon: Icons.location_on_outlined,
                  text: 'Map',
                  iconActiveColor: const Color(0xff132137),
                  textColor: const Color(0xff132137),
                  iconColor: Colors.grey.shade700,
                  textStyle: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xff132137),
                  ),
                ),
                GButton(
                  icon: Icons.home_outlined,
                  text: 'Home',
                  iconActiveColor: const Color(0xff132137),
                  textColor: const Color(0xff132137),
                  iconColor: Colors.grey.shade700,
                  textStyle: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xff132137),
                  ),
                ),
                GButton(
                  icon: Icons.person_outline,
                  text: 'Contacts',
                  iconActiveColor: const Color(0xff132137),
                  textColor: const Color(0xff132137),
                  iconColor: Colors.grey.shade700,
                  textStyle: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xff132137),
                  ),
                ),
              ],
              selectedIndex: _selectedIndex,
              onTabChange: _onItemTapped,
            ),
          ),
        ),
      ),
    );
  }
}