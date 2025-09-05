# Safety Map Feature

This feature provides a Google Maps integration that shows nearby safety locations such as police stations, hospitals, and safe houses.

## Features

- Real-time location tracking
- Display of nearby safety locations (police stations, hospitals, safe houses)
- Custom markers for different types of safety locations
- Zoom controls
- Map legend
- Error handling with retry options

## How to Use

1. Open the app and navigate to the Safety Map section
2. Allow location permissions when prompted
3. The map will show your current location with a blue marker
4. Safety locations will be shown with different colored markers:
   - Red: Police Stations
   - Green: Hospitals
   - Yellow: Safe Houses
   - Orange: Fire Stations
5. Use the zoom buttons on the right side to zoom in and out
6. Tap on any marker to see details about the location
7. Use the "My Location" button to center the map on your current location

## Data Sources

The app uses multiple data sources for safety locations:

1. Firestore Database: Pre-populated safety locations
2. Google Places API: Real-time nearby places based on your location
3. Hardcoded Fallback: In case both of the above fail

## Troubleshooting

If you encounter any issues:

1. Make sure location services are enabled on your device
2. Check that you have granted the app location permissions
3. Ensure you have an active internet connection
4. Try the "Refresh" button in the app bar
5. If the map fails to load, use the "Retry" button on the error screen

## Developer Notes

To populate the safety locations in Firestore:

1. Uncomment the `PopulateSafetyLocations.run()` line in main.dart
2. Run the app once
3. Comment the line back to prevent duplicate entries

```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  // Uncomment to populate safety locations (run once, then comment back)
  // await PopulateSafetyLocations.run();
  
  runApp(const MyApp());
}
```
