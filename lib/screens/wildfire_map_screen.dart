// Final optimized version: Efficient marker handling and clustering for large datasets
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_marker_cluster/flutter_map_marker_cluster.dart';
import 'package:latlong2/latlong.dart';
import '../services/firms_service.dart';
import '../models/fire_point.dart';

class WildfireMapScreen extends StatefulWidget {
  const WildfireMapScreen({super.key});

  @override
  State<WildfireMapScreen> createState() => _WildfireMapScreenState();
}

class _WildfireMapScreenState extends State<WildfireMapScreen> {
  List<Marker> allMarkers = [];
  String selectedSensor = 'VIIRS_ALL';
  int selectedDay = 1;
  bool isSatellite = true;
  double mapZoom = 5.0;
  bool showClusters = true;
  bool isLoading = false;
  LatLngBounds? currentBounds;
  final Distance distance = Distance();

  final sensorOptions = {
    'VIIRS_ALL': 'VIIRS (Tümü)',
    'VIIRS_SNPP_NRT': 'VIIRS (S-NPP)',
    'VIIRS_NOAA20_NRT': 'VIIRS (NOAA-20)',
    'VIIRS_NOAA21_NRT': 'VIIRS (NOAA-21)',
  };

  final dayOptions = [1, 3, 7];

  // Performance optimization: adaptive marker limits based on device performance
  int get _maxMarkers {
    // Remove strict limits - show all data but with performance optimizations
    if (selectedDay == 1) return 2000;
    if (selectedDay == 3) return 3000;
    return 5000; // 7 days - show more data
  }

  // Adaptive clustering based on zoom and data density
  bool get _shouldUseClustering {
    if (allMarkers.length < 100) return false; // Small dataset, no clustering
    if (mapZoom >= 8) return false; // Close zoom, show individual markers
    return true; // Use clustering for performance
  }

  // Dynamic cluster radius based on zoom and data density
  int get _clusterRadius {
    if (mapZoom < 4) return 80; // Very zoomed out - larger clusters
    if (mapZoom < 6) return 60; // Zoomed out
    if (mapZoom < 8) return 40; // Medium zoom
    return 30; // Close zoom - smaller clusters
  }

  @override
  void initState() {
    super.initState();
    _loadFireData();
  }

  Future<void> _loadFireData() async {
    setState(() => isLoading = true);

    try {
      final fireData = await _fetchFireData();
      final optimizedMarkers = await _generateOptimizedMarkers(fireData);

      setState(() {
        allMarkers = optimizedMarkers;
        isLoading = false;
      });
    } catch (e) {
      setState(() => isLoading = false);
      print('Error loading fire data: $e');
    }
  }

  Future<Map<String, List<FirePoint>>> _fetchFireData() async {
    List<FirePoint> densityFires = [];
    List<FirePoint> visibleFires = [];

    if (selectedSensor == 'VIIRS_ALL') {
      final sensors = [
        'VIIRS_SNPP_NRT',
        'VIIRS_NOAA20_NRT',
        'VIIRS_NOAA21_NRT',
      ];
      final allFutures = [
        ...sensors.map((s) => FirmsService.fetchFires(source: s, dayRange: 7)),
        ...sensors.map(
          (s) => FirmsService.fetchFires(source: s, dayRange: selectedDay),
        ),
      ];
      final results = await Future.wait(allFutures);
      densityFires = results.take(3).expand((e) => e).toList();
      visibleFires = results.skip(3).expand((e) => e).toList();
    } else {
      final results = await Future.wait([
        FirmsService.fetchFires(source: selectedSensor, dayRange: 7),
        FirmsService.fetchFires(source: selectedSensor, dayRange: selectedDay),
      ]);
      densityFires = results[0];
      visibleFires = results[1];
    }

    return {'density': densityFires, 'visible': visibleFires};
  }

  Future<List<Marker>> _generateOptimizedMarkers(
    Map<String, List<FirePoint>> fireData,
  ) async {
    final densityFires = fireData['density']!;
    final visibleFires = fireData['visible']!;

    // 1. Viewport filtering only
    final viewportFiltered = _filterByViewport(visibleFires);
    _logPerformance('Viewport filtering', viewportFiltered.length);

    // 2. Generate markers with performance optimizations
    final markers = viewportFiltered.map((fire) {
      final nearbyCount = densityFires.where((other) {
        if (other == fire) return false;
        final latDiff = (fire.latitude - other.latitude).abs();
        final lngDiff = (fire.longitude - other.longitude).abs();
        return latDiff < 0.3 && lngDiff < 0.3; // ~30km
      }).length;

      return _createMarkerWithDialog(fire, nearbyCount);
    }).toList();

    _logPerformance('Marker generation', markers.length);
    return markers;
  }

  List<FirePoint> _filterByViewport(List<FirePoint> fires) {
    if (currentBounds == null) {
      // For longer day ranges, show more data even without bounds
      if (selectedDay == 7) {
        // Show fires in a wider area for 7 days
        return fires
            .where(
              (f) =>
                  f.latitude >= 30 &&
                  f.latitude <= 48 &&
                  f.longitude >= 20 &&
                  f.longitude <= 50,
            )
            .toList();
      } else if (selectedDay == 3) {
        // Show fires in Turkey and nearby regions for 3 days
        return fires
            .where(
              (f) =>
                  f.latitude >= 35 &&
                  f.latitude <= 43 &&
                  f.longitude >= 25 &&
                  f.longitude <= 45,
            )
            .toList();
      } else {
        // Show only Turkey for 1 day
        return fires
            .where((f) => _isInsideTurkey(f.latitude, f.longitude))
            .toList();
      }
    }

    // If we have bounds, use them but still apply day-based logic
    return fires.where((fire) {
      final point = LatLng(fire.latitude, fire.longitude);
      return currentBounds!.contains(point);
    }).toList();
  }

  bool _isInsideTurkey(double lat, double lng) {
    return lat >= 35 && lat <= 43 && lng >= 25 && lng <= 45;
  }

  String get _mapTileUrl => isSatellite
      ? 'https://services.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}'
      : 'https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}{r}.png';

  Color densityColor(int count) {
    if (count >= 20) return Colors.red;
    if (count >= 10) return Colors.orange;
    return Colors.yellow;
  }

  // Dynamic cluster color based on marker count
  Color _getClusterColor(int markerCount) {
    if (markerCount >= 100) return Colors.red.withOpacity(0.9);
    if (markerCount >= 50) return Colors.orange.withOpacity(0.8);
    if (markerCount >= 20) return Colors.deepOrange.withOpacity(0.7);
    return Colors.red.withOpacity(0.6);
  }

  double _markerSize() {
    // Base size by day range - longer ranges get slightly larger markers
    double baseSize;
    if (selectedDay == 1)
      baseSize = 4;
    else if (selectedDay == 3)
      baseSize = 5;
    else
      baseSize = 6; // 7 days

    // Apply zoom scaling
    if (mapZoom < 4) return baseSize + 2; // Very zoomed out - larger markers
    if (mapZoom < 6) return baseSize + 1;
    if (mapZoom < 8) return baseSize;
    return baseSize - 1; // Close zoom - smaller markers
  }

  void _showFireDialog(FirePoint fire) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Yangın Detayı"),
        content: Text('''
🚀 Uydu: ${fire.satellite}
📍 Konum: ${fire.latitude.toStringAsFixed(2)}, ${fire.longitude.toStringAsFixed(2)}
🔥 Parlaklık: ${fire.brightness}
⚡ FRP: ${fire.frp} MW
📊 Güven: ${fire.confidence}
🍗 Görünüm: ${fire.daynight == 'D' ? 'Gündüz' : 'Gece'}
🗓 Tarih: ${fire.date} ${fire.time}
'''),
        actions: [
          TextButton(
            child: const Text('Kapat'),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  // Create marker with proper tap handling and performance optimization
  Marker _createMarkerWithDialog(FirePoint fire, int nearbyCount) {
    final color = densityColor(nearbyCount);
    final size = _markerSize();

    return Marker(
      width: 16, // Smaller marker for better performance
      height: 16,
      point: LatLng(fire.latitude, fire.longitude),
      child: CustomPaint(
        painter: FireMarkerPainter(color: color, size: size),
        child: GestureDetector(
          onTap: () => _showFireDialog(fire),
          behavior: HitTestBehavior.opaque, // Better touch detection
        ),
      ),
    );
  }

  // Performance monitoring
  void _logPerformance(String operation, int dataSize) {
    if (dataSize > 1000) {
      print('Performance: $operation with $dataSize items');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Wildfire Map'),
        actions: [
          IconButton(
            icon: Icon(showClusters ? Icons.blur_circular : Icons.scatter_plot),
            tooltip: showClusters ? 'Nokta Modu' : 'Küme Modu',
            onPressed: () => setState(() => showClusters = !showClusters),
          ),
          IconButton(
            icon: Icon(isSatellite ? Icons.map : Icons.satellite),
            onPressed: () => setState(() => isSatellite = !isSatellite),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: selectedSensor,
                    items: sensorOptions.entries
                        .map(
                          (entry) => DropdownMenuItem(
                            value: entry.key,
                            child: Text(entry.value),
                          ),
                        )
                        .toList(),
                    decoration: const InputDecoration(labelText: 'Sensor'),
                    onChanged: (val) {
                      if (val != null) {
                        setState(() => selectedSensor = val);
                        _loadFireData();
                      }
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<int>(
                    value: selectedDay,
                    items: dayOptions
                        .map(
                          (day) => DropdownMenuItem(
                            value: day,
                            child: Text('$day Days'),
                          ),
                        )
                        .toList(),
                    decoration: const InputDecoration(labelText: 'Range'),
                    onChanged: (val) {
                      if (val != null) {
                        setState(() => selectedDay = val);
                        _loadFireData();
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : FlutterMap(
                    options: MapOptions(
                      center: const LatLng(39.0, 35.0),
                      zoom: mapZoom,
                      onPositionChanged: (pos, _) {
                        if (pos.zoom != null) {
                          final newZoom = pos.zoom!;
                          final newBounds = pos.bounds;

                          setState(() {
                            mapZoom = newZoom;
                            currentBounds = newBounds;
                          });

                          // Only reload data if zoom changed significantly (more than 2 levels)
                          if ((newZoom - mapZoom).abs() > 2.0) {
                            _loadFireData();
                          }
                        }
                      },
                      interactionOptions: const InteractionOptions(
                        flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
                      ),
                    ),
                    children: [
                      TileLayer(
                        urlTemplate: _mapTileUrl,
                        subdomains: ['a', 'b', 'c'],
                        userAgentPackageName: 'com.example.wildfire_map_app',
                      ),
                      if (showClusters)
                        MarkerClusterLayerWidget(
                          options: MarkerClusterLayerOptions(
                            maxClusterRadius: _clusterRadius,
                            size: const Size(50, 50),
                            markers: allMarkers,
                            builder: (context, clusterMarkers) {
                              // Smart clustering based on data density
                              if (mapZoom >= 8 && clusterMarkers.length <= 3) {
                                return const SizedBox.shrink(); // Hide small clusters at close zoom
                              }

                              // Adaptive cluster size based on marker count
                              final clusterSize = clusterMarkers.length > 50
                                  ? 60.0
                                  : 50.0;

                              return Container(
                                width: clusterSize,
                                height: clusterSize,
                                decoration: BoxDecoration(
                                  color: _getClusterColor(
                                    clusterMarkers.length,
                                  ),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.white,
                                    width: 2,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.3),
                                      blurRadius: 4,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Center(
                                  child: Text(
                                    '${clusterMarkers.length}',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: clusterMarkers.length > 100
                                          ? 10
                                          : 12,
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        )
                      else
                        MarkerLayer(markers: allMarkers),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

// CustomPainter for optimized marker rendering
class FireMarkerPainter extends CustomPainter {
  final Color color;
  final double size;

  FireMarkerPainter({required this.color, required this.size});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final rect = Rect.fromCenter(
      center: Offset(size.width / 2, size.height / 2),
      width: this.size,
      height: this.size,
    );

    canvas.drawRect(rect, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
