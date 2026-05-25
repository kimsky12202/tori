package main

import (
	"net/http"
	"strconv"
	"time"

	"github.com/pocketbase/dbx"
	"github.com/pocketbase/pocketbase"
	"github.com/pocketbase/pocketbase/core"
	"github.com/pocketbase/pocketbase/tools/filesystem"
	"github.com/pocketbase/pocketbase/tools/hook"
)

func registerCapsuleRoutes(app *pocketbase.PocketBase) {
	app.OnServe().Bind(&hook.Handler[*core.ServeEvent]{
		Func: func(e *core.ServeEvent) error {
			e.Router.POST("/capsules", createCapsule(app))
			e.Router.GET("/capsules", listCapsules(app))
			e.Router.GET("/capsules/{id}", getCapsule(app))
			e.Router.PATCH("/capsules/{id}/bury", buryCapsule(app))
			return e.Next()
		},
	})
}

func createCapsule(app *pocketbase.PocketBase) func(*core.RequestEvent) error {
	return func(re *core.RequestEvent) error {
		if re.Auth == nil {
			return re.JSON(http.StatusUnauthorized, map[string]string{"message": "unauthorized"})
		}

		if err := re.Request.ParseMultipartForm(50 << 20); err != nil {
			return re.JSON(http.StatusBadRequest, map[string]string{"message": "invalid form data"})
		}

		lat, err := strconv.ParseFloat(re.Request.FormValue("latitude"), 64)
		if err != nil {
			return re.JSON(http.StatusBadRequest, map[string]string{"message": "invalid latitude"})
		}
		lng, err := strconv.ParseFloat(re.Request.FormValue("longitude"), 64)
		if err != nil {
			return re.JSON(http.StatusBadRequest, map[string]string{"message": "invalid longitude"})
		}
		now := time.Now().UTC()
		openConfig, err := parseCapsuleOpenConfig(re, now)
		if err != nil {
			return re.JSON(http.StatusBadRequest, map[string]string{"message": err.Error()})
		}

		memberIDs := parseRequestedGroupMemberIDs(re)
		if err := validateRequestedGroupMembers(app, re.Auth.Id, memberIDs); err != nil {
			return re.JSON(http.StatusBadRequest, map[string]string{"message": err.Error()})
		}

		col, err := app.FindCollectionByNameOrId("capsules")
		if err != nil {
			return re.JSON(http.StatusInternalServerError, map[string]string{"message": err.Error()})
		}

		record := core.NewRecord(col)
		record.Set("users", re.Auth.Id)
		record.Set("location", map[string]float64{"lat": lat, "lon": lng})
		record.Set("memo", re.Request.FormValue("memo"))
		record.Set("emotion", re.Request.FormValue("emotion"))
		record.Set("music_title", re.Request.FormValue("music_title"))
		record.Set("music_artist", re.Request.FormValue("music_artist"))
		record.Set("status", "created")

		photoUploadCount := 0
		if photos := re.Request.MultipartForm.File["photos"]; len(photos) > 0 {
			var files []*filesystem.File
			for _, fh := range photos {
				if f, err := filesystem.NewFileFromMultipart(fh); err == nil {
					files = append(files, f)
				}
			}
			if len(files) > 0 {
				record.Set("photos", files)
				photoUploadCount = len(files)
			}
		}

		if videos := re.Request.MultipartForm.File["videos"]; len(videos) > 0 {
			var files []*filesystem.File
			for _, fh := range videos {
				if f, err := filesystem.NewFileFromMultipart(fh); err == nil {
					files = append(files, f)
				}
			}
			record.Set("videos", files)
		}

		if musicFiles := re.Request.MultipartForm.File["music"]; len(musicFiles) > 0 {
			if f, err := filesystem.NewFileFromMultipart(musicFiles[0]); err == nil {
				record.Set("music", f)
			}
		}

		if err := app.Save(record); err != nil {
			return re.JSON(http.StatusBadRequest, map[string]string{"message": err.Error()})
		}

		if err := createGroupCapsuleMembers(app, record.Id, re.Auth.Id, memberIDs); err != nil {
			_ = app.Delete(record)
			return re.JSON(http.StatusInternalServerError, map[string]string{"message": err.Error()})
		}
		if err := createCapsuleOpenSetting(app, record.Id, openConfig); err != nil {
			_ = app.Delete(record)
			return re.JSON(http.StatusInternalServerError, map[string]string{"message": err.Error()})
		}

		trackCapsuleCreatedChallenge(app, re.Auth.Id)
		for _, memberID := range memberIDs {
			trackCapsuleCreatedChallenge(app, memberID)
		}
		trackPhotoUploadedChallenge(app, re.Auth.Id, photoUploadCount)

		return re.JSON(http.StatusCreated, map[string]any{
			"capsule": map[string]any{
				"id":               record.Id,
				"status":           record.GetString("status"),
				"location":         record.Get("location"),
				"created":          record.GetString("created"),
				"is_group_capsule": len(memberIDs) > 0,
				"group_member_ids": memberIDs,
				"open_option":      openConfig.Option,
				"open_after_days": func() any {
					if openConfig.OpenAfterDays > 0 {
						return openConfig.OpenAfterDays
					}
					return nil
				}(),
				"open_at": func() any {
					if openConfig.OpenAt == nil {
						return nil
					}
					return openConfig.OpenAt.UTC()
				}(),
			},
		})
	}
}

func listCapsules(app *pocketbase.PocketBase) func(*core.RequestEvent) error {
	return func(re *core.RequestEvent) error {
		if re.Auth == nil {
			return re.JSON(http.StatusUnauthorized, map[string]string{"message": "unauthorized"})
		}

		records, err := app.FindAllRecords("capsules",
			dbx.HashExp{"users": re.Auth.Id},
		)
		if err != nil {
			return re.JSON(http.StatusInternalServerError, map[string]string{"message": err.Error()})
		}

		groupRecords, err := findGroupCapsulesForUser(app, re.Auth.Id)
		if err != nil {
			return re.JSON(http.StatusInternalServerError, map[string]string{"message": err.Error()})
		}

		uniqueRecords := make([]*core.Record, 0, len(records)+len(groupRecords))
		seen := make(map[string]struct{}, len(records)+len(groupRecords))
		for _, r := range append(records, groupRecords...) {
			if _, exists := seen[r.Id]; exists {
				continue
			}
			seen[r.Id] = struct{}{}
			uniqueRecords = append(uniqueRecords, r)
		}

		result := make([]map[string]any, 0, len(uniqueRecords))
		for _, r := range uniqueRecords {
			openMeta, _, err := buildCapsuleOpenMeta(app, r.Id, time.Now().UTC())
			if err != nil {
				return re.JSON(http.StatusInternalServerError, map[string]string{"message": err.Error()})
			}
			result = append(result, map[string]any{
				"id":        r.Id,
				"status":    r.GetString("status"),
				"location":  r.Get("location"),
				"emotion":   r.GetString("emotion"),
				"created":   r.GetString("created"),
				"buried_at": r.Get("buried_at"),
				"open":      openMeta,
			})
		}

		return re.JSON(http.StatusOK, map[string]any{"capsules": result})
	}
}

func getCapsule(app *pocketbase.PocketBase) func(*core.RequestEvent) error {
	return func(re *core.RequestEvent) error {
		if re.Auth == nil {
			return re.JSON(http.StatusUnauthorized, map[string]string{"message": "unauthorized"})
		}

		record, err := app.FindRecordById("capsules", re.Request.PathValue("id"))
		if err != nil {
			return re.JSON(http.StatusNotFound, map[string]string{"message": "capsule not found"})
		}

		canAccess, err := canAccessCapsule(app, re.Auth.Id, record)
		if err != nil {
			return re.JSON(http.StatusInternalServerError, map[string]string{"message": err.Error()})
		}
		if !canAccess {
			return re.JSON(http.StatusForbidden, map[string]string{"message": "forbidden"})
		}
		openMeta, canOpenNow, err := buildCapsuleOpenMeta(app, record.Id, time.Now().UTC())
		if err != nil {
			return re.JSON(http.StatusInternalServerError, map[string]string{"message": err.Error()})
		}
		if !canOpenNow {
			return re.JSON(http.StatusLocked, map[string]any{
				"message": "capsule is not open yet",
				"open":    openMeta,
			})
		}

		trackCapsuleViewedChallenge(app, re.Auth.Id)

		return re.JSON(http.StatusOK, map[string]any{
			"capsule": map[string]any{
				"id":           record.Id,
				"status":       record.GetString("status"),
				"location":     record.Get("location"),
				"memo":         record.GetString("memo"),
				"emotion":      record.GetString("emotion"),
				"music_title":  record.GetString("music_title"),
				"music_artist": record.GetString("music_artist"),
				"photos":       record.Get("photos"),
				"videos":       record.Get("videos"),
				"music":        record.GetString("music"),
				"created":      record.GetString("created"),
				"buried_at":    record.Get("buried_at"),
				"open":         openMeta,
			},
		})
	}
}

func buryCapsule(app *pocketbase.PocketBase) func(*core.RequestEvent) error {
	return func(re *core.RequestEvent) error {
		if re.Auth == nil {
			return re.JSON(http.StatusUnauthorized, map[string]string{"message": "unauthorized"})
		}

		record, err := app.FindRecordById("capsules", re.Request.PathValue("id"))
		if err != nil {
			return re.JSON(http.StatusNotFound, map[string]string{"message": "capsule not found"})
		}

		canAccess, err := canAccessCapsule(app, re.Auth.Id, record)
		if err != nil {
			return re.JSON(http.StatusInternalServerError, map[string]string{"message": err.Error()})
		}
		if !canAccess {
			return re.JSON(http.StatusForbidden, map[string]string{"message": "forbidden"})
		}

		record.Set("status", "buried")
		record.Set("buried_at", time.Now().UTC())

		if err := app.Save(record); err != nil {
			return re.JSON(http.StatusBadRequest, map[string]string{"message": err.Error()})
		}

		// 캡슐을 묻으면 반경 내 관광지를 자동 인증 처리 (요구사항: AR 인증/캡슐 등록 → 완료 마커)
		if loc, ok := record.Get("location").(map[string]any); ok {
			lat, _ := toFloat(loc["lat"])
			lon, _ := toFloat(loc["lon"])
			if lat != 0 || lon != 0 {
				tryMarkNearbyTouristSpots(app, re.Auth.Id, record.Id, lat, lon)
			}
		}

		return re.JSON(http.StatusOK, map[string]any{
			"capsule": map[string]any{
				"id":        record.Id,
				"status":    record.GetString("status"),
				"buried_at": record.Get("buried_at"),
			},
		})
	}
}
