// lib/services/auth_service.dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:ceriv_app/models/user_model.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Obtém o usuário atual
  User? get currentUser => _auth.currentUser;

  // Stream de alterações do estado de autenticação
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Registro com e-mail e senha
  Future<UserCredential> registerWithEmailAndPassword(
      String email, String password, UserModel userData) async {
    try {
      // Criar usuário no Firebase Authentication
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Adicionar dados do usuário ao Firestore
      await _firestore.collection('users').doc(userCredential.user!.uid).set(
            userData.copyWith(id: userCredential.user!.uid).toMap(),
          );

      return userCredential;
    } catch (e) {
      rethrow;
    }
  }

  // Login com e-mail e senha
  Future<UserCredential> signInWithEmailAndPassword(
      String email, String password) async {
    try {
      return await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
    } catch (e) {
      rethrow;
    }
  }

  // Login com CPF (usaremos e-mail por trás dos panos)
  Future<UserCredential> signInWithCPF(String cpf, String password) async {
    try {
      // Buscar o usuário pelo CPF no Firestore
      final querySnapshot = await _firestore
          .collection('users')
          .where('cpf', isEqualTo: cpf)
          .limit(1)
          .get();

      if (querySnapshot.docs.isEmpty) {
        throw FirebaseAuthException(
          code: 'user-not-found',
          message: 'Usuário não encontrado com este CPF.',
        );
      }

      // Obter o e-mail associado ao CPF
      final email = querySnapshot.docs.first.get('email') as String;

      // Fazer login usando o e-mail e senha
      return await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
    } catch (e) {
      rethrow;
    }
  }

  // Recuperação de senha
  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } catch (e) {
      rethrow;
    }
  }

  // Recuperação de senha por CPF
  Future<void> sendPasswordResetEmailByCPF(String cpf) async {
    try {
      // Buscar o usuário pelo CPF no Firestore
      final querySnapshot = await _firestore
          .collection('users')
          .where('cpf', isEqualTo: cpf)
          .limit(1)
          .get();

      if (querySnapshot.docs.isEmpty) {
        throw FirebaseAuthException(
          code: 'user-not-found',
          message: 'Usuário não encontrado com este CPF.',
        );
      }

      // Obter o e-mail associado ao CPF
      final email = querySnapshot.docs.first.get('email') as String;

      // Enviar e-mail de recuperação de senha
      await _auth.sendPasswordResetEmail(email: email);
    } catch (e) {
      rethrow;
    }
  }

  // Logout
  Future<void> signOut() async {
    await _auth.signOut();
  }

  // Obter dados do usuário atual do Firestore
  Future<UserModel?> getCurrentUserData() async {
    try {
      if (currentUser == null) return null;

      final doc =
          await _firestore.collection('users').doc(currentUser!.uid).get();

      if (!doc.exists) return null;

      return UserModel.fromMap(doc.data()!);
    } catch (e) {
      return null;
    }
  }

  // Atualizar dados do usuário
  Future<void> updateUserData(UserModel userData) async {
    try {
      if (currentUser == null) throw Exception('Nenhum usuário autenticado.');

      await _firestore
          .collection('users')
          .doc(currentUser!.uid)
          .update(userData.toMap());
    } catch (e) {
      rethrow;
    }
  }
}