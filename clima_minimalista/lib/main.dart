import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

import 'config.dart';

void main() => runApp(const ClimaApp());

// ---------------------------------------------------------------------------
// Modelo
// ---------------------------------------------------------------------------

class Clima {
  final String ciudad;
  final String pais;
  final double temp;
  final double sensacion;
  final double tempMin;
  final double tempMax;
  final int humedad;
  final double vientoKmh;
  final String descripcion;
  final String icono;
  final String principal; // Clear, Clouds, Rain, ...

  const Clima({
    required this.ciudad,
    required this.pais,
    required this.temp,
    required this.sensacion,
    required this.tempMin,
    required this.tempMax,
    required this.humedad,
    required this.vientoKmh,
    required this.descripcion,
    required this.icono,
    required this.principal,
  });

  /// Parseo del JSON de /data/2.5/weather
  factory Clima.fromJson(Map<String, dynamic> j) {
    final main = j['main'] as Map<String, dynamic>;
    final weather = (j['weather'] as List).first as Map<String, dynamic>;
    final wind = (j['wind'] as Map<String, dynamic>?) ?? {};
    final sys = (j['sys'] as Map<String, dynamic>?) ?? {};

    return Clima(
      ciudad: (j['name'] ?? '') as String,
      pais: (sys['country'] ?? '') as String,
      temp: (main['temp'] as num).toDouble(),
      sensacion: (main['feels_like'] as num).toDouble(),
      tempMin: (main['temp_min'] as num).toDouble(),
      tempMax: (main['temp_max'] as num).toDouble(),
      humedad: (main['humidity'] as num).toInt(),
      // La API da m/s; lo pasamos a km/h
      vientoKmh: ((wind['speed'] as num?)?.toDouble() ?? 0) * 3.6,
      descripcion: (weather['description'] ?? '') as String,
      icono: (weather['icon'] ?? '01d') as String,
      principal: (weather['main'] ?? '') as String,
    );
  }
}

// ---------------------------------------------------------------------------
// Servicios
// ---------------------------------------------------------------------------

class ClimaService {
  static const _host = 'api.openweathermap.org';

  Future<Clima> porCiudad(String ciudad) => _pedir({'q': ciudad});

  Future<Clima> porCoordenadas(double lat, double lon) =>
      _pedir({'lat': '$lat', 'lon': '$lon'});

  Future<Clima> _pedir(Map<String, String> params) async {
    final uri = Uri.https(_host, '/data/2.5/weather', {
      ...params,
      'appid': kOpenWeatherKey,
      'units': 'metric', // °C
      'lang': 'es',
    });

    final respuesta = await http.get(uri).timeout(const Duration(seconds: 10));

    switch (respuesta.statusCode) {
      case 200:
        return Clima.fromJson(
            jsonDecode(respuesta.body) as Map<String, dynamic>);
      case 401:
        throw Exception(
            'API key no válida o aún no activa (puede tardar hasta 2 horas).');
      case 404:
        throw Exception('No encontré esa ciudad. Revisa el nombre.');
      case 429:
        throw Exception('Demasiadas consultas. Intenta en un minuto.');
      default:
        throw Exception('Error del servidor (${respuesta.statusCode}).');
    }
  }
}

/// Obtiene la ubicación actual con permisos (plus con geolocator).
Future<Position> obtenerUbicacion() async {
  if (!await Geolocator.isLocationServiceEnabled()) {
    throw Exception('Activa los servicios de ubicación del dispositivo.');
  }

  var permiso = await Geolocator.checkPermission();
  if (permiso == LocationPermission.denied) {
    permiso = await Geolocator.requestPermission();
  }
  if (permiso == LocationPermission.denied) {
    throw Exception('Permiso de ubicación denegado.');
  }
  if (permiso == LocationPermission.deniedForever) {
    throw Exception(
        'Permiso de ubicación bloqueado. Actívalo en los ajustes del dispositivo.');
  }

  return Geolocator.getCurrentPosition(
    locationSettings: const LocationSettings(
      accuracy: LocationAccuracy.low,
      timeLimit: Duration(seconds: 15),
    ),
  );
}

// ---------------------------------------------------------------------------
// UI
// ---------------------------------------------------------------------------

class ClimaApp extends StatelessWidget {
  const ClimaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Clima Minimalista',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorSchemeSeed: Colors.lightBlue, useMaterial3: true),
      home: const ClimaScreen(),
    );
  }
}

class ClimaScreen extends StatefulWidget {
  const ClimaScreen({super.key});

  @override
  State<ClimaScreen> createState() => _ClimaScreenState();
}

class _ClimaScreenState extends State<ClimaScreen> {
  final _servicio = ClimaService();
  final _controller = TextEditingController();
  late Future<Clima> _futuro;

  @override
  void initState() {
    super.initState();
    _futuro = _servicio.porCiudad(kCiudadInicial);
  }

  void _buscarCiudad(String ciudad) {
    final c = ciudad.trim();
    if (c.isEmpty) return;
    FocusScope.of(context).unfocus();
    setState(() => _futuro = _servicio.porCiudad(c));
  }

  void _usarMiUbicacion() {
    FocusScope.of(context).unfocus();
    _controller.clear();
    setState(() {
      _futuro = obtenerUbicacion()
          .then((p) => _servicio.porCoordenadas(p.latitude, p.longitude));
    });
  }

  void _reintentar() => setState(() => _futuro = _servicio.porCiudad(
      _controller.text.trim().isEmpty ? kCiudadInicial : _controller.text));

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Fondo según el clima, para un look minimalista pero vivo.
  List<Color> _colores(String? principal) {
    switch (principal) {
      case 'Clear':
        return const [Color(0xFF2193B0), Color(0xFF6DD5ED)];
      case 'Clouds':
        return const [Color(0xFF606C88), Color(0xFF3F4C6B)];
      case 'Rain':
      case 'Drizzle':
        return const [Color(0xFF373B44), Color(0xFF4286F4)];
      case 'Thunderstorm':
        return const [Color(0xFF232526), Color(0xFF414345)];
      case 'Snow':
        return const [Color(0xFF83A4D4), Color(0xFF6A8CB5)];
      default:
        return const [Color(0xFF4568DC), Color(0xFFB06AB3)];
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Clima>(
      future: _futuro,
      builder: (context, snapshot) {
        final clima = snapshot.data;
        return Scaffold(
          body: AnimatedContainer(
            duration: const Duration(milliseconds: 500),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: _colores(clima?.principal),
              ),
            ),
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _buscador(),
                    Expanded(child: _contenido(snapshot)),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buscador() {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _controller,
            textInputAction: TextInputAction.search,
            onSubmitted: _buscarCiudad,
            style: const TextStyle(color: Colors.white),
            cursorColor: Colors.white,
            decoration: InputDecoration(
              hintText: 'Buscar ciudad...',
              hintStyle: const TextStyle(color: Colors.white70),
              prefixIcon: const Icon(Icons.search, color: Colors.white70),
              filled: true,
              fillColor: Colors.white24,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(30),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        IconButton.filledTonal(
          tooltip: 'Usar mi ubicación',
          onPressed: _usarMiUbicacion,
          icon: const Icon(Icons.my_location),
        ),
      ],
    );
  }

  Widget _contenido(AsyncSnapshot<Clima> snapshot) {
    // Estado de carga
    if (snapshot.connectionState == ConnectionState.waiting) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    }

    // Error
    if (snapshot.hasError) {
      final msg =
          snapshot.error.toString().replaceFirst('Exception: ', '');
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off, size: 56, color: Colors.white),
              const SizedBox(height: 12),
              Text(
                msg,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontSize: 16),
              ),
              const SizedBox(height: 16),
              FilledButton.tonalIcon(
                onPressed: _reintentar,
                icon: const Icon(Icons.refresh),
                label: const Text('Reintentar'),
              ),
            ],
          ),
        ),
      );
    }

    // Datos
    final c = snapshot.data!;
    return SingleChildScrollView(
      child: Column(
        children: [
          const SizedBox(height: 24),
          Text(
            c.pais.isEmpty ? c.ciudad : '${c.ciudad}, ${c.pais}',
            style: const TextStyle(
                color: Colors.white, fontSize: 28, fontWeight: FontWeight.w500),
          ),
          Image.network(
            'https://openweathermap.org/img/wn/${c.icono}@4x.png',
            width: 140,
            height: 140,
            errorBuilder: (_, __, ___) =>
                const Icon(Icons.wb_sunny, size: 100, color: Colors.white),
          ),
          Text(
            '${c.temp.round()}°',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 96,
              fontWeight: FontWeight.w200,
            ),
          ),
          Text(
            _capitalizar(c.descripcion),
            style: const TextStyle(color: Colors.white, fontSize: 20),
          ),
          const SizedBox(height: 4),
          Text(
            'Máx ${c.tempMax.round()}°  ·  Mín ${c.tempMin.round()}°',
            style: const TextStyle(color: Colors.white70, fontSize: 16),
          ),
          const SizedBox(height: 32),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _dato(Icons.thermostat, 'Sensación', '${c.sensacion.round()}°'),
                _dato(Icons.water_drop, 'Humedad', '${c.humedad}%'),
                _dato(Icons.air, 'Viento', '${c.vientoKmh.round()} km/h'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _dato(IconData icono, String etiqueta, String valor) {
    return Column(
      children: [
        Icon(icono, color: Colors.white),
        const SizedBox(height: 4),
        Text(valor,
            style: const TextStyle(
                color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600)),
        Text(etiqueta,
            style: const TextStyle(color: Colors.white70, fontSize: 12)),
      ],
    );
  }

  String _capitalizar(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
}
