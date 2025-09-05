import 'package:flutter/material.dart';
import 'package:sih_1/models/contact.dart';
import 'package:sih_1/services/offline_database/contact_database.dart';

class ContactProvider with ChangeNotifier {
  List<Contact> _contacts = [];
  final DatabaseHelper _dbHelper = DatabaseHelper();

  List<Contact> get contacts => _contacts;

  ContactProvider() {
    fetchContacts(); // Fetch contacts on initialization
  }

  Future<void> fetchContacts() async {
    _contacts = await _dbHelper.getContacts();
    notifyListeners(); // Notify listeners when contacts are fetched
  }

  Future<void> addContact(Contact contact) async {
    await _dbHelper.addContact(contact);
    fetchContacts();
  }

  Future<void> updateContact(Contact contact) async {
    await _dbHelper.updateContact(contact);
    fetchContacts();
  }

  Future<void> deleteContact(int id) async {
    await _dbHelper.deleteContact(id);
    fetchContacts();
  }
}
