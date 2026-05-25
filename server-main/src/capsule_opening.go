package main

import (
	"database/sql"
	"errors"
	"strconv"
	"strings"
	"time"

	"github.com/pocketbase/dbx"
	"github.com/pocketbase/pocketbase"
	"github.com/pocketbase/pocketbase/core"
)

const (
	capsuleOpenOptionAnytime          = "anytime"
	capsuleOpenOptionDaysLater        = "days_later"
	capsuleOpenOptionNextYearSameTime = "next_year_same_time"
)

type capsuleOpenConfig struct {
	Option        string
	OpenAt        *time.Time
	OpenAfterDays int
	NotifyEnabled bool
}

func parseCapsuleOpenConfig(re *core.RequestEvent, now time.Time) (capsuleOpenConfig, error) {
	option := strings.ToLower(strings.TrimSpace(re.Request.FormValue("open_option")))
	if option == "" {
		option = capsuleOpenOptionAnytime
	}

	switch option {
	case capsuleOpenOptionAnytime:
		return capsuleOpenConfig{
			Option:        option,
			NotifyEnabled: false,
		}, nil
	case capsuleOpenOptionDaysLater:
		rawDays := strings.TrimSpace(re.Request.FormValue("open_after_days"))
		days, err := strconv.Atoi(rawDays)
		if err != nil || days < 1 || days > 3650 {
			return capsuleOpenConfig{}, errors.New("open_after_days must be between 1 and 3650")
		}
		openAt := now.AddDate(0, 0, days)
		return capsuleOpenConfig{
			Option:        option,
			OpenAt:        &openAt,
			OpenAfterDays: days,
			NotifyEnabled: true,
		}, nil
	case capsuleOpenOptionNextYearSameTime:
		openAt := now.AddDate(1, 0, 0)
		return capsuleOpenConfig{
			Option:        option,
			OpenAt:        &openAt,
			NotifyEnabled: true,
		}, nil
	default:
		return capsuleOpenConfig{}, errors.New("open_option must be one of: anytime, days_later, next_year_same_time")
	}
}

func createCapsuleOpenSetting(
	app *pocketbase.PocketBase,
	capsuleID string,
	config capsuleOpenConfig,
) error {
	col, err := app.FindCollectionByNameOrId("capsule_open_settings")
	if err != nil {
		return err
	}

	record := core.NewRecord(col)
	record.Set("capsule", capsuleID)
	record.Set("open_option", config.Option)
	if config.OpenAfterDays > 0 {
		record.Set("open_after_days", config.OpenAfterDays)
	}
	if config.OpenAt != nil {
		record.Set("open_at", config.OpenAt.UTC())
	}
	record.Set("notify_enabled", config.NotifyEnabled)

	return app.Save(record)
}

func loadCapsuleOpenSetting(
	app *pocketbase.PocketBase,
	capsuleID string,
) (*core.Record, error) {
	record, err := app.FindFirstRecordByFilter(
		"capsule_open_settings",
		"capsule = {:capsule}",
		dbx.Params{"capsule": capsuleID},
	)
	if err != nil {
		if errors.Is(err, sql.ErrNoRows) {
			return nil, nil
		}
		return nil, err
	}
	return record, nil
}

func buildCapsuleOpenMeta(
	app *pocketbase.PocketBase,
	capsuleID string,
	now time.Time,
) (map[string]any, bool, error) {
	setting, err := loadCapsuleOpenSetting(app, capsuleID)
	if err != nil {
		return nil, false, err
	}
	if setting == nil {
		return map[string]any{
			"open_option":     capsuleOpenOptionAnytime,
			"open_after_days": nil,
			"open_at":         nil,
			"can_open_now":    true,
		}, true, nil
	}

	option := strings.ToLower(strings.TrimSpace(setting.GetString("open_option")))
	if option == "" {
		option = capsuleOpenOptionAnytime
	}

	openAtTime := setting.GetDateTime("open_at").Time().UTC()
	hasOpenAt := !setting.GetDateTime("open_at").IsZero()
	canOpen := true

	if option != capsuleOpenOptionAnytime && hasOpenAt {
		canOpen = !now.UTC().Before(openAtTime)
	}

	var openAtValue any
	if hasOpenAt {
		openAtValue = openAtTime
	}

	return map[string]any{
		"open_option":     option,
		"open_after_days": setting.GetInt("open_after_days"),
		"open_at":         openAtValue,
		"can_open_now":    canOpen,
	}, canOpen, nil
}
