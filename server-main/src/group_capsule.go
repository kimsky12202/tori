package main

import (
	"database/sql"
	"errors"
	"fmt"
	"strings"
	"time"

	"github.com/pocketbase/dbx"
	"github.com/pocketbase/pocketbase"
	"github.com/pocketbase/pocketbase/core"
)

const (
	groupCapsuleMemberStatusJoined = "joined"
	groupCapsuleMemberRoleOwner    = "owner"
	groupCapsuleMemberRoleMember   = "member"
)

func parseRequestedGroupMemberIDs(re *core.RequestEvent) []string {
	rawValues := re.Request.MultipartForm.Value["member_ids"]
	if len(rawValues) == 0 {
		return nil
	}

	seen := make(map[string]struct{}, len(rawValues))
	memberIDs := make([]string, 0, len(rawValues))
	for _, raw := range rawValues {
		for _, token := range strings.Split(raw, ",") {
			memberID := strings.TrimSpace(token)
			if memberID == "" || memberID == re.Auth.Id {
				continue
			}
			if _, exists := seen[memberID]; exists {
				continue
			}
			seen[memberID] = struct{}{}
			memberIDs = append(memberIDs, memberID)
		}
	}

	return memberIDs
}

func validateRequestedGroupMembers(
	app *pocketbase.PocketBase,
	ownerID string,
	memberIDs []string,
) error {
	for _, memberID := range memberIDs {
		if _, err := app.FindRecordById("users", memberID); err != nil {
			return fmt.Errorf("group member not found: %s", memberID)
		}

		isFriend, err := areAlreadyFriends(app, ownerID, memberID)
		if err != nil {
			return err
		}
		if !isFriend {
			return fmt.Errorf("group member is not your friend: %s", memberID)
		}
	}

	return nil
}

func createGroupCapsuleMembers(
	app *pocketbase.PocketBase,
	capsuleID string,
	ownerID string,
	memberIDs []string,
) error {
	if len(memberIDs) == 0 {
		return nil
	}

	col, err := app.FindCollectionByNameOrId("capsule_members")
	if err != nil {
		return err
	}

	now := time.Now().UTC()
	allParticipants := make([]string, 0, len(memberIDs)+1)
	allParticipants = append(allParticipants, ownerID)
	allParticipants = append(allParticipants, memberIDs...)

	for _, participantID := range allParticipants {
		record := core.NewRecord(col)
		record.Set("capsule", capsuleID)
		record.Set("user", participantID)
		record.Set("status", groupCapsuleMemberStatusJoined)
		record.Set("accepted_at", now)

		if participantID == ownerID {
			record.Set("role", groupCapsuleMemberRoleOwner)
		} else {
			record.Set("role", groupCapsuleMemberRoleMember)
			record.Set("invited_by", ownerID)
		}

		if err := app.Save(record); err != nil {
			return err
		}
	}

	return nil
}

func canAccessCapsule(app *pocketbase.PocketBase, userID string, capsule *core.Record) (bool, error) {
	if capsule.GetString("users") == userID {
		return true, nil
	}

	_, err := app.FindFirstRecordByFilter(
		"capsule_members",
		"capsule = {:capsule} && user = {:user} && status = {:status}",
		dbx.Params{
			"capsule": capsule.Id,
			"user":    userID,
			"status":  groupCapsuleMemberStatusJoined,
		},
	)
	if err == nil {
		return true, nil
	}
	if errors.Is(err, sql.ErrNoRows) {
		return false, nil
	}
	return false, err
}

func findGroupCapsulesForUser(app *pocketbase.PocketBase, userID string) ([]*core.Record, error) {
	memberRecords, err := app.FindRecordsByFilter(
		"capsule_members",
		"user = {:user} && status = {:status}",
		"",
		0,
		0,
		dbx.Params{
			"user":   userID,
			"status": groupCapsuleMemberStatusJoined,
		},
	)
	if err != nil {
		return nil, err
	}

	seen := make(map[string]struct{}, len(memberRecords))
	records := make([]*core.Record, 0, len(memberRecords))

	for _, memberRecord := range memberRecords {
		capsuleID := strings.TrimSpace(memberRecord.GetString("capsule"))
		if capsuleID == "" {
			continue
		}
		if _, exists := seen[capsuleID]; exists {
			continue
		}
		seen[capsuleID] = struct{}{}

		capsuleRecord, err := app.FindRecordById("capsules", capsuleID)
		if err != nil {
			if errors.Is(err, sql.ErrNoRows) {
				continue
			}
			return nil, err
		}
		records = append(records, capsuleRecord)
	}

	return records, nil
}
