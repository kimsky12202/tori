import 'dart:convert';

import 'package:http/http.dart' as http;

import 'auth_api.dart';

class FriendApiException implements Exception {
  const FriendApiException(this.message);

  final String message;

  @override
  String toString() => message;
}

class FriendUser {
  const FriendUser({
    required this.id,
    required this.username,
    required this.name,
  });

  final String id;
  final String username;
  final String name;

  String get displayName {
    final String trimmedName = name.trim();
    if (trimmedName.isNotEmpty) {
      return trimmedName;
    }
    return username.trim();
  }
}

class FriendListItem {
  const FriendListItem({
    required this.id,
    required this.username,
    required this.name,
    required this.friendshipId,
  });

  final String id;
  final String username;
  final String name;
  final String friendshipId;

  String get displayName {
    final String trimmedName = name.trim();
    if (trimmedName.isNotEmpty) {
      return trimmedName;
    }
    return username.trim();
  }
}

class FriendSearchUser {
  const FriendSearchUser({
    required this.id,
    required this.username,
    required this.name,
    required this.relationshipStatus,
    required this.pendingRequestId,
  });

  final String id;
  final String username;
  final String name;
  final String relationshipStatus;
  final String pendingRequestId;

  bool get canSendRequest => relationshipStatus == 'none';
  bool get isOutgoingPending => relationshipStatus == 'outgoing_pending';
  bool get isIncomingPending =>
      relationshipStatus == 'incoming_pending' && pendingRequestId.isNotEmpty;

  String get displayName {
    final String trimmedName = name.trim();
    if (trimmedName.isNotEmpty) {
      return trimmedName;
    }
    return username.trim();
  }
}

class FriendRequestItem {
  const FriendRequestItem({
    required this.id,
    required this.requesterId,
    required this.receiverId,
    required this.status,
    required this.peerUser,
  });

  final String id;
  final String requesterId;
  final String receiverId;
  final String status;
  final FriendUser peerUser;
}

class FriendApi {
  FriendApi({http.Client? httpClient})
    : _httpClient = httpClient ?? http.Client();

  final http.Client _httpClient;

  Future<List<FriendListItem>> listFriends({
    String keyword = '',
    int limit = 100,
    int offset = 0,
  }) async {
    final String token = _requireAccessToken();
    final Uri uri = Uri.parse('${AuthApi.baseUrl}/friends').replace(
      queryParameters: <String, String>{
        if (keyword.trim().isNotEmpty) 'q': keyword.trim(),
        'limit': limit.toString(),
        'offset': offset.toString(),
      },
    );

    final response = await _httpClient.get(
      uri,
      headers: <String, String>{'Authorization': 'Bearer $token'},
    );

    if (response.statusCode != 200) {
      throw FriendApiException(_extractErrorMessage(response));
    }

    final Map<String, dynamic> body = _asJsonMap(jsonDecode(response.body));
    final List<dynamic> rawItems = _asJsonList(body['friends']);

    return rawItems
        .map((dynamic item) => _parseFriendListItem(item))
        .whereType<FriendListItem>()
        .toList();
  }

  Future<List<FriendSearchUser>> searchUsers({
    required String query,
    int limit = 20,
  }) async {
    final String token = _requireAccessToken();
    final String trimmed = query.trim();
    if (trimmed.isEmpty) {
      return const <FriendSearchUser>[];
    }

    final Uri uri = Uri.parse('${AuthApi.baseUrl}/friends/search').replace(
      queryParameters: <String, String>{
        'q': trimmed,
        'limit': limit.toString(),
      },
    );

    final response = await _httpClient.get(
      uri,
      headers: <String, String>{'Authorization': 'Bearer $token'},
    );

    if (response.statusCode != 200) {
      throw FriendApiException(_extractErrorMessage(response));
    }

    final Map<String, dynamic> body = _asJsonMap(jsonDecode(response.body));
    final List<dynamic> rawItems = _asJsonList(body['users']);

    return rawItems
        .map((dynamic item) => _parseFriendSearchUser(item))
        .whereType<FriendSearchUser>()
        .toList();
  }

  Future<bool> sendFriendRequest({required String receiverId}) async {
    final String token = _requireAccessToken();

    final response = await _httpClient.post(
      Uri.parse('${AuthApi.baseUrl}/friend-requests'),
      headers: <String, String>{
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(<String, String>{'receiver_id': receiverId}),
    );

    if (response.statusCode == 201) {
      return false;
    }
    if (response.statusCode == 200) {
      return true;
    }

    throw FriendApiException(_extractErrorMessage(response));
  }

  Future<List<FriendRequestItem>> listIncomingRequests({
    String status = 'pending',
    int limit = 50,
    int offset = 0,
  }) async {
    final String token = _requireAccessToken();
    final Uri uri = Uri.parse('${AuthApi.baseUrl}/friend-requests/incoming')
        .replace(
          queryParameters: <String, String>{
            'status': status.trim().isEmpty ? 'pending' : status.trim(),
            'limit': limit.toString(),
            'offset': offset.toString(),
          },
        );

    final response = await _httpClient.get(
      uri,
      headers: <String, String>{'Authorization': 'Bearer $token'},
    );

    if (response.statusCode != 200) {
      throw FriendApiException(_extractErrorMessage(response));
    }

    final Map<String, dynamic> body = _asJsonMap(jsonDecode(response.body));
    final List<dynamic> rawItems = _asJsonList(body['friend_requests']);

    return rawItems
        .map((dynamic item) => _parseFriendRequestItem(item))
        .whereType<FriendRequestItem>()
        .toList();
  }

  Future<void> acceptFriendRequest({required String requestId}) async {
    final String token = _requireAccessToken();

    final response = await _httpClient.post(
      Uri.parse('${AuthApi.baseUrl}/friend-requests/$requestId/accept'),
      headers: <String, String>{'Authorization': 'Bearer $token'},
    );

    if (response.statusCode == 200) {
      return;
    }

    throw FriendApiException(_extractErrorMessage(response));
  }

  Future<void> rejectFriendRequest({required String requestId}) async {
    final String token = _requireAccessToken();

    final response = await _httpClient.post(
      Uri.parse('${AuthApi.baseUrl}/friend-requests/$requestId/reject'),
      headers: <String, String>{'Authorization': 'Bearer $token'},
    );

    if (response.statusCode == 200) {
      return;
    }

    throw FriendApiException(_extractErrorMessage(response));
  }

  Future<void> deleteFriend({required String friendId}) async {
    final String token = _requireAccessToken();

    final response = await _httpClient.delete(
      Uri.parse('${AuthApi.baseUrl}/friends/$friendId'),
      headers: <String, String>{'Authorization': 'Bearer $token'},
    );

    if (response.statusCode == 200) {
      return;
    }

    throw FriendApiException(_extractErrorMessage(response));
  }

  String _requireAccessToken() {
    final String? token = AuthApi.accessToken;
    if (token == null || token.isEmpty) {
      throw const FriendApiException('로그인 정보가 없습니다. 다시 로그인해주세요.');
    }
    return token;
  }

  FriendListItem? _parseFriendListItem(dynamic raw) {
    if (raw is! Map) {
      return null;
    }

    final Map<String, dynamic> json = Map<String, dynamic>.from(raw);
    return FriendListItem(
      id: (json['id'] ?? '').toString(),
      username: (json['username'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      friendshipId: (json['friendship_id'] ?? '').toString(),
    );
  }

  FriendSearchUser? _parseFriendSearchUser(dynamic raw) {
    if (raw is! Map) {
      return null;
    }

    final Map<String, dynamic> json = Map<String, dynamic>.from(raw);
    return FriendSearchUser(
      id: (json['id'] ?? '').toString(),
      username: (json['username'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      relationshipStatus: (json['relationship_status'] ?? 'none').toString(),
      pendingRequestId: (json['pending_request_id'] ?? '').toString(),
    );
  }

  FriendRequestItem? _parseFriendRequestItem(dynamic raw) {
    if (raw is! Map) {
      return null;
    }

    final Map<String, dynamic> json = Map<String, dynamic>.from(raw);
    final Map<String, dynamic> peerJson = _asJsonMap(json['peer_user']);

    return FriendRequestItem(
      id: (json['id'] ?? '').toString(),
      requesterId: (json['requester_id'] ?? '').toString(),
      receiverId: (json['receiver_id'] ?? '').toString(),
      status: (json['status'] ?? '').toString(),
      peerUser: FriendUser(
        id: (peerJson['id'] ?? '').toString(),
        username: (peerJson['username'] ?? '').toString(),
        name: (peerJson['name'] ?? '').toString(),
      ),
    );
  }

  Map<String, dynamic> _asJsonMap(dynamic value) {
    if (value is Map<String, dynamic>) {
      return value;
    }
    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }
    return <String, dynamic>{};
  }

  List<dynamic> _asJsonList(dynamic value) {
    if (value is List) {
      return value;
    }
    return const <dynamic>[];
  }

  String _extractErrorMessage(http.Response response) {
    try {
      final dynamic body = jsonDecode(response.body);
      if (body is Map<String, dynamic> && body['message'] != null) {
        return body['message'].toString();
      }
    } catch (_) {
      // Falls back to generic message when response body is not JSON.
    }

    return 'request failed: ${response.statusCode}';
  }
}
