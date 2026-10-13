import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _claveInstalacion = 'analitica_instalacion';
const _claveDias = 'analitica_dias';

String _fecha(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

class Analitica {
  static String? _instalacion;
  static List<String> _dias = [];

  /// Registra instalación (fecha) y día activo en prefs. Llamar al arrancar.
  static Future<void> iniciar() async {
    final prefs = await SharedPreferences.getInstance();
    final hoy = _fecha(DateTime.now());
    _instalacion = prefs.getString(_claveInstalacion);
    if (_instalacion == null) {
      _instalacion = hoy;
      await prefs.setString(_claveInstalacion, hoy);
    }
    _dias = prefs.getStringList(_claveDias) ?? [];
    if (!_dias.contains(hoy)) {
      _dias = [..._dias, hoy];
      await prefs.setStringList(_claveDias, _dias);
    }
  }

  /// debugPrint del evento (Firebase se difiere). Ej: 'partida_fin',
  /// {'modo': 'clasico', 'aciertos': 8}.
  static void evento(String nombre, [Map<String, Object?> params = const {}]) {
    debugPrint('[analitica] $nombre $params');
  }

  /// Fecha de instalación 'AAAA-MM-DD', o null antes de [iniciar].
  static String? get fechaInstalacion => _instalacion;

  /// Número de días distintos en que se abrió la app.
  static int get diasActivos => _dias.length;
}
