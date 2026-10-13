import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../config.dart';
import '../modelo/progreso.dart';

/// Regla pura del intersticial: solo tras resultado; no en las primeras
/// [interPartidasGracia] partidas, al menos [interCadaPartidas] partidas
/// desde el último y [interSegundosMin] s desde el último.
/// [partidasDesde]: partidas desde el último inter; [segundosDesde]: segundos
/// desde el último (use un valor grande si nunca hubo); [totalPartidas]:
/// partidas totales de la instalación (incluida la que acaba de terminar).
/// Reexportada desde progreso.dart.
export '../modelo/progreso.dart' show puedeMostrarInter;

class Anuncios {
  static bool _sdkListo = false;
  static InterstitialAd? _inter;
  static RewardedAd? _recompensado;

  /// UMP: requestConsentInfoUpdate -> loadAndShowConsentFormIfRequired ->
  /// si canRequestAds() MobileAds.initialize() y precarga inter y recompensado.
  /// ConsentDebugSettings solo en debug. Nunca lanza.
  static Future<void> iniciar() async {
    try {
      final c = Completer<void>();
      ConsentInformation.instance.requestConsentInfoUpdate(
        ConsentRequestParameters(
          consentDebugSettings: kDebugMode
              ? ConsentDebugSettings(debugGeography: DebugGeography.debugGeographyEea)
              : null,
        ),
        () => c.complete(),
        (_) => c.complete(),
      );
      await c.future;
      final f = Completer<void>();
      ConsentForm.loadAndShowConsentFormIfRequired((_) => f.complete());
      await f.future;
      await _iniciarSdk();
    } catch (e) {
      debugPrint('Anuncios.iniciar: $e');
    }
  }

  static Future<void> _iniciarSdk() async {
    if (_sdkListo || !await ConsentInformation.instance.canRequestAds()) return;
    await MobileAds.instance.initialize();
    _sdkListo = true;
    _cargarInter();
    _cargarRecompensado();
  }

  /// True si Ajustes debe mostrar "Opciones de privacidad".
  static Future<bool> privacidadRequerida() async {
    try {
      return await ConsentInformation.instance.getPrivacyOptionsRequirementStatus() ==
          PrivacyOptionsRequirementStatus.required;
    } catch (_) {
      return false;
    }
  }

  /// Reabre el formulario de privacidad UMP.
  static Future<void> mostrarOpcionesPrivacidad() async {
    try {
      final c = Completer<void>();
      ConsentForm.showPrivacyOptionsForm((_) => c.complete());
      await c.future;
      await _iniciarSdk();
    } catch (e) {
      debugPrint('Anuncios.mostrarOpcionesPrivacidad: $e');
    }
  }

  /// Banner adaptable listo para ponerse; SizedBox.shrink si no hay anuncio.
  /// Gestiona su propio ciclo de vida.
  static Widget banner() => const _Banner();

  static void _cargarInter() {
    InterstitialAd.load(
      adUnitId: idIntersticial,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (a) => _inter = a,
        onAdFailedToLoad: (e) => debugPrint('Inter: ${e.message}'),
      ),
    );
  }

  static void _cargarRecompensado() {
    RewardedAd.load(
      adUnitId: idRecompensado,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (a) => _recompensado = a,
        onAdFailedToLoad: (e) => debugPrint('Recompensado: ${e.message}'),
      ),
    );
  }

  /// Tras el resultado de una partida: muestra intersticial si
  /// [puedeMostrarInter] según [progreso] (y registra con registrarInter),
  /// luego llama [despues]. Si no hay anuncio, llama [despues] directo.
  static Future<void> intersticialSiToca(VoidCallback despues) async {
    final ad = _inter;
    final desde = progreso.ultimoInter == null
        ? 1 << 30
        : DateTime.now().difference(progreso.ultimoInter!).inSeconds;
    if (ad == null || !puedeMostrarInter(progreso.partidasDesdeInter, desde, progreso.partidasTotales)) {
      despues();
      return;
    }
    _inter = null;
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (a) {
        a.dispose();
        _cargarInter();
        despues();
      },
      onAdFailedToShowFullScreenContent: (a, _) {
        a.dispose();
        _cargarInter();
        despues();
      },
    );
    await progreso.registrarInter();
    await ad.show();
  }

  /// True si hay un recompensado precargado.
  static bool get recompensadoListo => _recompensado != null;

  /// Muestra el recompensado; devuelve true si el usuario ganó la recompensa.
  /// Precarga el siguiente al cerrar.
  static Future<bool> mostrarRecompensado() async {
    final ad = _recompensado;
    if (ad == null) return false;
    _recompensado = null;
    final fin = Completer<bool>();
    var gano = false;
    void cerrar(RewardedAd a) {
      a.dispose();
      _cargarRecompensado();
      if (!fin.isCompleted) fin.complete(gano);
    }

    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: cerrar,
      onAdFailedToShowFullScreenContent: (a, _) => cerrar(a),
    );
    await ad.show(onUserEarnedReward: (_, __) => gano = true);
    return fin.future;
  }
}

class _Banner extends StatefulWidget {
  const _Banner();

  @override
  State<_Banner> createState() => _BannerState();
}

class _BannerState extends State<_Banner> {
  BannerAd? _ad;
  int _ancho = 0;

  Future<void> _cargar(int ancho) async {
    _ancho = ancho;
    if (!Anuncios._sdkListo) return;
    final tam = await AdSize.getCurrentOrientationAnchoredAdaptiveBannerAdSize(ancho);
    if (tam == null || !mounted) return;
    BannerAd(
      adUnitId: idBanner,
      size: tam,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (a) {
          if (!mounted) {
            a.dispose();
            return;
          }
          _ad?.dispose();
          setState(() => _ad = a as BannerAd);
        },
        onAdFailedToLoad: (a, e) {
          a.dispose();
          debugPrint('Banner: ${e.message}');
        },
      ),
    ).load();
  }

  @override
  void dispose() {
    _ad?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ancho = MediaQuery.sizeOf(context).width.truncate();
    if (ancho != _ancho) _cargar(ancho);
    final ad = _ad;
    if (ad == null) return const SizedBox.shrink();
    return SizedBox(width: ad.size.width.toDouble(), height: ad.size.height.toDouble(), child: AdWidget(ad: ad));
  }
}
