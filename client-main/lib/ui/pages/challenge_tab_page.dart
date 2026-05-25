import 'package:flutter/material.dart';

import '../services/challenge_api.dart';

class ChallengeTabPage extends StatefulWidget {
  const ChallengeTabPage({super.key});

  @override
  State<ChallengeTabPage> createState() => _ChallengeTabPageState();
}

class _ChallengeTabPageState extends State<ChallengeTabPage> {
  static const Color _backgroundColor = Color(0xFFF4F1EA);
  static const Color _titleColor = Color(0xFF2E2B2A);
  static const Color _cardColor = Colors.white;
  static const Color _primaryColor = Color(0xFFA14040);
  static const Color _subtleTextColor = Color(0xFF7A756D);
  static const Color _completeColor = Color(0xFF2F8F4E);
  static const Color _claimedColor = Color(0xFF2F6F8F);

  final ChallengeApi _challengeApi = ChallengeApi();
  final Set<String> _claimingIds = <String>{};
  late Future<List<ChallengeItem>> _futureChallenges;

  @override
  void initState() {
    super.initState();
    _futureChallenges = _challengeApi.listMyChallenges();
  }

  Future<void> _refreshChallenges() async {
    final Future<List<ChallengeItem>> future = _challengeApi.listMyChallenges();
    setState(() {
      _futureChallenges = future;
    });
    await future;
  }

  Future<void> _claimChallenge(ChallengeItem item) async {
    if (!item.canClaim || _claimingIds.contains(item.id)) {
      return;
    }

    setState(() {
      _claimingIds.add(item.id);
    });

    try {
      await _challengeApi.claimChallenge(challengeId: item.id);
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('보상을 받았습니다.')));
      await _refreshChallenges();
    } on ChallengeApiException catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('보상 수령 중 오류가 발생했습니다.')));
    } finally {
      if (mounted) {
        setState(() {
          _claimingIds.remove(item.id);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          '업적',
          style: TextStyle(color: _titleColor, fontWeight: FontWeight.bold),
        ),
        actions: <Widget>[
          IconButton(
            onPressed: _refreshChallenges,
            icon: const Icon(Icons.refresh),
            color: _subtleTextColor,
            tooltip: '새로고침',
          ),
        ],
      ),
      body: FutureBuilder<List<ChallengeItem>>(
        future: _futureChallenges,
        builder:
            (
              BuildContext context,
              AsyncSnapshot<List<ChallengeItem>> snapshot,
            ) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: CircularProgressIndicator(color: _primaryColor),
                );
              }

              if (snapshot.hasError) {
                return _buildErrorState(snapshot.error);
              }

              final List<ChallengeItem> challenges =
                  snapshot.data ?? <ChallengeItem>[];
              if (challenges.isEmpty) {
                return const Center(
                  child: Text(
                    '아직 등록된 업적이 없습니다.',
                    style: TextStyle(color: _subtleTextColor, fontSize: 15),
                  ),
                );
              }

              return RefreshIndicator(
                onRefresh: _refreshChallenges,
                color: _primaryColor,
                child: ListView.separated(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  itemCount: challenges.length,
                  separatorBuilder: (BuildContext context, int index) {
                    return const SizedBox(height: 12);
                  },
                  itemBuilder: (BuildContext context, int index) {
                    final ChallengeItem challenge = challenges[index];
                    return _ChallengeCard(
                      challenge: challenge,
                      isClaiming: _claimingIds.contains(challenge.id),
                      onClaimPressed: () => _claimChallenge(challenge),
                    );
                  },
                ),
              );
            },
      ),
    );
  }

  Widget _buildErrorState(Object? error) {
    final String message = error is ChallengeApiException
        ? error.message
        : '업적을 불러오지 못했습니다.';

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(Icons.error_outline, color: _subtleTextColor, size: 36),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: _subtleTextColor, fontSize: 14),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _refreshChallenges,
              style: ElevatedButton.styleFrom(
                backgroundColor: _primaryColor,
                foregroundColor: Colors.white,
              ),
              child: const Text('다시 시도'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChallengeCard extends StatelessWidget {
  const _ChallengeCard({
    required this.challenge,
    required this.isClaiming,
    required this.onClaimPressed,
  });

  final ChallengeItem challenge;
  final bool isClaiming;
  final VoidCallback onClaimPressed;

  static const Color _titleColor = _ChallengeTabPageState._titleColor;
  static const Color _cardColor = _ChallengeTabPageState._cardColor;
  static const Color _primaryColor = _ChallengeTabPageState._primaryColor;
  static const Color _subtleTextColor = _ChallengeTabPageState._subtleTextColor;
  static const Color _completeColor = _ChallengeTabPageState._completeColor;
  static const Color _claimedColor = _ChallengeTabPageState._claimedColor;

  @override
  Widget build(BuildContext context) {
    final Color statusColor = _statusColor(challenge.status);
    final String statusLabel = _statusLabel(challenge.status);
    final IconData statusIcon = _statusIcon(challenge.status);

    return Container(
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(14),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x12000000),
            blurRadius: 8,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(statusIcon, color: statusColor),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    challenge.title,
                    style: const TextStyle(
                      color: _titleColor,
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                  ),
                ),
                Text(
                  statusLabel,
                  style: TextStyle(
                    color: statusColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              challenge.description,
              style: const TextStyle(color: _subtleTextColor),
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: challenge.progressRate,
                minHeight: 8,
                color: statusColor,
                backgroundColor: const Color(0xFFE8E3D8),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '진행도 ${challenge.progressValue}/${challenge.conditionValue}',
              style: const TextStyle(
                color: _subtleTextColor,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (challenge.canClaim) ...<Widget>[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: isClaiming ? null : onClaimPressed,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primaryColor,
                    foregroundColor: Colors.white,
                  ),
                  child: isClaiming
                      ? const SizedBox(
                          height: 16,
                          width: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('보상 받기'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'claimed':
        return _claimedColor;
      case 'completed':
        return _completeColor;
      default:
        return _subtleTextColor;
    }
  }

  IconData _statusIcon(String status) {
    switch (status) {
      case 'claimed':
        return Icons.verified_outlined;
      case 'completed':
        return Icons.emoji_events;
      default:
        return Icons.flag_outlined;
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'claimed':
        return '수령 완료';
      case 'completed':
        return '달성';
      default:
        return '진행중';
    }
  }
}
