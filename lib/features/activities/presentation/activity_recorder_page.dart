import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/theme/app_theme.dart';
import 'activity_map_view.dart';
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
  final _mapKey = GlobalKey<ActivityMapViewState>();
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
        await _mapKey.currentState?.moveTo(_session.points.last, zoom: 16);
        if (mounted) setState(() => _mapError = null);
        return;
      }

      final position = await Geolocator.getCurrentPosition();
      if (!mounted || !_mapReady) return;
      await _mapKey.currentState?.moveTo(
        LatLng(position.latitude, position.longitude),
        zoom: 16,
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
        await _mapKey.currentState?.moveTo(_session.points.last, zoom: 16.5);
        return;
      }
      final position = await Geolocator.getCurrentPosition();
      if (!mounted) return;
      await _mapKey.currentState?.moveTo(
        LatLng(position.latitude, position.longitude),
        zoom: 16.5,
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
            ActivityMapView(
              key: _mapKey,
              points: points,
              initialCenter: currentPoint,
              onReady: () {
                _mapReady = true;
                _prepareMap();
              },
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
                      style: TextStyle(color: Colors.white, fontSize: 12),
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
                watchReachable: _session.watchReachable,
              ),
            ),
            Positioned(
              right: 18,
              bottom: 300,
              child: FloatingActionButton.small(
                heroTag: 'locate',
                onPressed: _centerOnCurrentLocation,
                backgroundColor: AppColors.card,
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
                distanceLabel: _session.formattedDistance,
                pace: _session.formattedPace,
                heartRate: _session.formattedHeartRate,
                avgHeartRate: _session.formattedAvgHeartRate,
                maxHeartRate: _session.formattedMaxHeartRate,
                elevation: _session.formattedElevation,
                altitude: _session.formattedAltitude,
                calories: _session.formattedCalories,
                watchLinked: _session.watchReachable,
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
      await _mapKey.currentState?.moveTo(_session.points.last, zoom: 16);
      setState(() => _mapError = null);
    }
  }
}

class _LivePill extends StatelessWidget {
  const _LivePill({
    required this.isRecording,
    required this.elapsed,
    required this.watchReachable,
  });

  final bool isRecording;
  final String elapsed;
  final bool watchReachable;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: AppColors.card.withValues(alpha: .94),
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
            style: TextStyle(
              color: AppColors.ink,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
          const Spacer(),
          Icon(
            Icons.watch_rounded,
            size: 18,
            color: watchReachable
                ? const Color(0xFF2ECC71)
                : const Color(0xFFE74C3C),
          ),
          const SizedBox(width: 10),
          Text(
            elapsed,
            style: TextStyle(
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
    required this.distanceLabel,
    required this.pace,
    required this.heartRate,
    required this.avgHeartRate,
    required this.maxHeartRate,
    required this.elevation,
    required this.altitude,
    required this.calories,
    required this.watchLinked,
    required this.isRecording,
    required this.isBusy,
    required this.onPressed,
    this.onMinimize,
  });

  final String elapsed;
  final String distanceLabel;
  final String pace;
  final String heartRate;
  final String avgHeartRate;
  final String maxHeartRate;
  final String elevation;
  final String altitude;
  final String calories;
  final bool watchLinked;
  final bool isRecording;
  final bool isBusy;
  final VoidCallback onPressed;
  final VoidCallback? onMinimize;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 22),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 20)],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(
                Icons.watch_rounded,
                size: 22,
                color: watchLinked ? const Color(0xFF2ECC71) : const Color(0xFFE74C3C),
              ),
              const Spacer(),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _RecorderMetric(label: 'Süre', value: elapsed),
              _RecorderMetric(label: 'Mesafe', value: distanceLabel),
              _RecorderMetric(label: 'Tempo', value: pace),
              _RecorderMetric(label: 'Kalori', value: '$calories kcal'),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _RecorderMetric(label: 'Nabız', value: '$heartRate bpm'),
              _RecorderMetric(label: 'Ort.', value: avgHeartRate),
              _RecorderMetric(label: 'Max', value: maxHeartRate),
              _RecorderMetric(label: 'Yükseliş', value: elevation),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _RecorderMetric(label: 'İrtifa', value: altitude),
              const Spacer(),
              const Spacer(),
              const Spacer(),
            ],
          ),
          const SizedBox(height: 14),
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
                      side: BorderSide(color: AppColors.line),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
              ],
              Expanded(
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
          Text(label, style: TextStyle(color: AppColors.mutedInk, fontSize: 11)),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              color: AppColors.ink,
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
