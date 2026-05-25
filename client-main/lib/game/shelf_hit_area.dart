import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';

class ShelfHitArea extends PositionComponent
    with HasGameRef<FlameGame>, TapCallbacks {
  final void Function() onTapShelf;

  ShelfHitArea({
    required Vector2 position,
    required Vector2 size,
    required this.onTapShelf,
  }) : super(position: position, size: size, priority: 100);

  @override
  void onTapDown(TapDownEvent event) {
    onTapShelf();
  }
}