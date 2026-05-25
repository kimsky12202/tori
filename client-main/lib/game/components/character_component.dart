import 'dart:async';
import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:flame/game.dart';
import 'package:flutter/animation.dart';

enum CharDirection { south, north, east, west }
enum CharAction { idle, walk, pickup, carry }

class CharacterComponent extends SpriteAnimationComponent
    with HasGameRef<FlameGame> {
  CharacterComponent() : super(size: Vector2(110, 110), anchor: Anchor.center);

  static const double _frameTime = 0.18;
  static const double _walkSpeed = 180;

  // ★ 캔버스 크기: 232×232
  static const double _spriteSourceSize = 232.0;

  // ★ 손(=캡슐 중심) 오프셋 — 캔버스 중심(116,116) 기준 offset
  //   에셋 측정 후 실제 값으로 교체
  // _spriteSourceSize 확인
  static const int _capsuleAttachFrame = 2;

  static const Map<String, List<List<double>>> _handOffsets = {
    'pickup_south': [
      [50, 70, 500],   // pickup_1 (손 뻗기, 500 캔버스)
      [50, 70, 500],   // pickup_2 (허리 숙임, 손 위치 동일)
      [30, 23, 232],   // pickup_3 (들어올림) ← 캡슐 추적 시작
      [12, 10, 232],   // pickup_4 (가슴 앞)
    ],
    'carry_south': [[-3, 5, 232], [-3, 5, 232], [-3, 5, 232], [-3, 5, 232]],
    'carry_east':  [[20, 8, 232], [24, 9, 232], [20, 8, 232], [20, 8, 232]],
    'carry_west':  [[-29, -8, 232], [-31, -2, 232], [-27, -2, 232], [-33, -3, 232]],
  };


  late final SpriteAnimation _idle;
  late final SpriteAnimation _pickup;
  late final Map<CharDirection, SpriteAnimation> _walk;
  late final Map<CharDirection, SpriteAnimation> _carry;

  CharAction _currentAction = CharAction.idle;
  CharDirection _currentDirection = CharDirection.south;
  int _currentFrameIndex = 0;

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    // idle: 기존 형식 (frame_000.png, 0-indexed, 3-digit padding)
    _idle = await _loadAnim(
      'character/idle/frame_',
      4,
      startIndex: 0,
      padding: 3,
      loop: true,
    );

    // pickup: pickup_1.png ~ pickup_4.png (1-indexed, no padding)
    _pickup = await _loadAnim(
      'character/pickup/pickup_',
      4,
      startIndex: 1,
      loop: false,
    );

    // walk: walk/<dir>/<dir>_1.png ~ <dir>_4.png
    _walk = {
      CharDirection.south: await _loadAnim('character/walk/south/walk_south_', 4, startIndex: 1),
      CharDirection.north: await _loadAnim('character/walk/north/walk_north_', 4, startIndex: 1),
      CharDirection.east:  await _loadAnim('character/walk/east/walk_east_',  4, startIndex: 1),
      CharDirection.west:  await _loadAnim('character/walk/west/walk_west_',  4, startIndex: 1),
    };

    // carry: carry/<dir>/<dir>_1.png ~ <dir>_4.png
    _carry = {
      CharDirection.south: await _loadAnim('character/carry/south/carry_south_', 4, startIndex: 1),
      CharDirection.east:  await _loadAnim('character/carry/east/carry_east_',  4, startIndex: 1),
      CharDirection.west:  await _loadAnim('character/carry/west/carry_west_',  4, startIndex: 1),
    };

    animation = _idle;
  }

  /// 유연한 애니메이션 로더.
  /// - startIndex: 0 또는 1
  /// - padding: 0이면 패딩 없음, 3이면 '001' 형식
  Future<SpriteAnimation> _loadAnim(
    String prefix,
    int count, {
    int startIndex = 1,
    int padding = 0,
    bool loop = true,
  }) async {
    final sprites = await Future.wait(List.generate(count, (i) {
      final n = (i + startIndex).toString();
      final name = padding > 0 ? n.padLeft(padding, '0') : n;
      return Sprite.load('$prefix$name.png');
    }));
    return SpriteAnimation.spriteList(sprites,
        stepTime: _frameTime, loop: loop);
  }

  Vector2 get currentHandWorldPos {
    final table = _handOffsets[_handOffsetKey()];
    if (table == null) return position.clone();

    final idx = _currentFrameIndex.clamp(0, table.length - 1);
    final off = table[idx];
    // off[2] = 그 프레임의 캔버스 크기 (없으면 기본값)
    final canvasSize = off.length > 2 ? off[2] : _spriteSourceSize;
    final scale = size.x / canvasSize;
    return position + Vector2(off[0] * scale, off[1] * scale);
  }

  String _handOffsetKey() {
    if (_currentAction == CharAction.pickup) return 'pickup_south';
    if (_currentAction == CharAction.carry) {
      switch (_currentDirection) {
        case CharDirection.south: return 'carry_south';
        case CharDirection.east:  return 'carry_east';
        case CharDirection.west:  return 'carry_west';
        case CharDirection.north: return 'carry_south';
      }
    }
    return 'carry_south';
  }

  void setIdle() {
    _currentAction = CharAction.idle;
    animation = _idle;
  }

  CharDirection _directionTo(Vector2 target) {
    final delta = target - position;
    if (delta.x.abs() > delta.y.abs()) {
      return delta.x > 0 ? CharDirection.east : CharDirection.west;
    } else {
      return delta.y > 0 ? CharDirection.south : CharDirection.north;
    }
  }

  Future<void> walkTo(Vector2 target) => _moveTo(target, carrying: false);
  Future<void> carryTo(Vector2 target) => _moveTo(target, carrying: true);

  Future<void> _moveTo(Vector2 target, {required bool carrying}) {
    if (position.distanceTo(target) < 5) return Future.value();

    final dir = _directionTo(target);
    _currentDirection = dir;
    _currentAction = carrying ? CharAction.carry : CharAction.walk;

    final animMap = carrying ? _carry : _walk;
    animation = animMap[dir] ?? animMap[CharDirection.south]!;
    animationTicker?.reset();

    final completer = Completer<void>();
    final duration =
        (position.distanceTo(target) / _walkSpeed).clamp(0.3, 2.0);
    add(MoveEffect.to(
      target,
      EffectController(duration: duration, curve: Curves.easeInOut),
      onComplete: completer.complete,
    ));
    return completer.future;
  }

  Future<void> playPickup({VoidCallback? onCapsuleAttach}) async {
    _currentAction = CharAction.pickup;
    _currentDirection = CharDirection.south;
    animation = _pickup;
    animationTicker?.reset();

    final attachDelay = Duration(
        milliseconds:
            (_frameTime * _capsuleAttachFrame * 1000).round());
    final totalDelay =
        Duration(milliseconds: (_frameTime * 4 * 1000).round());

    if (onCapsuleAttach != null) {
      Future.delayed(attachDelay, () {
        if (isMounted) onCapsuleAttach();
      });
    }
    await Future.delayed(totalDelay);
  }

  @override
  void update(double dt) {
    super.update(dt);
    final ticker = animationTicker;
    if (ticker != null) {
      _currentFrameIndex = ticker.currentIndex;
    }
  }
}