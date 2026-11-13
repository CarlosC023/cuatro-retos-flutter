import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'config.dart';

void main() => runApp(const PeliculasApp());

// ---------------------------------------------------------------------------
// Modelos
// ---------------------------------------------------------------------------

class Pelicula {
  final int id;
  final String titulo;
  final String sinopsis;
  final String? posterPath;
  final String fecha;
  final double calificacion;

  const Pelicula({
    required this.id,
    required this.titulo,
    required this.sinopsis,
    required this.posterPath,
    required this.fecha,
    required this.calificacion,
  });

  factory Pelicula.fromJson(Map<String, dynamic> j) => Pelicula(
        id: j['id'] as int,
        titulo: (j['title'] ?? 'Sin título') as String,
        sinopsis: (j['overview'] ?? '') as String,
        posterPath: j['poster_path'] as String?,
        fecha: (j['release_date'] ?? '') as String,
        calificacion: (j['vote_average'] as num?)?.toDouble() ?? 0,
      );

  String get anio => fecha.length >= 4 ? fecha.substring(0, 4) : '—';

  String? get posterUrl => posterPath == null
      ? null
      : 'https://image.tmdb.org/t/p/w500$posterPath';
}

/// Estado de ánimo -> géneros de TMDB.
/// Los ids se separan con "|" (o). Si [generos] es null, se usan tendencias.
class Animo {
  final String emoji;
  final String etiqueta;
  final String? generos;
  const Animo(this.emoji, this.etiqueta, this.generos);
}

const List<Animo> kAnimos = [
  Animo('🔥', 'Tendencias', null),
  Animo('😄', 'Feliz', '35|10751'), // Comedia | Familia
  Animo('😢', 'Triste', '18'), // Drama
  Animo('🤩', 'Emocionado', '28|12'), // Acción | Aventura
  Animo('😌', 'Relajado', '16|10751'), // Animación | Familia
  Animo('😍', 'Romántico', '10749'), // Romance
  Animo('😱', 'Con miedo', '27|53'), // Terror | Thriller
  Animo('🤔', 'Curioso', '878|9648'), // Ciencia ficción | Misterio
];

// ---------------------------------------------------------------------------
// Servicio TMDB
// ---------------------------------------------------------------------------

class TmdbService {
  static const _host = 'api.themoviedb.org';
  final _random = Random();

  Future<List<Pelicula>> peliculasPorAnimo(Animo animo) async {
    final Uri uri;
    if (animo.generos == null) {
      // Tendencias de la semana
      uri = Uri.https(_host, '/3/trending/movie/week', {
        'api_key': kTmdbApiKey,
        'language': 'es-MX',
      });
    } else {
      // Películas populares del género; página al azar para variar resultados
      uri = Uri.https(_host, '/3/discover/movie', {
        'api_key': kTmdbApiKey,
        'language': 'es-MX',
        'sort_by': 'popularity.desc',
        'with_genres': animo.generos!,
        'vote_count.gte': '200',
        'include_adult': 'false',
        'page': '${_random.nextInt(3) + 1}',
      });
    }

    final respuesta = await http.get(uri).timeout(const Duration(seconds: 10));

    if (respuesta.statusCode == 401) {
      throw Exception('API key inválida. Revisa lib/config.dart.');
    }
    if (respuesta.statusCode != 200) {
      throw Exception('Error del servidor (${respuesta.statusCode}).');
    }

    final json = jsonDecode(respuesta.body) as Map<String, dynamic>;
    final lista = (json['results'] as List)
        .map((e) => Pelicula.fromJson(e as Map<String, dynamic>))
        .where((p) => p.posterPath != null)
        .toList();

    if (lista.isEmpty) throw Exception('No se encontraron películas.');
    return lista;
  }
}

// ---------------------------------------------------------------------------
// UI
// ---------------------------------------------------------------------------

class PeliculasApp extends StatelessWidget {
  const PeliculasApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Película del Fin de Semana',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorSchemeSeed: Colors.red, useMaterial3: true),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _servicio = TmdbService();
  final _scroll = ScrollController();
  final _random = Random();

  int _animoIdx = 0;
  late Future<List<Pelicula>> _futuro;
  List<Pelicula> _lista = [];
  Pelicula? _destacada;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  void _cargar() {
    setState(() {
      _futuro = _servicio.peliculasPorAnimo(kAnimos[_animoIdx]).then((lista) {
        _lista = lista;
        _destacada = lista[_random.nextInt(lista.length)];
        return lista;
      });
    });
  }

  void _otraAlAzar() {
    if (_lista.isEmpty) return;
    setState(() => _destacada = _lista[_random.nextInt(_lista.length)]);
  }

  void _elegir(Pelicula p) {
    setState(() => _destacada = p);
    _scroll.animateTo(0,
        duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('🎬 Película del Fin de Semana'),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // Selector de estado de ánimo
          SizedBox(
            height: 56,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              scrollDirection: Axis.horizontal,
              itemCount: kAnimos.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, i) {
                final a = kAnimos[i];
                return ChoiceChip(
                  label: Text('${a.emoji} ${a.etiqueta}'),
                  selected: _animoIdx == i,
                  onSelected: (_) {
                    _animoIdx = i;
                    _cargar();
                  },
                );
              },
            ),
          ),
          Expanded(
            child: FutureBuilder<List<Pelicula>>(
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
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.movie_filter, size: 48),
                          const SizedBox(height: 8),
                          Text('No se pudieron cargar las películas.\n$msg',
                              textAlign: TextAlign.center),
                          const SizedBox(height: 12),
                          FilledButton.icon(
                            onPressed: _cargar,
                            icon: const Icon(Icons.refresh),
                            label: const Text('Reintentar'),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                final lista = snapshot.data!;
                final destacada = _destacada!;
                return ListView(
                  controller: _scroll,
                  padding: const EdgeInsets.all(16),
                  children: [
                    Text('🎲 Te recomendamos',
                        style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 8),
                    _Destacada(pelicula: destacada, onOtra: _otraAlAzar),
                    const SizedBox(height: 24),
                    Text('Más opciones',
                        style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 8),
                    for (final p in lista)
                      _PeliculaTile(pelicula: p, onTap: () => _elegir(p)),
                    const SizedBox(height: 8),
                    Text(
                      'Datos de TMDB. Este producto usa la API de TMDB pero no está avalado ni certificado por TMDB.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _Poster extends StatelessWidget {
  final Pelicula pelicula;
  final double ancho;
  const _Poster({required this.pelicula, required this.ancho});

  @override
  Widget build(BuildContext context) {
    final alto = ancho * 1.5;
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        width: ancho,
        height: alto,
        child: pelicula.posterUrl == null
            ? const ColoredBox(
                color: Colors.black12,
                child: Icon(Icons.movie, size: 32),
              )
            : Image.network(
                pelicula.posterUrl!,
                fit: BoxFit.cover,
                loadingBuilder: (context, child, progress) => progress == null
                    ? child
                    : const Center(child: CircularProgressIndicator()),
                errorBuilder: (_, __, ___) => const ColoredBox(
                  color: Colors.black12,
                  child: Icon(Icons.broken_image),
                ),
              ),
      ),
    );
  }
}

class _Destacada extends StatelessWidget {
  final Pelicula pelicula;
  final VoidCallback onOtra;
  const _Destacada({required this.pelicula, required this.onOtra});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _Poster(pelicula: pelicula, ancho: 200),
            const SizedBox(height: 12),
            Text(
              pelicula.titulo,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 4),
            Text('${pelicula.anio}  ·  ⭐ ${pelicula.calificacion.toStringAsFixed(1)}'),
            const SizedBox(height: 8),
            Text(
              pelicula.sinopsis.isEmpty
                  ? 'Sin sinopsis disponible en español.'
                  : pelicula.sinopsis,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: onOtra,
              icon: const Icon(Icons.casino),
              label: const Text('Otra al azar'),
            ),
          ],
        ),
      ),
    );
  }
}

class _PeliculaTile extends StatelessWidget {
  final Pelicula pelicula;
  final VoidCallback onTap;
  const _PeliculaTile({required this.pelicula, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Poster(pelicula: pelicula, ancho: 70),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(pelicula.titulo,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 2),
                    Text('${pelicula.anio}  ·  ⭐ ${pelicula.calificacion.toStringAsFixed(1)}',
                        style: Theme.of(context).textTheme.bodySmall),
                    const SizedBox(height: 4),
                    Text(
                      pelicula.sinopsis.isEmpty
                          ? 'Sin sinopsis disponible.'
                          : pelicula.sinopsis,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
