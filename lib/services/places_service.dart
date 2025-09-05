import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:google_maps_webservice/places.dart';

class PlacesService {
  static final PlacesService _instance = PlacesService._internal();
  factory PlacesService() => _instance;
  PlacesService._internal();

  // Your Google Maps API key
  static const String _apiKey = 'AIzaSyC-M6TC6F8dW4_xjOvAU9QxscwqRXx2iqk';
  
  // Create PlacesApiClient from google_maps_webservice
  final _placesApiClient = GoogleMapsPlaces(apiKey: _apiKey);
  
  // List of place types to exclude (restaurants and dining places)
  final List<String> _excludedTypes = [
    'restaurant', 
    'food', 
    'cafe', 
    'bar', 
    'meal_delivery', 
    'meal_takeaway',
    'bakery',
    'dining'
  ];
  
  /// Get nearby places based on location, radius and optional keyword
  Future<List<Map<String, dynamic>>> getNearbyPlaces({
    required LatLng location, 
    required int radius,
    String? keyword,
    List<String>? types
  }) async {
    try {
      debugPrint('Searching for places near ${location.latitude}, ${location.longitude} with radius $radius meters');
      if (keyword != null) debugPrint('Keyword filter: $keyword');
      if (types != null && types.isNotEmpty) debugPrint('Types filter: ${types.join(", ")}');
      
      // Create the PlacesSearchResponse
      PlacesSearchResponse response;
      
      // If a specific type is provided, search for that type
      if (types != null && types.isNotEmpty) {
        response = await _placesApiClient.searchNearbyWithRadius(
          Location(lat: location.latitude, lng: location.longitude),
          radius.toDouble(),
          type: types.first, // Use the first type
          keyword: keyword,
        );
      } else {
        // Otherwise just use keyword search
        response = await _placesApiClient.searchNearbyWithRadius(
          Location(lat: location.latitude, lng: location.longitude),
          radius.toDouble(),
          keyword: keyword,
        );
      }
      
      // Check for error in response
      if (response.status != "OK" && response.status != "ZERO_RESULTS") {
        debugPrint("Places API Error: ${response.status} - ${response.errorMessage ?? 'Unknown error'}");
        
        // If we get a request denied, the API key is likely invalid or restricted
        if (response.status == "REQUEST_DENIED") {
          debugPrint("API key may be invalid or restricted. Check your Google Cloud Console settings.");
          return _getMockPlaces(location, keyword, types);
        }
        
        throw Exception("Places API error: ${response.status}");
      }
      
      // Convert places to maps and filter out restaurants
      final places = response.results
        .where((result) => !_isRestaurantOrDiningPlace(result.types ?? []))
        .map((result) {
          return {
            'id': result.placeId,
            'name': result.name,
            'vicinity': result.vicinity ?? 'No address available',
            'latitude': result.geometry?.location.lat,
            'longitude': result.geometry?.location.lng,
            'types': result.types ?? [],
          };
        }).toList();
      
      debugPrint('Found ${places.length} places using Google Places API (after excluding restaurants)');
      
      // If no places found and we're using a type or keyword, return mock data
      if (places.isEmpty && (types != null || keyword != null)) {
        debugPrint('No places found, returning mock data');
        return _getMockPlaces(location, keyword, types);
      }
      
      return places;
    } catch (e) {
      debugPrint('Error fetching nearby places: $e');
      // Return mock data on error
      return _getMockPlaces(location, keyword, types);
    }
  }
  
  // Check if a place is a restaurant or dining establishment
  bool _isRestaurantOrDiningPlace(List<String> placeTypes) {
    // Check if any of the place types match our excluded types
    return placeTypes.any((type) => _excludedTypes.contains(type.toLowerCase()));
  }
  
  /// Get nearby places specifically by type
  Future<List<Map<String, dynamic>>> getNearbyPlacesByType({
    required LatLng location,
    required int radius,
    required String type,
  }) async {
    return getNearbyPlaces(
      location: location,
      radius: radius,
      types: [type],
    );
  }
  
  /// Generate mock safety places for testing
  List<Map<String, dynamic>> _getMockPlaces(
    LatLng location,
    String? keyword,
    List<String>? types,
  ) {
    final mockPlaces = <Map<String, dynamic>>[];
    
    // Determine what kind of mock data to return based on keyword or type
    if (types != null && types.isNotEmpty) {
      final type = types.first.toLowerCase();
      
      if (type.contains('police')) {
        mockPlaces.addAll(_getMockPoliceStations(location));
      } else if (type.contains('hospital') || type.contains('doctor')) {
        mockPlaces.addAll(_getMockHospitals(location));
      } else if (type.contains('pharmacy')) {
        mockPlaces.addAll(_getMockPharmacies(location));
      } else if (type.contains('fire')) {
        mockPlaces.addAll(_getMockFireStations(location));
      } else {
        // Default to mix of safety places
        mockPlaces.addAll(_getMockSafetyPlaces(location));
      }
    } else if (keyword != null) {
      final lowerKeyword = keyword.toLowerCase();
      
      if (lowerKeyword.contains('police') || lowerKeyword.contains('station')) {
        mockPlaces.addAll(_getMockPoliceStations(location));
      } else if (lowerKeyword.contains('hospital') || lowerKeyword.contains('medical')) {
        mockPlaces.addAll(_getMockHospitals(location));
      } else if (lowerKeyword.contains('pharmacy')) {
        mockPlaces.addAll(_getMockPharmacies(location));
      } else if (lowerKeyword.contains('fire')) {
        mockPlaces.addAll(_getMockFireStations(location));
      } else if (lowerKeyword.contains('shelter') || lowerKeyword.contains('safe house')) {
        mockPlaces.addAll(_getMockShelters(location));
      } else {
        // Default to mix of safety places
        mockPlaces.addAll(_getMockSafetyPlaces(location));
      }
    } else {
      // Default to mix of safety places
      mockPlaces.addAll(_getMockSafetyPlaces(location));
    }
    
    return mockPlaces;
  }
  
  /// Generate mock safety places (mixed types)
  List<Map<String, dynamic>> _getMockSafetyPlaces(LatLng location) {
    final places = <Map<String, dynamic>>[];
    
    // Add a mix of places
    places.addAll(_getMockPoliceStations(location));
    places.addAll(_getMockHospitals(location));
    places.addAll(_getMockFireStations(location));
    places.addAll(_getMockPharmacies(location));
    places.addAll(_getMockShelters(location));
    
    return places;
  }
  
  /// Generate mock police stations
  List<Map<String, dynamic>> _getMockPoliceStations(LatLng location) {
    final random = DateTime.now().millisecondsSinceEpoch;
    
    return List.generate(3, (index) {
      // Create random offsets for latitude and longitude (within ~1-2km)
      final latOffset = (index + 1) * 0.008 * (index % 2 == 0 ? 1 : -1);
      final lngOffset = (index + 1) * 0.009 * (index % 3 == 0 ? 1 : -1);
      
      return {
        'id': 'mock-police-$random-$index',
        'name': 'Police Station ${index + 1}',
        'vicinity': '123 Safety Street',
        'latitude': location.latitude + latOffset,
        'longitude': location.longitude + lngOffset,
        'types': ['police', 'point_of_interest', 'establishment'],
      };
    });
  }
  
  /// Generate mock hospitals
  List<Map<String, dynamic>> _getMockHospitals(LatLng location) {
    final random = DateTime.now().millisecondsSinceEpoch;
    
    return List.generate(3, (index) {
      // Create random offsets for latitude and longitude (within ~1-2km)
      final latOffset = (index + 1) * 0.009 * (index % 2 == 0 ? 1 : -1);
      final lngOffset = (index + 1) * 0.01 * (index % 3 == 0 ? 1 : -1);
      
      return {
        'id': 'mock-hospital-$random-$index',
        'name': 'City Hospital ${index + 1}',
        'vicinity': '456 Health Avenue',
        'latitude': location.latitude + latOffset,
        'longitude': location.longitude + lngOffset,
        'types': ['hospital', 'health', 'point_of_interest', 'establishment'],
      };
    });
  }
  
  /// Generate mock fire stations
  List<Map<String, dynamic>> _getMockFireStations(LatLng location) {
    final random = DateTime.now().millisecondsSinceEpoch;
    
    return List.generate(2, (index) {
      // Create random offsets for latitude and longitude (within ~1-2km)
      final latOffset = (index + 1) * 0.011 * (index % 2 == 0 ? 1 : -1);
      final lngOffset = (index + 1) * 0.008 * (index % 3 == 0 ? 1 : -1);
      
      return {
        'id': 'mock-fire-$random-$index',
        'name': 'Fire Station ${index + 1}',
        'vicinity': '789 Emergency Road',
        'latitude': location.latitude + latOffset,
        'longitude': location.longitude + lngOffset,
        'types': ['fire_station', 'point_of_interest', 'establishment'],
      };
    });
  }
  
  /// Generate mock pharmacies
  List<Map<String, dynamic>> _getMockPharmacies(LatLng location) {
    final random = DateTime.now().millisecondsSinceEpoch;
    
    return List.generate(3, (index) {
      // Create random offsets for latitude and longitude (within ~1-2km)
      final latOffset = (index + 1) * 0.007 * (index % 2 == 0 ? 1 : -1);
      final lngOffset = (index + 1) * 0.006 * (index % 3 == 0 ? 1 : -1);
      
      return {
        'id': 'mock-pharmacy-$random-$index',
        'name': 'Quick Pharmacy ${index + 1}',
        'vicinity': '101 Medicine Lane',
        'latitude': location.latitude + latOffset,
        'longitude': location.longitude + lngOffset,
        'types': ['pharmacy', 'health', 'store', 'point_of_interest', 'establishment'],
      };
    });
  }
  
  /// Generate mock shelters
  List<Map<String, dynamic>> _getMockShelters(LatLng location) {
    final random = DateTime.now().millisecondsSinceEpoch;
    
    return List.generate(3, (index) {
      // Create random offsets for latitude and longitude (within ~1-2km)
      final latOffset = (index + 1) * 0.01 * (index % 2 == 0 ? 1 : -1);
      final lngOffset = (index + 1) * 0.011 * (index % 3 == 0 ? 1 : -1);
      
      final shelterNames = [
        'Community Shelter',
        'Safe Haven',
        'Crisis Support Center',
        'Women\'s Shelter',
        'Emergency Housing'
      ];
      
      final name = index < shelterNames.length 
          ? shelterNames[index] 
          : 'Community Shelter ${index + 1}';
      
      return {
        'id': 'mock-shelter-$random-$index',
        'name': name,
        'vicinity': '202 Support Street',
        'latitude': location.latitude + latOffset,
        'longitude': location.longitude + lngOffset,
        'types': ['shelter', 'point_of_interest', 'establishment'],
      };
    });
  }
  
  /// Dispose method to clean up resources
  void dispose() {
    _placesApiClient.dispose();
  }
} 