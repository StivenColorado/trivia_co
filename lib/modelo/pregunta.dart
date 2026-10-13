import 'dart:convert';
import 'dart:math';

import 'package:flutter/services.dart';

import '../config.dart';

class Pregunta {
  final String id, texto, categoria;
  final List<String> opciones;

  /// Índice de la opción correcta en [opciones].
  final int correcta;

  /// 1..3
  final int dificultad;

  const Pregunta(this.id, this.texto, this.opciones, this.correcta, this.dificultad, this.categoria);

  factory Pregunta.fromJson(Map<String, dynamic> j, String categoria) => Pregunta(
        j['id'] as String,
        j['p'] as String,
        List<String>.from(j['o'] as List),
        j['r'] as int,
        j['d'] as int,
        categoria,
      );

  /// Copia con opciones barajadas y [correcta] actualizada.
  Pregunta barajada(Random azar) {
    final orden = List.generate(opciones.length, (i) => i)..shuffle(azar);
    return Pregunta(id, texto, [for (final i in orden) opciones[i]], orden.indexOf(correcta), dificultad, categoria);
  }
}

/// Carga todas las categorías del idioma desde assets/preguntas/(idioma)/.
Future<List<Pregunta>> cargarBanco(String idioma) async {
  final banco = <Pregunta>[];
  for (final cat in categoriasPorIdioma[idioma] ?? categoriasPorIdioma['en']!) {
    final json = jsonDecode(await rootBundle.loadString('assets/preguntas/$idioma/$cat.json')) as Map<String, dynamic>;
    for (final p in json['preguntas'] as List) {
      banco.add(Pregunta.fromJson(p as Map<String, dynamic>, cat));
    }
  }
  return banco;
}

/// Elige hasta [n] preguntas al azar priorizando las no vistas; si faltan,
/// completa con vistas. Devuelve las opciones ya barajadas.
List<Pregunta> elegirNoVistas(List<Pregunta> banco, Set<String> vistas, int n, [Random? azar]) {
  azar ??= Random();
  final nuevas = banco.where((p) => !vistas.contains(p.id)).toList()..shuffle(azar);
  final viejas = banco.where((p) => vistas.contains(p.id)).toList()..shuffle(azar);
  return [...nuevas, ...viejas].take(n).map((p) => p.barajada(azar!)).toList();
}

/// Reto diario: mismas [preguntasPorPartida] preguntas para una fecha e idioma
/// (sembrado por fecha 'AAAA-MM-DD' + idioma). Orden de opciones también fijo.
List<Pregunta> retoDelDia(List<Pregunta> banco, String fecha, String idioma) {
  final ordenado = [...banco]..sort((a, b) => a.id.compareTo(b.id));
  final azar = Random((fecha + idioma).codeUnits.fold<int>(7, (h, c) => (h * 31 + c) & 0x7fffffff));
  ordenado.shuffle(azar);
  return ordenado.take(preguntasPorPartida).map((p) => p.barajada(azar)).toList();
}
