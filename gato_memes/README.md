# 🐱 Gato Memes (Reto 2)

App Flutter que consume la API de Cataas para mostrar gatos aleatorios con
una frase encima y filtros opcionales.

## Cómo correrlo

1. Crea la estructura de plataformas dentro de esta carpeta:
   ```
   flutter create .
   ```
   (No sobrescribe `lib/main.dart` ni `pubspec.yaml` si le dices que no, pero
   si lo hace, vuelve a copiar los archivos de este proyecto.)
2. Instala dependencias y ejecuta:
   ```
   flutter pub get
   flutter run
   ```

## Android: permiso de internet
`flutter create` ya agrega `INTERNET` en el manifest de debug. Para release,
confirma que `android/app/src/main/AndroidManifest.xml` tenga:
```xml
<uses-permission android:name="android.permission.INTERNET"/>
```

## Cómo funciona
La URL se arma con `Uri(pathSegments: ['cat','says', texto])`, que codifica el
texto automáticamente. El parámetro `t` evita la caché para obtener un gato
nuevo en cada toque.
