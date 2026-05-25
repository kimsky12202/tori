package main

import "testing"

func TestBuildFriendRequestFiltersIncomingWithStatus(t *testing.T) {
	queryFilter, countFilter, params, err := buildFriendRequestFilters(
		friendRequestDirectionIncoming,
		"user_1",
		friendRequestStatusPending,
		true,
	)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}

	if queryFilter != "receiver_id = {:authId} && status = {:status}" {
		t.Fatalf("unexpected queryFilter: %s", queryFilter)
	}
	if countFilter != "receiver_id = {:authId} AND status = {:status}" {
		t.Fatalf("unexpected countFilter: %s", countFilter)
	}
	if got := params["authId"]; got != "user_1" {
		t.Fatalf("unexpected authId param: %v", got)
	}
	if got := params["status"]; got != friendRequestStatusPending {
		t.Fatalf("unexpected status param: %v", got)
	}
}

func TestBuildFriendRequestFiltersOutgoingAllStatus(t *testing.T) {
	queryFilter, countFilter, params, err := buildFriendRequestFilters(
		friendRequestDirectionOutgoing,
		"user_2",
		"all",
		false,
	)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}

	if queryFilter != "requester_id = {:authId}" {
		t.Fatalf("unexpected queryFilter: %s", queryFilter)
	}
	if countFilter != "requester_id = {:authId}" {
		t.Fatalf("unexpected countFilter: %s", countFilter)
	}
	if got := params["authId"]; got != "user_2" {
		t.Fatalf("unexpected authId param: %v", got)
	}
	if _, exists := params["status"]; exists {
		t.Fatalf("status param should not exist when applyStatusFilter is false")
	}
}

func TestBuildFriendRequestFiltersInvalidDirection(t *testing.T) {
	_, _, _, err := buildFriendRequestFilters("unknown", "user", "pending", true)
	if err == nil {
		t.Fatalf("expected error for invalid direction")
	}
}
