package main

import (
	"database/sql"
	"errors"
	"net/http"
	"sort"
	"strings"
	"time"

	"github.com/pocketbase/dbx"
	"github.com/pocketbase/pocketbase"
	"github.com/pocketbase/pocketbase/core"
	"github.com/pocketbase/pocketbase/tools/hook"
)

type challengeConditionType string

const (
	challengeConditionTravelCreated    challengeConditionType = "travel_created"
	challengeConditionCapsuleCreated   challengeConditionType = "capsule_created"
	challengeConditionPhotoUploaded    challengeConditionType = "photo_uploaded"
	challengeConditionPlaceVisited     challengeConditionType = "place_visited"
	challengeConditionConsecutiveLogin challengeConditionType = "consecutive_login"
	challengeConditionCapsuleViewed    challengeConditionType = "capsule_viewed"
)

const (
	challengeStatusInProgress = "in_progress"
	challengeStatusCompleted  = "completed"
	challengeStatusClaimed    = "claimed"
)

var (
	errChallengeNotFound       = errors.New("challenge not found")
	errUserChallengeNotFound   = errors.New("user challenge not found")
	errChallengeNotCompleted   = errors.New("challenge not completed")
	errChallengeAlreadyClaimed = errors.New("challenge already claimed")
)

type challengeService struct {
	app *pocketbase.PocketBase
}

func newChallengeService(app *pocketbase.PocketBase) *challengeService {
	return &challengeService{app: app}
}

func registerChallengeRoutes(app *pocketbase.PocketBase) {
	app.OnServe().Bind(&hook.Handler[*core.ServeEvent]{
		Func: func(e *core.ServeEvent) error {
			e.Router.GET("/challenges/me", listMyChallenges(app))
			e.Router.POST("/challenges/{id}/claim", claimChallengeReward(app))
			return e.Next()
		},
	})
}

func listMyChallenges(app *pocketbase.PocketBase) func(*core.RequestEvent) error {
	return func(re *core.RequestEvent) error {
		if re.Auth == nil {
			return re.JSON(http.StatusUnauthorized, map[string]string{"message": "unauthorized"})
		}

		service := newChallengeService(app)
		items, err := service.listUserChallenges(re.Auth.Id)
		if err != nil {
			return re.JSON(http.StatusInternalServerError, map[string]string{"message": err.Error()})
		}

		return re.JSON(http.StatusOK, map[string]any{"challenges": items})
	}
}

func claimChallengeReward(app *pocketbase.PocketBase) func(*core.RequestEvent) error {
	return func(re *core.RequestEvent) error {
		if re.Auth == nil {
			return re.JSON(http.StatusUnauthorized, map[string]string{"message": "unauthorized"})
		}

		challengeID := strings.TrimSpace(re.Request.PathValue("id"))
		if challengeID == "" {
			return re.JSON(http.StatusBadRequest, map[string]string{"message": "challenge id is required"})
		}

		service := newChallengeService(app)
		record, err := service.claimChallenge(re.Auth.Id, challengeID)
		if err != nil {
			switch {
			case errors.Is(err, errChallengeNotFound):
				return re.JSON(http.StatusNotFound, map[string]string{"message": "challenge not found"})
			case errors.Is(err, errUserChallengeNotFound):
				return re.JSON(http.StatusNotFound, map[string]string{"message": "challenge progress not found"})
			case errors.Is(err, errChallengeNotCompleted):
				return re.JSON(http.StatusBadRequest, map[string]string{"message": "challenge is not completed"})
			case errors.Is(err, errChallengeAlreadyClaimed):
				return re.JSON(http.StatusConflict, map[string]string{"message": "challenge reward already claimed"})
			default:
				return re.JSON(http.StatusInternalServerError, map[string]string{"message": err.Error()})
			}
		}

		return re.JSON(http.StatusOK, map[string]any{
			"user_challenge": map[string]any{
				"id":           record.Id,
				"challenge":    record.GetString("challenge"),
				"status":       record.GetString("status"),
				"progress":     record.GetInt("progress_value"),
				"completed_at": record.Get("completed_at"),
				"claimed_at":   record.Get("claimed_at"),
			},
		})
	}
}

func (s *challengeService) listUserChallenges(userID string) ([]map[string]any, error) {
	userChallengeRecords, err := s.app.FindAllRecords("user_challenges", dbx.HashExp{"user": userID})
	if err != nil {
		return nil, err
	}

	userChallengesByChallengeID := make(map[string]*core.Record, len(userChallengeRecords))
	for _, item := range userChallengeRecords {
		userChallengesByChallengeID[item.GetString("challenge")] = item
	}

	activeChallenges, err := s.findActiveChallengesByCondition("")
	if err != nil {
		return nil, err
	}

	sort.Slice(activeChallenges, func(i, j int) bool {
		leftSort := activeChallenges[i].GetInt("sort_order")
		rightSort := activeChallenges[j].GetInt("sort_order")
		if leftSort != rightSort {
			return leftSort < rightSort
		}
		return activeChallenges[i].GetString("title") < activeChallenges[j].GetString("title")
	})

	result := make([]map[string]any, 0, len(activeChallenges))
	for _, challenge := range activeChallenges {
		userChallenge := userChallengesByChallengeID[challenge.Id]
		result = append(result, buildChallengeResponse(challenge, userChallenge))
	}

	return result, nil
}

func (s *challengeService) trackAction(userID string, conditionType challengeConditionType, delta int) error {
	if userID == "" {
		return nil
	}

	challenges, err := s.findActiveChallengesByCondition(conditionType)
	if err != nil {
		return err
	}
	if len(challenges) == 0 {
		return nil
	}

	now := time.Now().UTC()
	for _, challenge := range challenges {
		if err := s.applyActionToChallenge(userID, challenge, conditionType, delta, now); err != nil {
			return err
		}
	}

	return nil
}

func (s *challengeService) claimChallenge(userID, challengeID string) (*core.Record, error) {
	challenge, err := s.app.FindRecordById("challenges", challengeID)
	if err != nil {
		return nil, errChallengeNotFound
	}

	userChallenge, err := s.app.FindFirstRecordByFilter(
		"user_challenges",
		"user = {:user} && challenge = {:challenge}",
		dbx.Params{"user": userID, "challenge": challengeID},
	)
	if err != nil {
		if errors.Is(err, sql.ErrNoRows) {
			return nil, errUserChallengeNotFound
		}
		return nil, err
	}

	status := normalizeChallengeStatus(userChallenge.GetString("status"))
	if status == challengeStatusClaimed {
		return nil, errChallengeAlreadyClaimed
	}

	target := challenge.GetInt("condition_value")
	if target <= 0 {
		target = 1
	}

	progress := userChallenge.GetInt("progress_value")
	if status != challengeStatusCompleted && progress < target {
		return nil, errChallengeNotCompleted
	}

	now := time.Now().UTC()
	if userChallenge.GetDateTime("completed_at").IsZero() {
		userChallenge.Set("completed_at", now)
	}

	userChallenge.Set("status", challengeStatusClaimed)
	userChallenge.Set("claimed_at", now)

	if err := s.app.Save(userChallenge); err != nil {
		return nil, err
	}

	return userChallenge, nil
}

func (s *challengeService) applyActionToChallenge(
	userID string,
	challenge *core.Record,
	conditionType challengeConditionType,
	delta int,
	now time.Time,
) error {
	userChallenge, isNewRecord, err := s.findOrInitUserChallenge(userID, challenge.Id)
	if err != nil {
		return err
	}

	status := normalizeChallengeStatus(userChallenge.GetString("status"))
	if status == challengeStatusCompleted || status == challengeStatusClaimed {
		return nil
	}

	target := challenge.GetInt("condition_value")
	if target <= 0 {
		target = 1
	}

	currentProgress := userChallenge.GetInt("progress_value")
	if currentProgress < 0 {
		currentProgress = 0
	}

	var (
		nextProgress int
		changed      bool
	)

	if conditionType == challengeConditionConsecutiveLogin {
		nextProgress, changed = calculateConsecutiveLoginProgress(
			currentProgress,
			userChallenge.GetDateTime("updated").Time().UTC(),
			now,
		)
	} else {
		step := delta
		if step <= 0 {
			step = 1
		}
		nextProgress = currentProgress + step
		changed = step != 0
	}

	if changed {
		userChallenge.Set("progress_value", nextProgress)
	}

	shouldComplete := nextProgress >= target
	if shouldComplete {
		userChallenge.Set("status", challengeStatusCompleted)
		if userChallenge.GetDateTime("completed_at").IsZero() {
			userChallenge.Set("completed_at", now)
		}
	}

	if !isNewRecord && !changed && !shouldComplete {
		return nil
	}

	return s.app.Save(userChallenge)
}

func (s *challengeService) findOrInitUserChallenge(userID, challengeID string) (*core.Record, bool, error) {
	record, err := s.app.FindFirstRecordByFilter(
		"user_challenges",
		"user = {:user} && challenge = {:challenge}",
		dbx.Params{"user": userID, "challenge": challengeID},
	)
	if err == nil {
		return record, false, nil
	}
	if !errors.Is(err, sql.ErrNoRows) {
		return nil, false, err
	}

	collection, err := s.app.FindCollectionByNameOrId("user_challenges")
	if err != nil {
		return nil, false, err
	}

	record = core.NewRecord(collection)
	record.Set("user", userID)
	record.Set("challenge", challengeID)
	record.Set("status", challengeStatusInProgress)
	record.Set("progress_value", 0)

	return record, true, nil
}

func (s *challengeService) findActiveChallengesByCondition(conditionType challengeConditionType) ([]*core.Record, error) {
	expressions := []dbx.Expression{
		dbx.HashExp{"is_active": true},
	}
	if conditionType != "" {
		expressions = append(expressions, dbx.HashExp{"condition_type": string(conditionType)})
	}

	records, err := s.app.FindAllRecords("challenges", expressions...)
	if err != nil {
		return nil, err
	}

	now := time.Now().UTC()
	result := make([]*core.Record, 0, len(records))
	for _, challenge := range records {
		if !isInChallengeWindow(challenge, now) {
			continue
		}
		result = append(result, challenge)
	}

	return result, nil
}

func isInChallengeWindow(challenge *core.Record, now time.Time) bool {
	startAt := challenge.GetDateTime("start_at")
	if !startAt.IsZero() && now.Before(startAt.Time()) {
		return false
	}

	endAt := challenge.GetDateTime("end_at")
	if !endAt.IsZero() && now.After(endAt.Time()) {
		return false
	}

	return true
}

func calculateConsecutiveLoginProgress(current int, lastUpdated, now time.Time) (int, bool) {
	if current < 0 {
		current = 0
	}
	if lastUpdated.IsZero() {
		if current >= 1 {
			return current, false
		}
		return 1, true
	}

	today := startOfUTCDay(now)
	lastDay := startOfUTCDay(lastUpdated)

	if today.Equal(lastDay) {
		return current, false
	}

	if today.Sub(lastDay) == 24*time.Hour {
		if current < 1 {
			current = 1
		}
		return current + 1, true
	}

	return 1, true
}

func startOfUTCDay(t time.Time) time.Time {
	utc := t.UTC()
	return time.Date(utc.Year(), utc.Month(), utc.Day(), 0, 0, 0, 0, time.UTC)
}

func normalizeChallengeStatus(status string) string {
	switch status {
	case challengeStatusCompleted, challengeStatusClaimed:
		return status
	default:
		return challengeStatusInProgress
	}
}

func buildChallengeResponse(challenge, userChallenge *core.Record) map[string]any {
	status := challengeStatusInProgress
	progress := 0
	var completedAt any
	var claimedAt any

	if userChallenge != nil {
		status = normalizeChallengeStatus(userChallenge.GetString("status"))
		progress = userChallenge.GetInt("progress_value")
		completedAt = userChallenge.Get("completed_at")
		claimedAt = userChallenge.Get("claimed_at")
	}

	target := challenge.GetInt("condition_value")
	if target <= 0 {
		target = 1
	}

	return map[string]any{
		"id":              challenge.Id,
		"code":            challenge.GetString("code"),
		"title":           challenge.GetString("title"),
		"description":     challenge.GetString("description"),
		"category":        challenge.GetString("category"),
		"challenge_type":  challenge.GetString("challenge_type"),
		"condition_type":  challenge.GetString("condition_type"),
		"condition_value": target,
		"reward_type":     challenge.GetString("reward_type"),
		"reward_value":    challenge.GetInt("reward_value"),
		"icon":            challenge.GetString("icon"),
		"sort_order":      challenge.GetInt("sort_order"),
		"status":          status,
		"progress_value":  progress,
		"completed_at":    completedAt,
		"claimed_at":      claimedAt,
	}
}

func trackTravelCreatedChallenge(app *pocketbase.PocketBase, userID string) {
	trackChallengeAction(app, userID, challengeConditionTravelCreated, 1)
}

func trackCapsuleCreatedChallenge(app *pocketbase.PocketBase, userID string) {
	trackChallengeAction(app, userID, challengeConditionCapsuleCreated, 1)
}

func trackPhotoUploadedChallenge(app *pocketbase.PocketBase, userID string, photoCount int) {
	if photoCount <= 0 {
		return
	}
	trackChallengeAction(app, userID, challengeConditionPhotoUploaded, photoCount)
}

func trackPlaceVisitedChallenge(app *pocketbase.PocketBase, userID string) {
	trackChallengeAction(app, userID, challengeConditionPlaceVisited, 1)
}

func trackConsecutiveLoginChallenge(app *pocketbase.PocketBase, userID string) {
	trackChallengeAction(app, userID, challengeConditionConsecutiveLogin, 1)
}

func trackCapsuleViewedChallenge(app *pocketbase.PocketBase, userID string) {
	trackChallengeAction(app, userID, challengeConditionCapsuleViewed, 1)
}

func trackChallengeAction(
	app *pocketbase.PocketBase,
	userID string,
	conditionType challengeConditionType,
	delta int,
) {
	service := newChallengeService(app)
	if err := service.trackAction(userID, conditionType, delta); err != nil {
		app.Logger().Error(
			"failed to track challenge action",
			"userId", userID,
			"conditionType", string(conditionType),
			"delta", delta,
			"error", err,
		)
	}
}
