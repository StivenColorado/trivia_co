import 'package:flutter/material.dart';

import '../config.dart';
import '../modelo/progreso.dart';
import '../servicios/anuncios.dart';
import '../textos.dart';
import 'ajustes.dart';
import 'juego.dart';

const _iconos = {
  'cultura': '🎭',
  'geografia': '🌍',
  'colombia': '🇨🇴',
  'ciencia': '🔬',
  'historia': '🏛️',
  'deportes': '⚽',
  'entretenimiento': '🎬',
};
const _colores = {
  'cultura': Color(0xFFE91E63),
  'geografia': Color(0xFF009688),
  'colombia': Color(0xFFF9A825),
  'ciencia': Color(0xFF2196F3),
  'historia': Color(0xFF8D6E63),
  'deportes': Color(0xFF43A047),
  'entretenimiento': Color(0xFFFF5722),
};

class Inicio extends StatelessWidget {
  const Inicio({super.key});

  void _jugar(BuildContext c, Modo m, [String? cat]) =>
      Navigator.push(c, MaterialPageRoute(builder: (_) => Juego(modo: m, categoria: cat)));

  void _aviso(BuildContext c, String msg) =>
      ScaffoldMessenger.of(c).showSnackBar(SnackBar(content: Text(msg)));

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: progreso,
        builder: (context, _) {
          final cats = categoriasPorIdioma[progreso.idioma] ?? categoriasPorIdioma['en']!;
          return Scaffold(
            body: SafeArea(
              child: ListView(padding: const EdgeInsets.all(16), children: [
                _cabecera(context),
                const SizedBox(height: 16),
                _tarjeta(
                  colores: const [Color(0xFFFF6F00), Color(0xFFFFB300)],
                  icono: '🔥',
                  titulo: t('reto_titulo'),
                  sub: progreso.retoHechoHoy ? t('reto_hecho') : t('reto_sub'),
                  alTocar: progreso.retoHechoHoy ? null : () => _jugar(context, Modo.diario),
                ),
                if (progreso.rachaRestaurable > 0)
                  TextButton.icon(
                    icon: const Icon(Icons.replay),
                    label: Text(t('restaurar', {'n': progreso.rachaRestaurable})),
                    onPressed: () async {
                      if (await Anuncios.mostrarRecompensado()) {
                        await progreso.restaurarRacha();
                        if (context.mounted) _aviso(context, t('racha_restaurada'));
                      }
                    },
                  ),
                const SizedBox(height: 16),
                Text(t('clasico'), style: Theme.of(context).textTheme.titleLarge),
                Text(t('clasico_sub')),
                const SizedBox(height: 8),
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 1.5,
                  children: [for (final c in cats) _categoria(context, c)],
                ),
                const SizedBox(height: 16),
                _tarjeta(
                  colores: const [Color(0xFF1565C0), Color(0xFF29B6F6)],
                  icono: '⏱️',
                  titulo: t('contrarreloj'),
                  sub: progreso.contrarrelojDesbloqueado
                      ? t('contra_sub')
                      : '🔒 ${t('bloqueado', {'n': nivelContrarreloj})}',
                  alTocar: progreso.contrarrelojDesbloqueado ? () => _jugar(context, Modo.contrarreloj) : null,
                ),
              ]),
            ),
          );
        },
      );

  Widget _cabecera(BuildContext context) {
    final n = progreso.nivel;
    final base = (n - 1) * (n - 1) * xpBaseNivel, tope = n * n * xpBaseNivel;
    return Card(
      color: const Color(0xFF6C3CE9),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: DefaultTextStyle.merge(
          style: const TextStyle(color: Colors.white),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Text(t('nivel', {'n': n}), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.settings, color: Colors.white),
                tooltip: t('ajustes'),
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const Ajustes())),
              ),
            ]),
            LinearProgressIndicator(
              value: (progreso.xp - base) / (tope - base),
              minHeight: 8,
              borderRadius: BorderRadius.circular(4),
              backgroundColor: Colors.white24,
              color: Colors.amber,
            ),
            const SizedBox(height: 4),
            Text(t('xp', {'a': progreso.xp, 'b': tope})),
            const SizedBox(height: 8),
            Row(children: [
              Text('🔥 ${t('dias', {'n': progreso.racha})}', style: const TextStyle(fontSize: 16)),
              const Spacer(),
              Text('🪙 ${progreso.monedas}', style: const TextStyle(fontSize: 16)),
            ]),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                style: TextButton.styleFrom(foregroundColor: Colors.white, padding: EdgeInsets.zero),
                onPressed: () async {
                  final ok = progreso.protectores < protectoresMax && await progreso.comprarProtector();
                  if (!context.mounted) return;
                  _aviso(
                      context,
                      ok
                          ? t('protector_comprado')
                          : progreso.protectores >= protectoresMax
                              ? t('protector_max')
                              : t('sin_monedas'));
                },
                child: Text('🛡️ ${t('protector', {'p': progreso.protectores, 'm': protectoresMax, 'c': precioProtector})}'),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _categoria(BuildContext context, String c) {
    final libre = progreso.categoriaDesbloqueada(c);
    final color = libre ? _colores[c]! : Colors.grey;
    return Material(
      color: color,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: libre
            ? () => _jugar(context, Modo.clasico, c)
            : () => _aviso(context, '🔒 ${t('bloqueado', {'n': nivelCategoria[c]!})}'),
        child: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(libre ? _iconos[c]! : '🔒', style: const TextStyle(fontSize: 30)),
            Text(t('cat_$c'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            if (!libre)
              Text(t('bloqueado', {'n': nivelCategoria[c]!}), style: const TextStyle(color: Colors.white70)),
          ]),
        ),
      ),
    );
  }

  Widget _tarjeta({
    required List<Color> colores,
    required String icono,
    required String titulo,
    required String sub,
    required VoidCallback? alTocar,
  }) =>
      Opacity(
        opacity: alTocar == null ? 0.6 : 1,
        child: Ink(
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: colores),
            borderRadius: BorderRadius.circular(20),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: alTocar,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(children: [
                Text(icono, style: const TextStyle(fontSize: 40)),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(titulo,
                        style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                    Text(sub, style: const TextStyle(color: Colors.white)),
                  ]),
                ),
              ]),
            ),
          ),
        ),
      );
}
