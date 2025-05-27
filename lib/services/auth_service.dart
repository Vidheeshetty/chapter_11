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
        _googleAccount = await _googleSignIn.signInSilently();
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

  // Begin phone number verification
  Future<bool> verifyPhoneNumber(String phoneNumber) async {
    _authState = AuthState.loading;
    _errorMessage = null;
    _phoneNumber = phoneNumber;
    notifyListeners();

    try {
      await _firebaseAuth.verifyPhoneNumber(
        phoneNumber: phoneNumber,
        verificationCompleted: (PhoneAuthCredential credential) async {
          // Auto-verification completed
          try {
            await _firebaseAuth.signInWithCredential(credential);
            _lastMethod = AuthMethod.phone;
            _isPhoneVerified = true;
          } catch (e) {
            _errorMessage = 'Auto-verification failed: ${e.toString()}';
            _authState = AuthState.error;
            notifyListeners();
          }
        },
        verificationFailed: (FirebaseAuthException e) {
          _authState = AuthState.error;
          _errorMessage = _getErrorMessage(e);
          notifyListeners();
        },
        codeSent: (String verificationId, int? resendToken) {
          _verificationId = verificationId;
          _authState = AuthState.unauthenticated;
          notifyListeners();
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          _verificationId = verificationId;
        },
        timeout: const Duration(seconds: 60),
      );

      return true;
    } catch (e) {
      _authState = AuthState.error;
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  // Verify SMS code
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
      final credential = PhoneAuthProvider.credential(
        verificationId: _verificationId!,
        smsCode: smsCode,
      );

      await _firebaseAuth.signInWithCredential(credential);

      _isPhoneVerified = true;
      _lastMethod = AuthMethod.phone;
      _authState = AuthState.authenticated;

      notifyListeners();
      return true;
    } catch (e) {
      _authState = AuthState.error;
      _errorMessage = _getErrorMessage(e);
      notifyListeners();
      return false;
    }
  }

  // Google Sign In
  Future<bool> signInWithGoogle() async {
    _authState = AuthState.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      // Sign out any existing Google account first
      await _googleSignIn.signOut();

      // Trigger the authentication flow
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

      if (googleUser == null) {
        // User cancelled the sign-in
        _authState = AuthState.unauthenticated;
        notifyListeners();
        return false;
      }

      // Obtain the auth details from the request
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

      // Create a new credential
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Sign in to Firebase with the Google credential
      await _firebaseAuth.signInWithCredential(credential);

      _googleAccount = googleUser;
      _lastMethod = AuthMethod.google;
      _authState = AuthState.authenticated;

      notifyListeners();
      return true;
    } catch (e) {
      _authState = AuthState.error;
      _errorMessage = _getErrorMessage(e);
      notifyListeners();
      return false;
    }
  }

  // Sign out
  Future<void> signOut() async {
    _authState = AuthState.loading;
    notifyListeners();

    try {
      // Sign out from Firebase
      await _firebaseAuth.signOut();

      // Sign out from Google if signed in with Google
      if (_lastMethod == AuthMethod.google) {
        await _googleSignIn.signOut();
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

      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();
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

  // Helper method to get user-friendly error messages
  String _getErrorMessage(dynamic error) {
    if (error is FirebaseAuthException) {
      switch (error.code) {
        case 'invalid-phone-number':
          return 'The phone number is invalid.';
        case 'invalid-verification-code':
          return 'The verification code is invalid.';
        case 'too-many-requests':
          return 'Too many requests. Please try again later.';
        case 'network-request-failed':
          return 'Network error. Please check your connection.';
        case 'account-exists-with-different-credential':
          return 'An account already exists with a different sign-in method.';
        case 'invalid-credential':
          return 'The credential is invalid or has expired.';
        case 'operation-not-allowed':
          return 'This sign-in method is not enabled.';
        case 'user-disabled':
          return 'This account has been disabled.';
        case 'user-not-found':
          return 'No account found with this phone number.';
        case 'wrong-password':
          return 'Incorrect password.';
        default:
          return 'Authentication failed: ${error.message}';
      }
    } else {
      return error.toString();
    }
  }
}