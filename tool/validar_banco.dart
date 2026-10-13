import 'dart:convert';
import 'dart:io';

const minPorArchivo = 50, minPorIdioma = 300;
const _tildes = {'á': 'a', 'é': 'e', 'í': 'i', 'ó': 'o', 'ú': 'u', 'ü': 'u', 'ñ': 'n'};

String _norm(String s) => s.toLowerCase().split('').map((c) => _tildes[c] ?? c).join().replaceAll(RegExp(r'\s+'), ' ').trim();

void main(List<String> args) {
  final errores = <String>[], avisos = <String>[];
  final todo = args.isEmpty;
  final archivos = todo
      ? (Directory('assets/preguntas').listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.json')).map((f) => f.path).toList()..sort())
      : args;
  final porIdioma = <String, int>{};
  final textosPorIdioma = <String, Set<String>>{};
  final ids = <String>{};

  for (final ruta in archivos) {
    final partes = ruta.replaceAll('\\', '/').split('/');
    final idioma = partes[partes.length - 2];
    final categoria = partes.last.replaceAll('.json', '');
    void err(String m) => errores.add('$ruta: $m');
    Map<String, dynamic> json;
    try {
      json = jsonDecode(File(ruta).readAsStringSync()) as Map<String, dynamic>;
    } catch (e) {
      err('JSON inválido ($e)');
      continue;
    }
    if (json['idioma'] != idioma) err('idioma "${json['idioma']}" != "$idioma"');
    if (json['categoria'] != categoria) err('categoria "${json['categoria']}" != "$categoria"');
    final lista = (json['preguntas'] as List?) ?? [];
    if (lista.length < minPorArchivo) err('${lista.length} preguntas (mínimo $minPorArchivo)');
    porIdioma[idioma] = (porIdioma[idioma] ?? 0) + lista.length;
    final vistos = textosPorIdioma.putIfAbsent(idioma, () => {});
    final dif = [0, 0, 0];
    final formatoId = RegExp('^$idioma-$categoria-\\d{3}\$');
    for (final p in lista) {
      final id = p['id'];
      void e(String m) => err('$id: $m');
      if (id is! String || !formatoId.hasMatch(id)) {
        e('id con formato inválido (esperado $idioma-$categoria-NNN)');
      } else if (!ids.add(id)) {
        e('id duplicado');
      }
      final texto = p['p'];
      if (texto is! String || texto.isEmpty || texto.length > 120) {
        e('p vacía o >120 caracteres');
      } else if (!vistos.add(_norm(texto))) {
        e('pregunta duplicada');
      }
      final o = p['o'];
      if (o is! List || o.length != 4 || o.any((x) => x is! String || x.trim().isEmpty)) {
        e('o debe tener exactamente 4 opciones no vacías');
      } else {
        if (o.map((x) => _norm(x as String)).toSet().length != 4) e('opciones duplicadas');
        if (o.any((x) => (x as String).length > 32)) e('opción >32 caracteres');
      }
      final r = p['r'];
      if (r is! int || r < 0 || r > 3) e('r fuera de 0..3');
      final d = p['d'];
      if (d is! int || d < 1 || d > 3) {
        e('d fuera de 1..3');
      } else {
        dif[d - 1]++;
      }
    }
    final n = lista.length;
    if (n > 0 && (dif[0] / n < .3 || dif[0] / n > .5 || dif[2] / n < .1 || dif[2] / n > .3)) {
      avisos.add('$ruta: dificultad d1/d2/d3 = ${dif.join('/')} (objetivo 40/40/20 %)');
    }
  }
  if (todo) {
    for (final i in porIdioma.entries) {
      if (i.value < minPorIdioma) errores.add('idioma ${i.key}: ${i.value} preguntas (mínimo $minPorIdioma)');
    }
  }
  for (final a in avisos) {
    stdout.writeln('AVISO $a');
  }
  for (final e in errores) {
    stdout.writeln('ERROR $e');
  }
  stdout.writeln(errores.isEmpty ? 'OK' : '${errores.length} errores');
  exit(errores.isEmpty ? 0 : 1);
}
