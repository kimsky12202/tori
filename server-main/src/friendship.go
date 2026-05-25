package main

import (
	"database/sql"
	"errors"
	"net/http"
	"strconv"
	"strings"

	"github.com/pocketbase/dbx"
	"github.com/pocketbase/pocketbase"
	"github.com/pocketbase/pocketbase/core"
	"github.com/pocketbase/pocketbase/tools/hook"
)

const (
	friendRequestStatusPending  = "pending"
	friendRequestStatusAccepted = "accepted"
	friendRequestStatusRejected = "rejected"

	friendRelationshipNone            = "none"
	friendRelationshipOutgoingPending = "outgoing_pending"
	friendRelationshipIncomingPending = "incoming_pending"
	friendRelationshipFriends         = "friends"

	friendRequestDirectionIncoming = "incoming"
	friendRequestDirectionOutgoing = "outgoing"
)

type createFriendRequestBody struct {
	ReceiverID string `json:"receiver_id"`
}

func registerFriendshipRoutes(app *pocketbase.PocketBase) {
	app.OnServe().Bind(&hook.Handler[*core.ServeEvent]{
		Func: func(e *core.ServeEvent) error {
			e.Router.GET("/friends", listFriends(app))
			e.Router.GET("/friends/search", searchFriends(app))
			e.Router.POST("/friend-requests", createFriendRequest(app))
			e.Router.GET("/friend-requests/incoming", listIncomingFriendRequests(app))
			e.Router.GET("/friend-requests/outgoing", listOutgoingFriendRequests(app))
			e.Router.POST("/friend-requests/{id}/accept", acceptFriendRequest(app))
			e.Router.POST("/friend-requests/{id}/reject", rejectFriendRequest(app))
			e.Router.DELETE("/friends/{id}", deleteFriend(app))
			return e.Next()
		},
	})
}

func listFriends(app *pocketbase.PocketBase) func(*core.RequestEvent) error {
	return func(re *core.RequestEvent) error {
		if re.Auth == nil {
			return re.JSON(http.StatusUnauthorized, map[string]string{"message": "unauthorized"})
		}

		keyword := strings.TrimSpace(re.Request.URL.Query().Get("q"))
		if keyword == "" {
			keyword = strings.TrimSpace(re.Request.URL.Query().Get("keyword"))
		}
		normalizedKeyword := strings.ToLower(keyword)

		limit, err := parseFriendsLimit(re.Request.URL.Query().Get("limit"))
		if err != nil {
			return re.JSON(http.StatusBadRequest, map[string]string{"message": err.Error()})
		}
		offset, err := parseFriendsOffset(re.Request.URL.Query().Get("offset"))
		if err != nil {
			return re.JSON(http.StatusBadRequest, map[string]string{"message": err.Error()})
		}

		friendships, err := app.FindRecordsByFilter(
			"friendships",
			"user_id = {:me} || friend_id = {:me}",
			"",
			0,
			0,
			dbx.Params{"me": re.Auth.Id},
		)
		if err != nil {
			return re.JSON(http.StatusInternalServerError, map[string]string{"message": err.Error()})
		}

		filtered := make([]map[string]any, 0, len(friendships))
		for _, friendship := range friendships {
			friendID := resolveFriendID(re.Auth.Id, friendship)
			if friendID == "" || friendID == re.Auth.Id {
				continue
			}

			friendUser, err := app.FindRecordById("users", friendID)
			if err != nil {
				if errors.Is(err, sql.ErrNoRows) {
					continue
				}
				return re.JSON(http.StatusInternalServerError, map[string]string{"message": err.Error()})
			}

			if normalizedKeyword != "" && !isUserMatchedKeyword(friendUser, normalizedKeyword) {
				continue
			}

			filtered = append(filtered, map[string]any{
				"friendship_id": friendship.Id,
				"id":            friendUser.Id,
				"username":      friendUser.GetString("username"),
				"name":          friendUser.GetString("name"),
			})
		}

		total := len(filtered)
		start, end := paginate(total, offset, limit)
		items := filtered[start:end]

		return re.JSON(http.StatusOK, map[string]any{
			"friends": items,
			"meta": map[string]any{
				"total":  total,
				"offset": offset,
				"limit":  limit,
			},
		})
	}
}

func searchFriends(app *pocketbase.PocketBase) func(*core.RequestEvent) error {
	return func(re *core.RequestEvent) error {
		if re.Auth == nil {
			return re.JSON(http.StatusUnauthorized, map[string]string{"message": "unauthorized"})
		}

		keyword := strings.TrimSpace(re.Request.URL.Query().Get("q"))
		if keyword == "" {
			keyword = strings.TrimSpace(re.Request.URL.Query().Get("keyword"))
		}
		if keyword == "" {
			return re.JSON(http.StatusBadRequest, map[string]string{"message": "query keyword is required"})
		}

		limit, err := parseSearchLimit(re.Request.URL.Query().Get("limit"))
		if err != nil {
			return re.JSON(http.StatusBadRequest, map[string]string{"message": err.Error()})
		}

		usersCollection, err := app.FindCollectionByNameOrId("users")
		if err != nil {
			return re.JSON(http.StatusInternalServerError, map[string]string{"message": err.Error()})
		}

		searchFields := make([]string, 0, 3)
		if usersCollection.Fields.GetByName("username") != nil {
			searchFields = append(searchFields, "username:lower ~ {:keyword}")
		}
		if usersCollection.Fields.GetByName("name") != nil {
			searchFields = append(searchFields, "name:lower ~ {:keyword}")
		}
		if usersCollection.Fields.GetByName("email") != nil {
			searchFields = append(searchFields, "email:lower ~ {:keyword}")
		}

		if len(searchFields) == 0 {
			return re.JSON(http.StatusInternalServerError, map[string]string{"message": "no searchable field in users collection"})
		}

		filter := "id != {:authId} && (" + strings.Join(searchFields, " || ") + ")"
		users, err := app.FindRecordsByFilter(
			"users",
			filter,
			"",
			limit,
			0,
			dbx.Params{
				"authId":  re.Auth.Id,
				"keyword": "%" + strings.ToLower(keyword) + "%",
			},
		)
		if err != nil {
			return re.JSON(http.StatusInternalServerError, map[string]string{"message": err.Error()})
		}

		items := make([]map[string]any, 0, len(users))
		for _, user := range users {
			relationshipStatus, pendingRequestID, err := relationshipStatusWithRequest(app, re.Auth.Id, user.Id)
			if err != nil {
				return re.JSON(http.StatusInternalServerError, map[string]string{"message": err.Error()})
			}

			if relationshipStatus == friendRelationshipFriends {
				continue
			}

			items = append(items, map[string]any{
				"id":                  user.Id,
				"username":            user.GetString("username"),
				"name":                user.GetString("name"),
				"relationship_status": relationshipStatus,
				"pending_request_id":  pendingRequestID,
			})
		}

		return re.JSON(http.StatusOK, map[string]any{"users": items})
	}
}

func listIncomingFriendRequests(app *pocketbase.PocketBase) func(*core.RequestEvent) error {
	return func(re *core.RequestEvent) error {
		return listFriendRequestsByDirection(re, app, friendRequestDirectionIncoming)
	}
}

func listOutgoingFriendRequests(app *pocketbase.PocketBase) func(*core.RequestEvent) error {
	return func(re *core.RequestEvent) error {
		return listFriendRequestsByDirection(re, app, friendRequestDirectionOutgoing)
	}
}

func listFriendRequestsByDirection(
	re *core.RequestEvent,
	app *pocketbase.PocketBase,
	direction string,
) error {
	if re.Auth == nil {
		return re.JSON(http.StatusUnauthorized, map[string]string{"message": "unauthorized"})
	}

	limit, err := parseFriendsLimit(re.Request.URL.Query().Get("limit"))
	if err != nil {
		return re.JSON(http.StatusBadRequest, map[string]string{"message": err.Error()})
	}
	offset, err := parseFriendsOffset(re.Request.URL.Query().Get("offset"))
	if err != nil {
		return re.JSON(http.StatusBadRequest, map[string]string{"message": err.Error()})
	}

	status, applyStatusFilter, err := parseFriendRequestStatusFilter(
		re.Request.URL.Query().Get("status"),
	)
	if err != nil {
		return re.JSON(http.StatusBadRequest, map[string]string{"message": err.Error()})
	}

	queryFilter, countFilter, params, err := buildFriendRequestFilters(
		direction,
		re.Auth.Id,
		status,
		applyStatusFilter,
	)
	if err != nil {
		return re.JSON(http.StatusBadRequest, map[string]string{"message": err.Error()})
	}

	total, err := app.CountRecords(
		"friend_requests",
		dbx.NewExp(countFilter, params),
	)
	if err != nil {
		return re.JSON(http.StatusInternalServerError, map[string]string{"message": err.Error()})
	}

	records, err := app.FindRecordsByFilter(
		"friend_requests",
		queryFilter,
		"",
		limit,
		offset,
		params,
	)
	if err != nil {
		return re.JSON(http.StatusInternalServerError, map[string]string{"message": err.Error()})
	}

	items := make([]map[string]any, 0, len(records))
	for _, request := range records {
		peerID := request.GetString("receiver_id")
		if direction == friendRequestDirectionIncoming {
			peerID = request.GetString("requester_id")
		}

		peerUser, err := app.FindRecordById("users", peerID)
		if err != nil {
			if errors.Is(err, sql.ErrNoRows) {
				continue
			}
			return re.JSON(http.StatusInternalServerError, map[string]string{"message": err.Error()})
		}

		items = append(items, map[string]any{
			"id":           request.Id,
			"requester_id": request.GetString("requester_id"),
			"receiver_id":  request.GetString("receiver_id"),
			"status":       request.GetString("status"),
			"created":      request.GetString("created"),
			"updated":      request.GetString("updated"),
			"peer_user": map[string]any{
				"id":       peerUser.Id,
				"username": peerUser.GetString("username"),
				"name":     peerUser.GetString("name"),
			},
		})
	}

	return re.JSON(http.StatusOK, map[string]any{
		"friend_requests": items,
		"meta": map[string]any{
			"direction": direction,
			"status": map[string]any{
				"value":          status,
				"is_all_status":  !applyStatusFilter,
				"applied_filter": applyStatusFilter,
			},
			"total":  total,
			"offset": offset,
			"limit":  limit,
		},
	})
}

func createFriendRequest(app *pocketbase.PocketBase) func(*core.RequestEvent) error {
	return func(re *core.RequestEvent) error {
		if re.Auth == nil {
			return re.JSON(http.StatusUnauthorized, map[string]string{"message": "unauthorized"})
		}

		var body createFriendRequestBody
		if err := re.BindBody(&body); err != nil {
			return re.JSON(http.StatusBadRequest, map[string]string{"message": err.Error()})
		}

		requesterID := strings.TrimSpace(re.Auth.Id)
		receiverID := strings.TrimSpace(body.ReceiverID)
		if receiverID == "" {
			return re.JSON(http.StatusBadRequest, map[string]string{"message": "receiver_id is required"})
		}

		// 1) 자기 자신에게 요청 불가
		if requesterID == receiverID {
			return re.JSON(http.StatusBadRequest, map[string]string{"message": "cannot send a friend request to yourself"})
		}

		if _, err := app.FindRecordById("users", receiverID); err != nil {
			return re.JSON(http.StatusNotFound, map[string]string{"message": "receiver not found"})
		}

		// 2) 이미 친구면 요청 불가
		isFriend, err := areAlreadyFriends(app, requesterID, receiverID)
		if err != nil {
			return re.JSON(http.StatusInternalServerError, map[string]string{"message": err.Error()})
		}
		if isFriend {
			return re.JSON(http.StatusConflict, map[string]string{"message": "already friends"})
		}

		// 3) 이미 pending 요청(내가 보낸 요청)이 있으면 중복 요청 불가
		sameDirectionPending, err := findPendingFriendRequest(app, requesterID, receiverID)
		switch {
		case err == nil:
			return re.JSON(http.StatusConflict, map[string]string{"message": "friend request already pending"})
		case !errors.Is(err, sql.ErrNoRows):
			return re.JSON(http.StatusInternalServerError, map[string]string{"message": err.Error()})
		default:
			_ = sameDirectionPending
		}

		// 4) 상대가 나에게 pending 요청을 보낸 상태면 즉시 수락 처리
		reversePending, err := findPendingFriendRequest(app, receiverID, requesterID)
		switch {
		case err == nil:
			if err := markFriendRequestAccepted(app, reversePending); err != nil {
				return re.JSON(http.StatusInternalServerError, map[string]string{"message": err.Error()})
			}

			friendshipRecord, err := ensureFriendship(app, requesterID, receiverID)
			if err != nil {
				return re.JSON(http.StatusInternalServerError, map[string]string{"message": err.Error()})
			}

			return re.JSON(http.StatusOK, map[string]any{
				"message": "incoming request accepted automatically",
				"friend_request": map[string]any{
					"id":           reversePending.Id,
					"requester_id": reversePending.GetString("requester_id"),
					"receiver_id":  reversePending.GetString("receiver_id"),
					"status":       reversePending.GetString("status"),
				},
				"friendship": map[string]any{
					"id":        friendshipRecord.Id,
					"user_id":   friendshipRecord.GetString("user_id"),
					"friend_id": friendshipRecord.GetString("friend_id"),
					"created":   friendshipRecord.GetString("created"),
				},
			})
		case !errors.Is(err, sql.ErrNoRows):
			return re.JSON(http.StatusInternalServerError, map[string]string{"message": err.Error()})
		}

		friendRequestCollection, err := app.FindCollectionByNameOrId("friend_requests")
		if err != nil {
			return re.JSON(http.StatusInternalServerError, map[string]string{"message": err.Error()})
		}

		record := core.NewRecord(friendRequestCollection)
		record.Set("requester_id", requesterID)
		record.Set("receiver_id", receiverID)
		record.Set("status", friendRequestStatusPending)

		if err := app.Save(record); err != nil {
			return re.JSON(http.StatusBadRequest, map[string]string{"message": err.Error()})
		}

		return re.JSON(http.StatusCreated, map[string]any{
			"friend_request": map[string]any{
				"id":           record.Id,
				"requester_id": record.GetString("requester_id"),
				"receiver_id":  record.GetString("receiver_id"),
				"status":       record.GetString("status"),
				"created":      record.GetString("created"),
			},
		})
	}
}

func acceptFriendRequest(app *pocketbase.PocketBase) func(*core.RequestEvent) error {
	return func(re *core.RequestEvent) error {
		if re.Auth == nil {
			return re.JSON(http.StatusUnauthorized, map[string]string{"message": "unauthorized"})
		}

		friendRequestID := strings.TrimSpace(re.Request.PathValue("id"))
		if friendRequestID == "" {
			return re.JSON(http.StatusBadRequest, map[string]string{"message": "friend request id is required"})
		}

		request, err := app.FindRecordById("friend_requests", friendRequestID)
		if err != nil {
			return re.JSON(http.StatusNotFound, map[string]string{"message": "friend request not found"})
		}

		requesterID := request.GetString("requester_id")
		receiverID := request.GetString("receiver_id")
		status := normalizeFriendRequestStatus(request.GetString("status"))

		if receiverID != re.Auth.Id {
			return re.JSON(http.StatusForbidden, map[string]string{"message": "only receiver can accept this request"})
		}

		if status != friendRequestStatusPending {
			return re.JSON(http.StatusConflict, map[string]string{"message": "friend request is not pending"})
		}

		if err := markFriendRequestStatus(app, request, friendRequestStatusAccepted); err != nil {
			return re.JSON(http.StatusInternalServerError, map[string]string{"message": err.Error()})
		}

		friendshipRecord, err := ensureFriendship(app, requesterID, receiverID)
		if err != nil {
			return re.JSON(http.StatusInternalServerError, map[string]string{"message": err.Error()})
		}

		return re.JSON(http.StatusOK, map[string]any{
			"friend_request": map[string]any{
				"id":           request.Id,
				"requester_id": request.GetString("requester_id"),
				"receiver_id":  request.GetString("receiver_id"),
				"status":       request.GetString("status"),
				"updated":      request.GetString("updated"),
			},
			"friendship": map[string]any{
				"id":        friendshipRecord.Id,
				"user_id":   friendshipRecord.GetString("user_id"),
				"friend_id": friendshipRecord.GetString("friend_id"),
				"created":   friendshipRecord.GetString("created"),
			},
		})
	}
}

func rejectFriendRequest(app *pocketbase.PocketBase) func(*core.RequestEvent) error {
	return func(re *core.RequestEvent) error {
		if re.Auth == nil {
			return re.JSON(http.StatusUnauthorized, map[string]string{"message": "unauthorized"})
		}

		friendRequestID := strings.TrimSpace(re.Request.PathValue("id"))
		if friendRequestID == "" {
			return re.JSON(http.StatusBadRequest, map[string]string{"message": "friend request id is required"})
		}

		request, err := app.FindRecordById("friend_requests", friendRequestID)
		if err != nil {
			return re.JSON(http.StatusNotFound, map[string]string{"message": "friend request not found"})
		}

		receiverID := request.GetString("receiver_id")
		status := normalizeFriendRequestStatus(request.GetString("status"))

		if receiverID != re.Auth.Id {
			return re.JSON(http.StatusForbidden, map[string]string{"message": "only receiver can reject this request"})
		}

		if status != friendRequestStatusPending {
			return re.JSON(http.StatusConflict, map[string]string{"message": "friend request is not pending"})
		}

		if err := markFriendRequestStatus(app, request, friendRequestStatusRejected); err != nil {
			return re.JSON(http.StatusInternalServerError, map[string]string{"message": err.Error()})
		}

		return re.JSON(http.StatusOK, map[string]any{
			"friend_request": map[string]any{
				"id":           request.Id,
				"requester_id": request.GetString("requester_id"),
				"receiver_id":  request.GetString("receiver_id"),
				"status":       request.GetString("status"),
				"updated":      request.GetString("updated"),
			},
		})
	}
}

func deleteFriend(app *pocketbase.PocketBase) func(*core.RequestEvent) error {
	return func(re *core.RequestEvent) error {
		if re.Auth == nil {
			return re.JSON(http.StatusUnauthorized, map[string]string{"message": "unauthorized"})
		}

		friendID := strings.TrimSpace(re.Request.PathValue("id"))
		if friendID == "" {
			return re.JSON(http.StatusBadRequest, map[string]string{"message": "friend id is required"})
		}
		if friendID == re.Auth.Id {
			return re.JSON(http.StatusBadRequest, map[string]string{"message": "cannot delete yourself from friend list"})
		}

		friendship, err := app.FindFirstRecordByFilter(
			"friendships",
			"(user_id = {:me} && friend_id = {:friend}) || (user_id = {:friend} && friend_id = {:me})",
			dbx.Params{"me": re.Auth.Id, "friend": friendID},
		)
		if err != nil {
			if errors.Is(err, sql.ErrNoRows) {
				return re.JSON(http.StatusNotFound, map[string]string{"message": "friendship not found"})
			}
			return re.JSON(http.StatusInternalServerError, map[string]string{"message": err.Error()})
		}

		if err := app.Delete(friendship); err != nil {
			return re.JSON(http.StatusInternalServerError, map[string]string{"message": err.Error()})
		}

		return re.JSON(http.StatusOK, map[string]any{
			"message":       "friend deleted",
			"friendship_id": friendship.Id,
			"friend_id":     friendID,
		})
	}
}

func areAlreadyFriends(app *pocketbase.PocketBase, userID, friendID string) (bool, error) {
	_, err := app.FindFirstRecordByFilter(
		"friendships",
		"(user_id = {:userA} && friend_id = {:userB}) || (user_id = {:userB} && friend_id = {:userA})",
		dbx.Params{"userA": userID, "userB": friendID},
	)
	if err == nil {
		return true, nil
	}
	if errors.Is(err, sql.ErrNoRows) {
		return false, nil
	}
	return false, err
}

func findPendingFriendRequest(app *pocketbase.PocketBase, requesterID, receiverID string) (*core.Record, error) {
	return app.FindFirstRecordByFilter(
		"friend_requests",
		"requester_id = {:requester} && receiver_id = {:receiver} && status = {:status}",
		dbx.Params{
			"requester": requesterID,
			"receiver":  receiverID,
			"status":    friendRequestStatusPending,
		},
	)
}

func markFriendRequestAccepted(app *pocketbase.PocketBase, record *core.Record) error {
	record.Set("status", normalizeFriendRequestStatus(friendRequestStatusAccepted))
	return app.Save(record)
}

func markFriendRequestStatus(app *pocketbase.PocketBase, record *core.Record, status string) error {
	record.Set("status", normalizeFriendRequestStatus(status))
	return app.Save(record)
}

func ensureFriendship(app *pocketbase.PocketBase, userA, userB string) (*core.Record, error) {
	existing, err := app.FindFirstRecordByFilter(
		"friendships",
		"(user_id = {:userA} && friend_id = {:userB}) || (user_id = {:userB} && friend_id = {:userA})",
		dbx.Params{"userA": userA, "userB": userB},
	)
	if err == nil {
		return existing, nil
	}
	if !errors.Is(err, sql.ErrNoRows) {
		return nil, err
	}

	leftID, rightID := normalizeFriendPair(userA, userB)

	friendshipsCollection, err := app.FindCollectionByNameOrId("friendships")
	if err != nil {
		return nil, err
	}

	record := core.NewRecord(friendshipsCollection)
	record.Set("user_id", leftID)
	record.Set("friend_id", rightID)

	if err := app.Save(record); err != nil {
		return nil, err
	}

	return record, nil
}

func normalizeFriendPair(a, b string) (string, string) {
	if a <= b {
		return a, b
	}
	return b, a
}

func normalizeFriendRequestStatus(status string) string {
	return strings.ToLower(strings.TrimSpace(status))
}

func relationshipStatusWithRequest(app *pocketbase.PocketBase, meID, otherID string) (string, string, error) {
	isFriend, err := areAlreadyFriends(app, meID, otherID)
	if err != nil {
		return "", "", err
	}
	if isFriend {
		return friendRelationshipFriends, "", nil
	}

	outgoing, err := findPendingFriendRequest(app, meID, otherID)
	if err == nil {
		return friendRelationshipOutgoingPending, outgoing.Id, nil
	}
	if !errors.Is(err, sql.ErrNoRows) {
		return "", "", err
	}

	incoming, err := findPendingFriendRequest(app, otherID, meID)
	if err == nil {
		return friendRelationshipIncomingPending, incoming.Id, nil
	}
	if !errors.Is(err, sql.ErrNoRows) {
		return "", "", err
	}

	return friendRelationshipNone, "", nil
}

func parseSearchLimit(raw string) (int, error) {
	const (
		defaultLimit = 20
		maxLimit     = 50
	)

	raw = strings.TrimSpace(raw)
	if raw == "" {
		return defaultLimit, nil
	}

	n, err := strconv.Atoi(raw)
	if err != nil || n <= 0 {
		return 0, errors.New("limit must be a positive integer")
	}

	if n > maxLimit {
		n = maxLimit
	}
	return n, nil
}

func parseFriendsLimit(raw string) (int, error) {
	const (
		defaultLimit = 20
		maxLimit     = 100
	)

	raw = strings.TrimSpace(raw)
	if raw == "" {
		return defaultLimit, nil
	}

	n, err := strconv.Atoi(raw)
	if err != nil || n <= 0 {
		return 0, errors.New("limit must be a positive integer")
	}

	if n > maxLimit {
		n = maxLimit
	}
	return n, nil
}

func parseFriendsOffset(raw string) (int, error) {
	raw = strings.TrimSpace(raw)
	if raw == "" {
		return 0, nil
	}

	n, err := strconv.Atoi(raw)
	if err != nil || n < 0 {
		return 0, errors.New("offset must be a non-negative integer")
	}
	return n, nil
}

func parseFriendRequestStatusFilter(raw string) (string, bool, error) {
	status := normalizeFriendRequestStatus(raw)
	if status == "" {
		return friendRequestStatusPending, true, nil
	}

	if status == "all" {
		return status, false, nil
	}

	switch status {
	case friendRequestStatusPending, friendRequestStatusAccepted, friendRequestStatusRejected:
		return status, true, nil
	default:
		return "", false, errors.New("status must be one of: pending, accepted, rejected, all")
	}
}

func buildFriendRequestFilters(
	direction string,
	authID string,
	status string,
	applyStatusFilter bool,
) (string, string, dbx.Params, error) {
	filterParts := make([]string, 0, 2)
	params := dbx.Params{"authId": authID}

	switch direction {
	case friendRequestDirectionIncoming:
		filterParts = append(filterParts, "receiver_id = {:authId}")
	case friendRequestDirectionOutgoing:
		filterParts = append(filterParts, "requester_id = {:authId}")
	default:
		return "", "", nil, errors.New("invalid request direction")
	}

	if applyStatusFilter {
		filterParts = append(filterParts, "status = {:status}")
		params["status"] = status
	}

	queryFilter := strings.Join(filterParts, " && ")
	countFilter := strings.Join(filterParts, " AND ")
	return queryFilter, countFilter, params, nil
}

func resolveFriendID(meID string, friendship *core.Record) string {
	userID := friendship.GetString("user_id")
	friendID := friendship.GetString("friend_id")

	if userID == meID {
		return friendID
	}
	if friendID == meID {
		return userID
	}
	return ""
}

func isUserMatchedKeyword(user *core.Record, keyword string) bool {
	if keyword == "" {
		return true
	}

	// Users collection can differ between environments, so we check common fields safely.
	candidates := []string{
		user.GetString("username"),
		user.GetString("name"),
		user.GetString("email"),
	}
	for _, candidate := range candidates {
		if strings.Contains(strings.ToLower(candidate), keyword) {
			return true
		}
	}
	return false
}

func paginate(total, offset, limit int) (int, int) {
	if total <= 0 || offset >= total {
		return 0, 0
	}

	start := offset
	end := start + limit
	if end > total {
		end = total
	}
	return start, end
}
