import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class AuthService {
  static const _storage = FlutterSecureStorage();
  static const _usernameKey = 'username';
  static const _passwordKey = 'password';
  static const _isLoggedInKey = 'is_logged_in';

  static Future<void> initialize() async {
    // Initialize secure storage
  }

  static Future<bool> isLoggedIn() async {
    final isLoggedIn = await _storage.read(key: _isLoggedInKey);
    return isLoggedIn == 'true';
  }

  static Future<bool> login(String username, String password) async {
    final storedUsername = await _storage.read(key: _usernameKey);
    final storedPassword = await _storage.read(key: _passwordKey);

    if (storedUsername == username && storedPassword == password) {
      await _storage.write(key: _isLoggedInKey, value: 'true');
      return true;
    }
    return false;
  }

  static Future<bool> signup(String username, String password) async {
    final existingUsername = await _storage.read(key: _usernameKey);
    if (existingUsername != null) {
      return false;
    }

    await _storage.write(key: _usernameKey, value: username);
    await _storage.write(key: _passwordKey, value: password);
    await _storage.write(key: _isLoggedInKey, value: 'true');
    return true;
  }

  static Future<void> logout() async {
    await _storage.delete(key: _isLoggedInKey);
  }

  static Future<String?> getUsername() async {
    return await _storage.read(key: _usernameKey);
  }
}

