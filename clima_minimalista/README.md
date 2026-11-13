# 🌤️ Clima Minimalista (Reto 3)

Muestra el clima actual con la API de OpenWeatherMap: ciudad inicial
configurable, buscador de ciudades y botón de ubicación (plus con `geolocator`).
Incluye estado de carga (`CircularProgressIndicator`) y manejo de errores.

## Cómo correrlo
```
flutter create .
flutter pub get
flutter run
```
Si `flutter create .` pregunta por sobrescribir, conserva `lib/main.dart`,
`lib/config.dart` y `pubspec.yaml` de este proyecto.

## Permisos (necesarios para "Usar mi ubicación")

### Android
En `android/app/src/main/AndroidManifest.xml`, dentro de `<manifest>` y
antes de `<application>`:
```xml
<uses-permission android:name="android.permission.INTERNET"/>
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION"/>
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION"/>
```

### iOS
En `ios/Runner/Info.plist`:
```xml
<key>NSLocationWhenInUseUsageDescription</key>
<string>Necesitamos tu ubicación para mostrar el clima de tu zona.</string>
```

## API key
Está en `lib/config.dart` (`kOpenWeatherKey`). Si da error 401, puede que
todavía no esté activa (hasta ~2 horas después de registrarte).
La ciudad inicial se cambia en `kCiudadInicial`.
