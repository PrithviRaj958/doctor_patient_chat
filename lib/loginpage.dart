import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final auth = FirebaseAuth.instance;

  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final nameController = TextEditingController();
  final specializationController = TextEditingController();
  String selectedRole = 'Patient';

  bool isLogin = true;
  String error = '';
  bool loading = false;

  void handleAuth() async {
    setState(() {
      loading = true;
      error = '';
    });

    try {
      if (isLogin) {
        // Use name to find email
        final name = nameController.text.trim();
        final password = passwordController.text.trim();

        final userSnap = await FirebaseFirestore.instance
            .collection('users')
            .where('name', isEqualTo: name)
            .limit(1)
            .get();

        if (userSnap.docs.isEmpty) {
          throw FirebaseAuthException(
              code: 'user-not-found', message: 'No user found with this name.');
        }

        final email = userSnap.docs.first['email'];
        await auth.signInWithEmailAndPassword(
          email: email,
          password: password,
        );
      } else {
        // Registration
        await auth.createUserWithEmailAndPassword(
          email: emailController.text.trim(),
          password: passwordController.text.trim(),
        );
        final uid = auth.currentUser!.uid;

        final userData = {
          'email': emailController.text.trim(),
          'name': nameController.text.trim(),
          'role': selectedRole,
        };

        if (selectedRole == 'Doctor') {
          userData['specialization'] = specializationController.text.trim();
        }

        await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .set(userData);
      }
    } on FirebaseAuthException catch (e) {
      setState(() => error = e.message ?? 'Authentication error');
    } catch (e) {
      setState(() => error = 'Something went wrong');
    } finally {
      setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.teal[50],
      body: Center(
        child: SingleChildScrollView(
          child: Container(
            width: 320,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 12,
                  offset: Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircleAvatar(
                  radius: 36,
                  backgroundImage: AssetImage('assets/logo.png'),
                  backgroundColor: Colors.transparent,
                ),
                const SizedBox(height: 12),
                Text(
                  isLogin ? 'Login' : 'Register',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.teal,
                  ),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: nameController,
                  decoration: InputDecoration(
                    labelText: 'Name',
                    prefixIcon: Icon(Icons.person_outline),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                if (!isLogin)
                  TextField(
                    controller: emailController,
                    decoration: InputDecoration(
                      labelText: 'Email',
                      prefixIcon: Icon(Icons.email_outlined),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                const SizedBox(height: 12),
                TextField(
                  controller: passwordController,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    prefixIcon: Icon(Icons.lock_outline),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                if (!isLogin) ...[
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: selectedRole,
                    onChanged: (value) => setState(() => selectedRole = value!),
                    decoration: InputDecoration(
                      labelText: 'Select Role',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    items: ['Patient', 'Doctor']
                        .map((role) => DropdownMenuItem(
                              value: role,
                              child: Text(role),
                            ))
                        .toList(),
                  ),
                  if (selectedRole == 'Doctor') ...[
                    const SizedBox(height: 12),
                    TextField(
                      controller: specializationController,
                      decoration: InputDecoration(
                        labelText: 'Specialization',
                        prefixIcon: Icon(Icons.medical_services_outlined),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ],
                ],
                const SizedBox(height: 16),
                if (error.isNotEmpty)
                  Text(
                    error,
                    style: const TextStyle(color: Colors.red, fontSize: 13),
                  ),
                if (loading)
                  const Padding(
                    padding: EdgeInsets.all(8.0),
                    child: CircularProgressIndicator(),
                  )
                else
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: handleAuth,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.teal,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        isLogin ? 'Login' : 'Register',
                        style: const TextStyle(fontSize: 16),
                      ),
                    ),
                  ),
                TextButton(
                  onPressed: () => setState(() => isLogin = !isLogin),
                  child: Text(
                    isLogin
                        ? "Don't have an account? Register"
                        : "Already have an account? Login",
                    style: const TextStyle(color: Colors.teal),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
