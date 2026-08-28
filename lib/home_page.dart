import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:rtmp_broadcaster/rtmp_broadcaster.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with WidgetsBindingObserver {
  CameraController? _controller;
  List<CameraDescription> _cameras = [];

  bool _initialized = false;
  bool _streaming = false;
  bool _frontCamera = true;

  String _status = 'Pronto';
  String _localIp = '';

  final _ipController = TextEditingController();
  final _portController = TextEditingController(text: '1935');

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadPrefs();
    _initCamera();
    _fetchLocalIp();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.dispose();
    _ipController.dispose();
    _portController.dispose();
    WakelockPlus.disable();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive && _streaming) {
      _stopStream();
    }
  }

  Future<void> _loadPrefs() async {
    final p = await SharedPreferences.getInstance();
    setState(() {
      _ipController.text = p.getString('pc_ip') ?? '';
      _portController.text = p.getString('port') ?? '1935';
    });
  }

  Future<void> _savePrefs() async {
    final p = await SharedPreferences.getInstance();
    await p.setString('pc_ip', _ipController.text.trim());
    await p.setString('port', _portController.text.trim());
  }

  Future<void> _initCamera() async {
    try {
      _cameras = await availableCameras();
      if (_cameras.isEmpty) {
        _setStatus('Nenhuma câmera encontrada');
        return;
      }

      final cam = _cameras.firstWhere(
            (c) => c.lensDirection ==
            (_frontCamera
                ? CameraLensDirection.front
                : CameraLensDirection.back),
        orElse: () => _cameras.first,
      );

      final controller = CameraController(
        cam,
        ResolutionPreset.high,
        enableAudio: true,
      );

      await controller.initialize();

      if (!mounted) return;
      setState(() {
        _controller = controller;
        _initialized = true;
        _status = 'Câmera pronta';
      });
    } catch (e) {
      _setStatus('Erro câmera: $e');
    }
  }

  Future<void> _switchCamera() async {
    if (_streaming) return;
    setState(() => _frontCamera = !_frontCamera);
    await _controller?.dispose();
    setState(() {
      _controller = null;
      _initialized = false;
    });
    await _initCamera();
  }

  Future<void> _fetchLocalIp() async {
    final info = NetworkInfo();
    final ip = await info.getWifiIP();
    setState(() => _localIp = ip ?? 'desconhecido');
  }

  String get _rtmpUrl {
    final ip = _ipController.text.trim();
    final port = _portController.text.trim();
    return 'rtmp://$ip:$port/live';
  }

  Future<void> _startStream() async {
    if (!_initialized || _controller == null) return;

    if (_ipController.text.trim().isEmpty) {
      _showSnack('Digite o IP do PC');
      return;
    }

    await _savePrefs();
    _setStatus('Conectando...');

    try {
      await _controller!.startVideoStreaming(
        _rtmpUrl,
        bitrate: 1500 * 1024,
      );
      WakelockPlus.enable();
      setState(() => _streaming = true);
      _setStatus('Transmitindo 🔴');
    } on CameraException catch (e) {
      _setStatus('Erro: ${e.description}');
    }
  }

  Future<void> _stopStream() async {
    try {
      await _controller?.stopEverything();
    } catch (_) {}
    WakelockPlus.disable();
    setState(() {
      _streaming = false;
      _status = 'Parado';
    });
  }

  void _setStatus(String s) {
    if (mounted) setState(() => _status = s);
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  void _copyRtmpUrl() {
    Clipboard.setData(ClipboardData(text: _rtmpUrl));
    _showSnack('URL copiada: $_rtmpUrl');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            _buildPreview(),
            Expanded(child: _buildControls()),
          ],
        ),
      ),
    );
  }

  Widget _buildPreview() {
    return Expanded(
      flex: 5,
      child: Stack(
        fit: StackFit.expand,
        children: [
          _initialized && _controller != null
              ? CameraPreview(_controller!)
              : const Center(child: CircularProgressIndicator()),

          if (_streaming)
            Positioned(
              top: 12,
              left: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.red,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  '● LIVE',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
            ),

          Positioned(
            bottom: 8,
            right: 8,
            child: IconButton(
              icon: const Icon(Icons.flip_camera_android, color: Colors.white, size: 28),
              onPressed: _streaming ? null : _switchCamera,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildControls() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                flex: 3,
                child: TextField(
                  controller: _ipController,
                  enabled: !_streaming,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'IP do PC',
                    hintText: '192.168.1.x',
                    prefixIcon: Icon(Icons.computer),
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 80,
                child: TextField(
                  controller: _portController,
                  enabled: !_streaming,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Porta',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),

          Row(
            children: [
              const Icon(Icons.link, size: 16, color: Colors.grey),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  _rtmpUrl,
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.copy, size: 16),
                onPressed: _copyRtmpUrl,
                tooltip: 'Copiar URL',
              ),
            ],
          ),

          Text(
            'IP deste celular: $_localIp',
            style: const TextStyle(color: Colors.grey, fontSize: 12),
          ),

          const SizedBox(height: 16),

          SizedBox(
            height: 52,
            child: ElevatedButton.icon(
              onPressed: _initialized
                  ? (_streaming ? _stopStream : _startStream)
                  : null,
              icon: Icon(_streaming ? Icons.stop : Icons.videocam),
              label: Text(
                _streaming ? 'Parar transmissão' : 'Iniciar transmissão',
                style: const TextStyle(fontSize: 16),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: _streaming ? Colors.red : Colors.deepPurple,
                foregroundColor: Colors.white,
              ),
            ),
          ),

          const SizedBox(height: 12),

          Center(
            child: Text(
              _status,
              style: TextStyle(
                color: _streaming ? Colors.greenAccent : Colors.grey,
                fontSize: 13,
              ),
            ),
          ),

          const SizedBox(height: 16),

          const _ObsInstructions(),
        ],
      ),
    );
  }
}

class _ObsInstructions extends StatelessWidget {
  const _ObsInstructions();

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.grey[900],
      child: const ExpansionTile(
        title: Text('Como configurar no OBS', style: TextStyle(fontSize: 13)),
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Step('1', 'OBS → Fontes → + → Mídia'),
                _Step('2', 'Desmarque "Arquivo local"'),
                _Step('3', 'Input: rtmp://localhost:1935/live'),
                _Step('4', 'Marque "Loop" e "Reconectar ao terminar"'),
                _Step('5', 'Inicie o stream no app → clique ▶ na fonte'),
                _Step('6', 'Ferramentas → Virtual Camera → Iniciar'),
                _Step('USB', 'Execute setup.py no PC antes de conectar'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Step extends StatelessWidget {
  final String num;
  final String text;
  const _Step(this.num, this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 32,
            child: Text(
              num,
              style: const TextStyle(
                color: Colors.deepPurpleAccent,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}