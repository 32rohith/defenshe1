import 'package:appwrite/appwrite.dart';
import 'package:appwrite/models.dart';

class AppWriteService {
  static Client? _client;
  static Account? _account;
  static Databases? _database;

  static final AppWriteService _instance = AppWriteService._internal();

  factory AppWriteService() {
    return _instance;
  }

  AppWriteService._internal();

  // Initialize Appwrite Client
  Future<void> init() async {
    if (_client != null) return;

    _client = Client()
        .setEndpoint('https://cloud.appwrite.io/v1') // Replace with your Appwrite endpoint
        .setProject('672c9cc4001d5826f024'); // Replace with your project ID

    _account = Account(_client!);
    _database = Databases(_client!);
  }

  // Initiate phone-based authentication with createPhoneToken
  Future<String?> initiatePhoneAuth(String phoneNumber) async {
    try {
      final response = await _account!.createPhoneToken(
        userId: ID.unique(),         // Generates a unique ID for the new user
        phone: phoneNumber,     // The phone number for authentication
      );
      return response.userId;        // Returns the user ID for OTP verification
    } catch (e) {
      print("Error initiating phone auth: $e");
      return null;
    }
  }

  // Verify OTP using the user ID and OTP (token)
  Future<bool> verifyOTP(String userId, String secret) async {
    try {
      await _account!.updatePhoneSession(
        userId: userId,
        secret: secret,
      );
      return true;
    } catch (e) {
      print("Error verifying OTP: $e");
      return false;
    }
  }

  // Store user data in Appwrite database
  Future<void> storeUserData(String name, String age, List<Map<String, String>> contacts) async {
    try {
      await _database!.createDocument(
        databaseId: '<YOUR_DATABASE_ID>',     // Replace with your Appwrite database ID
        collectionId: '<YOUR_COLLECTION_ID>', // Replace with your Appwrite collection ID
        documentId: ID.unique(),              // Creates a unique document ID
        data: {
          'name': name,
          'age': age,
          'contacts': contacts,
        },
      );
    } catch (e) {
      print("Error storing user data: $e");
    }
  }

  // Get the logged-in user information
  Future<User?> getUser() async {
    try {
      return await _account!.get();
    } catch (e) {
      print("Error fetching user: $e");
      return null;
    }
  }
}
