import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../main.dart';
import '../modelo/pregunta.dart';
import '../modelo/progreso.dart';
import '../servicios/anuncios.dart';
import '../servicios/notificaciones.dart';
import '../textos.dart';

class Ajustes extends StatelessWidget {
  const Ajustes({super.key});

  Future<void> _idioma(String nuevo) async {
    await progreso.cambiarIdioma(nuevo);
    banco = await cargarBanco(nuevo);
  }

  Future<void> _recordatorio(BuildContext c, bool on) async {
    if (!on) {
      await Notificaciones.cancelar();
      return progreso.fijarRecordatorio(false);
    }
    if (await Notificaciones.pedirPermiso()) {
      await progreso.fijarRecordatorio(true);
      await Notificaciones.reprogramar(racha: progreso.racha);
    } else if (c.mounted) {
      ScaffoldMessenger.of(c).showSnackBar(SnackBar(content: Text(t('permiso_denegado'))));
    }
  }

  Future<void> _politica(BuildContext c) async {
    final texto = await rootBundle.loadString('assets/privacidad_${progreso.idioma}.txt');
    if (!c.mounted) return;
    showDialog(
      context: c,
      builder: (_) => AlertDialog(
        title: Text(t('politica')),
        content: SingleChildScrollView(child: Text(texto)),
        actions: [TextButton(onPressed: () => Navigator.pop(c), child: Text(t('cerrar')))],
      ),
    );
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: progreso,
        builder: (context, _) => Scaffold(
          appBar: AppBar(title: Text(t('ajustes'))),
          body: ListView(children: [
            ListTile(
              title: Text(t('idioma')),
              trailing: SegmentedButton<String>(
                showSelectedIcon: false,
                segments: [
                  ButtonSegment(value: 'es', label: Text(t('idioma_es'))),
                  ButtonSegment(value: 'en', label: Text(t('idioma_en'))),
                ],
                selected: {progreso.idioma},
                onSelectionChanged: (s) => _idioma(s.first),
              ),
            ),
            SwitchListTile(
              title: Text(t('recordatorio')),
              subtitle: Text(t('recordatorio_sub')),
              value: progreso.recordatorio,
              onChanged: (v) => _recordatorio(context, v),
            ),
            FutureBuilder<bool>(
              future: Anuncios.privacidadRequerida(),
              builder: (_, s) => s.data == true
                  ? ListTile(
                      title: Text(t('privacidad_opciones')),
                      leading: const Icon(Icons.privacy_tip_outlined),
                      onTap: Anuncios.mostrarOpcionesPrivacidad,
                    )
                  : const SizedBox.shrink(),
            ),
            ListTile(
              title: Text(t('politica')),
              leading: const Icon(Icons.description_outlined),
              onTap: () => _politica(context),
            ),
          ]),
        ),
      );
}
