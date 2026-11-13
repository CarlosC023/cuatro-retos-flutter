# 💸 Convertidor Cripto (Reto 4)

Muestra el precio de Bitcoin, Ethereum y Solana en USD (API pública de
CoinGecko, sin key) y calcula cuántas fracciones comprarías con el monto
que escribas.

## Cómo correrlo
```
flutter create .
flutter pub get
flutter run
```
Si `flutter create .` pregunta por sobrescribir, conserva `lib/main.dart` y
`pubspec.yaml` de este proyecto.

## Android release
Verifica que `android/app/src/main/AndroidManifest.xml` tenga:
```xml
<uses-permission android:name="android.permission.INTERNET"/>
```
