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
    scopes: ['email', 'profile'],
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
      // Check if user is already signed in with Google
      await _googleSignIn.signInSilently();

      // Listen to auth state changes
      _firebaseAuth.authStateChanges().listen(_onAuthStateChanged);

      // Check current user
      _currentUser = _firebaseAuth.currentUser;

      if (_currentUser != null) {
        await _loadAuthMethod();
        _authState = AuthState.authenticated;
        print('User already authenticated: ${_currentUser!.uid}');
      } else {
        _authState = AuthState.unauthenticated;
      }
    } catch (e) {
      print('Error during initialization: $e');
      _authState = AuthState.unauthenticated;
      _errorMessage = e.toString();
    }

    notifyListeners();
  }

  void _onAuthStateChanged(User? user) async {
    print('Auth state changed: ${user?.uid}');
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
        // Try to get the current Google account
        _googleAccount = _googleSignIn.currentUser;
      } else if (authMethod == 'phone') {
        _lastMethod = AuthMethod.phone;
        _phoneNumber = prefs.getString('phoneNumber');
        _isPhoneVerified = true;
      }
    } catch (e) {
      print('Error loading auth method: $e');
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
      print('Error saving auth method: $e');
    }
  }

  // Enhanced Google Sign In with better error handling
  Future<bool> signInWithGoogle() async {
    print('=== Starting Google Sign-In ===');

    _authState = AuthState.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      // First, sign out any existing sessions to ensure clean state
      await _googleSignIn.signOut();
      await Future.delayed(const Duration(milliseconds: 500));

      print('Initiating Google Sign-In flow...');
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

      if (googleUser == null) {
        print('User cancelled Google Sign-In');
        _authState = AuthState.unauthenticated;
        notifyListeners();
        return false;
      }

      print('Google user selected: ${googleUser.email}');
      print('Display name: ${googleUser.displayName}');

      // Obtain the auth details from the request
      print('Getting authentication details...');
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

      if (googleAuth.accessToken == null || googleAuth.idToken == null) {
        throw Exception('Failed to obtain Google authentication tokens');
      }

      print('Successfully obtained Google auth tokens');

      // Create a new credential
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      print('Created Firebase credential, signing in...');

      // Sign in to Firebase with the Google credential
      final UserCredential userCredential = await _firebaseAuth.signInWithCredential(credential);

      if (userCredential.user != null) {
        print('✅ Firebase sign-in successful!');
        print('User ID: ${userCredential.user!.uid}');
        print('Email: ${userCredential.user!.email}');
        print('Display name: ${userCredential.user!.displayName}');

        _googleAccount = googleUser;
        _lastMethod = AuthMethod.google;
        _authState = AuthState.authenticated;
        _currentUser = userCredential.user;

        await _saveAuthMethod();
        notifyListeners();

        return true;
      } else {
        throw Exception('Firebase authentication returned null user');
      }
    } on FirebaseAuthException catch (e) {
      print('❌ Firebase Auth error: ${e.code} - ${e.message}');
      _authState = AuthState.error;
      _errorMessage = _getFirebaseAuthErrorMessage(e);
      _lastMethod = null;
      notifyListeners();
      return false;
    } catch (e) {
      print('❌ Google Sign-In error: $e');
      _authState = AuthState.error;
      _errorMessage = 'Google Sign-in failed. Please check your internet connection and try again.';
      _lastMethod = null;
      notifyListeners();
      return false;
    }
  }

  // Enhanced Phone number verification
  Future<bool> verifyPhoneNumber(String phoneNumber) async {
    print('=== Starting Phone Verification ===');
    print('Phone number: $phoneNumber');

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
          try {
            print('✅ Auto verification completed');
            await _firebaseAuth.signInWithCredential(credential);
            _lastMethod = AuthMethod.phone;
            _isPhoneVerified = true;
            _authState = AuthState.authenticated;
            notifyListeners();
          } catch (e) {
            print('❌ Auto-verification failed: $e');
            _errorMessage = 'Auto-verification failed. Please enter the code manually.';
            _authState = AuthState.error;
            notifyListeners();
          }
        },
        verificationFailed: (FirebaseAuthException e) {
          print('❌ Phone verification failed: ${e.code} - ${e.message}');
          _authState = AuthState.error;

          switch (e.code) {
            case 'invalid-phone-number':
              _errorMessage = 'The phone number format is invalid. Please check and try again.';
              break;
            case 'too-many-requests':
              _errorMessage = 'Too many requests. Please wait before trying again.';
              break;
            case 'quota-exceeded':
              _errorMessage = 'SMS quota exceeded. Please try using the test number: +91 7718556613';
              break;
            case 'missing-client-identifier':
            case 'app-not-authorized':
              _errorMessage = 'App verification failed. Please use the test number: +91 7718556613';
              break;
            default:
              _errorMessage = 'Phone verification failed. Please use the test number: +91 7718556613';
          }
          notifyListeners();
        },
        codeSent: (String verificationId, int? resendToken) {
          print('✅ SMS code sent successfully');
          _verificationId = verificationId;
          _resendToken = resendToken;
          _authState = AuthState.unauthenticated;
          _errorMessage = null;
          notifyListeners();
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          print('Code auto-retrieval timeout');
          _verificationId = verificationId;
        },
      );

      return true;
    } catch (e) {
      print('❌ Phone verification error: $e');
      _authState = AuthState.error;
      _errorMessage = 'Phone verification failed. Please use the test number: +91 7718556613';
      notifyListeners();
      return false;
    }
  }

  // Enhanced SMS code verification
  Future<bool> verifySmsCode(String smsCode) async {
    if (_verificationId == null) {
      _errorMessage = 'Verification session expired. Please request a new code.';
      _authState = AuthState.error;
      notifyListeners();
      return false;
    }

    print('=== Verifying SMS Code ===');
    print('Code: $smsCode');

    _authState = AuthState.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: _verificationId!,
        smsCode: smsCode,
      );

      await _firebaseAuth.signInWithCredential(credential);

      _isPhoneVerified = true;
      _lastMethod = AuthMethod.phone;
      _authState = AuthState.authenticated;

      print('✅ Phone verification successful');
      await _saveAuthMethod();
      notifyListeners();
      return true;
    } on FirebaseAuthException catch (e) {
      print('❌ SMS verification failed: ${e.code} - ${e.message}');
      _authState = AuthState.error;

      switch (e.code) {
        case 'invalid-verification-code':
          _errorMessage = 'Invalid code. Please check and try again.';
          break;
        case 'session-expired':
          _errorMessage = 'Code expired. Please request a new one.';
          break;
        default:
          _errorMessage = 'Verification failed. Please try again.';
      }
      notifyListeners();
      return false;
    } catch (e) {
      print('❌ Unexpected SMS verification error: $e');
      _authState = AuthState.error;
      _errorMessage = 'Verification failed. Please try again.';
      notifyListeners();
      return false;
    }
  }

  // Enhanced sign out
  Future<void> signOut() async {
    print('=== Signing Out ===');
    _authState = AuthState.loading;
    notifyListeners();

    try {
      // Sign out from Firebase first
      await _firebaseAuth.signOut();

      // Then sign out from Google if needed
      if (_lastMethod == AuthMethod.google || _googleAccount != null) {
        try {
          await _googleSignIn.signOut();
          await _googleSignIn.disconnect();
        } catch (e) {
          print('Google sign out error: $e');
          // Continue with sign out even if Google fails
        }
      }

      // Clear saved auth state
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();

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

      print('✅ Sign out successful');
      notifyListeners();
    } catch (e) {
      print('❌ Sign out error: $e');
      _errorMessage = 'Sign out failed. Please try again.';
      _authState = AuthState.unauthenticated;
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
        return 'An account already exists with this email using a different sign-in method.';
      case 'invalid-credential':
        return 'The credential is invalid or has expired. Please try again.';
      case 'operation-not-allowed':
        return 'Google Sign-In is not enabled. Please contact support.';
      case 'user-disabled':
        return 'This account has been disabled. Please contact support.';
      case 'user-not-found':
        return 'No account found. Please try signing up first.';
      case 'wrong-password':
        return 'Incorrect password. Please try again.';
      case 'invalid-verification-code':
        return 'The verification code is invalid.';
      case 'invalid-verification-id':
        return 'The verification ID is invalid.';
      case 'network-request-failed':
        return 'Network error. Please check your connection and try again.';
      default:
        return 'Authentication failed. Please try again.';
    }
  }
}