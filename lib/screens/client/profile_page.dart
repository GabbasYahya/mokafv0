import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:mokaf2/constants/app_colors.dart'; // Assuming AppColors is here
import 'package:mokaf2/auth/login.dart'; // For navigation back to LoginPage

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final User? _currentUser = FirebaseAuth.instance.currentUser;

  Future<void> _logout() async {
    await FirebaseAuth.instance.signOut();
    if (mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const LoginPage()),
        (Route<dynamic> route) => false,
      );
    }
  }

  void _navigateToEditProfile() {
    // TODO: Implement navigation to an EditProfileScreen
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Navigate to Edit Profile Screen (Not Implemented)')),
    );
    // Example: Navigator.push(context, MaterialPageRoute(builder: (context) => EditProfileScreen()));
  }

  @override
  Widget build(BuildContext context) {
    String displayName = _currentUser?.displayName ?? "No Name";
    String email = _currentUser?.email ?? "No Email";
    String photoURL = _currentUser?.photoURL ?? "";
    String initial = displayName.isNotEmpty ? displayName[0].toUpperCase() : (email.isNotEmpty ? email[0].toUpperCase() : "?");

    return Scaffold(
      appBar: AppBar(
  title: Row(
    children: [
      Image.asset(
        'assets/images/logo.png',
        height: 40,
        width: 40,
        fit: BoxFit.contain,
      ),
      const SizedBox(width: 12),
      const Text(
        'My Profile', 
        style: TextStyle(color: AppColors.white),
      ),
    ],
  ),
  backgroundColor: AppColors.primaryPurple,
  elevation: 0,
  iconTheme: const IconThemeData(color: AppColors.white),
),
      backgroundColor: AppColors.pageBackground, // A light background color
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 20),
            CircleAvatar(
              radius: 60,
              backgroundColor: AppColors.secondaryPurple.withOpacity(0.2),
              backgroundImage: photoURL.isNotEmpty ? NetworkImage(photoURL) : null,
              child: photoURL.isEmpty
                  ? Text(
                      initial,
                      style: const TextStyle(fontSize: 50, color: AppColors.primaryPurple, fontWeight: FontWeight.bold),
                    )
                  : null,
            ),
            const SizedBox(height: 20),
            Text(
              displayName,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              email,
              style: const TextStyle(fontSize: 16, color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 30),
            _buildProfileOption(
              icon: Icons.edit_outlined,
              title: 'Edit Profile',
              onTap: _navigateToEditProfile,
            ),
            _buildProfileOption(
              icon: Icons.settings_outlined,
              title: 'Account Settings',
              onTap: () {
                // TODO: Implement navigation to Account Settings
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Account Settings (Not Implemented)')),
                );
              },
            ),
            _buildProfileOption(
              icon: Icons.lock_outline,
              title: 'Change Password',
              onTap: () {
                // TODO: Implement navigation to Change Password Screen
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Change Password (Not Implemented)')),
                );
              },
            ),
            _buildProfileOption(
              icon: Icons.help_outline,
              title: 'Help & Support',
              onTap: () {
                // TODO: Implement navigation to Help & Support
                 ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Help & Support (Not Implemented)')),
                );
              },
            ),
            const SizedBox(height: 30),
            ElevatedButton.icon(
              icon: const Icon(Icons.logout, color: AppColors.white),
              label: const Text('Logout', style: TextStyle(color: AppColors.white, fontSize: 16)),
              onPressed: _logout,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 3,
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileOption({required IconData icon, required String title, required VoidCallback onTap}) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: Icon(icon, color: AppColors.primaryPurple),
        title: Text(title, style: const TextStyle(fontSize: 16, color: AppColors.textPrimary)),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: AppColors.textSecondary),
        onTap: onTap,
      ),
    );
  }
}

// Ensure you have AppColors defined, for example:
// class AppColors {
//   static const Color primaryPurple = Colors.deepPurple;
//   static const Color secondaryPurple = Colors.purple;
//   static const Color white = Colors.white;
//   static const Color textPrimary = Colors.black87;
//   static const Color textSecondary = Colors.grey;
//   static const Color pageBackground = Color(0xFFF4F6F8); // Example light grey