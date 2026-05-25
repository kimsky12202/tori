import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'dart:ui' show FilterQuality;
import 'package:flutter/material.dart' show Paint;
import 'shelf_capsule_component.dart';

/// 책장 본체 + 슬롯별 캡슐(ClipComponent로 칸 안에 클리핑) 관리
class ShelfComponent extends PositionComponent
    with HasGameRef<FlameGame>, TapCallbacks {
  /// 책장 sprite 좌상단 (화면 월드 좌표)
  final Vector2 shelfPos;
  /// 책장 sprite 크기 (화면 월드 좌표)
  final Vector2 shelfSize;
  /// 슬롯 9개 중심 (화면 월드 좌표) — index 0~8
  final List<Vector2> slotCenters;
  /// 한 칸 크기 (화면 월드 좌표) — 클리핑 영역
  final Vector2 slotSize;
  /// 책장 탭 콜백
  final void Function() onTapShelf;

  ShelfComponent({
    required this.shelfPos,
    required this.shelfSize,
    required this.slotCenters,
    required this.slotSize,
    required this.onTapShelf,
  });

  late final SpriteComponent _body;

  // 슬롯별로 보관된 캡슐 (slotIndex → 캡슐). 빈 칸은 없음.
  final Map<int, ShelfCapsuleComponent> _slotCapsules = {};
  // 슬롯별 ClipComponent (재사용)
  final Map<int, ClipComponent> _slotClips = {};

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    // 책장 탭 영역 = 책장 전체
    position = shelfPos;
    size = shelfSize;

    final paint = Paint()..filterQuality = FilterQuality.none;

    // 책장 본체 (priority 1) — 캡슐(2)보다 뒤
    // position이 ShelfComponent 기준 (0,0) = 책장 좌상단
    _body = SpriteComponent(
      sprite: await Sprite.load('room/shelf.png'),
      position: Vector2.zero(),
      size: shelfSize,
      anchor: Anchor.topLeft,
      paint: paint,
    )..priority = 1;
    add(_body);
  }

  @override
  void onTapDown(TapDownEvent event) {
    onTapShelf();
  }

  /// 슬롯에 캡슐 배치 (ClipComponent로 칸 밖 클리핑)
  Future<void> placeCapsule({
    required int slotIndex,
    required String capsuleId,
    required String design,
  }) async {
    if (slotIndex < 0 || slotIndex >= slotCenters.length) return;
    if (_slotCapsules.containsKey(slotIndex)) return; // 이미 있음

    // 슬롯 중심 → ShelfComponent 기준 상대 좌표
    final slotCenterLocal = slotCenters[slotIndex] - shelfPos;
    // 클립 영역 좌상단 = 중심 - 칸크기/2
    final clipPos = slotCenterLocal - slotSize / 2;

    final capsule = ShelfCapsuleComponent(
      capsuleId: capsuleId,
      slotIndex: slotIndex,
      design: design,
    )
      // 캡슐 위치는 클립 내부 기준 = 칸 중앙
      ..position = slotSize / 2
      ..size = slotSize * 0.9 // 칸보다 약간 작게 (칸 안에 여유)
      ..anchor = Anchor.center;
    await capsule.onLoad();

    // 칸 영역으로 클리핑 (캡슐이 칸 밖으로 안 나가게)
    final clip = ClipComponent.rectangle(
      position: clipPos,
      size: slotSize,
    )
      ..priority = 2 // 책장 본체(1)보다 앞
      ..add(capsule);

    add(clip);
    _slotClips[slotIndex] = clip;
    _slotCapsules[slotIndex] = capsule;
  }

  /// 캡슐 해체 — 해당 슬롯 비우기
  void removeCapsule(String capsuleId) {
    int? targetSlot;
    _slotCapsules.forEach((slot, capsule) {
      if (capsule.capsuleId == capsuleId) targetSlot = slot;
    });
    if (targetSlot == null) return;

    _slotClips[targetSlot]?.removeFromParent();
    _slotClips.remove(targetSlot);
    _slotCapsules.remove(targetSlot);
  }

  /// 사용 중이지 않은 가장 작은 슬롯 (없으면 -1)
  int nextEmptySlot() {
    for (int i = 0; i < slotCenters.length; i++) {
      if (!_slotCapsules.containsKey(i)) return i;
    }
    return -1;
  }
}