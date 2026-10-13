import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:trivia_co/modelo/progreso.dart';

void main() {
  group('calcularRacha', () {
    test('seguida (ayer) sigue', () {
      final r = calcularRacha('2026-03-09', '2026-03-10', 4, 1);
      expect(r, (racha: 4, protectores: 1, perdida: false));
    });
    test('mismo día sin cambios', () {
      expect(calcularRacha('2026-03-10', '2026-03-10', 4, 0).racha, 4);
    });
    test('falta 1 día con protector lo gasta', () {
      final r = calcularRacha('2026-03-08', '2026-03-10', 4, 1);
      expect(r, (racha: 4, protectores: 0, perdida: false));
    });
    test('falta 1 día sin protector pierde', () {
      final r = calcularRacha('2026-03-08', '2026-03-10', 4, 0);
      expect(r, (racha: 0, protectores: 0, perdida: true));
    });
    test('faltan 2 días pierde aun con protector', () {
      final r = calcularRacha('2026-03-07', '2026-03-10', 4, 2);
      expect(r, (racha: 0, protectores: 2, perdida: true));
    });
    test('cruza cambio de mes', () {
      expect(calcularRacha('2026-02-28', '2026-03-01', 2, 0).racha, 2);
    });
  });

  test('umbrales de nivel', () {
    expect(nivelDeXp(0), 1);
    expect(nivelDeXp(99), 1);
    expect(nivelDeXp(100), 2);
    expect(nivelDeXp(399), 2);
    expect(nivelDeXp(400), 3);
    expect(nivelDeXp(1600), 5);
  });

  test('puedeMostrarInter', () {
    expect(puedeMostrarInter(3, 200, 5), isTrue);
    expect(puedeMostrarInter(3, 200, 2), isFalse); // gracia
    expect(puedeMostrarInter(2, 200, 5), isFalse); // pocas partidas
    expect(puedeMostrarInter(3, 100, 5), isFalse); // poco tiempo
  });

  group('Progreso', () {
    test('desbloqueo por nivel y XP', () async {
      SharedPreferences.setMockInitialValues({});
      final p = Progreso();
      await p.cargar();
      expect(p.categoriaDesbloqueada('cultura'), isTrue);
      expect(p.categoriaDesbloqueada('ciencia'), isFalse);
      expect(p.contrarrelojDesbloqueado, isFalse);
      expect(await p.registrarAcierto(seguidos: 3), 15);
      expect(await p.registrarAcierto(seguidos: 1, reto: true), 20);
      p.xp = 100;
      expect(p.categoriaDesbloqueada('ciencia'), isTrue);
      expect(p.contrarrelojDesbloqueado, isTrue);
      expect(p.categoriaDesbloqueada('historia'), isFalse);
    });

    test('migra claves racha/ultimo y protector gastado', () async {
      final hace2 = fechaDe(DateTime.now().subtract(const Duration(days: 2)));
      SharedPreferences.setMockInitialValues({'racha': 5, 'ultimo': hace2, 'protectores': 1});
      final p = Progreso();
      await p.cargar();
      expect(p.racha, 5);
      expect(p.protectores, 0);
    });

    test('racha perdida un día es restaurable', () async {
      final hace2 = fechaDe(DateTime.now().subtract(const Duration(days: 2)));
      SharedPreferences.setMockInitialValues({'racha': 5, 'ultimo': hace2});
      final p = Progreso();
      await p.cargar();
      expect(p.racha, 0);
      expect(p.rachaRestaurable, 5);
      await p.restaurarRacha();
      expect(p.racha, 5);
      expect(p.puedeRestaurarRacha, isFalse);
    });

    test('reto, monedas y protectores', () async {
      SharedPreferences.setMockInitialValues({'monedas': 200});
      final p = Progreso();
      await p.cargar();
      expect(await p.completarReto(), 25);
      expect(await p.completarReto(), 0);
      expect(p.racha, 1);
      expect(await p.comprarProtector(), isTrue);
      expect(p.monedas, 200 + 25 - 150);
      expect(await p.comprarProtector(), isFalse);
    });

    test('vistas por idioma y partidas persisten', () async {
      SharedPreferences.setMockInitialValues({'idioma': 'es'});
      final p = Progreso();
      await p.cargar();
      await p.marcarVistas(['es-cultura-001']);
      await p.registrarPartida();
      await p.cambiarIdioma('en');
      expect(p.vistas, isEmpty);
      final q = Progreso();
      await q.cargar();
      expect(q.idioma, 'en');
      expect(q.partidasTotales, 1);
      await q.cambiarIdioma('es');
      expect(q.vistas, {'es-cultura-001'});
    });
  });
}
