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
    this.fitRoute = false,
    this.interactive = true,
  });

  final List<ll.LatLng> points;
  final ll.LatLng initialCenter;
  final VoidCallback? onReady;
  final bool fitRoute;
  final bool interactive;

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

  Future<void> fitToRoute() async {
    final route = widget.points;
    if (route.length < 2) return;

    var minLat = route.first.latitude;
    var maxLat = route.first.latitude;
    var minLng = route.first.longitude;
    var maxLng = route.first.longitude;
    for (final p in route) {
      if (p.latitude < minLat) minLat = p.latitude;
      if (p.latitude > maxLat) maxLat = p.latitude;
      if (p.longitude < minLng) minLng = p.longitude;
      if (p.longitude > maxLng) maxLng = p.longitude;
    }
    // Tek nokta / çok kısa rota için padding
    if ((maxLat - minLat).abs() < 1e-5) {
      minLat -= 0.002;
      maxLat += 0.002;
    }
    if ((maxLng - minLng).abs() < 1e-5) {
      minLng -= 0.002;
      maxLng += 0.002;
    }

    if (Platform.isIOS) {
      await _apple?.moveCamera(
        am.CameraUpdate.newLatLngBounds(
          am.LatLngBounds(
            southwest: am.LatLng(minLat, minLng),
            northeast: am.LatLng(maxLat, maxLng),
          ),
          48,
        ),
      );
      return;
    }

    final bounds = LatLngBounds(
      ll.LatLng(minLat, minLng),
      ll.LatLng(maxLat, maxLng),
    );
    _flutterMap?.fitCamera(
      CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.all(36)),
    );
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
      myLocationEnabled: widget.interactive,
      myLocationButtonEnabled: false,
      compassEnabled: widget.interactive,
      rotateGesturesEnabled: widget.interactive,
      pitchGesturesEnabled: widget.interactive,
      scrollGesturesEnabled: widget.interactive,
      zoomGesturesEnabled: widget.interactive,
      trackingMode: am.TrackingMode.none,
      onMapCreated: (controller) async {
        _apple = controller;
        _ready = true;
        if (widget.fitRoute) {
          await fitToRoute();
        }
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
        if (route.isNotEmpty)
          am.Circle(
            circleId: am.CircleId('start'),
            center: am.LatLng(route.first.latitude, route.first.longitude),
            radius: 10,
            fillColor: AppColors.orange,
            strokeColor: Colors.white,
            strokeWidth: 2,
          ),
        am.Circle(
          circleId: am.CircleId('end'),
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
        interactionOptions: InteractionOptions(
          flags: widget.interactive
              ? InteractiveFlag.all
              : InteractiveFlag.none,
        ),
        onMapReady: () async {
          _ready = true;
          if (widget.fitRoute) {
            await fitToRoute();
          }
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
            if (route.isNotEmpty)
              Marker(
                point: route.first,
                width: 18,
                height: 18,
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.orange,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 3),
                  ),
                ),
              ),
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
