import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'screens/registration_screen.dart';

void main() async {
  WidgetFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(); //inicia antes de rodar o app
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'App Cadastro',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const RegistrationScreen(),
    );
  }
}