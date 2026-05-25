package main

import (
	"bytes"
	"context"
	"database/sql"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"net/http"
	"os"
	"strconv"
	"strings"
	"sync/atomic"
	"time"

	"github.com/pocketbase/dbx"
	"github.com/pocketbase/pocketbase"
	"github.com/pocketbase/pocketbase/core"
	"github.com/pocketbase/pocketbase/tools/hook"
	"golang.org/x/oauth2"
	"golang.org/x/oauth2/google"
)

const (
	groupCapsuleOpenPushCronJobID = "group_capsule_open_push"
	groupCapsuleOpenPushCronExpr  = "* * * * *"
	maxPushTokenLength            = 4096
	maxPushPlatformLength         = 32
	maxPushDeviceIDLength         = 255
	fcmMessagingScope             = "https://www.googleapis.com/auth/firebase.messaging"
	fcmSendMessageURLTemplate     = "https://fcm.googleapis.com/v1/projects/%s/messages:send"
	capsuleOpenPushPayloadType    = "capsule_open"
	capsuleOpenPushTitle          = "Capsule is open"
	capsuleOpenPushBodyGroup      = "A group capsule can now be opened."
	capsuleOpenPushBodyIndividual = "Your capsule can now be opened."
	pushTokenPlatformAndroid      = "android"
	pushTokenPlatformIOS          = "ios"
	pushTokenPlatformWeb          = "web"
	pushTokenPlatformMacOS        = "macos"
	pushTokenPlatformWindows      = "windows"
	pushTokenPlatformLinux        = "linux"
)

var (
	groupCapsulePushCronRunning atomic.Bool
	fcmConfigWarningLogged      atomic.Bool
)

type registerPushTokenBody struct {
	FCMToken string `json:"fcm_token"`
	Platform string `json:"platform"`
	DeviceID string `json:"device_id"`
}

type deactivatePushTokenBody struct {
	FCMToken string `json:"fcm_token"`
	DeviceID string `json:"device_id"`
}

type fcmPushService struct {
	client    *http.Client
	projectID string
}

type fcmSendMessageRequest struct {
	Message fcmMessagePayload `json:"message"`
}

type fcmMessagePayload struct {
	Token        string            `json:"token"`
	Notification fcmNotification   `json:"notification"`
	Data         map[string]string `json:"data,omitempty"`
}

type fcmNotification struct {
	Title string `json:"title"`
	Body  string `json:"body"`
}

type fcmSendError struct {
	StatusCode   int
	Status       string
	Message      string
	FCMErrorCode string
	RawBody      string
}

func (e *fcmSendError) Error() string {
	if e == nil {
		return "unknown fcm send error"
	}

	message := strings.TrimSpace(e.Message)
	if message == "" {
		message = strings.TrimSpace(e.RawBody)
	}
	if message == "" {
		message = "fcm send failed"
	}

	return "fcm send failed (" + strconv.Itoa(e.StatusCode) + "): " + message
}

func (e *fcmSendError) isInvalidTokenError() bool {
	if e == nil {
		return false
	}

	switch strings.ToUpper(strings.TrimSpace(e.FCMErrorCode)) {
	case "UNREGISTERED", "INVALID_ARGUMENT", "SENDER_ID_MISMATCH":
		return true
	}

	return false
}

type fcmErrorResponse struct {
	Error struct {
		Code    int    `json:"code"`
		Message string `json:"message"`
		Status  string `json:"status"`
		Details []struct {
			Type      string `json:"@type"`
			ErrorCode string `json:"errorCode"`
		} `json:"details"`
	} `json:"error"`
}

func registerGroupCapsulePushFeatures(app *pocketbase.PocketBase) {
	registerPushTokenRoutes(app)
	registerGroupCapsuleOpenPushCron(app)
}

func registerPushTokenRoutes(app *pocketbase.PocketBase) {
	app.OnServe().Bind(&hook.Handler[*core.ServeEvent]{
		Func: func(e *core.ServeEvent) error {
			e.Router.POST("/push-tokens", upsertPushToken(app))
			e.Router.DELETE("/push-tokens", deactivatePushToken(app))
			return e.Next()
		},
	})
}

func upsertPushToken(app *pocketbase.PocketBase) func(*core.RequestEvent) error {
	return func(re *core.RequestEvent) error {
		if re.Auth == nil {
			return re.JSON(http.StatusUnauthorized, map[string]string{"message": "unauthorized"})
		}

		body, err := parseRegisterPushTokenBody(re)
		if err != nil {
			return re.JSON(http.StatusBadRequest, map[string]string{"message": err.Error()})
		}

		token := strings.TrimSpace(body.FCMToken)
		platform, err := normalizePushPlatform(body.Platform)
		if err != nil {
			return re.JSON(http.StatusBadRequest, map[string]string{"message": err.Error()})
		}
		deviceID, err := normalizeDeviceID(body.DeviceID)
		if err != nil {
			return re.JSON(http.StatusBadRequest, map[string]string{"message": err.Error()})
		}

		record, err := findPushTokenRecordByToken(app, token)
		if err != nil {
			return re.JSON(http.StatusInternalServerError, map[string]string{"message": err.Error()})
		}

		if record == nil {
			col, err := app.FindCollectionByNameOrId("user_push_tokens")
			if err != nil {
				return re.JSON(http.StatusInternalServerError, map[string]string{"message": err.Error()})
			}
			record = core.NewRecord(col)
		}

		now := time.Now().UTC()
		record.Set("user", re.Auth.Id)
		record.Set("fcm_token", token)
		record.Set("platform", platform)
		record.Set("device_id", deviceID)
		record.Set("is_active", true)
		record.Set("last_seen_at", now)

		if err := app.Save(record); err != nil {
			return re.JSON(http.StatusBadRequest, map[string]string{"message": err.Error()})
		}

		if deviceID != "" {
			if err := deactivateOtherPushTokensOnDevice(app, re.Auth.Id, deviceID, token, now); err != nil {
				return re.JSON(http.StatusInternalServerError, map[string]string{"message": err.Error()})
			}
		}

		return re.JSON(http.StatusOK, map[string]any{
			"push_token": map[string]any{
				"id":           record.Id,
				"fcm_token":    token,
				"platform":     platform,
				"device_id":    deviceID,
				"is_active":    true,
				"last_seen_at": now,
			},
		})
	}
}

func deactivatePushToken(app *pocketbase.PocketBase) func(*core.RequestEvent) error {
	return func(re *core.RequestEvent) error {
		if re.Auth == nil {
			return re.JSON(http.StatusUnauthorized, map[string]string{"message": "unauthorized"})
		}

		body, err := parseDeactivatePushTokenBody(re)
		if err != nil {
			return re.JSON(http.StatusBadRequest, map[string]string{"message": err.Error()})
		}

		token := strings.TrimSpace(body.FCMToken)
		deviceID := strings.TrimSpace(body.DeviceID)
		if token == "" && deviceID == "" {
			return re.JSON(http.StatusBadRequest, map[string]string{"message": "fcm_token or device_id is required"})
		}

		filterParts := []string{"user = {:user}"}
		params := dbx.Params{"user": re.Auth.Id}

		if token != "" {
			filterParts = append(filterParts, "fcm_token = {:token}")
			params["token"] = token
		}
		if deviceID != "" {
			filterParts = append(filterParts, "device_id = {:device}")
			params["device"] = deviceID
		}

		records, err := app.FindRecordsByFilter(
			"user_push_tokens",
			strings.Join(filterParts, " && "),
			"",
			0,
			0,
			params,
		)
		if err != nil {
			return re.JSON(http.StatusInternalServerError, map[string]string{"message": err.Error()})
		}

		now := time.Now().UTC()
		deactivated := 0
		for _, record := range records {
			if !record.GetBool("is_active") {
				continue
			}
			record.Set("is_active", false)
			record.Set("last_seen_at", now)
			if err := app.Save(record); err != nil {
				return re.JSON(http.StatusInternalServerError, map[string]string{"message": err.Error()})
			}
			deactivated++
		}

		return re.JSON(http.StatusOK, map[string]any{
			"deactivated": deactivated,
		})
	}
}

func parseRegisterPushTokenBody(re *core.RequestEvent) (registerPushTokenBody, error) {
	var body registerPushTokenBody
	if err := re.BindBody(&body); err != nil {
		_ = re.Request.ParseForm()
		body.FCMToken = re.Request.FormValue("fcm_token")
		body.Platform = re.Request.FormValue("platform")
		body.DeviceID = re.Request.FormValue("device_id")
	}

	body.FCMToken = strings.TrimSpace(body.FCMToken)
	if body.FCMToken == "" {
		return body, errors.New("fcm_token is required")
	}
	if len(body.FCMToken) > maxPushTokenLength {
		return body, errors.New("fcm_token is too long")
	}

	return body, nil
}

func parseDeactivatePushTokenBody(re *core.RequestEvent) (deactivatePushTokenBody, error) {
	var body deactivatePushTokenBody
	if err := re.BindBody(&body); err != nil {
		_ = re.Request.ParseForm()
		body.FCMToken = re.Request.FormValue("fcm_token")
		body.DeviceID = re.Request.FormValue("device_id")
	}

	return body, nil
}

func normalizePushPlatform(raw string) (string, error) {
	platform := strings.ToLower(strings.TrimSpace(raw))
	if platform == "" {
		return "", nil
	}

	switch platform {
	case pushTokenPlatformAndroid, pushTokenPlatformIOS, pushTokenPlatformWeb, pushTokenPlatformMacOS, pushTokenPlatformWindows, pushTokenPlatformLinux:
		return platform, nil
	default:
		if len(platform) > maxPushPlatformLength {
			return "", errors.New("platform is too long")
		}
		return platform, nil
	}
}

func normalizeDeviceID(raw string) (string, error) {
	deviceID := strings.TrimSpace(raw)
	if len(deviceID) > maxPushDeviceIDLength {
		return "", errors.New("device_id is too long")
	}
	return deviceID, nil
}

func findPushTokenRecordByToken(app *pocketbase.PocketBase, token string) (*core.Record, error) {
	record, err := app.FindFirstRecordByFilter(
		"user_push_tokens",
		"fcm_token = {:token}",
		dbx.Params{"token": token},
	)
	if err != nil {
		if errors.Is(err, sql.ErrNoRows) {
			return nil, nil
		}
		return nil, err
	}

	return record, nil
}

func deactivateOtherPushTokensOnDevice(
	app *pocketbase.PocketBase,
	userID string,
	deviceID string,
	currentToken string,
	now time.Time,
) error {
	records, err := app.FindRecordsByFilter(
		"user_push_tokens",
		"user = {:user} && device_id = {:device} && fcm_token != {:token} && is_active = true",
		"",
		0,
		0,
		dbx.Params{
			"user":   userID,
			"device": deviceID,
			"token":  currentToken,
		},
	)
	if err != nil {
		return err
	}

	for _, record := range records {
		record.Set("is_active", false)
		record.Set("last_seen_at", now)
		if err := app.Save(record); err != nil {
			return err
		}
	}

	return nil
}

func registerGroupCapsuleOpenPushCron(app *pocketbase.PocketBase) {
	if err := app.Cron().Add(groupCapsuleOpenPushCronJobID, groupCapsuleOpenPushCronExpr, func() {
		if !groupCapsulePushCronRunning.CompareAndSwap(false, true) {
			return
		}
		defer groupCapsulePushCronRunning.Store(false)

		executeGroupCapsuleOpenPushCron(app)
	}); err != nil {
		app.Logger().Error(
			"failed to register capsule open push cron",
			"error", err,
		)
	}
}

func executeGroupCapsuleOpenPushCron(app *pocketbase.PocketBase) {
	now := time.Now().UTC()
	settings, err := findDueOpenSettingsForPush(app, now)
	if err != nil {
		app.Logger().Error(
			"failed to load capsule open settings for push",
			"error", err,
		)
		return
	}
	if len(settings) == 0 {
		return
	}

	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()

	pusher, err := newFCMPushService(ctx)
	if err != nil {
		if !fcmConfigWarningLogged.Swap(true) {
			app.Logger().Warn(
				"capsule open push is skipped because FCM is not configured",
				"error", err,
			)
		}
		return
	}
	fcmConfigWarningLogged.Store(false)

	for _, setting := range settings {
		shouldMarkDone, err := processOpenSettingPush(ctx, app, pusher, setting)
		if err != nil {
			app.Logger().Error(
				"failed to process capsule open push",
				"capsuleId", setting.GetString("capsule"),
				"settingId", setting.Id,
				"error", err,
			)
		}
		if !shouldMarkDone {
			continue
		}

		setting.Set("notify_enabled", false)
		if err := app.Save(setting); err != nil {
			app.Logger().Error(
				"failed to mark capsule open push as completed",
				"capsuleId", setting.GetString("capsule"),
				"settingId", setting.Id,
				"error", err,
			)
		}
	}
}

func findDueOpenSettingsForPush(app *pocketbase.PocketBase, now time.Time) ([]*core.Record, error) {
	records, err := app.FindRecordsByFilter(
		"capsule_open_settings",
		"notify_enabled = true",
		"open_at",
		500,
		0,
		nil,
	)
	if err != nil {
		return nil, err
	}

	due := make([]*core.Record, 0, len(records))
	for _, record := range records {
		option := strings.ToLower(strings.TrimSpace(record.GetString("open_option")))
		if option == capsuleOpenOptionAnytime {
			continue
		}
		openAt := record.GetDateTime("open_at")
		if openAt.IsZero() {
			continue
		}
		if openAt.Time().UTC().After(now) {
			continue
		}
		due = append(due, record)
	}

	return due, nil
}

func processOpenSettingPush(
	ctx context.Context,
	app *pocketbase.PocketBase,
	pusher *fcmPushService,
	setting *core.Record,
) (bool, error) {
	capsuleID := strings.TrimSpace(setting.GetString("capsule"))
	if capsuleID == "" {
		return true, nil
	}

	capsule, err := app.FindRecordById("capsules", capsuleID)
	if err != nil {
		if errors.Is(err, sql.ErrNoRows) {
			return true, nil
		}
		return false, err
	}

	userIDs, err := resolveCapsuleParticipantUserIDs(app, capsule)
	if err != nil {
		return false, err
	}
	if len(userIDs) == 0 {
		return true, nil
	}

	isGroupCapsule := len(userIDs) > 1
	payloadData := map[string]string{
		"type":       capsuleOpenPushPayloadType,
		"capsule_id": capsuleID,
		"is_group":   strconv.FormatBool(isGroupCapsule),
	}

	anyTransientFailure := false

	for _, userID := range userIDs {
		tokens, err := findActivePushTokensByUser(app, userID)
		if err != nil {
			return false, err
		}
		for _, tokenRecord := range tokens {
			token := strings.TrimSpace(tokenRecord.GetString("fcm_token"))
			if token == "" {
				continue
			}

			title := capsuleOpenPushTitle
			body := capsuleOpenPushBodyIndividual
			if isGroupCapsule {
				body = capsuleOpenPushBodyGroup
			}
			err := pusher.sendNotification(ctx, token, title, body, payloadData)
			if err == nil {
				continue
			}

			var sendErr *fcmSendError
			if errors.As(err, &sendErr) && sendErr.isInvalidTokenError() {
				now := time.Now().UTC()
				tokenRecord.Set("is_active", false)
				tokenRecord.Set("last_seen_at", now)
				if saveErr := app.Save(tokenRecord); saveErr != nil {
					app.Logger().Error(
						"failed to deactivate invalid push token",
						"userId", userID,
						"tokenId", tokenRecord.Id,
						"error", saveErr,
					)
				}
				continue
			}

			anyTransientFailure = true
			app.Logger().Warn(
				"failed to send capsule open push",
				"userId", userID,
				"tokenId", tokenRecord.Id,
				"error", err,
			)
		}
	}

	if anyTransientFailure {
		return false, nil
	}

	return true, nil
}

func resolveCapsuleParticipantUserIDs(app *pocketbase.PocketBase, capsule *core.Record) ([]string, error) {
	seen := map[string]struct{}{}
	userIDs := make([]string, 0, 4)

	ownerID := strings.TrimSpace(capsule.GetString("users"))
	if ownerID != "" {
		seen[ownerID] = struct{}{}
		userIDs = append(userIDs, ownerID)
	}

	memberRecords, err := app.FindRecordsByFilter(
		"capsule_members",
		"capsule = {:capsule} && status = {:status}",
		"",
		0,
		0,
		dbx.Params{
			"capsule": capsule.Id,
			"status":  groupCapsuleMemberStatusJoined,
		},
	)
	if err != nil {
		return nil, err
	}

	for _, member := range memberRecords {
		userID := strings.TrimSpace(member.GetString("user"))
		if userID == "" {
			continue
		}
		if _, exists := seen[userID]; exists {
			continue
		}
		seen[userID] = struct{}{}
		userIDs = append(userIDs, userID)
	}

	return userIDs, nil
}

func findActivePushTokensByUser(app *pocketbase.PocketBase, userID string) ([]*core.Record, error) {
	records, err := app.FindRecordsByFilter(
		"user_push_tokens",
		"user = {:user} && is_active = true",
		"",
		0,
		0,
		dbx.Params{"user": userID},
	)
	if err != nil {
		return nil, err
	}

	return records, nil
}

func newFCMPushService(ctx context.Context) (*fcmPushService, error) {
	var (
		creds *google.Credentials
		err   error
	)

	serviceAccountJSON := strings.TrimSpace(os.Getenv("FCM_SERVICE_ACCOUNT_JSON"))
	if serviceAccountJSON != "" {
		creds, err = google.CredentialsFromJSON(ctx, []byte(serviceAccountJSON), fcmMessagingScope)
	} else {
		creds, err = google.FindDefaultCredentials(ctx, fcmMessagingScope)
	}
	if err != nil {
		return nil, err
	}

	projectID := strings.TrimSpace(os.Getenv("FCM_PROJECT_ID"))
	if projectID == "" {
		projectID = strings.TrimSpace(creds.ProjectID)
	}
	if projectID == "" {
		return nil, errors.New("missing FCM project id")
	}

	return &fcmPushService{
		client:    oauth2.NewClient(ctx, creds.TokenSource),
		projectID: projectID,
	}, nil
}

func (s *fcmPushService) sendNotification(
	ctx context.Context,
	token string,
	title string,
	body string,
	data map[string]string,
) error {
	payload := fcmSendMessageRequest{
		Message: fcmMessagePayload{
			Token: token,
			Notification: fcmNotification{
				Title: title,
				Body:  body,
			},
			Data: data,
		},
	}

	rawBody, err := json.Marshal(payload)
	if err != nil {
		return err
	}

	url := fmt.Sprintf(fcmSendMessageURLTemplate, s.projectID)
	req, err := http.NewRequestWithContext(ctx, http.MethodPost, url, bytes.NewReader(rawBody))
	if err != nil {
		return err
	}
	req.Header.Set("Content-Type", "application/json")

	resp, err := s.client.Do(req)
	if err != nil {
		return err
	}
	defer resp.Body.Close()

	if resp.StatusCode >= http.StatusOK && resp.StatusCode < http.StatusMultipleChoices {
		return nil
	}

	respBody, _ := io.ReadAll(io.LimitReader(resp.Body, 1<<20))
	return buildFCMSendError(resp.StatusCode, respBody)
}

func buildFCMSendError(statusCode int, body []byte) error {
	sendErr := &fcmSendError{
		StatusCode: statusCode,
		RawBody:    strings.TrimSpace(string(body)),
	}

	if len(body) == 0 {
		return sendErr
	}

	var parsed fcmErrorResponse
	if err := json.Unmarshal(body, &parsed); err != nil {
		return sendErr
	}

	sendErr.Message = strings.TrimSpace(parsed.Error.Message)
	sendErr.Status = strings.TrimSpace(parsed.Error.Status)
	for _, detail := range parsed.Error.Details {
		code := strings.TrimSpace(detail.ErrorCode)
		if code != "" {
			sendErr.FCMErrorCode = code
			break
		}
	}

	return sendErr
}
