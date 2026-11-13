import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

void main() => runApp(const CriptoApp());

// ---------------------------------------------------------------------------
// Modelo
// ---------------------------------------------------------------------------

/// Criptomoneda que mostramos en la app.
class Cripto {
  final String id; // id que usa CoinGecko en la URL
  final String nombre;
  final String simbolo;
  final int decimales; // decimales a mostrar en la fracción comprada
  final Color color;

  const Cripto(this.id, this.nombre, this.simbolo, this.decimales, this.color);
}

const List<Cripto> kCriptos = [
  Cripto('bitcoin', 'Bitcoin', 'BTC', 8, Color(0xFFF7931A)),
  Cripto('ethereum', 'Ethereum', 'ETH', 6, Color(0xFF627EEA)),
  Cripto('solana', 'Solana', 'SOL', 4, Color(0xFF14F195)),
];

/// Precio actual de una cripto en USD y su cambio en 24 h.
class Precio {
  final double usd;
  final double? cambio24h;
  const Precio(this.usd, this.cambio24h);
}

// ---------------------------------------------------------------------------
// Servicio (API CoinGecko, sin autenticación)
// ---------------------------------------------------------------------------

class CoinGeckoService {
  static const _host = 'api.coingecko.com';

  /// Endpoint:
  /// https://api.coingecko.com/api/v3/simple/price
  ///   ?ids=bitcoin,ethereum,solana&vs_currencies=usd&include_24hr_change=true
  Future<Map<String, Precio>> obtenerPrecios() async {
    final uri = Uri.https(_host, '/api/v3/simple/price', {
      'ids': kCriptos.map((c) => c.id).join(','),
      'vs_currencies': 'usd',
      'include_24hr_change': 'true',
    });

    final respuesta =
        await http.get(uri).timeout(const Duration(seconds: 10));

    if (respuesta.statusCode == 429) {
      throw Exception('Demasiadas consultas. Espera un minuto e intenta de nuevo.');
    }
    if (respuesta.statusCode != 200) {
      throw Exception('Error del servidor (${respuesta.statusCode}).');
    }

    final json = jsonDecode(respuesta.body) as Map<String, dynamic>;
    final resultado = <String, Precio>{};
    for (final c in kCriptos) {
      final datos = json[c.id] as Map<String, dynamic>?;
      if (datos == null) continue;
      resultado[c.id] = Precio(
        (datos['usd'] as num).toDouble(),
        (datos['usd_24h_change'] as num?)?.toDouble(),
      );
    }
    return resultado;
  }
}

// ---------------------------------------------------------------------------
// Utilidades
// ---------------------------------------------------------------------------

String formatoUsd(double valor) {
  final partes = valor.toStringAsFixed(2).split('.');
  final entero = partes[0].replaceAllMapped(
    RegExp(r'\B(?=(\d{3})+(?!\d))'),
    (m) => ',',
  );
  return '\$$entero.${partes[1]}';
}

// ---------------------------------------------------------------------------
// UI
// ---------------------------------------------------------------------------

class CriptoApp extends StatelessWidget {
  const CriptoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Convertidor Cripto',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorSchemeSeed: Colors.indigo, useMaterial3: true),
      home: const ConvertidorScreen(),
    );
  }
}

class ConvertidorScreen extends StatefulWidget {
  const ConvertidorScreen({super.key});

  @override
  State<ConvertidorScreen> createState() => _ConvertidorScreenState();
}

class _ConvertidorScreenState extends State<ConvertidorScreen> {
  final _servicio = CoinGeckoService();
  final _controller = TextEditingController(text: '100');

  late Future<Map<String, Precio>> _futuro;
  DateTime? _ultimaActualizacion;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _cargar();
    // Refresco automático cada 60 s (el plan gratis de CoinGecko tiene límite).
    _timer = Timer.periodic(const Duration(seconds: 60), (_) => _cargar());
  }

  void _cargar() {
    setState(() {
      _futuro = _servicio.obtenerPrecios().then((datos) {
        _ultimaActualizacion = DateTime.now();
        return datos;
      });
    });
  }

  /// Convierte el texto a double; acepta coma o punto decimal.
  double get _montoUsd {
    final texto = _controller.text.replaceAll(',', '.').trim();
    return double.tryParse(texto) ?? 0;
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  String _hora(DateTime t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}:${t.second.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('💸 Convertidor Cripto'),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: 'Actualizar precios',
            icon: const Icon(Icons.refresh),
            onPressed: _cargar,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _controller,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Monto en USD',
                prefixText: '\$ ',
                border: OutlineInputBorder(),
              ),
              onChanged: (_) => setState(() {}), // recalcula sin nueva petición
            ),
            const SizedBox(height: 16),
            Expanded(
              child: FutureBuilder<Map<String, Precio>>(
                future: _futuro,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    final msg = snapshot.error
                        .toString()
                        .replaceFirst('Exception: ', '');
                    return Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.cloud_off, size: 48),
                          const SizedBox(height: 8),
                          Text(
                            'No se pudieron cargar los precios.\n$msg',
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 12),
                          FilledButton.icon(
                            onPressed: _cargar,
                            icon: const Icon(Icons.refresh),
                            label: const Text('Reintentar'),
                          ),
                        ],
                      ),
                    );
                  }

                  final precios = snapshot.data!;
                  return Column(
                    children: [
                      Expanded(
                        child: ListView.separated(
                          itemCount: kCriptos.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 8),
                          itemBuilder: (context, i) {
                            final cripto = kCriptos[i];
                            final precio = precios[cripto.id];
                            if (precio == null) {
                              return ListTile(
                                title: Text(cripto.nombre),
                                subtitle: const Text('Sin datos'),
                              );
                            }
                            return _CriptoCard(
                              cripto: cripto,
                              precio: precio,
                              fraccion: _montoUsd / precio.usd,
                            );
                          },
                        ),
                      ),
                      if (_ultimaActualizacion != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            'Actualizado: ${_hora(_ultimaActualizacion!)} · se refresca cada 60 s',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CriptoCard extends StatelessWidget {
  final Cripto cripto;
  final Precio precio;
  final double fraccion;

  const _CriptoCard({
    required this.cripto,
    required this.precio,
    required this.fraccion,
  });

  @override
  Widget build(BuildContext context) {
    final cambio = precio.cambio24h;
    final sube = (cambio ?? 0) >= 0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: cripto.color,
              child: Text(
                cripto.simbolo[0],
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${cripto.nombre} (${cripto.simbolo})',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 2),
                  Text(formatoUsd(precio.usd)),
                  if (cambio != null)
                    Text(
                      '${sube ? '▲' : '▼'} ${cambio.abs().toStringAsFixed(2)}% (24 h)',
                      style: TextStyle(
                        color: sube ? Colors.green : Colors.red,
                        fontSize: 12,
                      ),
                    ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  fraccion.toStringAsFixed(cripto.decimales),
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                Text(cripto.simbolo,
                    style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
