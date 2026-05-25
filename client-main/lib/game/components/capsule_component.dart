import 'dart:async';
import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:flame/game.dart';
import 'package:flutter/animation.dart';

class CapsuleComponent extends SpriteComponent with HasGameRef<FlameGame> {
  CapsuleComponent() : super(size: Vector2(55, 55), anchor: Anchor.center);

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    sprite = await Sprite.load('capsule/base/south.png');
  }

  Future<void> fallTo(Vector2 target) {
    final completer = Completer<void>();
    add(MoveEffect.to(
      target,
      EffectController(duration: 0.85, curve: Curves.bounceOut),
      onComplete: completer.complete,
    ));
    return completer.future;
  }
}