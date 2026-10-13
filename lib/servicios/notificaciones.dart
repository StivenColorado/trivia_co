import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz_datos;
import 'package:timezone/timezone.dart' as tz;

import '../config.dart';
import '../textos.dart';

// Respaldo si textos.dart aún no define las claves notif_*.
const _respaldo = {
  'es': {
    'notif_1_titulo': 'Tu reto diario te espera',
    'notif_1_cuerpo': 'Mantén tu racha de {racha} días. ¡Solo toma un minuto!',
    'notif_2_titulo': '¿Cuánto sabes hoy?',
    'notif_2_cuerpo': 'Nuevas preguntas listas para ti.',
    'notif_3_titulo': 'Te extrañamos',
    'notif_3_cuerpo': 'Vuelve y retoma tu racha con el reto de hoy.',
    'canal_nombre': 'Recordatorios',
  },
  'en': {
    'notif_1_titulo': 'Your daily challenge awaits',
    'notif_1_cuerpo': 'Keep your {racha}-day streak alive. It only takes a minute!',
    'notif_2_titulo': 'How much do you know today?',
    'notif_2_cuerpo': 'Fresh questions are ready for you.',
    'notif_3_titulo': 'We miss you',
    'notif_3_cuerpo': 'Come back and restart your streak with today\'s challenge.',
    'canal_nombre': 'Reminders',
  },
};

String _texto(String clave, int racha) {
  final args = {'racha': racha};
  final v = t(clave, args);
  if (v != clave) return v;
  final mapa = _respaldo[idiomaTextos] ?? _respaldo['en']!;
  return (mapa[clave] ?? clave).replaceAll('{racha}', '$racha');
}

class Notificaciones {
  static final _plugin = FlutterLocalNotificationsPlugin();

  /// Inicializa plugin y zona horaria (tz.initializeTimeZones, instantes
  /// absolutos en UTC; sin flutter_timezone). Llamar al arrancar.
  static Future<void> iniciar() async {
    tz_datos.initializeTimeZones();
    await _plugin.initialize(const InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    ));
  }

  /// Pide POST_NOTIFICATIONS (Android 13+). True si concedido.
  static Future<bool> pedirPermiso() async {
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    return await android?.requestNotificationsPermission() ?? false;
  }

  /// Cancela los pendientes y programa hasta [recordatoriosMax] avisos
  /// puntuales a las [horaRecordatorio]:00 locales (D+1..D+3) con textos
  /// distintos (claves 'notif_1_*'..'notif_3_*' de textos.dart; [racha] para
  /// personalizar). inexactAllowWhileIdle. Llamar al abrir la app y al
  /// completar el reto, solo si progreso.recordatorio.
  static Future<void> reprogramar({required int racha}) async {
    await cancelar();
    final hoy = DateTime.now();
    final detalles = NotificationDetails(
      android: AndroidNotificationDetails(
        'recordatorios',
        _texto('canal_nombre', racha),
      ),
    );
    // Siempre desde mañana: el día ya jugado nunca recibe aviso.
    for (var i = 1; i <= recordatoriosMax; i++) {
      final local = DateTime(hoy.year, hoy.month, hoy.day + i, horaRecordatorio);
      final k = ((i - 1) % 3) + 1;
      await _plugin.zonedSchedule(
        i,
        _texto('notif_${k}_titulo', racha),
        _texto('notif_${k}_cuerpo', racha),
        tz.TZDateTime.from(local, tz.UTC),
        detalles,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      );
    }
  }

  static Future<void> cancelar() => _plugin.cancelAll();
}
