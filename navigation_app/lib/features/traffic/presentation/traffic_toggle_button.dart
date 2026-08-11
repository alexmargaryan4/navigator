import 'package:flutter/material.dart';

import '../mapbox_map_controller.dart';
import 'map_action_button.dart';

/// Toggles the live Mapbox traffic vector-tile overlay on the base map
/// (product spec §42) directly through [MapboxMapController].
///
/// The overlay itself is real, always-on traffic data rendered by the
/// map engine — this widget only owns the on/off UI state and the
/// smooth fade the overlay performs internally as sources/layers are
/// added or removed.
class TrafficToggleButton extends StatefulWidget {
  const TrafficToggleButton({super.key, required this.controller});

  final MapboxMapController? controller;

  @override
  State<TrafficToggleButton> createState() => _TrafficToggleButtonState();
}

class _TrafficToggleButtonState extends State<TrafficToggleButton> {
  bool _visible = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _visible = widget.controller?.isTrafficVisible ?? false;
  }

  Future<void> _toggle() async {
    final controller = widget.controller;
    if (controller == null || _busy) return;

    setState(() => _busy = true);
    final next = !_visible;
    await controller.setTrafficVisible(next);
    if (!mounted) return;
    setState(() {
      _visible = next;
      _busy = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MapActionButton(
      icon: Icons.traffic_rounded,
      tooltip: _visible ? 'Hide traffic' : 'Show traffic',
      isActive: _visible,
      onTap: _toggle,
    );
  }
}
