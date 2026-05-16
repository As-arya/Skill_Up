import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Singleton that holds the current logged-in user's data in memory and
/// persists sensitive fields (token, userId, name, email) to the platform
/// secure store (Android Keystore / iOS Keychain) via flutter_secure_storage.
class UserSession {
  UserSession._();
  static final UserSession instance = UserSession._();

  int userId = 0;
  String userName = '';
  String userEmail = '';
  String token = '';

  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  static const String _keyUserId = 'user_id';
  static const String _keyUserName = 'user_name';
  static const String _keyUserEmail = 'user_email';
  static const String _keyToken = 'user_token';

  Future<void> set({
    required int id,
    required String name,
    required String email,
    required String token,
  }) async {
    userId = id;
    userName = name;
    userEmail = email;
    this.token = token;

    await _storage.write(key: _keyUserId, value: id.toString());
    await _storage.write(key: _keyUserName, value: name);
    await _storage.write(key: _keyUserEmail, value: email);
    await _storage.write(key: _keyToken, value: token);
  }

  /// Restores session from secure storage. Returns true if a valid token was found.
  Future<bool> restore() async {
    final savedToken = await _storage.read(key: _keyToken);

    if (savedToken == null || savedToken.isEmpty) {
      return false;
    }

    final savedId = await _storage.read(key: _keyUserId);
    userId = int.tryParse(savedId ?? '') ?? 0;
    userName = await _storage.read(key: _keyUserName) ?? '';
    userEmail = await _storage.read(key: _keyUserEmail) ?? '';
    token = savedToken;

    return userId > 0 && token.isNotEmpty;
  }

  Future<void> clear() async {
    userId = 0;
    userName = '';
    userEmail = '';
    token = '';

    await _storage.delete(key: _keyUserId);
    await _storage.delete(key: _keyUserName);
    await _storage.delete(key: _keyUserEmail);
    await _storage.delete(key: _keyToken);
  }

  bool get isLoggedIn => userId > 0;
}
