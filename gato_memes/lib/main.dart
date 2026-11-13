import 'package:flutter/material.dart';

void main() => runApp(const GatoMemesApp());

class GatoMemesApp extends StatelessWidget {
  const GatoMemesApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Gato Memes',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: Colors.deepOrange,
        useMaterial3: true,
      ),
      home: const MemeScreen(),
    );
  }
}

/// Filtros disponibles en Cataas (valor de la API -> etiqueta).
const Map<String, String> kFiltros = {
  '': 'Ninguno',
  'mono': 'Blanco y negro',
  'sepia': 'Sepia',
  'negate': 'Negativo',
  'blur': 'Desenfoque',
  'pixel': 'Pixelado',
  'paint': 'Pintura',
};

class MemeScreen extends StatefulWidget {
  const MemeScreen({super.key});

  @override
  State<MemeScreen> createState() => _MemeScreenState();
}

class _MemeScreenState extends State<MemeScreen> {
  final TextEditingController _controller = TextEditingController();

  String _texto = '';
  String _filtro = '';
  int _semilla = DateTime.now().millisecondsSinceEpoch;

  /// Construye la URL dinámica de Cataas.
  /// - Sin texto:  https://cataas.com/cat
  /// - Con texto:  https://cataas.com/cat/says/<texto>
  /// El parámetro `t` solo evita que se reutilice la imagen en caché
  /// y así obtengamos un gato distinto cada vez.
  Uri get _url {
    final texto = _texto.trim();
    final query = <String, String>{
      't': _semilla.toString(),
      if (texto.isNotEmpty) 'fontSize': '48',
      if (texto.isNotEmpty) 'fontColor': 'white',
      if (_filtro.isNotEmpty) 'filter': _filtro,
    };
    return Uri(
      scheme: 'https',
      host: 'cataas.com',
      // pathSegments codifica espacios, acentos y símbolos automáticamente.
      pathSegments: texto.isEmpty ? ['cat'] : ['cat', 'says', texto],
      queryParameters: query,
    );
  }

  void _generar({bool nuevoGato = true}) {
    FocusScope.of(context).unfocus();
    setState(() {
      _texto = _controller.text;
      if (nuevoGato) _semilla = DateTime.now().millisecondsSinceEpoch;
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('🐱 Gato Memes'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              TextField(
                controller: _controller,
                textInputAction: TextInputAction.done,
                maxLength: 60,
                decoration: InputDecoration(
                  labelText: 'Escribe tu frase',
                  hintText: 'Ej. Lunes otra vez...',
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    tooltip: 'Limpiar',
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      _controller.clear();
                      _generar(nuevoGato: false);
                    },
                  ),
                ),
                onSubmitted: (_) => _generar(),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: _filtro,
                decoration: const InputDecoration(
                  labelText: 'Filtro',
                  border: OutlineInputBorder(),
                ),
                items: kFiltros.entries
                    .map((e) => DropdownMenuItem(
                          value: e.key,
                          child: Text(e.value),
                        ))
                    .toList(),
                onChanged: (v) {
                  setState(() => _filtro = v ?? '');
                  _generar(nuevoGato: false);
                },
              ),
              const SizedBox(height: 12),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    width: double.infinity,
                    color: Theme.of(context).colorScheme.surfaceContainerHighest,
                    child: Image.network(
                      _url.toString(),
                      key: ValueKey(_url.toString()),
                      fit: BoxFit.contain,
                      loadingBuilder: (context, child, progress) {
                        if (progress == null) return child;
                        return const Center(child: CircularProgressIndicator());
                      },
                      errorBuilder: (context, error, stack) => const Center(
                        child: Padding(
                          padding: EdgeInsets.all(16),
                          child: Text(
                            'No se pudo cargar el gato 😿\nRevisa tu conexión e intenta de nuevo.',
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _generar,
                      icon: const Icon(Icons.pets),
                      label: const Text('Generar meme'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
