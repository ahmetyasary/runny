import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/app_theme.dart';
import 'activity_session_controller.dart';

class ActivityRecorderPage extends StatefulWidget {
  const ActivityRecorderPage({
    super.key,
    required this.activityType,
    required this.session,
    this.onCompleted,
  });

  final String activityType;
  final ActivitySessionController session;
  final Future<void> Function(ActivityStopResult result)? onCompleted;

  @override
  State<ActivityRecorderPage> createState() => _ActivityRecorderPageState();
}

class _ActivityRecorderPageState extends State<ActivityRecorderPage> {
  final _mapController = MapController();
  bool _isLoadingLocation = false;
  bool _starting = false;
  bool _mapReady = false;
  String? _mapError;

  ActivitySessionController get _session => widget.session;

  @override
  void initState() {
    super.initState();
    _session.addListener(_onSessionChanged);
  }

  @override
  void dispose() {
    _session.removeListener(_onSessionChanged);
    super.dispose();
  }

  void _onSessionChanged() {
    if (!mounted) return;
    setState(() {});
    if (_mapReady && _session.points.isNotEmpty) {
      _mapController.move(_session.points.last, _mapController.camera.zoom);
    }
  }

  Future<void> _prepareMap() async {
    try {
      final enabled = await Geolocator.isLocationServiceEnabled();
      if (!enabled) {
        if (mounted) {
          setState(() => _mapError = 'Konum servisi kapalı.');
        }
        return;
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        if (mounted) {
          setState(() => _mapError = 'Konum izni gerekli.');
        }
        return;
      }

      if (_session.points.isNotEmpty) {
        _mapController.move(_session.points.last, 16);
        if (mounted) setState(() => _mapError = null);
        return;
      }

      final position = await Geolocator.getCurrentPosition();
      if (!mounted || !_mapReady) return;
      _mapController.move(
        LatLng(position.latitude, position.longitude),
        16,
      );
      setState(() => _mapError = null);
    } catch (_) {
      if (mounted) {
        setState(() => _mapError = 'Konum alınamadı.');
      }
    }
  }

  Future<void> _centerOnCurrentLocation() async {
    setState(() => _isLoadingLocation = true);
    try {
      if (_session.points.isNotEmpty) {
        _mapController.move(_session.points.last, 16.5);
        return;
      }
      final position = await Geolocator.getCurrentPosition();
      if (!mounted) return;
      _mapController.move(
        LatLng(position.latitude, position.longitude),
        16.5,
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Konum alınamadı.')),
      );
    } finally {
      if (mounted) setState(() => _isLoadingLocation = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const fallbackPoint = LatLng(41.0672, 29.0344);
    final points = _session.points;
    final currentPoint = points.isEmpty ? fallbackPoint : points.last;
    final routePoints = points.length >= 2 ? points : const <LatLng>[];

    return PopScope(
      canPop: !_session.isRecording,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (_session.isRecording) {
          _minimize();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.activityType),
          leading: IconButton(
            icon: Icon(
              _session.isRecording
                  ? Icons.keyboard_arrow_down_rounded
                  : Icons.arrow_back_rounded,
            ),
            onPressed: () {
              if (_session.isRecording) {
                _minimize();
              } else {
                Navigator.pop(context);
              }
            },
          ),
          actions: [
            if (_session.isRecording)
              TextButton(
                onPressed: _minimize,
                child: const Text('Küçült'),
              ),
          ],
        ),
        body: Stack(
          children: [
            FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: currentPoint,
                initialZoom: 15.5,
                onMapReady: () {
                  _mapReady = true;
                  _prepareMap();
                },
              ),
              children: [
                TileLayer(
                  // OSM ana sunucusu sık engellenir; Carto daha stabil.
                  urlTemplate:
                      'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}.png',
                  subdomains: const ['a', 'b', 'c', 'd'],
                  userAgentPackageName: 'com.smartlogy.runny',
                  maxZoom: 20,
                ),
                if (routePoints.isNotEmpty)
                  PolylineLayer(
                    polylines: [
                      Polyline(
                        points: routePoints,
                        color: AppColors.primaryDark,
                        strokeWidth: 5,
                      ),
                    ],
                  ),
                MarkerLayer(
                  markers: [
                    Marker(
                      point: currentPoint,
                      width: 28,
                      height: 28,
                      child: Container(
                        decoration: BoxDecoration(
                          color: AppColors.primaryDark,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 4),
                          boxShadow: const [
                            BoxShadow(color: Colors.black26, blurRadius: 8),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                RichAttributionWidget(
                  attributions: [
                    TextSourceAttribution(
                      '© OpenStreetMap, © CARTO',
                      onTap: () => launchUrl(
                        Uri.parse('https://www.openstreetmap.org/copyright'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            if (_mapError != null)
              Positioned(
                top: 70,
                left: 18,
                right: 18,
                child: Material(
                  color: Colors.black.withValues(alpha: .72),
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    child: Text(
                      _mapError!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ),
                ),
              ),
            Positioned(
              top: 18,
              left: 18,
              right: 18,
              child: _LivePill(
                isRecording: _session.isRecording,
                elapsed: _session.formattedElapsed,
              ),
            ),
            Positioned(
              right: 18,
              bottom: 210,
              child: FloatingActionButton.small(
                heroTag: 'locate',
                onPressed: _centerOnCurrentLocation,
                backgroundColor: Colors.white,
                foregroundColor: AppColors.ink,
                child: _isLoadingLocation
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.my_location_rounded),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: _RecorderPanel(
                elapsed: _session.formattedElapsed,
                distance: _session.distanceMeters,
                isRecording: _session.isRecording,
                isBusy: _starting,
                onPressed: _toggleRecording,
                onMinimize: _session.isRecording ? _minimize : null,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _minimize() {
    _session.minimize();
    Navigator.pop(context);
  }

  Future<void> _toggleRecording() async {
    if (_session.isRecording) {
      final result = await _session.stop();
      await widget.onCompleted?.call(result);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.message)),
      );
      Navigator.pop(context);
      return;
    }

    setState(() => _starting = true);
    final started = await _session.start(widget.activityType);
    if (!mounted) return;
    setState(() => _starting = false);
    if (!started) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Konum alınamadı. İzinleri ve konum servisini kontrol et.'),
        ),
      );
      return;
    }
    if (_mapReady && _session.points.isNotEmpty) {
      _mapController.move(_session.points.last, 16);
      setState(() => _mapError = null);
    }
  }
}

class _LivePill extends StatelessWidget {
  const _LivePill({required this.isRecording, required this.elapsed});

  final bool isRecording;
  final String elapsed;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .94),
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 12)],
      ),
      child: Row(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            width: 9,
            height: 9,
            decoration: BoxDecoration(
              color: isRecording ? Colors.redAccent : AppColors.orange,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            isRecording ? 'Kayıt devam ediyor' : 'Kayıt başlamadı',
            style: const TextStyle(
              color: AppColors.ink,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
          const Spacer(),
          Text(
            elapsed,
            style: const TextStyle(
              color: AppColors.primaryDark,
              fontWeight: FontWeight.w800,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}

class _RecorderPanel extends StatelessWidget {
  const _RecorderPanel({
    required this.elapsed,
    required this.distance,
    required this.isRecording,
    required this.isBusy,
    required this.onPressed,
    this.onMinimize,
  });

  final String elapsed;
  final double distance;
  final bool isRecording;
  final bool isBusy;
  final VoidCallback onPressed;
  final VoidCallback? onMinimize;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(22, 20, 22, 25),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 20)],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              _RecorderMetric(label: 'Süre', value: elapsed),
              _RecorderMetric(
                label: 'Mesafe',
                value: '${(distance / 1000).toStringAsFixed(2)} km',
              ),
              const _RecorderMetric(label: 'Tempo', value: '--:--'),
            ],
          ),
          const SizedBox(height: 19),
          Row(
            children: [
              if (onMinimize != null) ...[
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onMinimize,
                    icon: const Icon(Icons.picture_in_picture_alt_rounded),
                    label: const Text('Yüzdür'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.ink,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      side: const BorderSide(color: AppColors.line),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
              ],
              Expanded(
                flex: onMinimize == null ? 1 : 1,
                child: FilledButton.icon(
                  onPressed: isBusy ? null : onPressed,
                  icon: isBusy
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Icon(
                          isRecording
                              ? Icons.stop_rounded
                              : Icons.play_arrow_rounded,
                        ),
                  label: Text(
                    isRecording ? 'Aktiviteyi bitir' : 'Aktiviteyi başlat',
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor:
                        isRecording ? Colors.redAccent : AppColors.primaryDark,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RecorderMetric extends StatelessWidget {
  const _RecorderMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(label, style: const TextStyle(color: AppColors.mutedInk, fontSize: 11)),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              color: AppColors.ink,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}
