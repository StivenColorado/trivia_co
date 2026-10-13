import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config.dart';

/// Resultado de [calcularRacha].
typedef ResultadoRacha = ({int racha, int protectores, bool perdida});

DateTime _dia(String f) => DateTime.utc(int.parse(f.substring(0, 4)), int.parse(f.substring(5, 7)), int.parse(f.substring(8, 10)));

/// Días de calendario entre dos fechas 'AAAA-MM-DD' (b - a).
int diasEntre(String a, String b) => _dia(b).difference(_dia(a)).inDays;

/// Función pura. [ultimo] y [hoy] son fechas 'AAAA-MM-DD' ([ultimo] null si
/// nunca jugó). Mismo día: sin cambios. Ayer: sigue. Faltó exactamente un día
/// y hay protectores: gasta uno y sigue. Si no: racha 0 y [perdida] = true
/// (solo si había racha).
/// No incrementa la racha (eso lo hace [Progreso.completarReto]).
ResultadoRacha calcularRacha(String? ultimo, String hoy, int racha, int protectores) {
  if (ultimo == null) return (racha: 0, protectores: protectores, perdida: false);
  final d = diasEntre(ultimo, hoy);
  if (d <= 1) return (racha: racha, protectores: protectores, perdida: false);
  if (d == 2 && protectores > 0) return (racha: racha, protectores: protectores - 1, perdida: false);
  return (racha: 0, protectores: protectores, perdida: racha > 0);
}

/// Nivel = 1 + floor(sqrt(xp / xpBaseNivel)).
int nivelDeXp(int xp) {
  var n = 0;
  while ((n + 1) * (n + 1) * xpBaseNivel <= xp) {
    n++;
  }
  return 1 + n;
}

/// XP de un acierto con [seguidos] aciertos consecutivos (incluido este).
int xpPorAcierto(int seguidos, {bool reto = false}) =>
    (xpAcierto + (seguidos >= aciertosSeguidosBonus ? xpExtraRacha : 0)) * (reto ? multiplicadorRetoDiario : 1);

/// Regla del intersticial: tras [interPartidasGracia] partidas de gracia,
/// al menos [interCadaPartidas] desde el último y [interSegundosMin] s.
bool puedeMostrarInter(int partidasDesde, int segundosDesde, int totalPartidas) =>
    totalPartidas > interPartidasGracia && partidasDesde >= interCadaPartidas && segundosDesde >= interSegundosMin;

/// Fecha local 'AAAA-MM-DD'.
String fechaDe(DateTime d) => d.toIso8601String().substring(0, 10);

/// Estado persistente del jugador (SharedPreferences). Notifica a la UI.
class Progreso extends ChangeNotifier {
  late SharedPreferences _p;

  /// Carga prefs, migra claves antiguas 'racha' y 'ultimo', y aplica
  /// [calcularRacha] para hoy. Primer arranque: idioma por locale del sistema.
  Future<void> cargar() async {
    _p = await SharedPreferences.getInstance();
    idioma = _p.getString('idioma') ??
        (PlatformDispatcher.instance.locale.languageCode == 'es' ? 'es' : 'en');
    xp = _p.getInt('xp') ?? 0;
    monedas = _p.getInt('monedas') ?? 0;
    racha = _p.getInt('racha') ?? 0;
    protectores = _p.getInt('protectores') ?? 0;
    final u = _p.get('ultimo');
    ultimoReto = u is String && u.length >= 10 ? u.substring(0, 10) : null;
    vistas = {for (final i in _p.getStringList('vistas_$idioma') ?? <String>[]) i};
    partidasTotales = _p.getInt('partidas') ?? 0;
    partidasDesdeInter = _p.getInt('partidas_inter') ?? 0;
    final ui = _p.getString('ultimo_inter');
    ultimoInter = ui == null ? null : DateTime.tryParse(ui);
    retosCompletados = _p.getInt('retos') ?? 0;
    recordatorio = _p.getBool('recordatorio') ?? false;
    _perdida = _p.getInt('racha_perdida') ?? 0;
    _restaurada = _p.getString('restaurada');

    final hoy = fechaDe(DateTime.now());
    final r = calcularRacha(ultimoReto, hoy, racha, protectores);
    if (r.racha != racha || r.protectores != protectores) {
      if (r.perdida && diasEntre(ultimoReto!, hoy) == 2) {
        _perdida = racha;
        await _p.setInt('racha_perdida', _perdida);
      }
      racha = r.racha;
      protectores = r.protectores;
      await _p.setInt('racha', racha);
      await _p.setInt('protectores', protectores);
      if (!r.perdida && ultimoReto != null) {
        // Protector gastado: la racha sigue como si hubiera jugado ayer.
        ultimoReto = fechaDe(DateTime.now().subtract(const Duration(days: 1)));
        await _p.setString('ultimo', ultimoReto!);
      }
    }
    notifyListeners();
  }

  int _perdida = 0;
  String? _restaurada;

  /// 'es' o 'en'.
  String idioma = 'es';

  /// Cambia idioma, persiste y notifica (la UI recarga el banco).
  Future<void> cambiarIdioma(String nuevo) async {
    idioma = nuevo;
    vistas = {for (final i in _p.getStringList('vistas_$nuevo') ?? <String>[]) i};
    await _p.setString('idioma', nuevo);
    notifyListeners();
  }

  int xp = 0;
  int get nivel => nivelDeXp(xp);
  int monedas = 0;
  int racha = 0;
  int protectores = 0;

  /// Fecha del último reto diario completado, o null.
  String? ultimoReto;
  bool get retoHechoHoy => ultimoReto == fechaDe(DateTime.now());

  /// IDs de preguntas ya mostradas (para [elegirNoVistas]).
  Set<String> vistas = {};

  /// Total de partidas jugadas desde la instalación.
  int partidasTotales = 0;

  /// Partidas desde el último intersticial mostrado.
  int partidasDesdeInter = 0;

  /// Fecha-hora del último intersticial, o null.
  DateTime? ultimoInter;

  /// Número correlativo de reto diario completado (para "Trivia #n").
  int retosCompletados = 0;

  /// Racha anterior perdida por un solo día, restaurable con recompensado
  /// (una vez cada [restaurarRachaDiasEspera] días); 0 si no aplica.
  int get rachaRestaurable => puedeRestaurarRacha ? _perdida : 0;
  bool get puedeRestaurarRacha =>
      _perdida > 0 &&
      (_restaurada == null || diasEntre(_restaurada!, fechaDe(DateTime.now())) >= restaurarRachaDiasEspera);

  /// True si el usuario aceptó el recordatorio diario.
  bool recordatorio = false;
  Future<void> fijarRecordatorio(bool activo) async {
    recordatorio = activo;
    await _p.setBool('recordatorio', activo);
    notifyListeners();
  }

  bool categoriaDesbloqueada(String categoria) => (nivelCategoria[categoria] ?? 1) <= nivel;
  bool get contrarrelojDesbloqueado => nivel >= nivelContrarreloj;

  /// Suma XP por acierto: [xpAcierto] (+[xpExtraRacha] si [seguidos] >=
  /// [aciertosSeguidosBonus]), x[multiplicadorRetoDiario] si [reto]. Devuelve
  /// el XP sumado. Persiste.
  Future<int> registrarAcierto({required int seguidos, bool reto = false}) async {
    final n = xpPorAcierto(seguidos, reto: reto);
    xp += n;
    await _p.setInt('xp', xp);
    notifyListeners();
    return n;
  }

  Future<void> sumarMonedas(int n) async {
    monedas += n;
    await _p.setInt('monedas', monedas);
    notifyListeners();
  }

  /// Resta [n] monedas si alcanzan; false si no.
  Future<bool> gastarMonedas(int n) async {
    if (monedas < n) return false;
    await sumarMonedas(-n);
    return true;
  }

  /// Marca preguntas como vistas.
  Future<void> marcarVistas(Iterable<String> ids) async {
    vistas.addAll(ids);
    await _p.setStringList('vistas_$idioma', vistas.toList());
  }

  /// Cuenta una partida terminada (totales y desde intersticial).
  Future<void> registrarPartida() async {
    partidasTotales++;
    partidasDesdeInter++;
    await _p.setInt('partidas', partidasTotales);
    await _p.setInt('partidas_inter', partidasDesdeInter);
    notifyListeners();
  }

  /// Anota que se mostró un intersticial ahora (reinicia contadores).
  Future<void> registrarInter() async {
    partidasDesdeInter = 0;
    ultimoInter = DateTime.now();
    await _p.setInt('partidas_inter', 0);
    await _p.setString('ultimo_inter', ultimoInter!.toIso8601String());
  }

  /// Completa el reto de hoy: suma racha, [monedasReto] + min([monedasPorRacha]
  /// * racha, [monedasRachaMax]), fija [ultimoReto], incrementa
  /// [retosCompletados]. Devuelve monedas ganadas. No hace nada si ya hecho.
  Future<int> completarReto() async {
    if (retoHechoHoy) return 0;
    racha++;
    ultimoReto = fechaDe(DateTime.now());
    retosCompletados++;
    _perdida = 0;
    final ganadas = monedasReto + (monedasPorRacha * racha).clamp(0, monedasRachaMax);
    monedas += ganadas;
    await _p.setInt('racha', racha);
    await _p.setString('ultimo', ultimoReto!);
    await _p.setInt('retos', retosCompletados);
    await _p.setInt('racha_perdida', 0);
    await _p.setInt('monedas', monedas);
    notifyListeners();
    return ganadas;
  }

  /// Compra un protector de racha ([precioProtector], máx [protectoresMax]).
  Future<bool> comprarProtector() async {
    if (protectores >= protectoresMax || !await gastarMonedas(precioProtector)) return false;
    protectores++;
    await _p.setInt('protectores', protectores);
    notifyListeners();
    return true;
  }

  /// Restaura la racha perdida (tras ver recompensado). Ver [puedeRestaurarRacha].
  Future<void> restaurarRacha() async {
    if (!puedeRestaurarRacha) return;
    racha = _perdida;
    _perdida = 0;
    _restaurada = fechaDe(DateTime.now());
    ultimoReto = fechaDe(DateTime.now().subtract(const Duration(days: 1)));
    await _p.setInt('racha', racha);
    await _p.setInt('racha_perdida', 0);
    await _p.setString('restaurada', _restaurada!);
    await _p.setString('ultimo', ultimoReto!);
    notifyListeners();
  }
}

final progreso = Progreso();
