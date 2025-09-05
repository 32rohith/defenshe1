import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class ProfileSettingsScreen extends StatefulWidget {
  final String initialName;
  final String initialPhoneNumber;
  final String initialProfilePicture;

  const ProfileSettingsScreen({super.key, 
    required this.initialName,
    required this.initialPhoneNumber,
    required this.initialProfilePicture,
  });

  @override
  _ProfileSettingsScreenState createState() => _ProfileSettingsScreenState();
}

class _ProfileSettingsScreenState extends State<ProfileSettingsScreen> {
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  String _profilePictureUrl = '';

  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _nameController.text = widget.initialName;
    _phoneController.text = widget.initialPhoneNumber;
    _profilePictureUrl = widget.initialProfilePicture;
  }

  Future<void> _pickProfilePicture() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() {
        _profilePictureUrl = image.path;
      });
    }
  }

  void _deleteProfilePicture() {
    setState(() {
      _profilePictureUrl = ''; // Reset to default
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Profile'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: GestureDetector(
                onTap: _pickProfilePicture,
                child: CircleAvatar(
                  radius: 50,
                  backgroundImage: _profilePictureUrl.isNotEmpty
                      ? FileImage(File(_profilePictureUrl))
                      : const AssetImage('assets/default_profile_picture.png') as ImageProvider,
                  child: _profilePictureUrl.isEmpty
                      ? Icon(Icons.camera_alt, size: 50, color: Colors.grey[800])
                      : null,
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (_profilePictureUrl.isNotEmpty)
              Center(
                child: ElevatedButton(
                  onPressed: _deleteProfilePicture,
                  child: const Text('Delete Profile Picture'),
                ),
              ),
            const SizedBox(height: 16),
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Name',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _phoneController,
              decoration: const InputDecoration(
                labelText: 'Phone Number',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context, {
                  'name': _nameController.text,
                  'phone': _phoneController.text,
                  'profilePicture': _profilePictureUrl,
                });
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }
}
