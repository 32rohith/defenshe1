import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'dart:math' as math;
import 'package:flutter/services.dart';
import 'places_service.dart'; // Import our new Flutter-based Places service

class LocationService {
  static const String _apiKey = 'AIzaSyCGdUinxQQY5QviSTmZwOGXh2-uomrLTwk';
  
  // Flutter Places SDK availability methods (replacements for native ones)
  static Future<bool> isPlacesSDKAvailable() async {
    // We're using Flutter implementation which is always available
    return true;
  }
  
  static Future<String> getPlacesSDKInitializationError() async {
    // No initialization errors with Flutter implementation
    return '';
  }
  
  static Future<bool> forceReInitializePlacesSDK() async {
    // Nothing to reinitialize in Flutter implementation
    return true;
  }
  // Remove native Places SDK channel since we're using Flutter-only implementation
  
  static Future<Position> getCurrentLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    try {
      // Test if location services are enabled.
      serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        // Location services are not enabled, request user to enable them
        serviceEnabled = await Geolocator.openLocationSettings();
        if (!serviceEnabled) {
          throw Exception('Location services are disabled. Please enable location services in your device settings.');
        }
      }

      permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw Exception('Location permission denied. Please allow the app to access your location.');
        }
      }
      
      if (permission == LocationPermission.deniedForever) {
        throw Exception(
          'Location permission permanently denied. Please enable location access in app settings.');
      } 

      // When we reach here, permissions are granted and we can get the position
      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 15) // Add timeout to prevent hanging
      );
    } catch (e) {
      if (e is Exception) {
        rethrow; // Rethrow known exceptions with our custom messages
      }
      // Handle any other exceptions
      throw Exception('Error accessing location: ${e.toString()}. Please check your device settings and permissions.');
    }
  }

  // Calculate distance between two coordinates in kilometers
  static double calculateDistance(LatLng point1, LatLng point2) {
    const int earthRadius = 6371; // Earth's radius in kilometers
    
    // Convert latitude and longitude from degrees to radians
    final double lat1 = point1.latitude * math.pi / 180;
    final double lon1 = point1.longitude * math.pi / 180;
    final double lat2 = point2.latitude * math.pi / 180;
    final double lon2 = point2.longitude * math.pi / 180;
    
    // Haversine formula
    final double dlon = lon2 - lon1;
    final double dlat = lat2 - lat1;
    final double a = math.pow(math.sin(dlat / 2), 2) + 
                     math.cos(lat1) * math.cos(lat2) * 
                     math.pow(math.sin(dlon / 2), 2);
    final double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadius * c;
  }

  static Future<Set<Marker>> getNearbyPlaces(double latitude, double longitude, int radius) async {
    Set<Marker> markers = {};
    
    try {
      // First try to get data from Firestore
      final safeLocationsSnapshot = await FirebaseFirestore.instance.collection('safetyLocations').get();
      
      if (safeLocationsSnapshot.docs.isNotEmpty) {
        // Use data from Firestore
        for (var doc in safeLocationsSnapshot.docs) {
          final data = doc.data();
          markers.add(
            Marker(
              markerId: MarkerId(doc.id),
              position: LatLng(data['latitude'], data['longitude']),
              infoWindow: InfoWindow(
                title: data['name'],
                snippet: data['type'],
              ),
              icon: BitmapDescriptor.defaultMarkerWithHue(
                _getMarkerHue(data['type']),
              ),
            ),
          );
        }
      } else {
        // If Firestore is empty, use Google Places API
        await _fetchNearbyPlacesFromAPI(markers, latitude, longitude, radius);
      }
    } catch (e) {
      print('Error fetching safety locations from Firestore: $e');
      // Fallback to Google Places API
      await _fetchNearbyPlacesFromAPI(markers, latitude, longitude, radius);
    }
    
    // If we still don't have any markers, use hardcoded data as last resort
    if (markers.isEmpty) {
      _addHardcodedSafetyLocations(markers, latitude, longitude);
    }
    
    return markers;
  }
  
  static Future<void> _fetchNearbyPlacesFromAPI(
    Set<Marker> markers, 
    double latitude, 
    double longitude, 
    int radius
  ) async {
    try {
      // Use our new Flutter-based PlacesService instead of direct HTTP calls
      final placesService = PlacesService();
      
      // Fetch places for safety categories - removed crowded places, focus on emergency services only
      final List<String> safetyTypes = ['police', 'hospital', 'fire_station', 'pharmacy'];
      
      for (String type in safetyTypes) {
        final places = await placesService.getNearbyPlacesByType(
          location: LatLng(latitude, longitude),
          radius: radius,
          type: type,
        );
        
        // Add places to markers
        for (var place in places) {
          markers.add(
            Marker(
              markerId: MarkerId(place['id']),
              position: LatLng(place['latitude'], place['longitude']),
              infoWindow: InfoWindow(
                title: place['name'],
                snippet: place['vicinity'],
              ),
              icon: BitmapDescriptor.defaultMarkerWithHue(
                _getMarkerHue(type),
              ),
            ),
          );
        }
      }
    } catch (e) {
      print('Error fetching places from API: $e');
    }
  }
  
  static Future<Set<Marker>> getSafetyLocations() async {
    Set<Marker> markers = {};
    
    try {
      // Get data from Firestore if available
      final safeLocationsSnapshot = await FirebaseFirestore.instance.collection('safetyLocations').get();
      
      if (safeLocationsSnapshot.docs.isNotEmpty) {
        // Use data from Firestore
        for (var doc in safeLocationsSnapshot.docs) {
          final data = doc.data();
          markers.add(
            Marker(
              markerId: MarkerId(doc.id),
              position: LatLng(data['latitude'], data['longitude']),
              infoWindow: InfoWindow(
                title: data['name'],
                snippet: data['type'],
              ),
              icon: BitmapDescriptor.defaultMarkerWithHue(
                _getMarkerHue(data['type']),
              ),
            ),
          );
        }
      } else {
        // Use hardcoded data if Firestore collection is empty
        _addHardcodedSafetyLocations(markers, 13.067439, 80.237617);
      }
    } catch (e) {
      print('Error fetching safety locations: $e');
      // Fallback to hardcoded data
      _addHardcodedSafetyLocations(markers, 13.067439, 80.237617);
    }
    
    return markers;
  }
  
  static void _addHardcodedSafetyLocations(Set<Marker> markers, double centerLat, double centerLng) {
    final List<Map<String, dynamic>> safetyLocations = [
      {
        'id': 'policeStation1',
        'name': 'Central Police Station',
        'lat': centerLat + 0.002, 
        'lng': centerLng + 0.002,
        'type': 'police'
      },
      {
        'id': 'hospital1',
        'name': 'General Hospital',
        'lat': centerLat - 0.002, 
        'lng': centerLng - 0.002,
        'type': 'hospital'
      },
      {
        'id': 'safeHouse1',
        'name': 'Women Safety Center',
        'lat': centerLat - 0.005, 
        'lng': centerLng - 0.005,
        'type': 'safeHouse'
      },
      {
        'id': 'policeStation2',
        'name': 'Women Police Station',
        'lat': centerLat + 0.004, 
        'lng': centerLng + 0.005,
        'type': 'police'
      },
      {
        'id': 'hospital2',
        'name': 'Women & Children Hospital',
        'lat': centerLat - 0.008, 
        'lng': centerLng - 0.008,
        'type': 'hospital'
      },
    ];

    for (var location in safetyLocations) {
      markers.add(
        Marker(
          markerId: MarkerId(location['id']),
          position: LatLng(location['lat'], location['lng']),
          infoWindow: InfoWindow(
            title: location['name'],
            snippet: 'Safety Location',
          ),
          icon: BitmapDescriptor.defaultMarkerWithHue(
            _getMarkerHue(location['type']),
          ),
        ),
      );
    }
  }
  
  static double _getMarkerHue(String type) {
    switch (type) {
      case 'police':
        return BitmapDescriptor.hueRed;
      case 'hospital':
        return BitmapDescriptor.hueGreen;
      case 'safeHouse':
        return BitmapDescriptor.hueYellow;
      case 'fire_station':
        return BitmapDescriptor.hueOrange;
      case 'pharmacy':
        return BitmapDescriptor.hueBlue;
      default:
        return BitmapDescriptor.hueViolet;
    }
  }

  static Future<List<Place>> getNearbyPlacesByType(
    double latitude, 
    double longitude, 
    int radius,
    String type
  ) async {
    try {
      // Use our new Flutter-based Places service
      final placesService = PlacesService();
      final places = await placesService.getNearbyPlacesByType(
        location: LatLng(latitude, longitude),
        radius: radius,
        type: type,
      );
      
      // Convert from Map to Place objects
      return places.map((place) => Place(
        id: place['id'],
        name: place['name'],
        vicinity: place['vicinity'],
        position: LatLng(place['latitude'], place['longitude']),
        types: List<String>.from(place['types']),
      )).toList();
    } catch (e) {
      print('Error fetching places by type $type: $e');
      return _getMockSafetyPlaces(latitude, longitude, type);
    }
  }
  
  static Future<List<Place>> getNearbyPlacesByKeyword(
    double latitude, 
    double longitude, 
    int radius,
    String keyword
  ) async {
    try {
      // Use our new Flutter-based Places service
      final placesService = PlacesService();
      final places = await placesService.getNearbyPlaces(
        location: LatLng(latitude, longitude),
        radius: radius,
        keyword: keyword,
      );
      
      // Convert from Map to Place objects
      return places.map((place) => Place(
        id: place['id'],
        name: place['name'],
        vicinity: place['vicinity'],
        position: LatLng(place['latitude'], place['longitude']),
        types: List<String>.from(place['types']),
      )).toList();
    } catch (e) {
      print('Error fetching places by keyword $keyword: $e');
      return _getMockShelters(latitude, longitude);
    }
  }
  
  // For testing, generate mock safety places of a specific type around the specified location
  static List<Place> _getMockSafetyPlaces(double lat, double lng, String type) {
    // Use a fixed seed for consistent results
    final random = math.Random(42);
    
    // Generate names based on the type
    List<String> names = [];
    List<String> typesList = [];
    
    switch(type) {
      case 'police':
        names = ['Central Police Station', 'North District Police', 'South Police Station', 'Police Outpost', 'Community Police'];
        typesList = ['police'];
        break;
      case 'hospital':
        names = ['General Hospital', 'Community Medical Center', 'Emergency Care', 'City Hospital', 'Medical Center'];
        typesList = ['hospital', 'health'];
        break;
      case 'fire_station':
        names = ['City Fire Department', 'Fire Station 12', 'Emergency Fire Service', 'North Fire Brigade', 'Community Fire Station'];
        typesList = ['fire_station'];
        break;
      case 'pharmacy':
        names = ['City Pharmacy', 'MediQuick', '24/7 Pharmacy', 'Care Pharmacy', 'Health Drugstore'];
        typesList = ['pharmacy', 'health'];
        break;
      default:
        names = ['Safety Location', 'Safe Zone', 'Community Center', 'Public Safety Office', 'Emergency Point'];
        typesList = ['point_of_interest'];
        break;
    }
    
    // Generate mock places in vicinity
    List<Place> places = [];
    final numPlaces = 3 + random.nextInt(3); // 3-5 places
    
    for (int i = 0; i < numPlaces; i++) {
      // Create a random offset within ~1-2km
      final latOffset = (i + 1) * 0.01 * (random.nextBool() ? 1 : -1);
      final lngOffset = (i + 1) * 0.01 * (random.nextBool() ? 1 : -1);
      
      final name = i < names.length ? names[i] : '${names[0]} ${i+1}';
      
      places.add(Place(
        id: 'mock-$type-$i',
        name: name,
        vicinity: '${100 + i} Safety Street',
        position: LatLng(lat + latOffset, lng + lngOffset),
        types: typesList,
      ));
    }
    
    return places;
  }
  
  // For testing, generate mock shelters around the specified location
  static List<Place> _getMockShelters(double lat, double lng) {
    // Use a fixed seed for consistent results
    final random = math.Random(42);
    
    // Generate shelter names
    final List<String> names = [
      'Women\'s Shelter',
      'Crisis Center',
      'Safe House',
      'Community Shelter',
      'Emergency Housing'
    ];
    
    // Generate mock shelters in vicinity
    List<Place> places = [];
    final numPlaces = 3 + random.nextInt(3); // 3-5 places
    
    for (int i = 0; i < numPlaces; i++) {
      // Create a random offset within ~1-2km
      final latOffset = (i + 1) * 0.01 * (random.nextBool() ? 1 : -1);
      final lngOffset = (i + 1) * 0.01 * (random.nextBool() ? 1 : -1);
      
      final name = i < names.length ? names[i] : 'Community Shelter ${i+1}';
      
      places.add(Place(
        id: 'mock-shelter-$i',
        name: name,
        vicinity: '${200 + i} Support Street',
        position: LatLng(lat + latOffset, lng + lngOffset),
        types: ['point_of_interest', 'establishment'],
      ));
    }
    
    return places;
  }
}

class Place {
  final String id;
  final String name;
  final String vicinity;
  final LatLng position;
  final List<String> types;
  
  Place({
    required this.id,
    required this.name,
    required this.vicinity,
    required this.position,
    required this.types,
  });
} 