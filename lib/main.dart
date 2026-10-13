import 'package:flutter/material.dart';

import 'modelo/pregunta.dart';
import 'modelo/progreso.dart';
import 'pantallas/inicio.dart';
import 'servicios/analitica.dart';
import 'servicios/anuncios.dart';
import 'servicios/notificaciones.dart';
import 'textos.dart';

/// Banco de preguntas del idioma activo.
List<Pregunta> banco = [];

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await progreso.cargar();
  idiomaTextos = progreso.idioma;
  await Analitica.iniciar();
  await Anuncios.iniciar();
  banco = await cargarBanco(progreso.idioma);
  await Notificaciones.iniciar();
  if (progreso.recordatorio) await Notificaciones.reprogramar(racha: progreso.racha);
  runApp(const App());
}

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: progreso,
        builder: (_, __) {
          idiomaTextos = progreso.idioma;
          return MaterialApp(
            title: 'Trivia',
            debugShowCheckedModeBanner: false,
            theme: ThemeData(
              useMaterial3: true,
              colorSchemeSeed: const Color(0xFF6C3CE9),
              scaffoldBackgroundColor: const Color(0xFFF5F2FF),
            ),
            home: const Inicio(),
          );
        },
      );
}
