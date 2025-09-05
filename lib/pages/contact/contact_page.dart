import 'package:flutter/material.dart';
import 'package:flutter_phone_direct_caller/flutter_phone_direct_caller.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:sih_1/models/contact.dart';
import '../../providers/contact_provider.dart';
import 'package:flutter_slidable/flutter_slidable.dart';

class ContactPage extends StatelessWidget {
  const ContactPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Emergency Contacts'),
        automaticallyImplyLeading: false,
        centerTitle: true,
        actions: [
          IconButton(onPressed: () => _addContact(context), icon: const Icon(Icons.add))
        ],
      ),
      body: Consumer<ContactProvider>(
        builder: (context, provider, child) {
          return ListView.builder(
            itemCount: provider.contacts.length,
            itemBuilder: (context, index) {
              final contact = provider.contacts[index];
              return Padding(
                padding: const EdgeInsets.all(10),
                child: Container(
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    color:  const Color(0xff132137),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Slidable(
                    key: ValueKey(contact.id),
                    startActionPane: ActionPane(
                      motion: const StretchMotion(),
                      children: [
                        SlidableAction(
                          onPressed: (context) => _callContact(context, contact.phoneNumber),
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          icon: Icons.call,
                          label: 'Call',
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ],
                    ),
                    endActionPane: ActionPane(
                      motion: const StretchMotion(),
                      children: [
                        SlidableAction(
                          onPressed: (context) => _editContact(context, contact),
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                          icon: Icons.edit,
                          label: 'Edit',
                          borderRadius: const BorderRadius.only(topLeft: Radius.circular(12),bottomLeft: Radius.circular(12)),
                        ),
                        SlidableAction(
                          onPressed: (context) => _confirmDeleteContact(context, contact),
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                          icon: Icons.delete,
                          label: 'Delete',
                          
                          borderRadius: const BorderRadius.only(topRight: Radius.circular(12),bottomRight: Radius.circular(12)),
                        ),
                      ],
                    ),
                    child: ListTile(
                      leading: const CircleAvatar(
                      radius: 25,
                      backgroundColor: Colors.grey,
                      child: Icon(Icons.person, color: Colors.white),
                    ),
                      title: Text(contact.name,style: TextStyle(
                        color: Theme.of(context).colorScheme.secondary,
                      ),),
                      subtitle: Text(contact.phoneNumber,style: TextStyle(
                        color: Theme.of(context).colorScheme.primary,
                      ),),
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _callContact(BuildContext context, String phoneNumber) async {
    final status = await Permission.phone.request();

    if (status.isGranted) {
      try {
        await FlutterPhoneDirectCaller.callNumber(phoneNumber);
      } catch (e) {
        print("Failed to make call: $e");
      }
    } else if (status.isDenied) {
      print("Permission denied");
    } else if (status.isPermanentlyDenied) {
      print("Permission permanently denied");
      await openAppSettings();
    }
  }

  void _editContact(BuildContext context, Contact contact) {
    final nameController = TextEditingController(text: contact.name);
    final phoneController = TextEditingController(text: contact.phoneNumber);

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Edit Contact'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Name'),
              ),
              TextField(
                controller: phoneController,
                decoration: const InputDecoration(labelText: 'Phone Number'),
                keyboardType: TextInputType.phone,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close the dialog without doing anything
              },
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                final name = nameController.text.trim();
                final phoneNumber = phoneController.text.trim();

                if (name.isNotEmpty && phoneNumber.isNotEmpty) {
                  final updatedContact = Contact(id: contact.id, name: name, phoneNumber: phoneNumber);
                  Provider.of<ContactProvider>(context, listen: false).updateContact(updatedContact);
                  Navigator.of(context).pop(); // Close the dialog after updating the contact
                } else {
                  // You can show an error message here
                }
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  void _confirmDeleteContact(BuildContext context, Contact contact) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Contact'),
        content: Text('Are you sure you want to delete ${contact.name}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Provider.of<ContactProvider>(context, listen: false)
                  .deleteContact(contact.id!);
              Navigator.of(context).pop();
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _addContact(BuildContext context) {
    final nameController = TextEditingController();
    final phoneController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Add New Contact'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Name'),
              ),
              TextField(
                controller: phoneController,
                decoration: const InputDecoration(labelText: 'Phone Number'),
                keyboardType: TextInputType.phone,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close the dialog without doing anything
              },
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                final name = nameController.text.trim();
                final phoneNumber = phoneController.text.trim();

                if (name.isNotEmpty && phoneNumber.isNotEmpty) {
                  final newContact = Contact(name: name, phoneNumber: phoneNumber);
                  Provider.of<ContactProvider>(context, listen: false).addContact(newContact);
                  Navigator.of(context).pop(); // Close the dialog after adding the contact
                } else {
                  // You can show an error message here
                }
              },
              child: const Text('Add'),
            ),
          ],
        );
      },
    );
  }
}
