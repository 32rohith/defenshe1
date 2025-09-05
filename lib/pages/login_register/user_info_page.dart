import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:confetti/confetti.dart';
import 'dart:convert';
import 'package:provider/provider.dart';
import 'package:sih_1/providers/contact_provider.dart';
import 'package:sih_1/providers/auth_provider.dart';
import 'package:sih_1/pages/home_page.dart';
import 'package:sih_1/models/contact.dart';

class UserInfoPage extends StatefulWidget {
  final String phoneNumber;

  const UserInfoPage({super.key, required this.phoneNumber});

  @override
  _UserInfoPageState createState() => _UserInfoPageState();
}

class _UserInfoPageState extends State<UserInfoPage> {
  final nameController = TextEditingController();
  final ageController = TextEditingController();
  final addressController = TextEditingController();
  final List<Contact> contacts = [];
  final _confettiController = ConfettiController();
  bool _isLoading = false;

  @override
  void dispose() {
    _confettiController.dispose();
    super.dispose();
  }

  void addContact() {
    setState(() {
      contacts.add(Contact(name: '', phoneNumber: ''));
    });
  }

  Future<void> saveUserInfo() async {
    setState(() => _isLoading = true);
    
    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) return;

      // Save to Firebase
      await FirebaseFirestore.instance.collection('users').doc(userId).set({
        'name': nameController.text,
        'phoneNumber': widget.phoneNumber,
        'age': int.parse(ageController.text),
        'address': addressController.text,
        'contacts': contacts.map((c) => c.toMap()).toList(),
      });

      // Save locally
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_name', nameController.text);
      await prefs.setString('user_phoneNumber', widget.phoneNumber); // Save phone number locally
      await prefs.setInt('user_age', int.parse(ageController.text));
      await prefs.setString('user_address', addressController.text);

      // Convert contacts to JSON and save locally
      List<Map<String, dynamic>> contactList = contacts.map((c) => c.toMap()).toList();
      String contactsJson = jsonEncode(contactList);
      await prefs.setString('user_contacts', contactsJson);

      // Add contacts to ContactProvider
      for (var contact in contacts) {
        Provider.of<ContactProvider>(context, listen: false).addContact(contact);
      }

      // Update AuthProvider
      Provider.of<AutheProvider>(context, listen: false).setUserInfo(
        nameController.text,
        ageController.text,
        widget.phoneNumber,
        addressController.text,
      );

      // Show confetti
      _confettiController.play();
      
      // Navigate after delay
      await Future.delayed(const Duration(seconds: 2));
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => HomePage()),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error saving data')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.all(20),
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Name'),
              ),
              TextField(
                controller: ageController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Age'),
              ),
              TextField(
                controller: addressController,
                decoration: const InputDecoration(labelText: 'Address'),
              ),
              const SizedBox(height: 20),
              const Text('Emergency Contacts', style: TextStyle(fontSize: 18)),
              ...contacts.map((contact) => ContactField(contact: contact)),
              TextButton(
                onPressed: addContact,
                child: const Text('Add Contact'),
              ),
              ElevatedButton(
                onPressed: _isLoading ? null : saveUserInfo,
                child: _isLoading
                    ? const CircularProgressIndicator()
                    : const Text('Complete Setup'),
              ),
            ],
          ),
          Align(
            alignment: Alignment.topCenter,
            child: ConfettiWidget(
              confettiController: _confettiController,
              blastDirection: 3.14 / 2,
              maxBlastForce: 5,
              minBlastForce: 2,
              emissionFrequency: 0.05,
              numberOfParticles: 50,
            ),
          ),
        ],
      ),
    );
  }
}

class ContactField extends StatelessWidget {
  final Contact contact;
  
  const ContactField({super.key, required this.contact});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TextField(
          controller: TextEditingController(text: contact.name),
          onChanged: (value) => contact.name = value,
          decoration: const InputDecoration(labelText: 'Contact Name'),
        ),
        TextField(
          controller: TextEditingController(text: contact.phoneNumber),
          onChanged: (value) => contact.phoneNumber = value,
          keyboardType: TextInputType.phone,
          decoration: const InputDecoration(labelText: 'Contact Phone'),
        ),
        const SizedBox(height: 10),
      ],
    );
  }
}