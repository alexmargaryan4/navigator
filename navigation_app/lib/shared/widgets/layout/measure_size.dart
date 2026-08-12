import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// Wraps [child] and reports its rendered [Size] after every layout pass
/// via [onChange], without affecting the child's own size or position.
///
/// Used where a sibling needs to react to a widget's *actual* height —
/// e.g. keeping a floating control stack pinned above a bottom sheet
/// whose height depends on its content (route count, error text, etc.)
/// rather than a hand-picked constant that drifts out of sync and lets
/// the sheet overlap the controls.
class MeasureSize extends SingleChildRenderObjectWidget {
  const MeasureSize({
    super.key,
    required this.onChange,
    required Widget super.child,
  });

  final ValueChanged<Size> onChange;

  @override
  _MeasureSizeRenderObject createRenderObject(BuildContext context) {
    return _MeasureSizeRenderObject(onChange);
  }

  @override
  void updateRenderObject(
      BuildContext context, _MeasureSizeRenderObject renderObject) {
    renderObject.onChange = onChange;
  }
}

class _MeasureSizeRenderObject extends RenderProxyBox {
  _MeasureSizeRenderObject(this.onChange);

  ValueChanged<Size> onChange;
  Size? _oldSize;

  @override
  void performLayout() {
    super.performLayout();
    final newSize = child?.size;
    if (newSize != null && newSize != _oldSize) {
      _oldSize = newSize;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        onChange(newSize);
      });
    }
  }
}
