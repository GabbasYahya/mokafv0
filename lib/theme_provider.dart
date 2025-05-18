import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum ThemeType { client, provider }

class ThemeProvider with ChangeNotifier {
  ThemeData _currentTheme = clientTheme;
  ThemeType _currentThemeType = ThemeType.client;
  bool _userHasProviderRole = false; // New flag to track if user is a provider

  ThemeData get currentTheme => _currentTheme;
  ThemeType get currentThemeType => _currentThemeType;
  bool get userHasProviderRole => _userHasProviderRole;

  static final ThemeData clientTheme = ThemeData(
    primarySwatch: Colors.deepPurple,
    brightness: Brightness.light,
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.deepPurple,
      elevation: 0,
      iconTheme: IconThemeData(color: Colors.white),
      titleTextStyle: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w500),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.deepPurpleAccent,
        foregroundColor: Colors.white,
      )
    ),
  );

  static final ThemeData providerTheme = ThemeData(
    primaryColor: const Color(0xFF00BFA6), // Teal
    colorScheme: ColorScheme.fromSwatch().copyWith(
      primary: const Color(0xFF00BFA6), 
      secondary: const Color(0xFF00E5B9), 
      surface: const Color(0xFFE0F7F4), 
    ),
    scaffoldBackgroundColor: const Color(0xFFE0F7F4),
    brightness: Brightness.light,
    appBarTheme: const AppBarTheme(
      backgroundColor: Color(0xFF00BFA6), 
      elevation: 0,
      iconTheme: IconThemeData(color: Colors.white),
      titleTextStyle: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w500),
    ),
     elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF00E5B9), 
        foregroundColor: Colors.black87, 
      )
    ),
  );

  void setTheme(ThemeType themeType) {
    if (themeType == ThemeType.provider) {
      _currentTheme = providerTheme;
      _currentThemeType = ThemeType.provider;
    } else {
      _currentTheme = clientTheme;
      _currentThemeType = ThemeType.client;
    }
    notifyListeners();
  }

  // Method to set that the user has completed the provider registration
  void setUserHasProviderRole(bool hasRole) {
    _userHasProviderRole = hasRole;
    notifyListeners(); // Notify if you want UI to react to this change directly
  }

  void resetToClientDefaults() {
    _currentTheme = clientTheme;
    _currentThemeType = ThemeType.client;
    _userHasProviderRole = false; // Reset provider role status
    notifyListeners();
  }

  // Add this method to ThemeProvider:
  void refreshProviderStatus(String userId) async {
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();
          
      if (userDoc.exists) {
        final userData = userDoc.data() as Map<String, dynamic>;
        bool isProvider = userData['isProvider'] ?? false;
        
        // Update local state
        _userHasProviderRole = isProvider;
        notifyListeners();
      }
    } catch (e) {
      print('Error refreshing provider status: $e');
    }
  }

  // Add this method to prevent race conditions in theme changes
  Future<void> becomeProvider(BuildContext context) async {
    // First set the role
    _userHasProviderRole = true;
    notifyListeners();
    
    // Then set the theme - adding a microtask to ensure UI updates correctly
    Future.microtask(() {
      setTheme(ThemeType.provider);
    });
    
    // Save to preferences
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isProvider', true);
    await prefs.setInt('themeType', ThemeType.provider.index);
  }
}