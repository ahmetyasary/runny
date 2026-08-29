import 'dart:io';

import 'package:apple_maps_flutter/apple_maps_flutter.dart' as am;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' as ll;

import '../../../core/theme/app_theme.dart';

/// iOS: native Apple MapKit (ücretsiz, API key yok).
/// Android: raster tile fallback (Esri World Street Map).
class ActivityMapView extends StatefulWidget {
  const ActivityMapView({
    super.key,
    required this.points,
    required this.initialCenter,
    this.onReady,
  });

  final List<ll.LatLng> points;
  final ll.LatLng initialCenter;
  final VoidCallback? onReady;

  @override
  State<ActivityMapView> createState() => ActivityMapViewState();
}

class ActivityMapViewState extends State<ActivityMapView> {
  am.AppleMapController? _apple;
  MapController? _flutterMap;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    if (!Platform.isIOS) {
      _flutterMap = MapController();
    }
  }

  @override
  void didUpdateWidget(covariant ActivityMapView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_ready || widget.points.isEmpty) return;
    final last = widget.points.last;
    final oldLast =
        oldWidget.points.isEmpty ? null : oldWidget.points.last;
    if (oldLast != null &&
        oldLast.latitude == last.latitude &&
        oldLast.longitude == last.longitude) {
      return;
    }
    moveTo(last, zoom: 16);
  }

  Future<void> moveTo(ll.LatLng point, {double zoom = 16.5}) async {
    if (Platform.isIOS) {
      await _apple?.animateCamera(
        am.CameraUpdate.newLatLngZoom(
          am.LatLng(point.latitude, point.longitude),
          zoom,
        ),
      );
      return;
    }
    _flutterMap?.move(point, zoom);
  }

  @override
  Widget build(BuildContext context) {
    if (Platform.isIOS) {
      return _buildAppleMap();
    }
    return _buildFlutterMap();
  }

  Widget _buildAppleMap() {
    final route = widget.points;
    final center = route.isEmpty ? widget.initialCenter : route.last;
    final applePoints = [
      for (final p in route) am.LatLng(p.latitude, p.longitude),
    ];

    return am.AppleMap(
      initialCameraPosition: am.CameraPosition(
        target: am.LatLng(center.latitude, center.longitude),
        zoom: 15.5,
      ),
      mapType: am.MapType.standard,
      myLocationEnabled: true,
      myLocationButtonEnabled: false,
      compassEnabled: true,
      rotateGesturesEnabled: true,
      pitchGesturesEnabled: true,
      trackingMode: am.TrackingMode.none,
      onMapCreated: (controller) {
        _apple = controller;
        _ready = true;
        widget.onReady?.call();
      },
      polylines: route.length >= 2
          ? {
              am.Polyline(
                polylineId: am.PolylineId('route'),
                points: applePoints,
                color: AppColors.primaryDark,
                width: 5,
                polylineCap: am.Cap.roundCap,
                jointType: am.JointType.round,
              ),
            }
          : {},
      circles: {
        am.Circle(
          circleId: am.CircleId('me'),
          center: am.LatLng(center.latitude, center.longitude),
          radius: 12,
          fillColor: AppColors.primaryDark.withValues(alpha: 0.95),
          strokeColor: Colors.white,
          strokeWidth: 3,
        ),
      },
    );
  }

  Widget _buildFlutterMap() {
    final route = widget.points;
    final center = route.isEmpty ? widget.initialCenter : route.last;

    return FlutterMap(
      mapController: _flutterMap,
      options: MapOptions(
        initialCenter: center,
        initialZoom: 15.5,
        onMapReady: () {
          _ready = true;
          widget.onReady?.call();
        },
      ),
      children: [
        TileLayer(
          // Esri public basemap — no API key (Android fallback).
          urlTemplate:
              'https://server.arcgisonline.com/ArcGIS/rest/services/World_Street_Map/MapServer/tile/{z}/{y}/{x}',
          userAgentPackageName: 'com.smartlogy.runny',
          maxZoom: 19,
        ),
        if (route.length >= 2)
          PolylineLayer(
            polylines: [
              Polyline(
                points: route,
                color: AppColors.primaryDark,
                strokeWidth: 5,
              ),
            ],
          ),
        MarkerLayer(
          markers: [
            Marker(
              point: center,
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
      ],
    );
  }
}
