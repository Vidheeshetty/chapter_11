import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AuthMethod { phone, google }
enum AuthState { initial, loading, authenticated, unauthenticated, error }

class AuthService extends ChangeNotifier {
  // Firebase instances
  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: ['email'], // Simplified scopes
  );

  // Auth state
  AuthState _authState = AuthState.initial;
  String? _errorMessage;
  AuthMethod? _lastMethod;

  // User info
  String? _phoneNumber;
  bool _isPhoneVerified = false;
  GoogleSignInAccount? _googleAccount;
  User? _currentUser;

  // Verification code
  String? _verificationId;
  int? _resendToken;

  // Getters
  AuthState get authState => _authState;
  String? get errorMessage => _errorMessage;
  bool get isAuthenticated => _authState == AuthState.authenticated && _currentUser != null;
  bool get isLoading => _authState == AuthState.loading;
  AuthMethod? get lastMethod => _lastMethod;
  String? get phoneNumber => _phoneNumber;
  bool get isPhoneVerified => _isPhoneVerified;
  GoogleSignInAccount? get googleAccount => _googleAccount;
  User? get currentUser => _currentUser;

  Future<void> initialize() async {
    _authState = AuthState.initial;

    try {
      // Listen to auth state changes
      _firebaseAuth.authStateChanges().listen(_onAuthStateChanged);

      // Check current user
      _currentUser = _firebaseAuth.currentUser;

      if (_currentUser != null) {
        await _loadAuthMethod();
        _authState = AuthState.authenticated;
      } else {
        _authState = AuthState.unauthenticated;
      }
    } catch (e) {
      _authState = AuthState.unauthenticated;
      _errorMessage = e.toString();
    }

    notifyListeners();
  }

  void _onAuthStateChanged(User? user) async {
    _currentUser = user;

    if (user != null) {
      _authState = AuthState.authenticated;
      await _saveAuthMethod();
    } else {
      _authState = AuthState.unauthenticated;
      _lastMethod = null;
      _phoneNumber = null;
      _isPhoneVerified = false;
      _googleAccount = null;
    }

    notifyListeners();
  }

  Future<void> _loadAuthMethod() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final authMethod = prefs.getString('authMethod');

      if (authMethod == 'google') {
        _lastMethod = AuthMethod.google;
      } else if (authMethod == 'phone') {
        _lastMethod = AuthMethod.phone;
        _phoneNumber = prefs.getString('phoneNumber');
        _isPhoneVerified = true;
      }
    } catch (e) {
      // Handle error silently
    }
  }

  Future<void> _saveAuthMethod() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      if (_lastMethod == AuthMethod.google) {
        await prefs.setString('authMethod', 'google');
      } else if (_lastMethod == AuthMethod.phone) {
        await prefs.setString('authMethod', 'phone');
        if (_phoneNumber != null) {
          await prefs.setString('phoneNumber', _phoneNumber!);
        }
      }
    } catch (e) {
      // Handle error silently
    }
  }

  // Phone number verification - ENHANCED
  Future<bool> verifyPhoneNumber(String phoneNumber) async {
    _authState = AuthState.loading;
    _lastMethod = AuthMethod.phone;
    _errorMessage = null;
    _phoneNumber = phoneNumber;
    notifyListeners();

    try {
      await _firebaseAuth.verifyPhoneNumber(
        phoneNumber: phoneNumber,
        timeout: const Duration(seconds: 60),
        verificationCompleted: (PhoneAuthCredential credential) async {
          // Auto-verification completed (Android only)
          try {
            print('Auto verification completed');
            await _firebaseAuth.signInWithCredential(credential);
            _lastMethod = AuthMethod.phone;
            _isPhoneVerified = true;
            _authState = AuthState.authenticated;
            notifyListeners();
          } catch (e) {
            print('Auto-verification failed: $e');
            _errorMessage = 'Auto-verification failed: ${e.toString()}';
            _authState = AuthState.error;
            notifyListeners();
          }
        },
        verificationFailed: (FirebaseAuthException e) {
          print('Verification failed: ${e.code} - ${e.message}');
          _authState = AuthState.error;

          // Handle specific error cases
          switch (e.code) {
            case 'invalid-phone-number':
              _errorMessage = 'The phone number format is invalid.';
              break;
            case 'too-many-requests':
              _errorMessage = 'Too many requests. Please try again later.';
              break;
            case 'quota-exceeded':
              _errorMessage = 'SMS quota exceeded. Try using test numbers.';
              break;
            case 'missing-client-identifier':
              _errorMessage = 'Missing app verification. Please check Firebase setup.';
              break;
            case 'app-not-authorized':
              _errorMessage = 'App not authorized. Please check SHA fingerprint.';
              break;
            default:
              _errorMessage = 'Verification failed: ${e.message ?? 'Unknown error'}';
          }
          notifyListeners();
        },
        codeSent: (String verificationId, int? resendToken) {
          print('Code sent to $phoneNumber');
          _verificationId = verificationId;
          _resendToken = resendToken;
          _authState = AuthState.unauthenticated; // Ready for code input
          _errorMessage = null; // Clear any previous errors
          notifyListeners();
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          print('Auto retrieval timeout');
          _verificationId = verificationId;
        },
      );

      return true;
    } catch (e) {
      print('Phone verification error: $e');
      _authState = AuthState.error;
      _errorMessage = 'Phone verification failed: ${e.toString()}';
      notifyListeners();
      return false;
    }
  }

  // Verify SMS code - ENHANCED
  Future<bool> verifySmsCode(String smsCode) async {
    if (_verificationId == null) {
      _errorMessage = 'Verification ID not found. Please resend code.';
      _authState = AuthState.error;
      notifyListeners();
      return false;
    }

    _authState = AuthState.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      print('Verifying SMS code: $smsCode');
      final credential = PhoneAuthProvider.credential(
        verificationId: _verificationId!,
        smsCode: smsCode,
      );

      await _firebaseAuth.signInWithCredential(credential);

      _isPhoneVerified = true;
      _lastMethod = AuthMethod.phone;
      _authState = AuthState.authenticated;

      print('Phone verification successful');
      notifyListeners();
      return true;
    } on FirebaseAuthException catch (e) {
      print('SMS verification failed: ${e.code} - ${e.message}');
      _authState = AuthState.error;

      switch (e.code) {
        case 'invalid-verification-code':
          _errorMessage = 'Invalid verification code. Please try again.';
          break;
        case 'session-expired':
          _errorMessage = 'Verification code expired. Please request a new one.';
          break;
        default:
          _errorMessage = 'Verification failed: ${e.message ?? 'Unknown error'}';
      }
      notifyListeners();
      return false;
    } catch (e) {
      print('Unexpected SMS verification error: $e');
      _authState = AuthState.error;
      _errorMessage = 'Unexpected error: ${e.toString()}';
      notifyListeners();
      return false;
    }
  }

  // Google Sign In - ENHANCED WITH BETTER ERROR HANDLING
  Future<bool> signInWithGoogle() async {
    print('Starting Google Sign-In');
    _authState = AuthState.loading;
    _lastMethod = AuthMethod.google;
    _errorMessage = null;
    notifyListeners();

    try {
      // Trigger the authentication flow
      print('Triggering Google Sign-In flow');
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

      if (googleUser == null) {
        // User cancelled the sign-in
        print('User cancelled Google Sign-In');
        _authState = AuthState.unauthenticated;
        _lastMethod = null;
        notifyListeners();
        return false;
      }

      print('Google user selected: ${googleUser.email}');

      // Obtain the auth details from the request
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

      if (googleAuth.accessToken == null || googleAuth.idToken == null) {
        throw Exception('Failed to obtain Google authentication tokens');
      }

      print('Got Google auth tokens');

      // Create a new credential
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      print('Created Firebase credential');

      // Sign in to Firebase with the Google credential
      final UserCredential userCredential = await _firebaseAuth.signInWithCredential(credential);

      if (userCredential.user != null) {
        print('Firebase sign-in successful: ${userCredential.user!.uid}');
        _googleAccount = googleUser;
        _lastMethod = AuthMethod.google;
        _authState = AuthState.authenticated;
        _currentUser = userCredential.user;
        notifyListeners();
        return true;
      } else {
        throw Exception('Failed to authenticate with Firebase');
      }
    } on FirebaseAuthException catch (e) {
      print('Firebase Auth error: ${e.code} - ${e.message}');
      _authState = AuthState.error;
      _errorMessage = _getFirebaseAuthErrorMessage(e);
      _lastMethod = null;
      notifyListeners();
      return false;
    } catch (e) {
      print('Google Sign-In error: $e');
      _authState = AuthState.error;
      _errorMessage = 'Google Sign-in failed: ${e.toString()}';
      _lastMethod = null;
      notifyListeners();
      return false;
    }
  }

  // Sign out - ENHANCED
  Future<void> signOut() async {
    print('Signing out');
    _authState = AuthState.loading;
    notifyListeners();

    try {
      // Sign out from Firebase first
      await _firebaseAuth.signOut();

      // Then sign out from Google if needed
      if (_lastMethod == AuthMethod.google) {
        try {
          await _googleSignIn.signOut();
        } catch (e) {
          print('Google sign out failed: $e');
          // Continue with sign out even if Google fails
        }
      }

      // Clear saved auth state
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('authMethod');
      await prefs.remove('phoneNumber');

      // Reset state
      _authState = AuthState.unauthenticated;
      _lastMethod = null;
      _phoneNumber = null;
      _isPhoneVerified = false;
      _googleAccount = null;
      _currentUser = null;
      _verificationId = null;
      _resendToken = null;
      _errorMessage = null;

      print('Sign out successful');
      notifyListeners();
    } catch (e) {
      print('Sign out error: $e');
      _errorMessage = e.toString();
      _authState = AuthState.unauthenticated; // Still sign out even on error
      notifyListeners();
    }
  }

  // Reset error state
  void resetError() {
    _errorMessage = null;
    if (_authState == AuthState.error) {
      _authState = AuthState.unauthenticated;
    }
    notifyListeners();
  }

  // Helper method for Firebase Auth errors
  String _getFirebaseAuthErrorMessage(FirebaseAuthException error) {
    switch (error.code) {
      case 'account-exists-with-different-credential':
        return 'An account already exists with a different sign-in method.';
      case 'invalid-credential':
        return 'The credential is invalid or has expired.';
      case 'operation-not-allowed':
        return 'This sign-in method is not enabled.';
      case 'user-disabled':
        return 'This account has been disabled.';
      case 'user-not-found':
        return 'No account found with this credential.';
      case 'wrong-password':
        return 'Incorrect password.';
      case 'invalid-verification-code':
        return 'The verification code is invalid.';
      case 'invalid-verification-id':
        return 'The verification ID is invalid.';
      case 'network-request-failed':
        return 'Network error. Please check your connection.';
      default:
        return 'Authentication failed: ${error.message ?? 'Unknown error'}';
    }
  }
}