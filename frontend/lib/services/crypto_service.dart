import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:sodium_libs/sodium_libs.dart';

/// Serviço para criptografia de mensagens usando NaCl (Curve25519).
class CryptoService {
  // Inicialização do Sodium
  static late Sodium _sodium;
  static bool _initialized = false;
  
  // Construtor
  CryptoService() {
    _initializeSodium();
  }
  
  /// Inicializa a biblioteca Sodium.
  Future<void> _initializeSodium() async {
    if (_initialized) return;
    
    try {
      _sodium = await SodiumInit.init();
      _initialized = true;
      debugPrint('Sodium inicializado com sucesso');
    } catch (e) {
      debugPrint('Erro ao inicializar Sodium: $e');
    }
  }
  
  /// Gera um par de chaves para criptografia assimétrica.
  Future<KeyPair> generateKeyPair() async {
    await _ensureInitialized();
    
    try {
      // Gerar par de chaves Curve25519
      final keyPair = _sodium.crypto.box.keyPair();
      
      // Converter para Base64 para armazenamento
      final privateKeyB64 = base64Encode(keyPair.secretKey);
      final publicKeyB64 = base64Encode(keyPair.publicKey);
      
      return KeyPair(
        privateKey: privateKeyB64,
        publicKey: publicKeyB64,
      );
    } catch (e) {
      debugPrint('Erro ao gerar par de chaves: $e');
      rethrow;
    }
  }
  
  /// Criptografa uma mensagem usando criptografia assimétrica.
  Future<String> encrypt({
    required String plaintext,
    required String senderPrivateKey,
    required String recipientPublicKey,
  }) async {
    await _ensureInitialized();
    
    try {
      // Decodificar chaves de Base64
      final privateKey = base64Decode(senderPrivateKey);
      final publicKey = base64Decode(recipientPublicKey);
      
      // Converter plaintext para bytes
      final messageBytes = utf8.encode(plaintext);
      
      // Gerar nonce aleatório
      final nonce = _sodium.randombytes.buf(_sodium.crypto.box.nonceBytes);
      
      // Criptografar mensagem
      final ciphertext = _sodium.crypto.box.easy(
        message: messageBytes,
        nonce: nonce,
        publicKey: publicKey,
        secretKey: privateKey,
      );
      
      // Combinar nonce e ciphertext para transporte
      final combined = Uint8List(nonce.length + ciphertext.length);
      combined.setRange(0, nonce.length, nonce);
      combined.setRange(nonce.length, combined.length, ciphertext);
      
      // Converter para Base64 para transporte
      return base64Encode(combined);
    } catch (e) {
      debugPrint('Erro ao criptografar mensagem: $e');
      rethrow;
    }
  }
  
  /// Descriptografa uma mensagem usando criptografia assimétrica.
  Future<String> decrypt({
    required String ciphertext,
    required String recipientPrivateKey,
    required String senderPublicKey,
  }) async {
    await _ensureInitialized();
    
    try {
      // Decodificar chaves e ciphertext de Base64
      final privateKey = base64Decode(recipientPrivateKey);
      final publicKey = base64Decode(senderPublicKey);
      final combined = base64Decode(ciphertext);
      
      // Extrair nonce e ciphertext
      final nonceBytes = _sodium.crypto.box.nonceBytes;
      final nonce = combined.sublist(0, nonceBytes);
      final encryptedMessage = combined.sublist(nonceBytes);
      
      // Descriptografar mensagem
      final decrypted = _sodium.crypto.box.openEasy(
        cipherText: encryptedMessage,
        nonce: nonce,
        publicKey: publicKey,
        secretKey: privateKey,
      );
      
      // Converter para string
      return utf8.decode(decrypted);
    } catch (e) {
      debugPrint('Erro ao descriptografar mensagem: $e');
      rethrow;
    }
  }
  
  /// Gera uma assinatura para autenticação de mensagem.
  Future<String> sign({
    required String message,
    required String privateKey,
  }) async {
    await _ensureInitialized();
    
    try {
      // Decodificar chave privada de Base64
      final keyBytes = base64Decode(privateKey);
      
      // Converter mensagem para bytes
      final messageBytes = utf8.encode(message);
      
      // Gerar assinatura
      final signature = _sodium.crypto.sign.detached(
        message: messageBytes,
        secretKey: keyBytes,
      );
      
      // Converter para Base64
      return base64Encode(signature);
    } catch (e) {
      debugPrint('Erro ao gerar assinatura: $e');
      rethrow;
    }
  }
  
  /// Verifica a autenticidade de uma mensagem assinada.
  Future<bool> verify({
    required String message,
    required String signature,
    required String publicKey,
  }) async {
    await _ensureInitialized();
    
    try {
      // Decodificar chave pública e assinatura de Base64
      final keyBytes = base64Decode(publicKey);
      final signatureBytes = base64Decode(signature);
      
      // Converter mensagem para bytes
      final messageBytes = utf8.encode(message);
      
      // Verificar assinatura
      return _sodium.crypto.sign.verifyDetached(
        message: messageBytes,
        signature: signatureBytes,
        publicKey: keyBytes,
      );
    } catch (e) {
      debugPrint('Erro ao verificar assinatura: $e');
      return false;
    }
  }
  
  /// Criptografa dados simétricos com uma chave compartilhada.
  Future<String> encryptSymmetric({
    required String plaintext,
    required String key,
  }) async {
    await _ensureInitialized();
    
    try {
      // Decodificar chave de Base64
      final keyBytes = base64Decode(key);
      
      // Converter plaintext para bytes
      final messageBytes = utf8.encode(plaintext);
      
      // Gerar nonce aleatório
      final nonce = _sodium.randombytes.buf(_sodium.crypto.secretBox.nonceBytes);
      
      // Criptografar mensagem
      final ciphertext = _sodium.crypto.secretBox.easy(
        message: messageBytes,
        nonce: nonce,
        key: keyBytes,
      );
      
      // Combinar nonce e ciphertext para transporte
      final combined = Uint8List(nonce.length + ciphertext.length);
      combined.setRange(0, nonce.length, nonce);
      combined.setRange(nonce.length, combined.length, ciphertext);
      
      // Converter para Base64 para transporte
      return base64Encode(combined);
    } catch (e) {
      debugPrint('Erro ao criptografar dados simétricos: $e');
      rethrow;
    }
  }
  
  /// Descriptografa dados simétricos com uma chave compartilhada.
  Future<String> decryptSymmetric({
    required String ciphertext,
    required String key,
  }) async {
    await _ensureInitialized();
    
    try {
      // Decodificar chave e ciphertext de Base64
      final keyBytes = base64Decode(key);
      final combined = base64Decode(ciphertext);
      
      // Extrair nonce e ciphertext
      final nonceBytes = _sodium.crypto.secretBox.nonceBytes;
      final nonce = combined.sublist(0, nonceBytes);
      final encryptedMessage = combined.sublist(nonceBytes);
      
      // Descriptografar mensagem
      final decrypted = _sodium.crypto.secretBox.openEasy(
        cipherText: encryptedMessage,
        nonce: nonce,
        key: keyBytes,
      );
      
      // Converter para string
      return utf8.decode(decrypted);
    } catch (e) {
      debugPrint('Erro ao descriptografar dados simétricos: $e');
      rethrow;
    }
  }
  
  /// Gera uma chave simétrica aleatória.
  Future<String> generateSymmetricKey() async {
    await _ensureInitialized();
    
    try {
      // Gerar chave aleatória
      final key = _sodium.randombytes.buf(_sodium.crypto.secretBox.keyBytes);
      
      // Converter para Base64
      return base64Encode(key);
    } catch (e) {
      debugPrint('Erro ao gerar chave simétrica: $e');
      rethrow;
    }
  }
  
  /// Deriva uma chave simétrica a partir de uma senha.
  Future<String> deriveKeyFromPassword({
    required String password,
    required String salt,
  }) async {
    await _ensureInitialized();
    
    try {
      // Converter senha e salt para bytes
      final passwordBytes = utf8.encode(password);
      final saltBytes = base64Decode(salt);
      
      // Derivar chave
      final key = _sodium.crypto.pwhash.str(
        passwordBytes,
        opsLimit: _sodium.crypto.pwhash.opsLimitSensitive,
        memLimit: _sodium.crypto.pwhash.memLimitSensitive,
      );
      
      // Converter para Base64
      return base64Encode(key);
    } catch (e) {
      debugPrint('Erro ao derivar chave de senha: $e');
      rethrow;
    }
  }
  
  /// Gera uma salt aleatório para derivação de chave.
  Future<String> generateSalt() async {
    await _ensureInitialized();
    
    try {
      // Gerar salt aleatório
      final salt = _sodium.randombytes.buf(_sodium.crypto.pwhash.saltBytes);
      
      // Converter para Base64
      return base64Encode(salt);
    } catch (e) {
      debugPrint('Erro ao gerar salt: $e');
      rethrow;
    }
  }
  
  /// Garante que o Sodium está inicializado.
  Future<void> _ensureInitialized() async {
    if (!_initialized) {
      await _initializeSodium();
    }
  }
}

/// Representação de um par de chaves (pública/privada).
class KeyPair {
  final String privateKey;
  final String publicKey;
  
  KeyPair({
    required this.privateKey,
    required this.publicKey,
  });
  
  @override
  String toString() {
    return 'KeyPair{publicKey: $publicKey}';
  }
}