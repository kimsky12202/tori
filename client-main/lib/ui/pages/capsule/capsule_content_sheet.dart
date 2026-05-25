import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../services/friend_api.dart';
import 'youtube_music_search.dart';

const String kCapsuleOpenOptionAnytime = 'anytime';
const String kCapsuleOpenOptionDaysLater = 'days_later';
const String kCapsuleOpenOptionNextYearSameTime = 'next_year_same_time';

class CapsuleData {
  final String? memo;
  final String? emotion;
  final List<XFile> photos;
  final List<XFile> videos;
  final String? musicTitle;
  final String? musicArtist;
  final XFile? musicFile;
  final List<String> friendIds;
  final String openOption;
  final int? openAfterDays;

  const CapsuleData({
    this.memo,
    this.emotion,
    this.photos = const [],
    this.videos = const [],
    this.musicTitle,
    this.musicArtist,
    this.musicFile,
    this.friendIds = const [],
    this.openOption = kCapsuleOpenOptionAnytime,
    this.openAfterDays,
  });

  DateTime? calculateOpenAtUtc({DateTime? now}) {
    final baseNow = (now ?? DateTime.now()).toUtc();
    switch (openOption) {
      case kCapsuleOpenOptionDaysLater:
        final days = openAfterDays ?? 0;
        if (days <= 0) return null;
        return baseNow.add(Duration(days: days));
      case kCapsuleOpenOptionNextYearSameTime:
        return DateTime.utc(
          baseNow.year + 1,
          baseNow.month,
          baseNow.day,
          baseNow.hour,
          baseNow.minute,
          baseNow.second,
          baseNow.millisecond,
          baseNow.microsecond,
        );
      case kCapsuleOpenOptionAnytime:
      default:
        return null;
    }
  }

  bool get shouldScheduleOpenAlert => openOption != kCapsuleOpenOptionAnytime;
}

class CapsuleContentSheet extends StatefulWidget {
  final void Function(CapsuleData data) onConfirm;

  const CapsuleContentSheet({super.key, required this.onConfirm});

  @override
  State<CapsuleContentSheet> createState() => _CapsuleContentSheetState();
}

class _CapsuleContentSheetState extends State<CapsuleContentSheet> {
  final _memoController = TextEditingController();
  final _picker = ImagePicker();
  final _friendApi = FriendApi();

  String? _selectedEmotion;
  List<XFile> _photos = [];
  List<XFile> _videos = [];
  String? _musicTitle;
  String? _musicArtist;
  XFile? _musicFile;
  bool _isGroupCapsule = false;
  bool _isLoadingFriends = false;
  String? _friendsError;
  List<FriendListItem> _friends = const <FriendListItem>[];
  final Set<String> _selectedFriendIds = <String>{};
  String _openOption = kCapsuleOpenOptionAnytime;
  int _openAfterDays = 7;

  final _emotions = [
    '😊',
    '😢',
    '😍',
    '😎',
    '🥺',
    '😤',
    '🥳',
    '😌',
    '❤️',
    '🌟',
    '😭',
    '🤩',
    '😔',
    '🫶',
    '✨',
  ];

  @override
  void initState() {
    super.initState();
    _loadFriends();
  }

  @override
  void dispose() {
    _memoController.dispose();
    super.dispose();
  }

  Future<void> _loadFriends() async {
    if (_isLoadingFriends) return;
    setState(() {
      _isLoadingFriends = true;
      _friendsError = null;
    });

    try {
      final friends = await _friendApi.listFriends(limit: 100);
      if (!mounted) return;
      setState(() => _friends = friends);
    } on FriendApiException catch (e) {
      if (!mounted) return;
      setState(() => _friendsError = e.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _friendsError = '친구 목록을 불러오지 못했습니다.');
    } finally {
      if (mounted) {
        setState(() => _isLoadingFriends = false);
      }
    }
  }

  void _toggleGroupCapsule(bool value) {
    setState(() {
      _isGroupCapsule = value;
      if (!value) {
        _selectedFriendIds.clear();
      }
    });
  }

  void _toggleFriendSelection(String friendId) {
    setState(() {
      if (_selectedFriendIds.contains(friendId)) {
        _selectedFriendIds.remove(friendId);
      } else {
        _selectedFriendIds.add(friendId);
      }
    });
  }

  void _showMusicSearch() async {
    final result = await Navigator.push<MusicSearchResult>(
      context,
      MaterialPageRoute(builder: (_) => const YoutubeMusicSearch()),
    );
    if (result != null && mounted) {
      setState(() {
        _musicTitle = result.title;
        _musicArtist = result.artist;
        _musicFile = result.audioFile;
      });
    }
  }

  Future<void> _pickPhotos() async {
    final picked = await _picker.pickMultiImage(imageQuality: 80);
    if (picked.isNotEmpty) {
      setState(() => _photos = picked.take(5).toList());
    }
  }

  Future<void> _pickVideo() async {
    final picked = await _picker.pickVideo(source: ImageSource.gallery);
    if (picked != null) {
      setState(() => _videos = [picked]);
    }
  }

  void _showConfirmDialog() {
    final groupCount = _isGroupCapsule ? _selectedFriendIds.length : 0;
    final openDescription = switch (_openOption) {
      kCapsuleOpenOptionAnytime => '언제든지 열람 가능',
      kCapsuleOpenOptionDaysLater => '$_openAfterDays일 뒤 열람 가능',
      kCapsuleOpenOptionNextYearSameTime => '1년 뒤 같은 시간에 열람 가능',
      _ => '언제든지 열람 가능',
    };
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text(
          '캡슐을 생성하시겠습니까?',
          style: TextStyle(color: Colors.white, fontSize: 16),
        ),
        content: Text(
          groupCount > 0
              ? '담은 내용, 현재 위치, 그룹 참여자 $groupCount명이 저장됩니다.\n열람 시간: $openDescription'
              : '담은 내용과 현재 위치가 저장됩니다.\n열람 시간: $openDescription',
          style: const TextStyle(color: Colors.white54, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('아니오', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pop(context);
              widget.onConfirm(
                CapsuleData(
                  memo: _memoController.text.trim().isEmpty
                      ? null
                      : _memoController.text.trim(),
                  emotion: _selectedEmotion,
                  photos: _photos,
                  videos: _videos,
                  musicTitle: _musicTitle,
                  musicArtist: _musicArtist,
                  musicFile: _musicFile,
                  friendIds: _isGroupCapsule
                      ? _selectedFriendIds.toList(growable: false)
                      : const <String>[],
                  openOption: _openOption,
                  openAfterDays: _openOption == kCapsuleOpenOptionDaysLater
                      ? _openAfterDays
                      : null,
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFA14040),
            ),
            child: const Text('예', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF1A1A1A),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 4, 0),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1FAA8C).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.view_in_ar, color: Color(0xFF1FAA8C), size: 16),
                      SizedBox(width: 4),
                      Text(
                        'AR 인증',
                        style: TextStyle(
                          color: Color(0xFF1FAA8C),
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                const Text(
                  '캡슐 묻기',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close, color: Colors.white54),
                ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSection('📷 사진', _buildPhotoSection()),
                  const SizedBox(height: 24),
                  _buildSection('📝 메모', _buildMemoSection()),
                  const SizedBox(height: 24),
                  _buildSection('👥 그룹 캡슐', _buildGroupSection()),
                  const SizedBox(height: 24),
                  _buildSection('⏰ 열람 시간', _buildOpenTimeSection()),
                  const SizedBox(height: 24),
                  _buildSection('🎥 영상', _buildVideoSection()),
                  const SizedBox(height: 24),
                  _buildSection('💭 감정', _buildEmotionSection()),
                  const SizedBox(height: 24),
                  _buildSection('🎵 음악', _buildMusicSection()),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.white24),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        '닫기',
                        style: TextStyle(color: Colors.white54),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      onPressed: _showConfirmDialog,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1FAA8C),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      icon: const Icon(Icons.gps_fixed, color: Colors.white, size: 18),
                      label: const Text(
                        '여기에 묻기',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection(String title, Widget content) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 10),
        content,
      ],
    );
  }

  Widget _buildPhotoSection() {
    return SizedBox(
      height: 88,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          GestureDetector(
            onTap: _pickPhotos,
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: const Color(0xFF2A2A2A),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white12),
              ),
              child: const Icon(
                Icons.add_photo_alternate_outlined,
                color: Colors.white38,
                size: 28,
              ),
            ),
          ),
          ..._photos.map(
            (f) => Container(
              margin: const EdgeInsets.only(left: 8),
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                image: DecorationImage(
                  image: FileImage(File(f.path)),
                  fit: BoxFit.cover,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMemoSection() {
    return TextField(
      controller: _memoController,
      maxLines: 3,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        hintText: '이 순간을 기록하세요...',
        hintStyle: const TextStyle(color: Colors.white38),
        filled: true,
        fillColor: const Color(0xFF2A2A2A),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  Widget _buildVideoSection() {
    return GestureDetector(
      onTap: _pickVideo,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          color: const Color(0xFF2A2A2A),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white12),
        ),
        child: Column(
          children: [
            Icon(
              _videos.isEmpty ? Icons.videocam_outlined : Icons.videocam,
              color: _videos.isEmpty ? Colors.white38 : const Color(0xFFA14040),
              size: 32,
            ),
            const SizedBox(height: 6),
            Text(
              _videos.isEmpty ? '영상 추가' : '영상 1개 선택됨',
              style: TextStyle(
                color: _videos.isEmpty ? Colors.white38 : Colors.white,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGroupSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFF2A2A2A),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.white12),
          ),
          child: Row(
            children: [
              const Expanded(
                child: Text(
                  '친구와 함께 그룹 캡슐 만들기',
                  style: TextStyle(color: Colors.white, fontSize: 14),
                ),
              ),
              Switch(
                value: _isGroupCapsule,
                onChanged: _toggleGroupCapsule,
                activeThumbColor: const Color(0xFFA14040),
                activeTrackColor: const Color(
                  0xFFA14040,
                ).withValues(alpha: 0.35),
              ),
            ],
          ),
        ),
        if (_isGroupCapsule) ...[
          const SizedBox(height: 10),
          if (_isLoadingFriends)
            const Center(
              child: SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white54,
                ),
              ),
            )
          else if (_friendsError != null)
            Row(
              children: [
                Expanded(
                  child: Text(
                    _friendsError!,
                    style: const TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                ),
                TextButton(
                  onPressed: _loadFriends,
                  child: const Text(
                    '다시 시도',
                    style: TextStyle(color: Color(0xFFA14040)),
                  ),
                ),
              ],
            )
          else if (_friends.isEmpty)
            const Text(
              '추가된 친구가 없습니다. 친구를 먼저 추가해주세요.',
              style: TextStyle(color: Colors.white54, fontSize: 12),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _friends.map((friend) {
                final isSelected = _selectedFriendIds.contains(friend.id);
                return FilterChip(
                  selected: isSelected,
                  label: Text(friend.displayName),
                  onSelected: (_) => _toggleFriendSelection(friend.id),
                  selectedColor: const Color(
                    0xFFA14040,
                  ).withValues(alpha: 0.25),
                  backgroundColor: const Color(0xFF2A2A2A),
                  side: BorderSide(
                    color: isSelected
                        ? const Color(0xFFA14040)
                        : Colors.white24,
                  ),
                  labelStyle: TextStyle(
                    color: isSelected ? Colors.white : Colors.white70,
                  ),
                  checkmarkColor: const Color(0xFFA14040),
                );
              }).toList(),
            ),
          if (_selectedFriendIds.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              '${_selectedFriendIds.length}명 선택됨',
              style: const TextStyle(
                color: Color(0xFFA14040),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ],
    );
  }

  Widget _buildOpenTimeSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ChoiceChip(
              label: const Text('언제든지 열람'),
              selected: _openOption == kCapsuleOpenOptionAnytime,
              onSelected: (_) {
                setState(() => _openOption = kCapsuleOpenOptionAnytime);
              },
              selectedColor: const Color(0xFFA14040).withValues(alpha: 0.25),
              backgroundColor: const Color(0xFF2A2A2A),
              side: BorderSide(
                color: _openOption == kCapsuleOpenOptionAnytime
                    ? const Color(0xFFA14040)
                    : Colors.white24,
              ),
              labelStyle: TextStyle(
                color: _openOption == kCapsuleOpenOptionAnytime
                    ? Colors.white
                    : Colors.white70,
              ),
            ),
            ChoiceChip(
              label: const Text('며칠 뒤 열람'),
              selected: _openOption == kCapsuleOpenOptionDaysLater,
              onSelected: (_) {
                setState(() => _openOption = kCapsuleOpenOptionDaysLater);
              },
              selectedColor: const Color(0xFFA14040).withValues(alpha: 0.25),
              backgroundColor: const Color(0xFF2A2A2A),
              side: BorderSide(
                color: _openOption == kCapsuleOpenOptionDaysLater
                    ? const Color(0xFFA14040)
                    : Colors.white24,
              ),
              labelStyle: TextStyle(
                color: _openOption == kCapsuleOpenOptionDaysLater
                    ? Colors.white
                    : Colors.white70,
              ),
            ),
            ChoiceChip(
              label: const Text('1년 뒤 같은 시간'),
              selected: _openOption == kCapsuleOpenOptionNextYearSameTime,
              onSelected: (_) {
                setState(
                  () => _openOption = kCapsuleOpenOptionNextYearSameTime,
                );
              },
              selectedColor: const Color(0xFFA14040).withValues(alpha: 0.25),
              backgroundColor: const Color(0xFF2A2A2A),
              side: BorderSide(
                color: _openOption == kCapsuleOpenOptionNextYearSameTime
                    ? const Color(0xFFA14040)
                    : Colors.white24,
              ),
              labelStyle: TextStyle(
                color: _openOption == kCapsuleOpenOptionNextYearSameTime
                    ? Colors.white
                    : Colors.white70,
              ),
            ),
          ],
        ),
        if (_openOption == kCapsuleOpenOptionDaysLater) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF2A2A2A),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white12),
            ),
            child: Row(
              children: [
                IconButton(
                  onPressed: _openAfterDays > 1
                      ? () => setState(() => _openAfterDays -= 1)
                      : null,
                  icon: const Icon(Icons.remove, color: Colors.white70),
                ),
                Expanded(
                  child: Text(
                    '$_openAfterDays일 뒤 열람 가능',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                  ),
                ),
                IconButton(
                  onPressed: _openAfterDays < 3650
                      ? () => setState(() => _openAfterDays += 1)
                      : null,
                  icon: const Icon(Icons.add, color: Colors.white70),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildEmotionSection() {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: _emotions.map((e) {
        final isSelected = e == _selectedEmotion;
        return GestureDetector(
          onTap: () => setState(() => _selectedEmotion = isSelected ? null : e),
          child: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: isSelected
                  ? const Color(0xFFA14040).withValues(alpha: 0.3)
                  : const Color(0xFF2A2A2A),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isSelected
                    ? const Color(0xFFA14040)
                    : Colors.transparent,
                width: 2,
              ),
            ),
            child: Center(child: Text(e, style: const TextStyle(fontSize: 24))),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildMusicSection() {
    return GestureDetector(
      onTap: _showMusicSearch,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFF2A2A2A),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white12),
        ),
        child: Row(
          children: [
            Icon(
              Icons.music_note,
              color: _musicTitle != null
                  ? const Color(0xFFA14040)
                  : Colors.white38,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _musicTitle != null
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _musicTitle!,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                          ),
                        ),
                        Text(
                          _musicArtist ?? '',
                          style: const TextStyle(
                            color: Colors.white54,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    )
                  : const Text(
                      '음악 검색',
                      style: TextStyle(color: Colors.white38, fontSize: 14),
                    ),
            ),
            if (_musicTitle != null)
              GestureDetector(
                onTap: () => setState(() {
                  _musicTitle = null;
                  _musicArtist = null;
                }),
                child: const Icon(Icons.close, color: Colors.white38, size: 18),
              ),
          ],
        ),
      ),
    );
  }
}
