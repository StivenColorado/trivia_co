# Publicación y prueba

Entorno: `export JAVA_HOME=~/Android/jdk ANDROID_HOME=~/Android/sdk PATH=/home/user/development/flutter/bin:$PATH`

## 1. Identidad de la app
1. Cambiar `applicationId` en `android/app/build.gradle.kts` (hoy `com.trivia.trivia_co`; es definitivo una vez publicada). Ajustar también `namespace` si se quiere, y `enlacePlay` en `lib/config.dart` (usa el id).
2. Decidir el nombre comercial y sustituir `[NOMBRE DE LA APP]` en `docs/ficha_play.md`; cambiar `android:label` en `AndroidManifest.xml`.
3. Ícono: añadir `flutter_launcher_icons` a `dev_dependencies`, configurar `flutter_launcher_icons:` en `pubspec.yaml` (`android: true`, `image_path: "assets/icono.png"`, PNG 1024x1024; opcional `adaptive_icon_background`/`adaptive_icon_foreground`) y ejecutar `dart run flutter_launcher_icons`.

## 2. Firma release
1. Crear el keystore (guardarlo fuera del repo y hacer copia de seguridad; si se pierde no se puede actualizar la app sin el soporte de Play App Signing):
   `~/Android/jdk/bin/keytool -genkey -v -keystore ~/upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload`
2. Copiar `android/key.properties.example` a `android/key.properties` y completar contraseñas y ruta (`storeFile`). Ya está ignorado por git (`android/.gitignore`).
3. En `android/app/build.gradle.kts`: cargar `key.properties` (`java.util.Properties`), definir `signingConfigs { create("release") { keyAlias, keyPassword, storeFile = file(...), storePassword } }` y usar `signingConfig = signingConfigs.getByName("release")` en `buildTypes.release` (hoy usa la firma debug).
4. Generar el bundle: `flutter build appbundle --release` -> `build/app/outputs/bundle/release/app-release.aab`.
5. Subir el .aab a Play Console con Play App Signing (la clave generada es la de subida).

## 3. IDs reales de AdMob
1. En AdMob: crear la app (Android), y 3 bloques: banner, intersticial, recompensado.
2. `lib/config.dart`: reemplazar `idBanner`, `idIntersticial`, `idRecompensado` (hoy IDs de PRUEBA de Google).
3. `android/app/src/main/AndroidManifest.xml`: reemplazar el valor `com.google.android.gms.ads.APPLICATION_ID` (ID de prueba) por el real (`ca-app-pub-XXXX~YYYY`).
4. Vincular la app publicada en AdMob (Aplicaciones > Ver todas > la app > Agregar la app con su ficha de Play) una vez disponible en Play.
5. app-ads.txt: editar `docs/app-ads.txt` con tu `pub-...` y publicarlo en la RAÍZ del dominio del sitio web indicado en la ficha de Play (`https://tudominio/app-ads.txt`). Los GitHub Pages de proyecto (`usuario.github.io/repo`) no sirven en la raíz: usar un dominio propio o el repo `usuario.github.io`.
6. AdMob > Privacidad y mensajes: crear y publicar el mensaje de **GDPR** (EEE/Reino Unido) y los mensajes de **EE. UU. (regulaciones estatales)**, asociados a la app. Sin mensaje publicado, UMP no mostrará formulario.
7. **Nunca hacer clic en tus propios anuncios reales** (invalida la cuenta). Usar IDs de prueba o dispositivos de prueba registrados.

## 4. Play Console (cuenta personal)
- [ ] Cuenta de desarrollador creada y verificada (identidad, teléfono, dispositivo).
- [ ] Prueba cerrada: al menos 12 testers con opt-in durante 14 días continuos antes de pedir acceso a producción (requisito para cuentas personales nuevas; confirmar vigencia en la consola).
- [ ] Ficha: título, descripciones EN-US y es-419 (`docs/ficha_play.md`), ícono 512x512, gráfico destacado 1024x500, capturas de teléfono (mín. 2).
- [ ] Política de privacidad: URL pública (GitHub Pages con `docs/politica_privacidad.md`); rellenar `[CORREO DE CONTACTO]` y confirmar la fecha de vigencia antes.
- [ ] Declaración de anuncios: "Sí, contiene anuncios".
- [ ] Clasificación de contenido (IARC): cuestionario como juego de trivia, sin violencia ni contenido sensible.
- [ ] Público objetivo: 13+ (no marcar menores de 13, para no entrar en Familias).
- [ ] Seguridad de los datos: recopila ID de publicidad e información de uso/diagnóstico del dispositivo (AdMob) para publicidad; compartidos con terceros (Google); sin cuenta; los datos de progreso quedan en el dispositivo. Indicar que se puede ejercer opción de consentimiento (UMP).
- [ ] Declaración de ID de publicidad: sí (AdMob lo usa).
- [ ] Permisos: POST_NOTIFICATIONS (recordatorios), RECEIVE_BOOT_COMPLETED (reprogramarlos tras reiniciar), INTERNET (anuncios). Ver también si Play pide declaración de alarmas exactas: la app usa alarmas inexactas.
- [ ] País/regiones, precios (gratis), contacto.
- [ ] **targetSdk**: la app usa `flutter.targetSdkVersion` (según la versión de Flutter, ver el valor en `flutter doctor`/Gradle; Flutter 3.29 apunta a 35). Play exige un nivel mínimo de API de destino que sube cada año; confirmar en Play Console (Política > Nivel de API de destino) que el actual cumple, y si no, actualizar Flutter o fijar `targetSdk`.

## 5. Prueba manual en teléfono (APK/AAB de prueba)
`flutter build apk --debug` o instalar la prueba interna. Con IDs de PRUEBA.
- [ ] UMP: en primer arranque (con región EEE simulada en debug) aparece el formulario; tras aceptar, cargan anuncios; "Opciones de privacidad" en Ajustes reabre el formulario (si aplica). Si se rechaza, la app sigue funcionando.
- [ ] Anuncios de prueba: banner visible en Clásico/Reto (no en Contrarreloj) sin tapar botones; intersticial solo tras el resultado (no en las 2 primeras partidas, máx. 1 cada 3, >=180 s entre uno y otro); recompensado da +1 vida / 50-50 gratis / x2 monedas.
- [ ] Sin red: la app juega normal sin anuncios ni errores.
- [ ] Notificaciones: tras completar el primer reto diario se ofrece el recordatorio; en Android 13+ aparece el permiso; llegan avisos a las 19:00 (D+1..D+3, textos distintos); se reprograman al abrir la app; al desactivar se cancelan; sobreviven a un reinicio del teléfono.
- [ ] Racha: completar el reto diario suma racha; un día sin jugar la rompe; un protector se gasta si falta un día; restaurar racha con recompensado (1 vez/semana); reto diario solo una vez al día.
- [ ] Idioma: primer arranque sigue el idioma del teléfono (es -> es, otro -> en); cambiarlo en Ajustes recarga preguntas y textos; categoría Colombia solo en español.
- [ ] Contrarreloj: desbloqueo en nivel 2; 60 s; error resta 3 s; termina al llegar a 0 sin vidas.
- [ ] Progreso: XP, nivel, desbloqueos, monedas y compras (50/50, vida extra, protector máx. 2) persisten al cerrar y abrir la app.
- [ ] Compartir: el texto "Trivia #n" con emojis y enlace se envía correctamente.
- [ ] Política de privacidad se abre y se lee en ambos idiomas desde Ajustes.
