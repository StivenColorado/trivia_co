import 'dart:async';

import 'package:flutter/material.dart';

import '../config.dart';
import '../main.dart';
import '../modelo/pregunta.dart';
import '../modelo/progreso.dart';
import '../servicios/analitica.dart';
import '../servicios/anuncios.dart';
import '../servicios/notificaciones.dart';
import '../textos.dart';
import 'resultado.dart';

enum Modo { clasico, diario, contrarreloj }

class Juego extends StatefulWidget {
  final Modo modo;
  final String? categoria;
  const Juego({super.key, required this.modo, this.categoria});

  @override
  State<Juego> createState() => _JuegoState();
}

class _JuegoState extends State<Juego> {
  late final List<Pregunta> _preguntas;
  final _grilla = <bool>[];
  final _ocultas = <int>{};
  Timer? _timer;
  int _i = 0, _vidas = vidasClasico, _aciertos = 0, _seguidos = 0, _xp = 0, _monedas = 0;
  int _segundos = segundosContrarreloj;
  int? _elegida;
  bool _gratisUsado = false, _vidaGratisUsada = false, _terminando = false;

  Modo get _modo => widget.modo;

  @override
  void initState() {
    super.initState();
    _preguntas = switch (_modo) {
      Modo.diario => retoDelDia(banco, fechaDe(DateTime.now()), progreso.idioma),
      Modo.clasico => elegirNoVistas(
          banco.where((p) => p.categoria == widget.categoria).toList(), progreso.vistas, preguntasPorPartida),
      Modo.contrarreloj => elegirNoVistas(
          banco.where((p) => progreso.categoriaDesbloqueada(p.categoria)).toList(), progreso.vistas, 200),
    };
    if (_modo == Modo.contrarreloj) {
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        setState(() => _segundos--);
        if (_segundos <= 0) _fin();
      });
    }
    if (_preguntas.isEmpty) WidgetsBinding.instance.addPostFrameCallback((_) => _fin());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _responder(int o) async {
    if (_elegida != null || _terminando) return;
    final p = _preguntas[_i];
    final ok = o == p.correcta;
    setState(() => _elegida = o);
    _grilla.add(ok);
    progreso.marcarVistas([p.id]);
    if (ok) {
      _aciertos++;
      _seguidos++;
      _monedas += monedasAcierto;
      _xp += xpPorAcierto(_seguidos, reto: _modo == Modo.diario);
      progreso.registrarAcierto(seguidos: _seguidos, reto: _modo == Modo.diario);
      progreso.sumarMonedas(monedasAcierto);
    } else {
      _seguidos = 0;
      if (_modo == Modo.clasico) _vidas--;
      if (_modo == Modo.contrarreloj) _segundos -= penalizacionContrarreloj;
    }
    await Future.delayed(const Duration(milliseconds: 900));
    if (!mounted || _terminando) return;
    if (_modo == Modo.contrarreloj && _segundos <= 0) return _fin();
    if (_modo == Modo.clasico && _vidas <= 0) return _sinVidas();
    _avanzar();
  }

  void _avanzar() {
    if (_i + 1 >= _preguntas.length) {
      _fin();
      return;
    }
    setState(() {
      _i++;
      _elegida = null;
      _ocultas.clear();
    });
  }

  Future<void> _sinVidas() async {
    final video = !_vidaGratisUsada && Anuncios.recompensadoListo;
    final paga = progreso.monedas >= precioVidaExtra;
    if (!video && !paga) return _fin();
    final r = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (c) => AlertDialog(
        title: Text(t('sin_vidas')),
        content: Text(t('sin_vidas_texto')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, 'fin'), child: Text(t('terminar'))),
          if (paga)
            TextButton(
                onPressed: () => Navigator.pop(c, 'monedas'),
                child: Text(t('vida_monedas', {'c': precioVidaExtra}))),
          if (video)
            FilledButton(onPressed: () => Navigator.pop(c, 'video'), child: Text(t('vida_video'))),
        ],
      ),
    );
    var ok = false;
    if (r == 'video') {
      ok = await Anuncios.mostrarRecompensado();
      _vidaGratisUsada = ok;
    } else if (r == 'monedas') {
      ok = await progreso.gastarMonedas(precioVidaExtra);
    }
    if (!mounted) return;
    if (!ok) return _fin();
    _vidas = 1;
    _avanzar();
  }

  Future<void> _cincuenta() async {
    if (_elegida != null || _ocultas.isNotEmpty) return;
    if (!_gratisUsado && Anuncios.recompensadoListo) {
      if (!await Anuncios.mostrarRecompensado()) return;
      _gratisUsado = true;
    } else if (!await progreso.gastarMonedas(precioCincuenta)) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t('sin_monedas'))));
      return;
    }
    if (!mounted || _elegida != null) return;
    final malas = [0, 1, 2, 3]..remove(_preguntas[_i].correcta);
    setState(() => _ocultas.addAll((malas..shuffle()).take(2)));
  }

  Future<void> _fin() async {
    if (_terminando) return;
    _terminando = true;
    _timer?.cancel();
    await progreso.registrarPartida();
    var bonus = 0;
    if (_modo == Modo.diario) {
      bonus = await progreso.completarReto();
      if (progreso.retosCompletados == 1 && !progreso.recordatorio && mounted) await _optin();
      if (progreso.recordatorio) await Notificaciones.reprogramar(racha: progreso.racha);
    }
    Analitica.evento('partida_fin', {'modo': _modo.name, 'aciertos': _aciertos, 'total': _grilla.length});
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => Resultado(
          modo: _modo,
          aciertos: _aciertos,
          total: _modo == Modo.contrarreloj ? _grilla.length : _preguntas.length,
          grilla: _grilla,
          xp: _xp,
          monedas: _monedas + bonus,
        ),
      ),
    );
  }

  Future<void> _optin() async {
    final si = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(t('optin_titulo')),
        content: Text(t('optin_texto')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: Text(t('optin_no'))),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: Text(t('optin_si'))),
        ],
      ),
    );
    if (si == true && await Notificaciones.pedirPermiso()) await progreso.fijarRecordatorio(true);
  }

  Future<void> _salir() async {
    final si = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(t('salir_titulo')),
        content: Text(t('salir_texto')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: Text(t('seguir'))),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: Text(t('salir'))),
        ],
      ),
    );
    if (si == true && mounted) Navigator.pop(context);
  }

  Color? _color(int o) {
    if (_elegida == null) return null;
    if (o == _preguntas[_i].correcta) return Colors.green;
    return o == _elegida ? Colors.red : null;
  }

  @override
  Widget build(BuildContext context) {
    if (_preguntas.isEmpty) return const Scaffold();
    final p = _preguntas[_i];
    final contra = _modo == Modo.contrarreloj;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (pop, _) {
        if (!pop) _salir();
      },
      child: Scaffold(
        body: SafeArea(
          child: Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 4, 16, 0),
              child: Row(children: [
                IconButton(icon: const Icon(Icons.close), onPressed: _salir),
                Expanded(
                  child: contra
                      ? Text('⏱️ ${_segundos < 0 ? 0 : _segundos} s',
                          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold))
                      : Text(t('pregunta', {'i': _i + 1, 'n': _preguntas.length})),
                ),
                if (_modo == Modo.clasico)
                  Text('❤️' * (_vidas < 0 ? 0 : _vidas), style: const TextStyle(fontSize: 20)),
              ]),
            ),
            if (!contra)
              LinearProgressIndicator(value: (_i + 1) / _preguntas.length, minHeight: 6)
            else
              LinearProgressIndicator(value: (_segundos < 0 ? 0 : _segundos) / segundosContrarreloj, minHeight: 6),
            Expanded(
              child: ListView(padding: const EdgeInsets.all(16), children: [
                Card(
                  color: const Color(0xFF6C3CE9),
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(p.texto,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w600)),
                  ),
                ),
                const SizedBox(height: 8),
                for (var o = 0; o < p.opciones.length; o++)
                  if (!_ocultas.contains(o))
                    Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: FilledButton.tonal(
                        style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(56),
                          backgroundColor: _color(o),
                          foregroundColor: _color(o) == null ? null : Colors.white,
                        ),
                        onPressed: () => _responder(o),
                        child: Text(p.opciones[o], textAlign: TextAlign.center, style: const TextStyle(fontSize: 16)),
                      ),
                    ),
                const SizedBox(height: 12),
                Center(
                  child: OutlinedButton(
                    onPressed: _elegida == null && _ocultas.isEmpty ? _cincuenta : null,
                    child: Text(!_gratisUsado && Anuncios.recompensadoListo
                        ? '${t('cincuenta')} · ${t('gratis')} 🎬'
                        : '${t('cincuenta')} · $precioCincuenta 🪙'),
                  ),
                ),
              ]),
            ),
            if (!contra) Padding(padding: const EdgeInsets.only(top: 16), child: Anuncios.banner()),
          ]),
        ),
      ),
    );
  }
}
