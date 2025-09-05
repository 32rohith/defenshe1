import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

/*
 * This is a utility script to populate the safetyLocations collection in Firestore.
 * To run this script, uncomment the code in main.dart and run the app once.
 * Then comment it back to prevent duplicate entries.
 * 
 * Example usage in main.dart:
 * 
 * void main() async {
 *   WidgetsFlutterBinding.ensureInitialized();
 *   await Firebase.initializeApp(
 *     options: DefaultFirebaseOptions.currentPlatform,
 *   );
 *   
 *   // Uncomment to populate safety locations (run once, then comment back)
 *   // await PopulateSafetyLocations.run();
 *   
 *   runApp(const MyApp());
 * }
 */

class PopulateSafetyLocations {
  static Future<void> run() async {
    final FirebaseFirestore firestore = FirebaseFirestore.instance;
    final CollectionReference safetyLocations = firestore.collection('safetyLocations');
    
    // Check if collection already has data
    final snapshot = await safetyLocations.limit(1).get();
    if (snapshot.docs.isNotEmpty) {
      print('Safety locations already populated. Skipping...');
      return;
    }
    
    // Chennai safety locations
    final List<Map<String, dynamic>> chennaiLocations = [
      {
        'name': 'Chennai City Police Headquarters',
        'latitude': 13.0827,
        'longitude': 80.2707,
        'type': 'police',
        'address': 'Commissioner Office, Vepery, Chennai',
        'phone': '044-2345 2345'
      },
      {
        'name': 'All Women Police Station',
        'latitude': 13.0569,
        'longitude': 80.2425,
        'type': 'police',
        'address': 'Thousand Lights, Chennai',
        'phone': '044-2345 2365'
      },
      {
        'name': 'Government General Hospital',
        'latitude': 13.0796,
        'longitude': 80.2730,
        'type': 'hospital',
        'address': 'Park Town, Chennai',
        'phone': '044-2530 5000'
      },
      {
        'name': 'Apollo Hospital',
        'latitude': 13.0279,
        'longitude': 80.2508,
        'type': 'hospital',
        'address': 'Greams Road, Chennai',
        'phone': '044-2829 3333'
      },
      {
        'name': 'International Foundation for Crime Prevention and Victim Care',
        'latitude': 13.0418,
        'longitude': 80.2341,
        'type': 'safeHouse',
        'address': 'Nungambakkam, Chennai',
        'phone': '044-4309 9999'
      },
      {
        'name': 'Tamil Nadu Women\'s Commission',
        'latitude': 13.0569,
        'longitude': 80.2500,
        'type': 'safeHouse',
        'address': 'Kamarajar Salai, Chennai',
        'phone': '044-2859 1992'
      },
      {
        'name': 'Chennai Central Fire Station',
        'latitude': 13.0798,
        'longitude': 80.2785,
        'type': 'fire_station',
        'address': 'Anna Salai, Chennai',
        'phone': '044-101'
      }
    ];
    
    // Batch write to Firestore
    final WriteBatch batch = firestore.batch();
    
    for (final location in chennaiLocations) {
      final docRef = safetyLocations.doc();
      batch.set(docRef, {
        ...location,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
    
    await batch.commit();
    print('Successfully populated ${chennaiLocations.length} safety locations!');
  }
} 