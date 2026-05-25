import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart' show Paint;
import 'dart:ui' show FilterQuality;


class RoomBackground extends PositionComponent with HasGameRef<FlameGame> {
  final Vector2 roomScreenPos;   // 룸 sprite의 topLeft 화면 좌표
  final Vector2 roomScreenSize;  // 룸 sprite가 그려질 화면 크기

  RoomBackground({
    required this.roomScreenPos,
    required this.roomScreenSize,
  }) : super(priority: -10);

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    final roomSprite = await Sprite.load('room/hanok_room.png');
    add(SpriteComponent(
      sprite: roomSprite,
      position: roomScreenPos,
      size: roomScreenSize,
      anchor: Anchor.topLeft,
      paint: Paint()..filterQuality = FilterQuality.none,
    ));
  }
}