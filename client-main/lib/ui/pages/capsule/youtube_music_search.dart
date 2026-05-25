import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

class MusicSearchResult {
  final String title;
  final String artist;
  final XFile audioFile;

  const MusicSearchResult({
    required this.title,
    required this.artist,
    required this.audioFile,
  });
}

class YoutubeMusicSearch extends StatefulWidget {
  const YoutubeMusicSearch({super.key});

  @override
  State<YoutubeMusicSearch> createState() => _YoutubeMusicSearchState();
}

class _YoutubeMusicSearchState extends State<YoutubeMusicSearch> {
  final _searchController = TextEditingController();
  final _yt = YoutubeExplode();

  List<Video> _results = [];
  bool _isSearching = false;
  String? _downloadingId;

  @override
  void dispose() {
    _searchController.dispose();
    _yt.close();
    super.dispose();
  }

  Future<void> _search() async {
    if (_searchController.text.trim().isEmpty) return;
    setState(() {
      _isSearching = true;
      _results = [];
    });

    try {
      final results = await _yt.search.search(_searchController.text.trim());
      setState(() => _results = results.whereType<Video>().take(10).toList());
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('검색 중 오류가 발생했습니다.')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSearching = false);
    }
  }

  Future<void> _selectVideo(Video video) async {
    setState(() => _downloadingId = video.id.value);

    try {
      final manifest =
          await _yt.videos.streamsClient.getManifest(video.id);
      final streamInfo = manifest.audioOnly.withHighestBitrate();
      final stream = _yt.videos.streamsClient.get(streamInfo);

      final tempDir = await getTemporaryDirectory();
      final filePath = '${tempDir.path}/${video.id.value}.mp3';
      final file = File(filePath);
      final sink = file.openWrite();

      await stream.pipe(sink);
      await sink.flush();
      await sink.close();

      if (!mounted) return;
      Navigator.pop(
        context,
        MusicSearchResult(
          title: video.title,
          artist: video.author,
          audioFile: XFile(filePath),
        ),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('다운로드 중 오류가 발생했습니다.')),
        );
      }
    } finally {
      if (mounted) setState(() => _downloadingId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text('음악 검색', style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: '곡명 또는 아티스트 검색',
                      hintStyle: const TextStyle(color: Colors.white38),
                      filled: true,
                      fillColor: const Color(0xFF2A2A2A),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 12),
                    ),
                    onSubmitted: (_) => _search(),
                  ),
                ),
                const SizedBox(width: 10),
                ElevatedButton(
                  onPressed: _isSearching ? null : _search,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFA14040),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 13),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  child: _isSearching
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2),
                        )
                      : const Icon(Icons.search, color: Colors.white),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: _results.length,
              itemBuilder: (context, index) {
                final video = _results[index];
                final isDownloading = _downloadingId == video.id.value;
                return ListTile(
                  leading: ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: Image.network(
                      video.thumbnails.lowResUrl,
                      width: 56,
                      height: 42,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        width: 56,
                        height: 42,
                        color: const Color(0xFF2A2A2A),
                        child: const Icon(Icons.music_note,
                            color: Colors.white38),
                      ),
                    ),
                  ),
                  title: Text(
                    video.title,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    video.author,
                    style:
                        const TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                  trailing: isDownloading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              color: Color(0xFFA14040), strokeWidth: 2),
                        )
                      : const Icon(Icons.download,
                          color: Colors.white38, size: 20),
                  onTap: isDownloading ? null : () => _selectVideo(video),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}