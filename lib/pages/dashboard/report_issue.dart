import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:sih_1/providers/report_provider.dart';

class ReportIssueDialog extends StatelessWidget {
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();

  ReportIssueDialog({super.key});

  @override
  Widget build(BuildContext context) {
    final reportProvider = Provider.of<ReportIssueProvider>(context);

    return AlertDialog(
      title: const Text('Report an Issue'),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Describe the Issue:',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'Enter the issue description',
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 16),
            const Text(
              'Location:',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Center(
              child: ElevatedButton(
                onPressed: () async {
                  try {
                    await reportProvider.fetchCurrentLocation(context);
                    _locationController.text = reportProvider.location ?? '';
                  } catch (e) {
                    Fluttertoast.showToast(
                      msg: e.toString(),
                      toastLength: Toast.LENGTH_LONG,
                      gravity: ToastGravity.BOTTOM,
                    );
                  }
                },
                child: const Text('Fetch Current Location'),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _locationController,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'Enter the location',
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(context).pop(); // Close the dialog without doing anything
          },
          child: const Text(
            'Cancel',
            style: TextStyle(color: Colors.red),
          ),
        ),
        TextButton(
          onPressed: () async {
            String description = _descriptionController.text;
            String location = _locationController.text;

            if (description.isNotEmpty && location.isNotEmpty) {
              try {
                // Save the issue to Firebase
                await FirebaseFirestore.instance.collection('issues').add({
                  'description': description,
                  'location': location,
                  'timestamp': FieldValue.serverTimestamp(),
                });

                Fluttertoast.showToast(
                  msg: "Thank you for reporting the issue.",
                  toastLength: Toast.LENGTH_LONG,
                  gravity: ToastGravity.BOTTOM,
                  backgroundColor: Colors.green,
                  textColor: Colors.white,
                );

                // Clear the fields
                _descriptionController.clear();
                _locationController.clear();

                Navigator.of(context).pop(); // Close the dialog after submitting
              } catch (e) {
                Fluttertoast.showToast(
                  msg: 'Error reporting issue: $e',
                  toastLength: Toast.LENGTH_LONG,
                  gravity: ToastGravity.BOTTOM,
                );
              }
            } else {
              Fluttertoast.showToast(
                msg: 'Please fill in all fields',
                toastLength: Toast.LENGTH_LONG,
                gravity: ToastGravity.BOTTOM,
              );
            }
          },
          child: const Text('Submit'),
        ),
      ],
    );
  }
}