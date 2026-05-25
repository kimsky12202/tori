import 'package:flame/game.dart';
import 'package:flame/components.dart';
import 'components/room_background.dart';
import 'components/character_component.dart';
import 'components/capsule_component.dart';
import 'components/shelf_component.dart';

class TimecapsuleGame extends FlameGame {
  // ───────── 룸 이미지 좌표 (2000×2000 PNG 기준) ─────────
  static const double _roomImgW = 2000;
  static const double _roomImgH = 2000;

  static const double _roomScale = 2.0;       // 룸 크기 배율
  static const double _roomVerticalAlign = -0.5; // 세로 위치

  // 바닥 4꼭짓점 (룸 이미지 픽셀)
  static const _floorTopImg    = [1002.0, 824.0];
  static const _floorLeftImg   = [396.0, 1160.0];
  static const _floorRightImg  = [1602.0, 1157.0];
  static const _floorBottomImg = [1000.0, 1508.0];

  // ───────── 책장 (룸 이미지 픽셀 기준, 544 원본 크기) ─────────
  static const _shelfPosImg = [300.0, 660.0];  // 책장 좌상단 — 화면 보고 조정
  static const double _shelfSizeImg = 544.0;   // 책장 원본 크기

  // 슬롯 9개 중심 (룸 이미지 픽셀) — index 0~8
  static const List<List<double>> _shelfSlotsImg = [
    [528, 923], [603, 887], [672, 857], // row 0
    [527, 1011], [601, 973], [671, 937], // row 1
    [531, 1094], [602, 1055], [676, 1025], // row 2
  ];

  // 한 칸 크기 (룸 이미지 픽셀): 가로 ~56, 세로 ~65
  static const double _slotWImg = 56;
  static const double _slotHImg = 65;

  // ───────── 그리드 설정 ─────────
  static const int _gridSize = 6;

  // 캐릭터/드롭/책장앞 위치 (그리드 좌표)
  static const _charCell  = [3, 4];
  static const _dropCell  = [3, 1];
  static const _shelfCell = [1, 5]; // 책장 앞 도착 위치

  // ───────── 런타임 계산값 ─────────
  late Vector2 _roomScreenPos;
  late Vector2 _roomScreenSize;
  late double _imgToScreenScale;

  late CharacterComponent _character;
  late ShelfComponent _shelf;
  bool _isAnimating = false;
  CapsuleComponent? _carriedCapsule;

  // ───────── 좌표 변환 ─────────
  Vector2 _imgToWorld(List<double> img) => Vector2(
        _roomScreenPos.x + img[0] * _imgToScreenScale,
        _roomScreenPos.y + img[1] * _imgToScreenScale,
      );

  Vector2 _cell(double col, double row) {
    final u = col / _gridSize;
    final v = row / _gridSize;
    double lerp(double a, double b, double t) => a + (b - a) * t;
    final topX = lerp(_floorTopImg[0], _floorRightImg[0], u);
    final topY = lerp(_floorTopImg[1], _floorRightImg[1], u);
    final botX = lerp(_floorLeftImg[0], _floorBottomImg[0], u);
    final botY = lerp(_floorLeftImg[1], _floorBottomImg[1], u);
    final imgX = lerp(topX, botX, v);
    final imgY = lerp(topY, botY, v);
    return _imgToWorld([imgX, imgY]);
  }

  Vector2 _cellCenter(List<int> cell) =>
      _cell(cell[0] + 0.5, cell[1] + 0.5);

  // ───────── 로드 ─────────
  @override
  Future<void> onLoad() async {
    await super.onLoad();
    camera.viewfinder.anchor = Anchor.topLeft;

    // 룸 크기/위치 계산
    _roomScreenSize = Vector2(
      size.x * _roomScale,
      size.x * _roomScale * (_roomImgH / _roomImgW),
    );
    _roomScreenPos = Vector2(
      (size.x - _roomScreenSize.x) / 2,
      (size.y - _roomScreenSize.y) * _roomVerticalAlign,
    );
    _imgToScreenScale = _roomScreenSize.x / _roomImgW;

    // 1. 룸 배경
    add(RoomBackground(
      roomScreenPos: _roomScreenPos,
      roomScreenSize: _roomScreenSize,
    ));

    // 2. 책장 (슬롯 좌표/칸크기를 화면 좌표로 변환해서 전달)
    final shelfPos = _imgToWorld(_shelfPosImg);
    final shelfSize = Vector2(
      _shelfSizeImg * _imgToScreenScale,
      _shelfSizeImg * _imgToScreenScale,
    );
    final slotCenters = _shelfSlotsImg
        .map((s) => _imgToWorld(s))
        .toList();
    final slotSize = Vector2(
      _slotWImg * _imgToScreenScale,
      _slotHImg * _imgToScreenScale,
    );

    _shelf = ShelfComponent(
      shelfPos: shelfPos,
      shelfSize: shelfSize,
      slotCenters: slotCenters,
      slotSize: slotSize,
      onTapShelf: _onShelfTapped,
    )..priority = 10; // 룸(-10)보다 앞, 캐릭터(50)보다 뒤
    add(_shelf);

    // 3. 캐릭터
    final charScreen = _cellCenter(_charCell);
    final charSize = _imgToScreenScale * 280; // 2000기준이라 값 큼, 화면보고 조정
    _character = CharacterComponent()
      ..position = Vector2(charScreen.x, charScreen.y - charSize / 2)
      ..size = Vector2(charSize, charSize)
      ..priority = 50;
    add(_character);
  }

  void _onShelfTapped() {
    // TODO: 캡슐 리스트 페이지로 네비게이션
  }

  // ───────── 캡슐 등록 시퀀스 ─────────
  Future<void> onCapsuleRegistered({
    String design = 'base',
    String? capsuleId,
  }) async {
    if (_isAnimating) return;
    _isAnimating = true;

    final dropPos = _cellCenter(_dropCell);
    final charSize = _character.size.y;
    final capsuleSize = _imgToScreenScale * 90;

    // 1. 캡슐 낙하
    final capsule = CapsuleComponent()
      ..position = Vector2(dropPos.x, -60)
      ..size = Vector2(capsuleSize, capsuleSize)
      ..priority = 50;
    await add(capsule);
    await capsule.fallTo(dropPos);

    // 2. 캐릭터 → 캡슐 옆
    await _character.walkTo(Vector2(dropPos.x, dropPos.y - charSize / 4));

    // 3. 픽업 (frame 2부터 캡슐 추적)
    await _character.playPickup(
      onCapsuleAttach: () {
        _carriedCapsule = capsule;
        capsule.priority = 60;
      },
    );

    // 4. 캐리 → 책장 앞
    final shelfFront = _cellCenter(_shelfCell);
    await _character.carryTo(
        Vector2(shelfFront.x, shelfFront.y - charSize / 2));

    // 5. 책장 앞 도착 → 캐리 캡슐 제거 + 슬롯에 배치
    _carriedCapsule = null;
    capsule.removeFromParent();
    final slot = _shelf.nextEmptySlot();
    if (slot >= 0) {
      await _shelf.placeCapsule(
        slotIndex: slot,
        capsuleId: capsuleId ?? 'slot_$slot',
        design: design,
      );
    }

    // 6. 원위치 복귀
    final charPos = _cellCenter(_charCell);
    await _character.walkTo(Vector2(charPos.x, charPos.y - charSize / 2));
    _character.setIdle();

    _isAnimating = false;
  }

  // ───────── 캡슐 해체 (백엔드 신호) ─────────
  void removeCapsuleFromShelf(String capsuleId) {
    _shelf.removeCapsule(capsuleId);
  }

  // ───────── 매 프레임 캡슐 추적 ─────────
  @override
  void update(double dt) {
    super.update(dt);
    final c = _carriedCapsule;
    if (c != null && c.isMounted) {
      c.position = _character.currentHandWorldPos;
    }
  }
}