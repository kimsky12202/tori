import 'package:flutter/material.dart';

import '../services/friend_api.dart';

class FriendsPage extends StatefulWidget {
  const FriendsPage({super.key});

  @override
  State<FriendsPage> createState() => _FriendsPageState();
}

class _FriendsPageState extends State<FriendsPage> {
  static const Color _backgroundColor = Color(0xFFF4F1EA);
  static const Color _titleColor = Color(0xFF2E2B2A);
  static const Color _cardColor = Colors.white;
  static const Color _subtleTextColor = Color(0xFF7A756D);
  static const Color _primaryColor = Color(0xFFA14040);
  static const Color _dangerColor = Color(0xFFA14040);
  static const Color _successColor = Color(0xFF2F8F4E);

  final FriendApi _friendApi = FriendApi();
  final TextEditingController _searchController = TextEditingController();
  final Set<String> _requestingUserIds = <String>{};
  final Set<String> _acceptingRequestIds = <String>{};
  final Set<String> _rejectingRequestIds = <String>{};
  final Set<String> _deletingFriendIds = <String>{};

  List<FriendSearchUser> _searchResults = const <FriendSearchUser>[];
  List<FriendRequestItem> _incomingRequests = const <FriendRequestItem>[];
  List<FriendListItem> _friends = const <FriendListItem>[];

  bool _isLoadingSearch = false;
  bool _isLoadingIncoming = true;
  bool _isLoadingFriends = true;
  String? _searchError;
  String? _incomingError;
  String? _friendsError;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    await Future.wait(<Future<void>>[
      _loadIncomingRequests(showLoading: true),
      _loadFriends(showLoading: true),
    ]);
  }

  Future<void> _refreshAll() async {
    await Future.wait(<Future<void>>[
      _loadIncomingRequests(showLoading: false),
      _loadFriends(showLoading: false),
    ]);

    if (_searchController.text.trim().isNotEmpty) {
      await _searchUsers(showLoading: false);
    }
  }

  Future<void> _loadIncomingRequests({required bool showLoading}) async {
    if (showLoading && mounted) {
      setState(() {
        _isLoadingIncoming = true;
        _incomingError = null;
      });
    } else if (mounted) {
      setState(() {
        _incomingError = null;
      });
    }

    try {
      final List<FriendRequestItem> requests = await _friendApi
          .listIncomingRequests(status: 'pending');
      if (!mounted) {
        return;
      }
      setState(() {
        _incomingRequests = requests;
        _isLoadingIncoming = false;
      });
    } on FriendApiException catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _incomingError = e.message;
        _isLoadingIncoming = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _incomingError = '받은 친구 요청을 불러오지 못했습니다.';
        _isLoadingIncoming = false;
      });
    }
  }

  Future<void> _loadFriends({required bool showLoading}) async {
    if (showLoading && mounted) {
      setState(() {
        _isLoadingFriends = true;
        _friendsError = null;
      });
    } else if (mounted) {
      setState(() {
        _friendsError = null;
      });
    }

    try {
      final List<FriendListItem> friends = await _friendApi.listFriends();
      if (!mounted) {
        return;
      }
      setState(() {
        _friends = friends;
        _isLoadingFriends = false;
      });
    } on FriendApiException catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _friendsError = e.message;
        _isLoadingFriends = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _friendsError = '친구 목록을 불러오지 못했습니다.';
        _isLoadingFriends = false;
      });
    }
  }

  Future<void> _searchUsers({bool showLoading = true}) async {
    final String query = _searchController.text.trim();
    if (query.isEmpty) {
      if (!mounted) {
        return;
      }
      setState(() {
        _searchResults = const <FriendSearchUser>[];
        _searchError = null;
        _isLoadingSearch = false;
      });
      return;
    }

    if (showLoading && mounted) {
      setState(() {
        _isLoadingSearch = true;
        _searchError = null;
      });
    } else if (mounted) {
      setState(() {
        _searchError = null;
      });
    }

    try {
      final List<FriendSearchUser> users = await _friendApi.searchUsers(
        query: query,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _searchResults = users;
        _isLoadingSearch = false;
      });
    } on FriendApiException catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _searchError = e.message;
        _isLoadingSearch = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _searchError = '유저 검색에 실패했습니다.';
        _isLoadingSearch = false;
      });
    }
  }

  Future<void> _sendFriendRequest(FriendSearchUser user) async {
    if (_requestingUserIds.contains(user.id)) {
      return;
    }

    setState(() {
      _requestingUserIds.add(user.id);
    });

    try {
      final bool acceptedAutomatically = await _friendApi.sendFriendRequest(
        receiverId: user.id,
      );
      if (!mounted) {
        return;
      }
      _showSnackBar(
        acceptedAutomatically ? '상대의 요청을 바로 수락했습니다.' : '친구 요청을 보냈습니다.',
      );
      await _refreshAll();
    } on FriendApiException catch (e) {
      _showSnackBar(e.message);
    } catch (_) {
      _showSnackBar('친구 요청 처리 중 오류가 발생했습니다.');
    } finally {
      if (mounted) {
        setState(() {
          _requestingUserIds.remove(user.id);
        });
      }
    }
  }

  Future<void> _acceptFriendRequest(String requestId) async {
    if (_acceptingRequestIds.contains(requestId)) {
      return;
    }

    setState(() {
      _acceptingRequestIds.add(requestId);
    });

    try {
      await _friendApi.acceptFriendRequest(requestId: requestId);
      _showSnackBar('친구 요청을 수락했습니다.');
      await _refreshAll();
    } on FriendApiException catch (e) {
      _showSnackBar(e.message);
    } catch (_) {
      _showSnackBar('요청 수락 중 오류가 발생했습니다.');
    } finally {
      if (mounted) {
        setState(() {
          _acceptingRequestIds.remove(requestId);
        });
      }
    }
  }

  Future<void> _rejectFriendRequest(String requestId) async {
    if (_rejectingRequestIds.contains(requestId)) {
      return;
    }

    setState(() {
      _rejectingRequestIds.add(requestId);
    });

    try {
      await _friendApi.rejectFriendRequest(requestId: requestId);
      _showSnackBar('친구 요청을 거절했습니다.');
      await _refreshAll();
    } on FriendApiException catch (e) {
      _showSnackBar(e.message);
    } catch (_) {
      _showSnackBar('요청 거절 중 오류가 발생했습니다.');
    } finally {
      if (mounted) {
        setState(() {
          _rejectingRequestIds.remove(requestId);
        });
      }
    }
  }

  Future<void> _deleteFriend(FriendListItem friend) async {
    if (_deletingFriendIds.contains(friend.id)) {
      return;
    }

    final bool shouldDelete =
        await showDialog<bool>(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: const Text('친구 삭제'),
              content: Text('${friend.displayName}님을 친구 목록에서 삭제할까요?'),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('취소'),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text('삭제'),
                ),
              ],
            );
          },
        ) ??
        false;

    if (!shouldDelete || !mounted) {
      return;
    }

    setState(() {
      _deletingFriendIds.add(friend.id);
    });

    try {
      await _friendApi.deleteFriend(friendId: friend.id);
      _showSnackBar('친구를 삭제했습니다.');
      await _refreshAll();
    } on FriendApiException catch (e) {
      _showSnackBar(e.message);
    } catch (_) {
      _showSnackBar('친구 삭제 중 오류가 발생했습니다.');
    } finally {
      if (mounted) {
        setState(() {
          _deletingFriendIds.remove(friend.id);
        });
      }
    }
  }

  void _showSnackBar(String message) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          '친구',
          style: TextStyle(color: _titleColor, fontWeight: FontWeight.bold),
        ),
        iconTheme: const IconThemeData(color: _titleColor),
        actions: <Widget>[
          IconButton(
            onPressed: _refreshAll,
            icon: const Icon(Icons.refresh),
            tooltip: '새로고침',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refreshAll,
        color: _primaryColor,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: <Widget>[
            _buildSearchCard(),
            const SizedBox(height: 12),
            _buildIncomingRequestsCard(),
            const SizedBox(height: 12),
            _buildFriendsCard(),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchCard() {
    final bool hasQuery = _searchController.text.trim().isNotEmpty;

    return _buildCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text(
            '유저 검색',
            style: TextStyle(
              color: _titleColor,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: <Widget>[
              Expanded(
                child: TextField(
                  controller: _searchController,
                  textInputAction: TextInputAction.search,
                  onSubmitted: (_) => _searchUsers(),
                  decoration: InputDecoration(
                    hintText: '닉네임 또는 이메일 검색',
                    isDense: true,
                    filled: true,
                    fillColor: const Color(0xFFF8F6F1),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    suffixIcon: hasQuery
                        ? IconButton(
                            onPressed: () {
                              _searchController.clear();
                              setState(() {
                                _searchResults = const <FriendSearchUser>[];
                                _searchError = null;
                              });
                            },
                            icon: const Icon(Icons.close),
                          )
                        : null,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                height: 46,
                child: ElevatedButton(
                  onPressed: _isLoadingSearch ? null : _searchUsers,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primaryColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isLoadingSearch
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.search),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _buildSearchResults(),
        ],
      ),
    );
  }

  Widget _buildSearchResults() {
    if (_searchError != null) {
      return Text(
        _searchError!,
        style: const TextStyle(color: _dangerColor, fontSize: 13),
      );
    }

    if (_searchController.text.trim().isEmpty) {
      return const Text(
        '검색어를 입력하면 친구 요청을 보낼 유저를 찾을 수 있습니다.',
        style: TextStyle(color: _subtleTextColor, fontSize: 13),
      );
    }

    if (_isLoadingSearch) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: LinearProgressIndicator(minHeight: 3, color: _primaryColor),
      );
    }

    if (_searchResults.isEmpty) {
      return const Text(
        '검색 결과가 없습니다.',
        style: TextStyle(color: _subtleTextColor, fontSize: 13),
      );
    }

    return Column(children: _searchResults.map(_buildSearchUserRow).toList());
  }

  Widget _buildSearchUserRow(FriendSearchUser user) {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F6F1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: <Widget>[
          CircleAvatar(
            radius: 18,
            backgroundColor: const Color(0xFFE7E1D3),
            foregroundColor: _titleColor,
            child: Text(
              _firstLetter(user.displayName),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  user.displayName,
                  style: const TextStyle(
                    color: _titleColor,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '@${user.username}',
                  style: const TextStyle(
                    color: _subtleTextColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          _buildSearchAction(user),
        ],
      ),
    );
  }

  Widget _buildSearchAction(FriendSearchUser user) {
    if (_requestingUserIds.contains(user.id)) {
      return const SizedBox(
        width: 22,
        height: 22,
        child: CircularProgressIndicator(
          strokeWidth: 2.4,
          color: _primaryColor,
        ),
      );
    }

    if (user.canSendRequest) {
      return ElevatedButton(
        onPressed: () => _sendFriendRequest(user),
        style: ElevatedButton.styleFrom(
          backgroundColor: _primaryColor,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          minimumSize: const Size(0, 34),
        ),
        child: const Text('요청'),
      );
    }

    if (user.isOutgoingPending) {
      return OutlinedButton(
        onPressed: null,
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          minimumSize: const Size(0, 34),
        ),
        child: const Text('요청중'),
      );
    }

    if (user.isIncomingPending) {
      final bool isAccepting = _acceptingRequestIds.contains(
        user.pendingRequestId,
      );
      final bool isRejecting = _rejectingRequestIds.contains(
        user.pendingRequestId,
      );
      final bool isBusy = isAccepting || isRejecting;

      return Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          SizedBox(
            height: 30,
            child: ElevatedButton(
              onPressed: isBusy
                  ? null
                  : () => _acceptFriendRequest(user.pendingRequestId),
              style: ElevatedButton.styleFrom(
                backgroundColor: _successColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                minimumSize: const Size(0, 30),
                textStyle: const TextStyle(fontSize: 12),
              ),
              child: isAccepting
                  ? const SizedBox(
                      width: 12,
                      height: 12,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('수락'),
            ),
          ),
          const SizedBox(height: 4),
          SizedBox(
            height: 30,
            child: OutlinedButton(
              onPressed: isBusy
                  ? null
                  : () => _rejectFriendRequest(user.pendingRequestId),
              style: OutlinedButton.styleFrom(
                foregroundColor: _dangerColor,
                side: const BorderSide(color: _dangerColor),
                padding: const EdgeInsets.symmetric(horizontal: 10),
                minimumSize: const Size(0, 30),
                textStyle: const TextStyle(fontSize: 12),
              ),
              child: isRejecting
                  ? const SizedBox(
                      width: 12,
                      height: 12,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: _dangerColor,
                      ),
                    )
                  : const Text('거절'),
            ),
          ),
        ],
      );
    }

    return const SizedBox.shrink();
  }

  Widget _buildIncomingRequestsCard() {
    return _buildCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            '받은 요청 (${_incomingRequests.length})',
            style: const TextStyle(
              color: _titleColor,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          if (_isLoadingIncoming)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 10),
                child: CircularProgressIndicator(color: _primaryColor),
              ),
            )
          else if (_incomingError != null)
            Text(
              _incomingError!,
              style: const TextStyle(color: _dangerColor, fontSize: 13),
            )
          else if (_incomingRequests.isEmpty)
            const Text(
              '받은 친구 요청이 없습니다.',
              style: TextStyle(color: _subtleTextColor, fontSize: 13),
            )
          else
            Column(
              children: _incomingRequests
                  .map(_buildIncomingRequestRow)
                  .toList(),
            ),
        ],
      ),
    );
  }

  Widget _buildIncomingRequestRow(FriendRequestItem request) {
    final bool isAccepting = _acceptingRequestIds.contains(request.id);
    final bool isRejecting = _rejectingRequestIds.contains(request.id);
    final bool isBusy = isAccepting || isRejecting;

    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F6F1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: <Widget>[
          CircleAvatar(
            radius: 18,
            backgroundColor: const Color(0xFFE7E1D3),
            foregroundColor: _titleColor,
            child: Text(
              _firstLetter(request.peerUser.displayName),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  request.peerUser.displayName,
                  style: const TextStyle(
                    color: _titleColor,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '@${request.peerUser.username}',
                  style: const TextStyle(
                    color: _subtleTextColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            height: 32,
            child: ElevatedButton(
              onPressed: isBusy ? null : () => _acceptFriendRequest(request.id),
              style: ElevatedButton.styleFrom(
                backgroundColor: _successColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                minimumSize: const Size(0, 32),
              ),
              child: isAccepting
                  ? const SizedBox(
                      width: 12,
                      height: 12,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('수락'),
            ),
          ),
          const SizedBox(width: 6),
          SizedBox(
            height: 32,
            child: OutlinedButton(
              onPressed: isBusy ? null : () => _rejectFriendRequest(request.id),
              style: OutlinedButton.styleFrom(
                foregroundColor: _dangerColor,
                side: const BorderSide(color: _dangerColor),
                padding: const EdgeInsets.symmetric(horizontal: 10),
                minimumSize: const Size(0, 32),
              ),
              child: isRejecting
                  ? const SizedBox(
                      width: 12,
                      height: 12,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: _dangerColor,
                      ),
                    )
                  : const Text('거절'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFriendsCard() {
    return _buildCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            '친구 목록 (${_friends.length})',
            style: const TextStyle(
              color: _titleColor,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          if (_isLoadingFriends)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 10),
                child: CircularProgressIndicator(color: _primaryColor),
              ),
            )
          else if (_friendsError != null)
            Text(
              _friendsError!,
              style: const TextStyle(color: _dangerColor, fontSize: 13),
            )
          else if (_friends.isEmpty)
            const Text(
              '아직 친구가 없습니다.',
              style: TextStyle(color: _subtleTextColor, fontSize: 13),
            )
          else
            Column(children: _friends.map(_buildFriendRow).toList()),
        ],
      ),
    );
  }

  Widget _buildFriendRow(FriendListItem friend) {
    final bool isDeleting = _deletingFriendIds.contains(friend.id);

    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F6F1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: <Widget>[
          CircleAvatar(
            radius: 18,
            backgroundColor: const Color(0xFFE7E1D3),
            foregroundColor: _titleColor,
            child: Text(
              _firstLetter(friend.displayName),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  friend.displayName,
                  style: const TextStyle(
                    color: _titleColor,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '@${friend.username}',
                  style: const TextStyle(
                    color: _subtleTextColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: isDeleting ? null : () => _deleteFriend(friend),
            tooltip: '친구 삭제',
            icon: isDeleting
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: _dangerColor,
                    ),
                  )
                : const Icon(Icons.person_remove_outlined, color: _dangerColor),
          ),
        ],
      ),
    );
  }

  Widget _buildCard({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
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
      child: child,
    );
  }

  String _firstLetter(String value) {
    final String trimmed = value.trim();
    if (trimmed.isEmpty) {
      return '?';
    }
    return trimmed.substring(0, 1).toUpperCase();
  }
}
