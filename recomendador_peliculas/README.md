# 🎬 Película del Fin de Semana (Reto 1)

Elige tu estado de ánimo y la app consulta la API de TMDB para recomendarte
una película al azar y mostrarte una lista de opciones con su póster.
Incluye la opción "Tendencias" (películas de moda de la semana).

## Cómo correrlo
```
flutter create .
flutter pub get
flutter run
```
Si `flutter create .` pregunta por sobrescribir, conserva `lib/main.dart`,
`lib/config.dart` y `pubspec.yaml` de este proyecto.

## API key
Está en `lib/config.dart` (`kTmdbApiKey`). Si la regeneras en TMDB, cambia
solo ese valor.

## Android release
Verifica que `android/app/src/main/AndroidManifest.xml` tenga:
```xml
<uses-permission android:name="android.permission.INTERNET"/>
```
