import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'dart:ui' show FilterQuality;
import 'package:flutter/material.dart' show Paint;

class ShelfCapsuleComponent extends SpriteComponent
    with HasGameRef<FlameGame> {
  final String capsuleId;
  final int slotIndex;
  final String design;

  ShelfCapsuleComponent({
    required this.capsuleId,
    required this.slotIndex,
    this.design = 'base',
  }) : super(anchor: Anchor.center);

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    paint = Paint()..filterQuality = FilterQuality.none;
    sprite = await Sprite.load('capsule/$design/south-east.png');
  }
}