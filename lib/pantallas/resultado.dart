import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../config.dart';
import '../modelo/progreso.dart';
import '../servicios/anuncios.dart';
import '../textos.dart';
import 'juego.dart';

class Resultado extends StatefulWidget {
  final Modo modo;
  final int aciertos, total, xp, monedas;
  final List<bool> grilla;
  const Resultado({
    super.key,
    required this.modo,
    required this.aciertos,
    required this.total,
    required this.grilla,
    required this.xp,
    required this.monedas,
  });

  @override
  State<Resultado> createState() => _ResultadoState();
}

class _ResultadoState extends State<Resultado> {
  bool _duplicado = false;

  String get _emojis => widget.grilla.take(20).map((b) => b ? '🟩' : '🟥').join();

  void _compartir() {
    final args = {
      'n': progreso.retosCompletados,
      'racha': progreso.racha,
      'grilla': _emojis,
      'a': widget.aciertos,
      't': widget.total,
      'enlace': enlacePlay,
    };
    SharePlus.instance.share(ShareParams(text: t(widget.modo == Modo.diario ? 'share_reto' : 'share_libre', args)));
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.total == 0 ? 0.0 : widget.aciertos / widget.total;
    final msg = r == 1 ? 'res_perfecto' : r >= 0.6 ? 'res_bien' : 'res_practica';
    return PopScope(
      canPop: false,
      child: Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Text(t('res_titulo'), style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 8),
              Text('${widget.aciertos}/${widget.total}',
                  style: const TextStyle(fontSize: 64, fontWeight: FontWeight.bold, color: Color(0xFF6C3CE9))),
              Text(t(msg), style: const TextStyle(fontSize: 20)),
              const SizedBox(height: 16),
              Text(_emojis, style: const TextStyle(fontSize: 22), textAlign: TextAlign.center),
              const SizedBox(height: 16),
              Text('${t('res_xp', {'n': widget.xp})}   ${t('res_monedas', {'n': widget.monedas})} 🪙',
                  style: const TextStyle(fontSize: 18)),
              if (widget.modo == Modo.diario) Text('🔥 ${t('res_racha', {'n': progreso.racha})}'),
              const SizedBox(height: 24),
              if (widget.monedas > 0)
                OutlinedButton.icon(
                  icon: const Icon(Icons.ondemand_video),
                  label: Text(_duplicado ? t('res_x2_hecho') : t('res_x2')),
                  onPressed: _duplicado || !Anuncios.recompensadoListo
                      ? null
                      : () async {
                          if (await Anuncios.mostrarRecompensado()) {
                            await progreso.sumarMonedas(widget.monedas);
                            if (mounted) setState(() => _duplicado = true);
                          }
                        },
                ),
              OutlinedButton.icon(
                icon: const Icon(Icons.share),
                label: Text(t('compartir')),
                onPressed: _compartir,
              ),
              const SizedBox(height: 8),
              FilledButton(
                style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
                onPressed: () => Anuncios.intersticialSiToca(() {
                  if (mounted) Navigator.popUntil(context, (r) => r.isFirst);
                }),
                child: Text(t('volver')),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}
