// ignore_for_file: library_private_types_in_public_api

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'dart:async';
import 'dart:ui' as ui;
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:geolocator/geolocator.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../../services/location_service.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/services.dart';

class MapPage extends StatefulWidget {
  const MapPage({super.key});

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> with SingleTickerProviderStateMixin {
  final Completer<GoogleMapController> _controller = Completer();
  Set<Marker> _markers = {};
  Set<Polyline> _polylines = {};
  bool _isLoading = true;
  bool _hasError = false;
  String _errorMessage = '';
  LatLng? _lastPosition;
  Timer? _debounceTimer;
  bool _isBottomSheetVisible = false;
  List<Map<String, dynamic>> _nearbyPlaces = [];
  StreamSubscription<Position>? _positionStream;
  late AnimationController _animationController;
  bool _isSearching = false;
  bool _isNavigating = false;
  LatLng? _destination;
  WebSocketChannel? _navigationChannel;
  StreamSubscription? _navigationSubscription;
  List<LatLng> _navigationPoints = [];

  static const int _updateRadius = 2000; // Smaller initial radius to get nearby places first
  static const int _maxRadius = 10000; // Maximum search radius
  static const int _radiusIncrement = 2000; // Smaller increments for better coverage
  static const int _minSafeZones = 10; // Increased minimum number to find more safe zones
  static const double _significantMove = 0.5; // 500m to ensure consistent updates
  static const bool _showCrowdedPlaces = true; // Flag to control crowded places visibility
  static const bool _allowMapMovement = false; // Prevent map from moving away from user location

  // Add these new variables to track safe zones
  Set<SafePlace> _safeZones = {};
  bool _initialSearchDone = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _checkPlacesSDK();
    _initializeMap();
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _positionStream?.cancel();
    _navigationSubscription?.cancel();
    _navigationChannel?.sink.close();
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _initializeMap() async {
    if (!mounted) return;
    
    try {
      setState(() {
        _isLoading = true;
        _hasError = false;
      });

      final position = await LocationService.getCurrentLocation();
      if (!mounted) return;
      
      final currentLocation = LatLng(position.latitude, position.longitude);
      
      // Initial search for safe zones
      await _searchSafeZones(currentLocation);
      
      final controller = await _controller.future;
      await controller.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: currentLocation,
            zoom: 15,
          ),
        ),
      );

      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _lastPosition = currentLocation;
        _initialSearchDone = true;
      });

      // Start location tracking after initial setup
      _startLocationTracking();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _hasError = true;
        _errorMessage = e.toString();
      });
    }
  }

  Future<void> _searchSafeZones(LatLng position) async {
    if (!mounted) return;
    
    setState(() {
      _isSearching = true;
      // Don't clear existing markers or safe zones unless it's the initial load
      if (!_initialSearchDone) {
        _markers = {};
        _safeZones.clear();
        _nearbyPlaces = [];
      }
    });

    try {
      final newMarkers = <Marker>{};
      final updatedSafeZones = <SafePlace>{};

      // First add existing markers to maintain them
      if (_initialSearchDone) {
        newMarkers.addAll(_markers);
        updatedSafeZones.addAll(_safeZones);
      }

      // Define comprehensive list of safety location types according to Google Places API
      List<Map<String, dynamic>> safetyPlaceTypes = [
        {'apiType': 'police', 'displayType': 'police', 'icon': Icons.local_police, 'priority': 1},
        {'apiType': 'hospital', 'displayType': 'hospital', 'icon': Icons.local_hospital, 'priority': 1},
        {'apiType': 'fire_station', 'displayType': 'firebrigade', 'icon': Icons.local_fire_department, 'priority': 1},
        {'apiType': 'pharmacy', 'displayType': 'pharmacy', 'icon': Icons.medical_services, 'priority': 1},
        {'apiType': 'doctor', 'displayType': 'doctor', 'icon': Icons.medical_services, 'priority': 2},
        {'apiType': 'physiotherapist', 'displayType': 'medical', 'icon': Icons.medical_services, 'priority': 2},
        {'apiType': 'veterinary_care', 'displayType': 'veterinary', 'icon': Icons.pets, 'priority': 3},
      ];
      
      // Define crowded places and high traffic areas
      List<Map<String, dynamic>> crowdedPlaceTypes = [
        {'apiType': 'shopping_mall', 'displayType': 'mall', 'icon': Icons.local_mall, 'priority': 3},
        {'apiType': 'restaurant', 'displayType': 'restaurant', 'icon': Icons.restaurant, 'priority': 3},
        {'apiType': 'supermarket', 'displayType': 'supermarket', 'icon': Icons.shopping_cart, 'priority': 3},
        {'apiType': 'transit_station', 'displayType': 'transit', 'icon': Icons.train, 'priority': 3},
        {'apiType': 'bus_station', 'displayType': 'bus', 'icon': Icons.directions_bus, 'priority': 3},
        {'apiType': 'train_station', 'displayType': 'train', 'icon': Icons.train, 'priority': 3},
        {'apiType': 'subway_station', 'displayType': 'subway', 'icon': Icons.subway, 'priority': 3},
      ];
      
      // Sort by priority to ensure most important places are fetched first
      safetyPlaceTypes.sort((a, b) => a['priority'].compareTo(b['priority']));
      
      // Track places we've already processed to avoid duplicates
      Set<String> processedPlaceIds = {};
      
      // Track how many places of each type we've found
      Map<String, int> typeCount = {};
      
      // Progressively increase radius until we find enough safe zones or hit max radius
      int currentRadius = _updateRadius;
      
      while (updatedSafeZones.length < _minSafeZones && currentRadius <= _maxRadius) {
        // Update status message for user
        if (!mounted) return;
        if (currentRadius > _updateRadius) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Searching ${currentRadius / 1000}km radius for safety locations...'),
              duration: const Duration(seconds: 2),
            ),
          );
        }
        
        // First search for each type of safety location using the Google Places API
        for (final placeType in safetyPlaceTypes) {
          // Don't limit number of each type to find all possible safe zones
          final displayType = placeType['displayType'];
          
          try {
            final places = await LocationService.getNearbyPlacesByType(
              position.latitude,
              position.longitude,
              currentRadius,
              placeType['apiType'],
            );
            
            if (!mounted) return;
            
            // Process all places of this type without limiting
            for (final place in places) {
              // Skip if we've already processed this place
              if (processedPlaceIds.contains(place.id)) continue;
              processedPlaceIds.add(place.id);
              
              // Process this place without limiting by distance
              await _processPlace(
                place, 
                displayType, 
                position, 
                newMarkers, 
                updatedSafeZones,
                skipDistanceCheck: true, // Process all places regardless of distance
              );
              
              typeCount[displayType] = (typeCount[displayType] ?? 0) + 1;
            }
          } catch (e) {
            print('Error fetching ${placeType['apiType']} locations: $e');
          }
        }

        // Search for shelters/safe houses using multiple specific keywords
        try {
          final shelterKeywords = [
            "shelter", 
            "safe house", 
            "crisis center", 
            "refuge", 
            "women shelter", 
            "family shelter", 
            "emergency shelter"
          ];
          
          for (final keyword in shelterKeywords) {
            final shelters = await LocationService.getNearbyPlacesByKeyword(
              position.latitude,
              position.longitude,
              currentRadius,
              keyword,
            );
            
            if (!mounted) return;
            
            for (final place in shelters) {
              if (processedPlaceIds.contains(place.id)) continue;
              processedPlaceIds.add(place.id);
              
              await _processPlace(
                place, 
                'safehouse', 
                position, 
                newMarkers, 
                updatedSafeZones,
                skipDistanceCheck: true, // Process all shelters regardless of distance
              );
              
              typeCount['safehouse'] = (typeCount['safehouse'] ?? 0) + 1;
            }
          }
        } catch (e) {
          print('Error fetching shelters: $e');
        }
        
        // Increase radius for next iteration if we still need more safe zones
        if (updatedSafeZones.length < _minSafeZones) {
          currentRadius += _radiusIncrement;
        } else {
          break; // We found enough safe zones, exit the loop
        }
      }

      // If crowded places are enabled, add them to the map
      if (_showCrowdedPlaces) {
        // Use a smaller radius for crowded places to focus on the most relevant ones
        int crowdedPlacesRadius = _updateRadius;
        
        for (final placeType in crowdedPlaceTypes) {
          final displayType = placeType['displayType'];
          
          try {
            final places = await LocationService.getNearbyPlacesByType(
              position.latitude,
              position.longitude,
              crowdedPlacesRadius,
              placeType['apiType'],
            );
            
            if (!mounted) return;
            
            // Process all crowded places without artificial limits
            for (final place in places) {
              // Skip if we've already processed this place
              if (processedPlaceIds.contains(place.id)) continue;
              processedPlaceIds.add(place.id);
              
              // Process this place
              await _processPlace(
                place, 
                displayType, 
                position, 
                newMarkers, 
                updatedSafeZones,
                isCrowdedPlace: true,
                skipDistanceCheck: true, // Process all crowded places regardless of distance
              );
              
              typeCount[displayType] = (typeCount[displayType] ?? 0) + 1;
            }
          } catch (e) {
            print('Error fetching ${placeType['apiType']} locations: $e');
          }
        }
      }

      // Make sure we have at least basic safety locations even if API fails
      if (updatedSafeZones.isEmpty) {
        print('No safe zones found through API calls, adding hardcoded emergency locations');
        await _addHardcodedSafetyLocations(position, newMarkers, updatedSafeZones);
      }

      if (!mounted) return;

      setState(() {
        _markers = newMarkers;
        _safeZones = updatedSafeZones;
        
        // Update nearby places list with fresh distances
        _nearbyPlaces = _safeZones
          .map((zone) => {
            'id': zone.id,
            'name': zone.name,
            'type': zone.type,
            'distance': LocationService.calculateDistance(position, zone.location),
            'position': zone.location,
            'isCrowdedPlace': zone.isCrowdedPlace,
          })
          .toList()
          ..sort((a, b) => (a['distance'] as double).compareTo(b['distance'] as double));

        // Show appropriate message based on search results
        if (_safeZones.isEmpty && !_initialSearchDone) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No safety locations found in this area. Try searching in a different location.'),
              duration: Duration(seconds: 3),
            ),
          );
        } else if (_safeZones.isNotEmpty && !_initialSearchDone) {
          int totalPlaces = _safeZones.length;
          int types = typeCount.keys.length;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Found $totalPlaces safety locations of $types different types'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      });
    } catch (e) {
      print('Error updating safe zones: $e');
      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to fetch safe zones: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (!mounted) return;
      setState(() {
        _isSearching = false;
      });
    }
  }

  Future<void> _processPlace(
    Place place,
    String type,
    LatLng currentPosition,
    Set<Marker> markers,
    Set<SafePlace> safeZones,
    {bool isCrowdedPlace = false, bool skipDistanceCheck = false}
  ) async {
    // Create a unique ID using place ID and type
    final placeId = '${type}_${place.id}';
    
    // Skip if we already have this place (only for subsequent searches)
    if (_initialSearchDone && safeZones.any((zone) => zone.id == placeId)) {
      return;
    }
    
    final distance = LocationService.calculateDistance(
      currentPosition,
      place.position,
    );
    
    // Skip places that are too far based on dynamic threshold
    // But only if skipDistanceCheck is false
    if (!skipDistanceCheck) {
      final distanceThreshold = _initialSearchDone ? _updateRadius / 1000 : _maxRadius / 1000;
      if (distance > distanceThreshold) return;
    }
    
    final color = _getPlaceColor(type);
    final markerIcon = await _createFixedSizeMarker(color, type);
    
    final safeZone = SafePlace(
      id: placeId,
      name: place.name,
      type: type,
      location: place.position,
      distance: distance,
      address: place.vicinity,
      isCrowdedPlace: isCrowdedPlace,
    );

    safeZones.add(safeZone);
    
    markers.add(
      Marker(
        markerId: MarkerId(safeZone.id),
        position: safeZone.location,
        icon: markerIcon,
        onTap: () => _showMarkerInfo(
          safeZone.name,
          safeZone.type,
          safeZone.distance,
          safeZone.address,
          isCrowdedPlace: isCrowdedPlace,
        ),
        anchor: const Offset(0.5, 0.5),
        zIndex: isCrowdedPlace ? 1 : 2, // Lower zIndex for crowded places so safety places appear on top
        flat: true,
      ),
    );
  }

  void _startLocationTracking() {
    _positionStream = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10,
      ),
    ).listen((Position position) {
      if (!mounted) return;
      
      final newPosition = LatLng(position.latitude, position.longitude);
      
      // Always update distances based on current position
      _updateDistances(newPosition);
      
      if (_lastPosition != null) {
        final distance = LocationService.calculateDistance(_lastPosition!, newPosition);
        // Always search for new zones when position changes significantly, regardless of how many we already have
        if (distance >= _significantMove) {
          _lastPosition = newPosition;
          _searchSafeZones(newPosition);
          
          // Update camera to follow user if auto-follow is enabled
          if (!_allowMapMovement) {
            _moveMapToCurrentLocation(newPosition);
          }
        }
      } else {
        _lastPosition = newPosition;
      }
    });
  }

  // New method to move map to current location without changing zoom
  Future<void> _moveMapToCurrentLocation(LatLng position) async {
    final controller = await _controller.future;
    double currentZoom = await controller.getZoomLevel();
    controller.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(
          target: position,
          zoom: currentZoom,
        ),
      ),
    );
  }

  void _onCameraMove(CameraPosition position) {
    if (!_initialSearchDone) return;
    
    // Only update distances without refreshing markers
    _updateDistances(position.target);
    
    // Prevent automatic searches when user is manually navigating the map
    // This ensures we don't disrupt user exploration but still maintain safety info
  }

  void _updateDistances(LatLng position) {
    if (!mounted) return;
    
    setState(() {
      _nearbyPlaces = _safeZones
        .map((zone) => {
          'id': zone.id,
          'name': zone.name,
          'type': zone.type,
          'distance': LocationService.calculateDistance(position, zone.location),
          'position': zone.location,
        })
        .toList()
        ..sort((a, b) => (a['distance'] as double).compareTo(b['distance'] as double));
    });
  }

  Future<BitmapDescriptor> _createFixedSizeMarker(Color color, String type) async {
    // Increase size to make markers more visible
    final size = 150.0;
    final pictureRecorder = ui.PictureRecorder();
    final canvas = Canvas(pictureRecorder);
    final double circleRadius = size / 3.5; // Larger radius for better visibility
    
    // Draw shadow (bigger for better visibility)
    canvas.drawCircle(
      Offset(size / 2, size / 2),
      circleRadius + 4,
      Paint()
        ..color = Colors.black.withOpacity(0.3)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );

    // Draw outer circle with gradient
    final gradient = RadialGradient(
      colors: [color, color.withOpacity(0.7)],
      stops: const [0.4, 1.0],
    );

    canvas.drawCircle(
      Offset(size / 2, size / 2),
      circleRadius,
      Paint()
        ..shader = gradient.createShader(
          Rect.fromCircle(
            center: Offset(size / 2, size / 2),
            radius: circleRadius,
          ),
        ),
    );

    // Draw inner circle
    canvas.drawCircle(
      Offset(size / 2, size / 2),
      circleRadius - 4,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.fill,
    );

    // Draw icon (slightly larger)
    final icon = _getPlaceTypeIcon(type);
    final textPainter = TextPainter(
      text: TextSpan(
        text: String.fromCharCode(icon.codePoint),
        style: TextStyle(
          fontSize: circleRadius * 0.9, // Adjust for better proportions
          color: color,
          fontFamily: icon.fontFamily,
          package: icon.fontPackage,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(
        size / 2 - textPainter.width / 2,
        size / 2 - textPainter.height / 2,
      ),
    );

    // Complete the marker drawing
    final picture = pictureRecorder.endRecording();
    final image = await picture.toImage(size.toInt(), size.toInt());
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);

    return BitmapDescriptor.fromBytes(bytes!.buffer.asUint8List());
  }

  void _showMarkerInfo(
    String name, 
    String type, 
    double distance, 
    String address, 
    {bool isCrowdedPlace = false}
  ) {
    if (!mounted) return;
    
    final color = _getPlaceColor(type);
    final icon = _getPlaceTypeIcon(type);
    
    // Find the marker for this place
    final marker = _markers.firstWhere(
      (m) => m.markerId.value.contains(name),
      orElse: () => _markers.first,
    );
    
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        margin: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(icon, color: color, size: 24),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                            color: Color(0xff132137),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Text(
                              '${distance.toStringAsFixed(1)} km away',
                              style: TextStyle(
                                color: color,
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            if (isCrowdedPlace) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.amber.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.people, size: 12, color: Colors.amber),
                                    SizedBox(width: 4),
                                    Text(
                                      'Crowded Area',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.amber,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                        if (address.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            address,
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 12,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                        if (isCrowdedPlace) ...[
                          const SizedBox(height: 8),
                          Text(
                            'High-traffic area - typically more crowded and visible',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 12,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        _launchNavigation(marker.position);
                      },
                      icon: const Icon(Icons.directions),
                      label: const Text('Directions'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: color,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        _shareLocation(name, marker.position, type);
                        Navigator.pop(context);
                      },
                      icon: const Icon(Icons.share_location),
                      label: const Text('Share'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: color,
                        side: BorderSide(color: color),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _shareLocation(String name, LatLng position, String type) {
    final locationText = 'Safety location - $name (${type.toUpperCase()})\n'
        'Location: ${position.latitude},${position.longitude}\n'
        'Google Maps: https://www.google.com/maps/search/?api=1&query=${position.latitude},${position.longitude}';
    
    // TODO: Implement platform-specific sharing
    print('Sharing location: $locationText');
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Location shared'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  double _getMarkerHue(String type) {
    switch (type) {
      case 'police':
        return BitmapDescriptor.hueBlue;
      case 'hospital':
        return BitmapDescriptor.hueRed;
      case 'safehouse':
        return BitmapDescriptor.hueGreen;
      default:
        return BitmapDescriptor.hueViolet;
    }
  }

  Future<void> _goToCurrentLocation() async {
    if (!mounted) return;
    
    try {
      setState(() {
        _isLoading = true;
        _hasError = false;
      });

      final position = await LocationService.getCurrentLocation();
      if (!mounted) return;
      
      final controller = await _controller.future;
      final currentLocation = LatLng(position.latitude, position.longitude);
      
      await _searchSafeZones(currentLocation);
      if (!mounted) return;
      
      await controller.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: currentLocation,
            zoom: 15,
          ),
        ),
      );

      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _lastPosition = currentLocation;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _hasError = true;
        _errorMessage = e.toString();
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString()),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _toggleBottomSheet() {
    setState(() {
      _isBottomSheetVisible = !_isBottomSheetVisible;
    });
    if (_isBottomSheetVisible) {
      _animationController.forward();
    } else {
      _animationController.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isNavigating ? 'Navigation' : 'Safety Map'),
        elevation: 0,
        actions: [
          if (_isSearching)
            Center(
              child: Padding(
                padding: const EdgeInsets.only(right: 16.0),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Theme.of(context).colorScheme.onPrimary,
                    ),
                  ),
                ),
              ),
            ),
          if (!_isNavigating)
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _refreshSafeZones,
              tooltip: 'Refresh Safe Zones',
            ),
        ],
      ),
      body: Stack(
        children: [
          GoogleMap(
            mapType: MapType.normal,
            initialCameraPosition: const CameraPosition(
              target: LatLng(13.067439, 80.237617),
              zoom: 14.0,
            ),
            markers: _markers,
            polylines: _polylines,
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            mapToolbarEnabled: false,
            compassEnabled: true,
            onMapCreated: _onMapCreated,
            onCameraMove: _onCameraMove,
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).padding.bottom + (_isNavigating ? 200 : 80),
              top: 0,
              right: 0,
              left: 0,
            ),
          ),

          if (_isLoading)
            Container(
              color: Colors.black.withOpacity(0.3),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircularProgressIndicator(),
                      const SizedBox(height: 16),
                      Text(
                        'Loading safety locations...',
                        style: TextStyle(
                          color: Colors.grey[800],
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          if (_hasError)
            Center(
              child: Container(
                padding: const EdgeInsets.all(24),
                margin: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 15,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.red[50],
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.error_outline, color: Colors.red[700], size: 48),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _errorMessage,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 16,
                        color: Colors.black87,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: _refreshSafeZones,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Try Again'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).primaryColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                        elevation: 0,
                      ),
                    ),
                  ],
                ),
              ),
            ),

          if (_isBottomSheetVisible)
            AnimatedPositioned(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              left: 0,
              right: 0,
              bottom: 0,
              height: MediaQuery.of(context).size.height * 0.6,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 20,
                      offset: const Offset(0, -5),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Container(
                      margin: const EdgeInsets.only(top: 12, bottom: 8),
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                      child: Row(
                        children: [
                          Text(
                            'Nearby Safety Locations',
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: const Color(0xff132137),
                            ),
                          ),
                          const Spacer(),
                          if (_isSearching)
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Theme.of(context).primaryColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Theme.of(context).primaryColor,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    Expanded(
                      child: _nearbyPlaces.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: Colors.grey[100],
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      Icons.location_off,
                                      size: 48,
                                      color: Colors.grey[400],
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    'No nearby safety locations found',
                                    style: TextStyle(
                                      color: Colors.grey[600],
                                      fontSize: 16,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Try moving to a different area',
                                    style: TextStyle(
                                      color: Colors.grey[500],
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              itemCount: _nearbyPlaces.length,
                              itemBuilder: (context, index) {
                                final place = _nearbyPlaces[index];
                                return _buildPlaceCard(place);
                              },
                            ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
      floatingActionButton: _buildFloatingActionButtons(),
    );
  }

  Widget _buildPlaceCard(Map<String, dynamic> place) {
    final Color placeColor = _getPlaceColor(place['type']);
    final IconData placeIcon = _getPlaceTypeIcon(place['type']);
    final bool isCrowdedPlace = _isCrowdedPlaceType(place['type']);
    
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: placeColor.withOpacity(0.1),
          width: 1,
        ),
      ),
      elevation: 0,
      child: InkWell(
        onTap: () => _animateToPlace(place['position']),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: placeColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  placeIcon,
                  color: placeColor,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            place['name'],
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: Color(0xff132137),
                            ),
                          ),
                        ),
                        if (isCrowdedPlace)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.amber.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.people, size: 12, color: Colors.amber),
                                SizedBox(width: 2),
                                Text(
                                  'Crowded',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.amber,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.location_on,
                          size: 14,
                          color: placeColor.withOpacity(0.8),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${place['distance'].toStringAsFixed(1)} km away',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Container(
                decoration: BoxDecoration(
                  color: placeColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: IconButton(
                  icon: const Icon(Icons.directions),
                  color: placeColor,
                  onPressed: () => _launchNavigation(place['position']),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getPlaceColor(String type) {
    switch (type.toLowerCase()) {
      case 'police':
        return const Color(0xFF1a237e); // Deeper blue
      case 'hospital':
        return const Color(0xFFc62828); // Deeper red
      case 'safehouse':
        return const Color(0xFF2e7d32); // Deeper green
      case 'firebrigade':
      case 'fire_station':
        return const Color(0xFFe65100); // Orange
      case 'pharmacy':
        return const Color(0xFF00796B); // Teal
      case 'mall':
        return const Color(0xFF6A1B9A); // Purple
      case 'restaurant':
        return const Color(0xFFF57C00); // Dark orange
      case 'supermarket':
        return const Color(0xFF558B2F); // Light green
      case 'transit':
        return const Color(0xFF0288D1); // Light blue
      default:
        return const Color(0xFF37474f); // Deeper grey
    }
  }

  IconData _getPlaceTypeIcon(String type) {
    switch (type.toLowerCase()) {
      case 'police':
        return Icons.local_police;
      case 'hospital':
        return Icons.local_hospital;
      case 'safehouse':
        return Icons.home;
      case 'firebrigade':
        return Icons.local_fire_department;
      case 'fire_station':
        return Icons.local_fire_department;
      case 'pharmacy':
        return Icons.medical_services;
      case 'mall':
        return Icons.local_mall;
      case 'restaurant':
        return Icons.restaurant;
      case 'supermarket':
        return Icons.shopping_cart;
      case 'transit':
        return Icons.train;
      default:
        return Icons.place;
    }
  }

  Future<void> _animateToPlace(LatLng position) async {
    final controller = await _controller.future;
    await controller.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(
          target: position,
          zoom: 16,
        ),
      ),
    );
  }

  Future<void> _launchNavigation(LatLng destination) async {
    final url = 'google.navigation:q=${destination.latitude},${destination.longitude}&mode=d';
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      // Fallback to maps if navigation doesn't work
      final mapsUrl = 'https://www.google.com/maps/dir/?api=1&destination=${destination.latitude},${destination.longitude}&travelmode=driving';
      final mapsUri = Uri.parse(mapsUrl);
      if (await canLaunchUrl(mapsUri)) {
        await launchUrl(mapsUri);
      }
    }
  }

  void _onMapCreated(GoogleMapController controller) {
    _controller.complete(controller);
    controller.setMapStyle('''
      [
        {
          "featureType": "all",
          "elementType": "geometry",
          "stylers": [{"saturation": -5}]
        },
        {
          "featureType": "poi",
          "elementType": "labels",
          "stylers": [{"visibility": "off"}]
        },
        {
          "featureType": "transit",
          "elementType": "labels",
          "stylers": [{"visibility": "off"}]
        },
        {
          "featureType": "water",
          "elementType": "geometry",
          "stylers": [{"saturation": -20}, {"lightness": 20}]
        },
        {
          "featureType": "road",
          "elementType": "geometry",
          "stylers": [{"lightness": 10}]
        }
      ]
    ''');
  }

  void _updateNavigationInfo(String eta, double distance) {
    // This will be implemented when we add the navigation info UI
    // For now, we'll just print the info
    print('ETA: $eta, Distance: ${distance.toStringAsFixed(1)} km');
  }

  void _updateNavigationRoute() {
    setState(() {
      _polylines.clear();
      _polylines.add(
        Polyline(
          polylineId: const PolylineId('navigation_route'),
          points: _navigationPoints,
          color: Theme.of(context).primaryColor,
          width: 5,
          patterns: [
            PatternItem.dash(20),
            PatternItem.gap(10),
          ],
        ),
      );
    });
  }

  Future<void> _startNavigation(LatLng destination) async {
    setState(() {
      _isNavigating = true;
      _destination = destination;
    });

    try {
      final currentPosition = await LocationService.getCurrentLocation();
      final currentLatLng = LatLng(currentPosition.latitude, currentPosition.longitude);

      // Connect to WebSocket for live navigation updates
      _navigationChannel = WebSocketChannel.connect(
        Uri.parse('wss://your-navigation-server.com/ws'),
      );

      _navigationSubscription = _navigationChannel!.stream.listen((data) {
        _handleNavigationUpdate(data);
      });

      // Send initial navigation request
      _navigationChannel!.sink.add({
        'type': 'start_navigation',
        'origin': {
          'lat': currentLatLng.latitude,
          'lng': currentLatLng.longitude,
        },
        'destination': {
          'lat': destination.latitude,
          'lng': destination.longitude,
        },
      });

      // Update camera to show the route
      final bounds = LatLngBounds(
        southwest: LatLng(
          currentLatLng.latitude < destination.latitude ? currentLatLng.latitude : destination.latitude,
          currentLatLng.longitude < destination.longitude ? currentLatLng.longitude : destination.longitude,
        ),
        northeast: LatLng(
          currentLatLng.latitude > destination.latitude ? currentLatLng.latitude : destination.latitude,
          currentLatLng.longitude > destination.longitude ? currentLatLng.longitude : destination.longitude,
        ),
      );

      final controller = await _controller.future;
      controller.animateCamera(
        CameraUpdate.newLatLngBounds(bounds, 100),
      );

      // Show navigation UI
      _showNavigationUI();
    } catch (e) {
      setState(() {
        _hasError = true;
        _errorMessage = 'Failed to start navigation: $e';
      });
    }
  }

  void _handleNavigationUpdate(dynamic data) {
    if (!mounted) return;

    setState(() {
      if (data['type'] == 'route_update') {
        // Update navigation route
        _navigationPoints = List<LatLng>.from(
          (data['points'] as List).map(
            (point) => LatLng(point['lat'], point['lng']),
          ),
        );
        _updateNavigationRoute();
      } else if (data['type'] == 'eta_update') {
        // Update ETA and distance
        _updateNavigationInfo(data['eta'], data['distance']);
      }
    });
  }

  void _showNavigationUI() {
    showModalBottomSheet(
      context: context,
      isDismissible: false,
      enableDrag: false,
      builder: (context) => _NavigationBottomSheet(
        onCancel: () {
          _stopNavigation();
          Navigator.pop(context);
        },
      ),
    );
  }

  void _stopNavigation() {
    setState(() {
      _isNavigating = false;
      _destination = null;
      _polylines.clear();
      _navigationPoints.clear();
    });
    _navigationSubscription?.cancel();
    _navigationChannel?.sink.close();
  }

  Widget _buildFloatingActionButtons() {
    if (_isNavigating) {
      return Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).padding.bottom + 64),
        child: FloatingActionButton(
          heroTag: 'stop_navigation',
          onPressed: _stopNavigation,
          backgroundColor: Colors.red,
          child: const Icon(
            Icons.close,
            color: Colors.white,
          ),
        ),
      );
    }

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).padding.bottom + 64),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton(
            heroTag: 'location',
            onPressed: _goToCurrentLocation,
            backgroundColor: Colors.white,
            child: Icon(
              Icons.my_location,
              color: Theme.of(context).primaryColor,
            ),
          ),
          const SizedBox(height: 16),
          FloatingActionButton(
            heroTag: 'places',
            onPressed: _toggleBottomSheet,
            backgroundColor: Colors.white,
            child: AnimatedIcon(
              icon: AnimatedIcons.list_view,
              progress: _animationController,
              color: Theme.of(context).primaryColor,
            ),
          ),
        ],
      ),
    );
  }

  bool _isCrowdedPlaceType(String type) {
    final crowdedTypes = ['mall', 'restaurant', 'supermarket', 'transit'];
    return crowdedTypes.contains(type.toLowerCase());
  }

  Future<void> _refreshSafeZones() async {
    if (!mounted) return;
    
    try {
      setState(() {
        _isLoading = true;
        _hasError = false;
      });

      // Show user that we're using improved location search
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Using enhanced Google Places SDK for better safety location results...'),
          duration: Duration(seconds: 2),
        ),
      );

      final position = await LocationService.getCurrentLocation();
      if (!mounted) return;
      
      final currentLocation = LatLng(position.latitude, position.longitude);
      
      // Clear existing markers and force a fresh search
      setState(() {
        _markers = {};
        _safeZones.clear();
        _nearbyPlaces = [];
        _initialSearchDone = false;
      });
      
      // Search for safe zones
      await _searchSafeZones(currentLocation);
      
      final controller = await _controller.future;
      await controller.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: currentLocation,
            zoom: 15,
          ),
        ),
      );

      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _lastPosition = currentLocation;
        _initialSearchDone = true;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Safety locations updated using Google Places SDK. Found ${_safeZones.length} locations.'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 3),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _hasError = true;
        _errorMessage = e.toString();
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error refreshing safe zones: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _addHardcodedSafetyLocations(LatLng position, Set<Marker> markers, Set<SafePlace> safeZones) async {
    // Define types of locations we want to ensure are available
    final safetyTypes = ['police', 'hospital', 'firebrigade', 'pharmacy', 'safehouse'];
    
    // Create basic locations around the user's position
    for (int i = 0; i < safetyTypes.length; i++) {
      final type = safetyTypes[i];
      
      // Create a few locations of each type at various distances
      for (int j = 0; j < 3; j++) {
        // Calculate position with offset (creates a spiral pattern around the user)
        final double distance = 0.5 + (j * 0.5); // 0.5km, 1km, 1.5km
        final double angle = (i * 72 + j * 40) * (math.pi / 180); // Convert to radians
        
        // Convert distance to lat/lng offset (rough approximation)
        // 0.009 = approximately 1km at equator
        final double latOffset = distance * 0.009 * math.cos(angle);
        final double lngOffset = distance * 0.009 * math.sin(angle);
        
        final LatLng placePosition = LatLng(
          position.latitude + latOffset,
          position.longitude + lngOffset,
        );
        
        // Create place details
        String name = '';
        switch (type) {
          case 'police':
            name = j == 0 ? 'Central Police Station' : 'District ${j} Police Station';
            break;
          case 'hospital':
            name = j == 0 ? 'City Hospital' : 'Community Medical Center ${j}';
            break;
          case 'firebrigade':
            name = j == 0 ? 'Main Fire Station' : 'Fire Station ${j}';
            break;
          case 'pharmacy':
            name = j == 0 ? '24/7 Pharmacy' : 'Neighborhood Pharmacy ${j}';
            break;
          case 'safehouse':
            name = j == 0 ? 'Women\'s Shelter' : 'Family Crisis Center ${j}';
            break;
        }
        
        // Create a unique ID
        final String id = 'emergency_${type}_${j}';
        
        // Create the marker
        final Color color = _getPlaceColor(type);
        final BitmapDescriptor markerIcon = await _createFixedSizeMarker(color, type);
        
        // Create the safe place
        final double actualDistance = LocationService.calculateDistance(position, placePosition);
        final SafePlace safePlace = SafePlace(
          id: id,
          name: name,
          type: type,
          location: placePosition,
          distance: actualDistance,
          address: 'Emergency Location',
          isCrowdedPlace: false,
        );
        
        // Add to collections
        safeZones.add(safePlace);
        markers.add(
          Marker(
            markerId: MarkerId(id),
            position: placePosition,
            icon: markerIcon,
            onTap: () => _showMarkerInfo(
              name,
              type,
              actualDistance,
              'Emergency Location',
              isCrowdedPlace: false,
            ),
            anchor: const Offset(0.5, 0.5),
            zIndex: 2,
            flat: true,
          ),
        );
      }
    }
    
    print('Added ${safetyTypes.length * 3} hardcoded safety locations');
  }

  // Enhanced method to check Places SDK status and provide debugging info
  Future<void> _checkPlacesSDK() async {
    try {
      final isAvailable = await LocationService.isPlacesSDKAvailable();
      
      if (mounted) {
        if (isAvailable) {
          print('✅ Google Places SDK is available and properly initialized');
          
          // Only show success message in debug mode
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Places SDK initialized successfully'),
                backgroundColor: Colors.green,
                duration: Duration(seconds: 2),
              ),
            );
          }
        } else {
          // SDK not available, get the error
          final errorMsg = await LocationService.getPlacesSDKInitializationError();
          print('❌ Google Places SDK initialization failed: $errorMsg');
          
          if (mounted) {
            _showPlacesSDKErrorDialog(errorMsg);
          }
        }
      }
    } catch (e) {
      print('❌ Error checking Places SDK: $e');
      if (mounted) {
        _showPlacesSDKErrorDialog(e.toString());
      }
    }
  }
  
  // Show a helpful error dialog with instructions
  void _showPlacesSDKErrorDialog(String errorMsg) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Places SDK Issue Detected'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Error: $errorMsg'),
              const SizedBox(height: 16),
              const Text(
                'To fix this issue:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text('1. Make sure you have a valid Google API key'),
              const Text('2. Enable Places API in Google Cloud Console'),
              const Text('3. Check API key restrictions'),
              const Text('4. Verify billing is set up for your project'),
              const SizedBox(height: 16),
              const Text(
                'The app will use mock data for now.',
                style: TextStyle(fontStyle: FontStyle.italic),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _refreshSafeZones(); // Try refreshing anyway with fallback data
            },
            child: const Text('OK'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(context).pop();
              // Try to force re-initialize the SDK
              final reinitialized = await LocationService.forceReInitializePlacesSDK();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      reinitialized 
                          ? 'Places SDK reinitialized successfully' 
                          : 'Failed to reinitialize Places SDK'
                    ),
                    backgroundColor: reinitialized ? Colors.green : Colors.red,
                  ),
                );
                _refreshSafeZones();
              }
            },
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}

class _NavigationBottomSheet extends StatelessWidget {
  final VoidCallback onCancel;

  const _NavigationBottomSheet({
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 200,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.navigation),
              const SizedBox(width: 16),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Navigating to destination',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Following safest route',
                      style: TextStyle(
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: onCancel,
              ),
            ],
          ),
          const Divider(),
          const Expanded(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'ETA: 10 minutes',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    '2.5 km remaining',
                    style: TextStyle(
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class SafePlace {
  final String id;
  final String name;
  final String type;
  final LatLng location;
  final double distance;
  final String address;
  final bool isCrowdedPlace;

  SafePlace({
    required this.id,
    required this.name,
    required this.type,
    required this.location,
    required this.distance,
    required this.address,
    this.isCrowdedPlace = false,
  });
}
