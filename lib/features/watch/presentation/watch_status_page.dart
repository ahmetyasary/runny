import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../data/watch_bridge.dart';

class WatchStatusPage extends StatefulWidget {
  const WatchStatusPage({super.key});

  @override
  State<WatchStatusPage> createState() => _WatchStatusPageState();
}

class _WatchStatusPageState extends State<WatchStatusPage> {
  WatchStatus _status = const WatchStatus.unsupported();
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _refresh();
    WatchBridge.ensureListening();
    WatchBridge.events.listen((event) {
      if (event.type == WatchEventType.statusChanged && mounted) {
        _refresh();
      }
    });
  }

  Future<void> _refresh() async {
    setState(() => _loading = true);
    final status = await WatchBridge.getStatus();
    if (!mounted) return;
    setState(() {
      _status = status;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Apple Watch'),
        actions: [
          IconButton(
            onPressed: _refresh,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.line),
            ),
            child: _loading
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(12),
                      child: CircularProgressIndicator(),
                    ),
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.watch_rounded,
                            color: _status.isConnected
                                ? AppColors.primaryDark
                                : AppColors.mutedInk,
                            size: 28,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              _status.label,
                              style: const TextStyle(
                                color: AppColors.ink,
                                fontWeight: FontWeight.w800,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _StatusRow(label: 'Destekleniyor', value: _status.supported),
                      _StatusRow(label: 'Eşleşmiş', value: _status.paired),
                      _StatusRow(
                        label: 'Watch uygulaması',
                        value: _status.appInstalled,
                      ),
                      _StatusRow(label: 'Ulaşılabilir', value: _status.reachable),
                    ],
                  ),
          ),
          const SizedBox(height: 18),
          const Text(
            'Nasıl çalışır?',
            style: TextStyle(
              color: AppColors.ink,
              fontWeight: FontWeight.w800,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Telefon aktivite başlatınca süre ve mesafe saate iletilir. '
            'Saatten de aktivite başlatıp durdurabilirsin.\n\n'
            'Watch uygulamasını Xcode ile bir kez eklemen gerekir: '
            'ios/RunnyWatch klasöründeki SwiftUI kaynakları hazır.',
            style: TextStyle(color: AppColors.mutedInk, height: 1.45),
          ),
        ],
      ),
    );
  }
}

class _StatusRow extends StatelessWidget {
  const _StatusRow({required this.label, required this.value});

  final String label;
  final bool value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(color: AppColors.mutedInk, fontSize: 13),
            ),
          ),
          Icon(
            value ? Icons.check_circle_rounded : Icons.cancel_outlined,
            size: 18,
            color: value ? AppColors.primaryDark : AppColors.mutedInk,
          ),
        ],
      ),
    );
  }
}
