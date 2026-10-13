// IDs de PRUEBA de Google. Para publicar, reemplazar aquí (y el APPLICATION_ID
// en android/app/src/main/AndroidManifest.xml) por los reales de tu cuenta AdMob.
const idBanner = 'ca-app-pub-3940256099942544/6300978111';
const idIntersticial = 'ca-app-pub-3940256099942544/1033173712';
const idRecompensado = 'ca-app-pub-3940256099942544/5224354917';

const idiomas = ['es', 'en'];

/// Orden de categorías por idioma ('colombia' solo en es).
const categoriasPorIdioma = {
  'es': ['cultura', 'geografia', 'colombia', 'ciencia', 'historia', 'deportes', 'entretenimiento'],
  'en': ['cultura', 'geografia', 'ciencia', 'historia', 'deportes', 'entretenimiento'],
};

/// Nivel mínimo para desbloquear cada categoría.
const nivelCategoria = {
  'cultura': 1,
  'geografia': 1,
  'colombia': 1,
  'ciencia': 2,
  'historia': 3,
  'deportes': 4,
  'entretenimiento': 5,
};
const nivelContrarreloj = 2;

// Partidas
const preguntasPorPartida = 10;
const vidasClasico = 3;
const segundosContrarreloj = 60;
const penalizacionContrarreloj = 3; // segundos que resta un error

// XP y nivel (nivel = 1 + floor(sqrt(xp / xpBaseNivel)))
const xpAcierto = 10;
const xpExtraRacha = 5; // desde [aciertosSeguidosBonus] seguidos
const aciertosSeguidosBonus = 3;
const multiplicadorRetoDiario = 2;
const xpBaseNivel = 100;

// Monedas
const monedasAcierto = 2;
const monedasReto = 20;
const monedasPorRacha = 5; // x racha, tope [monedasRachaMax]
const monedasRachaMax = 50;
const precioCincuenta = 30;
const precioVidaExtra = 50;
const precioProtector = 150;
const protectoresMax = 2;

// Intersticial
const interCadaPartidas = 3;
const interSegundosMin = 180;
const interPartidasGracia = 2; // nunca en las primeras N partidas de la instalación

// Recompensado
const restaurarRachaDiasEspera = 7; // 1 vez por semana

// Recordatorios
const horaRecordatorio = 19;
const recordatoriosMax = 3; // D+1..D+3

// Compartir
const enlacePlay = 'https://play.google.com/store/apps/details?id=com.trivia.trivia_co';
