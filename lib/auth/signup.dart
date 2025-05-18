import 'package:flutter/material.dart';
import 'package:mokaf2/constants/app_colors.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // Added Firestore import

class AuthService {
  static Future<Map<String, dynamic>> signUp({
    required String name, // Added name parameter
    required String email,
    required String password,
  }) async {
    try {
      UserCredential userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      User? user = userCredential.user;

      if (user != null) {
        // Update Firebase Auth display name
        await user.updateDisplayName(name);
        await user.reload(); // Reload user to get updated info
        user = FirebaseAuth.instance.currentUser; // Re-fetch current user

        // Save additional user data to Firestore
        await FirebaseFirestore.instance.collection('users').doc(user!.uid).set({
          'uid': user.uid,
          'name': name,
          'email': email,
          'createdAt': Timestamp.now(),
          // You can add more fields here, e.g., 'role': 'client'
        });
      }
      
      // You might want to send a verification email here:
      // if (user != null && !user.emailVerified) {
      //   await user.sendEmailVerification();
      //   return {'success': true, 'message': 'Signup successful! Please verify your email.'};
      // }
      return {'success': true, 'message': 'Signup successful!'};
    } on FirebaseAuthException catch (e) {
      String message = 'An unknown error occurred during signup.';
      if (e.code == 'weak-password') {
        message = 'The password provided is too weak.';
      } else if (e.code == 'email-already-in-use') {
        message = 'An account already exists for that email.';
      } else if (e.code == 'invalid-email') {
        message = 'The email address is not valid.';
      }
      return {'success': false, 'message': message};
    } catch (e) {
      // This will catch errors from Firestore as well if they occur
      return {'success': false, 'message': 'Signup failed: ${e.toString()}'};
    }
  }
}

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  _SignUpScreenState createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _nameController = TextEditingController(); // Controller for name
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  String _errorMessage = '';

  @override
  void dispose() {
    _nameController.dispose(); // Dispose name controller
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _signUp() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // Password match check is already handled by the validator in _buildTextField
    // but an explicit check here before calling the service is also fine.
    if (_passwordController.text != _confirmPasswordController.text) {
      setState(() {
        _errorMessage = 'Passwords do not match.';
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Passwords do not match.'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final result = await AuthService.signUp(
        name: _nameController.text.trim(), // Pass name
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      if (!mounted) return;

      if (result['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? 'Signup successful!'),
            backgroundColor: Colors.green,
          ),
        );
        // Consider navigating to a login page or home page after successful signup
        // For now, it pops the current screen.
        if (Navigator.canPop(context)) {
          Navigator.pop(context); // Go back to login
        } else {
          // If signup is the first screen, navigate to login or home
          // Navigator.pushReplacementNamed(context, '/login'); // Example
        }
      } else {
        setState(() {
          _errorMessage = result['message'] ?? 'Signup failed. Please try again.';
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(_errorMessage),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'An unexpected error occurred: ${e.toString()}';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_errorMessage),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: AppBar(
  backgroundColor: AppColors.primaryPurple,
  elevation: 0,
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
        'Sign Up',
        style: TextStyle(color: AppColors.white),
      ),
    ],
  ),
  leading: IconButton(
    icon: const Icon(Icons.arrow_back, color: AppColors.white),
    onPressed: () => Navigator.of(context).pop(),
  ),
),
      body: Center( 
        child: SingleChildScrollView( 
          padding: const EdgeInsets.all(32.0),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch, 
              children: [
                const Text(
                  'Create Your Account', 
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 24, 
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Fill in the details below to get started.', 
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    color: AppColors.textSecondary, 
                  ),
                ),
                const SizedBox(height: 40),
                _buildTextField( // Name Field
                  controller: _nameController,
                  label: 'Full Name',
                  hint: 'Enter your full name',
                  obscureText: false,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your full name';
                    }
                    if (value.length < 3) {
                      return 'Name must be at least 3 characters';
                    }
                    return null;
                  },
                  icon: Icons.person_outline,
                  textInputType: TextInputType.name,
                ),
                const SizedBox(height: 20),
                _buildTextField(
                  controller: _emailController,
                  label: 'Email',
                  hint: 'Enter your email',
                  obscureText: false,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your email';
                    }
                    if (!RegExp(r"^[a-zA-Z0-9.a-zA-Z0-9.!#$%&'*+-/=?^_`{|}~]+@[a-zA-Z0-9]+\.[a-zA-Z]+").hasMatch(value)) {
                      return 'Please enter a valid email address';
                    }
                    return null;
                  },
                  icon: Icons.email_outlined, 
                  textInputType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 20),
                _buildTextField(
                  controller: _passwordController,
                  label: 'Password',
                  hint: 'Enter your password',
                  obscureText: true,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your password';
                    }
                    if (value.length < 6) {
                      return 'Password must be at least 6 characters';
                    }
                    return null;
                  },
                  icon: Icons.lock_outline, 
                ),
                const SizedBox(height: 20),
                _buildTextField(
                  controller: _confirmPasswordController,
                  label: 'Confirm Password',
                  hint: 'Re-enter your password',
                  obscureText: true,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please confirm your password';
                    }
                    if (value != _passwordController.text) {
                      return 'Passwords do not match';
                    }
                    return null;
                  },
                  icon: Icons.lock_outline, 
                  isLastField: true, // To set textInputAction to done
                ),
                if (_errorMessage.isNotEmpty && !_isLoading)
                  Padding(
                    padding: const EdgeInsets.only(top: 16.0, bottom: 10.0), 
                    child: Text(
                      _errorMessage,
                      style: const TextStyle(color: Colors.red, fontSize: 14),
                      textAlign: TextAlign.center,
                    ),
                  ),
                const SizedBox(height: 24), 
                ElevatedButton( 
                  onPressed: _isLoading ? null : _signUp,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.secondaryPurple,
                    padding: const EdgeInsets.symmetric(vertical: 16.0),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8.0),
                    ),
                    textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.white),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2.0,
                          ),
                        )
                      : const Text('Sign Up', style: TextStyle(color: AppColors.white)),
                ),
                const SizedBox(height: 20),
                TextButton(
                  onPressed: _isLoading ? null : () {
                    if (Navigator.canPop(context)) {
                       Navigator.pop(context); 
                    } else {
                      // Navigator.pushReplacementNamed(context, '/login'); 
                    }
                  },
                  child: const Text(
                    'Already have an account? Login',
                    style: TextStyle(
                      color: AppColors.primaryPurple,
                      fontWeight: FontWeight.w600, 
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required bool obscureText,
    String? Function(String?)? validator,
    IconData? icon, 
    TextInputType? textInputType, // Added textInputType
    bool isLastField = false, // Added to handle textInputAction
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: icon != null ? Icon(icon, color: AppColors.primaryPurple.withOpacity(0.7)) : null, 
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8.0),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder( 
          borderRadius: BorderRadius.circular(8.0),
          borderSide: BorderSide(color: Colors.grey.shade400),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8.0),
          borderSide: const BorderSide(color: AppColors.secondaryPurple, width: 2.0),
        ),
        errorBorder: OutlineInputBorder( 
          borderRadius: BorderRadius.circular(8.0),
          borderSide: const BorderSide(color: Colors.red, width: 1.0),
        ),
        focusedErrorBorder: OutlineInputBorder( 
          borderRadius: BorderRadius.circular(8.0),
          borderSide: const BorderSide(color: Colors.red, width: 2.0),
        ),
        filled: true, 
        fillColor: AppColors.white.withOpacity(0.9), 
      ),
      validator: validator,
      keyboardType: textInputType ?? (obscureText ? TextInputType.visiblePassword : TextInputType.text),
      textInputAction: isLastField ? TextInputAction.done : TextInputAction.next,
      onFieldSubmitted: isLastField && !_isLoading ? (_) => _signUp() : null,
    );
  }
}