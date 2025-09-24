import 'dart:convert';
import 'package:crypto/crypto.dart' as crypto;
import 'package:encrypt/encrypt.dart' as enc;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureStorageService {
  final _storage = const FlutterSecureStorage();

  // Keys for flutter_secure_storage
  static const String _masterEncryptionKeyStorageKey = 'master_encryption_key';
  static const String _notePasswordIVStorageKey = 'note_password_iv';
  static const String _notePasswordEncryptedHashStorageKey = 'note_password_encrypted_hash';

  enc.Key? _aesKey;
  enc.Encrypter? _encrypter;

  Future<void> _ensureEncryptionKeyAndEncrypter() async {
    if (_aesKey != null && _encrypter != null) {
      return;
    }

    String? keyString = await _storage.read(key: _masterEncryptionKeyStorageKey);
    if (keyString == null) {
      // Generate a new 256-bit (32 bytes) AES key
      final newKey = enc.Key.fromSecureRandom(32);
      await _storage.write(key: _masterEncryptionKeyStorageKey, value: newKey.base64);
      _aesKey = newKey;
      //print('New master encryption key generated and saved.');
    } else {
      _aesKey = enc.Key.fromBase64(keyString);
      //print('Master encryption key loaded from storage.');
    }
    _encrypter = enc.Encrypter(enc.AES(_aesKey!, mode: enc.AESMode.cbc));
  }

  String _hashPassword(String password) {
    final bytes = utf8.encode(password); // Convert password to bytes
    final digest = crypto.sha256.convert(bytes); // Hash using SHA-256
    return digest.toString(); // Return hex string of the hash
  }

  Future<void> savePassword(String password) async {
    await _ensureEncryptionKeyAndEncrypter();
    final String passwordHash = _hashPassword(password);

    // Generate a new random IV for each encryption
    final iv = enc.IV.fromSecureRandom(16); // AES block size is 16 bytes

    final encryptedPasswordHash = _encrypter!.encrypt(passwordHash, iv: iv);

    await _storage.write(key: _notePasswordIVStorageKey, value: iv.base64);
    await _storage.write(key: _notePasswordEncryptedHashStorageKey, value: encryptedPasswordHash.base64);
    //print('Password IV and encrypted hash saved to secure storage.');
  }

  Future<bool> isPasswordSet() async {
    final String? encryptedHash = await _storage.read(key: _notePasswordEncryptedHashStorageKey);
    return encryptedHash != null && encryptedHash.isNotEmpty;
  }

  Future<bool> verifyPassword(String inputPassword) async {
    await _ensureEncryptionKeyAndEncrypter();
    final String? ivBase64 = await _storage.read(key: _notePasswordIVStorageKey);
    final String? encryptedHashBase64 = await _storage.read(key: _notePasswordEncryptedHashStorageKey);

    if (ivBase64 == null || encryptedHashBase64 == null) {
      //print('IV or encrypted hash not found in storage.');
      return false; // No password set or corrupted
    }

    try {
      final iv = enc.IV.fromBase64(ivBase64);
      final encryptedHash = enc.Encrypted.fromBase64(encryptedHashBase64);

      final decryptedHash = _encrypter!.decrypt(encryptedHash, iv: iv);
      final String inputPasswordHash = _hashPassword(inputPassword);

      return decryptedHash == inputPasswordHash;
    } catch (e) {
      //print('Error during password verification: $e');
      return false;
    }
  }

  Future<void> deletePassword() async {
    await _storage.delete(key: _notePasswordIVStorageKey);
    await _storage.delete(key: _notePasswordEncryptedHashStorageKey);
    // Optionally, you might want to delete the master encryption key too,
    // but be careful as it would make all encrypted data unrecoverable.
    // await _storage.delete(key: _masterEncryptionKeyStorageKey);
    // _aesKey = null; // Clear the in-memory key
    // _encrypter = null;
    //print('Password IV and encrypted hash deleted from secure storage.');
  }
}