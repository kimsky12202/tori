package main

import (
	"errors"
	"math"
	"net/http"
	"sort"
	"strconv"
	"strings"
	"time"

	"github.com/pocketbase/dbx"
	"github.com/pocketbase/pocketbase"
	"github.com/pocketbase/pocketbase/core"
	"github.com/pocketbase/pocketbase/tools/hook"
)

const (
	visitSourceCapsule = "capsule"
	visitSourceAR      = "ar"
	visitSourceManual  = "manual"

	defaultVisitRadiusMeters = 200.0
	earthRadiusMeters        = 6371000.0
)

func registerTouristSpotRoutes(app *pocketbase.PocketBase) {
	app.OnServe().Bind(&hook.Handler[*core.ServeEvent]{
		Func: func(e *core.ServeEvent) error {
			e.Router.GET("/tourist-spots", listTouristSpots(app))
			e.Router.POST("/tourist-spots/{id}/visit", visitTouristSpot(app))
			return e.Next()
		},
	})
}

func listTouristSpots(app *pocketbase.PocketBase) func(*core.RequestEvent) error {
	return func(re *core.RequestEvent) error {
		if re.Auth == nil {
			return re.JSON(http.StatusUnauthorized, map[string]string{"message": "unauthorized"})
		}

		spots, err := app.FindAllRecords("tourist_spots",
			dbx.HashExp{"is_active": true},
		)
		if err != nil {
			return re.JSON(http.StatusInternalServerError, map[string]string{"message": err.Error()})
		}

		sort.SliceStable(spots, func(i, j int) bool {
			return spots[i].GetInt("sort_order") < spots[j].GetInt("sort_order")
		})

		visits, err := app.FindAllRecords("user_spot_visits",
			dbx.HashExp{"user": re.Auth.Id},
		)
		if err != nil {
			return re.JSON(http.StatusInternalServerError, map[string]string{"message": err.Error()})
		}

		visitMap := make(map[string]*core.Record, len(visits))
		for _, v := range visits {
			visitMap[v.GetString("spot")] = v
		}

		results := make([]map[string]any, 0, len(spots))
		for _, s := range spots {
			visit, visited := visitMap[s.Id]
			item := map[string]any{
				"id":          s.Id,
				"code":        s.GetString("code"),
				"name":        s.GetString("name"),
				"description": s.GetString("description"),
				"category":    s.GetString("category"),
				"icon":        s.GetString("icon"),
				"color":       s.GetString("color"),
				"location":    s.Get("location"),
				"radius_m":   s.GetInt("radius_m"),
				"image_url":   s.GetString("image_url"),
				"visited":     visited,
			}
			if visited {
				item["visit"] = map[string]any{
					"source":     visit.GetString("source"),
					"capsule":    visit.GetString("capsule"),
					"visited_at": visit.Get("visited_at"),
				}
			}
			results = append(results, item)
		}

		return re.JSON(http.StatusOK, map[string]any{"spots": results})
	}
}

func visitTouristSpot(app *pocketbase.PocketBase) func(*core.RequestEvent) error {
	return func(re *core.RequestEvent) error {
		if re.Auth == nil {
			return re.JSON(http.StatusUnauthorized, map[string]string{"message": "unauthorized"})
		}

		spotID := re.Request.PathValue("id")
		spot, err := app.FindRecordById("tourist_spots", spotID)
		if err != nil {
			return re.JSON(http.StatusNotFound, map[string]string{"message": "tourist spot not found"})
		}

		source := strings.ToLower(strings.TrimSpace(re.Request.FormValue("source")))
		if source == "" {
			source = visitSourceAR
		}

		capsuleID := strings.TrimSpace(re.Request.FormValue("capsule_id"))

		latRaw := strings.TrimSpace(re.Request.FormValue("latitude"))
		lngRaw := strings.TrimSpace(re.Request.FormValue("longitude"))
		if latRaw != "" && lngRaw != "" {
			lat, latErr := strconv.ParseFloat(latRaw, 64)
			lng, lngErr := strconv.ParseFloat(lngRaw, 64)
			if latErr != nil || lngErr != nil {
				return re.JSON(http.StatusBadRequest, map[string]string{"message": "invalid coordinates"})
			}

			radius := spotRadiusMeters(spot)
			loc := spotLocation(spot)
			if !isWithinRadius(lat, lng, loc.Lat, loc.Lon, radius) {
				return re.JSON(http.StatusBadRequest, map[string]any{
					"message": "too far from tourist spot",
					"radius":  radius,
				})
			}
		}

		visit, err := upsertSpotVisit(app, re.Auth.Id, spot.Id, source, capsuleID)
		if err != nil {
			return re.JSON(http.StatusInternalServerError, map[string]string{"message": err.Error()})
		}

		return re.JSON(http.StatusOK, map[string]any{
			"visit": map[string]any{
				"id":         visit.Id,
				"spot":       visit.GetString("spot"),
				"source":     visit.GetString("source"),
				"capsule":    visit.GetString("capsule"),
				"visited_at": visit.Get("visited_at"),
			},
		})
	}
}

type geoPoint struct {
	Lat float64
	Lon float64
}

func spotLocation(spot *core.Record) geoPoint {
	raw := spot.Get("location")
	if m, ok := raw.(map[string]any); ok {
		lat, _ := toFloat(m["lat"])
		lon, _ := toFloat(m["lon"])
		return geoPoint{Lat: lat, Lon: lon}
	}
	return geoPoint{}
}

func toFloat(value any) (float64, bool) {
	switch v := value.(type) {
	case float64:
		return v, true
	case float32:
		return float64(v), true
	case int:
		return float64(v), true
	case int64:
		return float64(v), true
	case string:
		f, err := strconv.ParseFloat(v, 64)
		if err == nil {
			return f, true
		}
	}
	return 0, false
}

func spotRadiusMeters(spot *core.Record) float64 {
	r := spot.GetInt("radius_m")
	if r > 0 {
		return float64(r)
	}
	return defaultVisitRadiusMeters
}

func isWithinRadius(lat1, lon1, lat2, lon2, radiusMeters float64) bool {
	return haversineMeters(lat1, lon1, lat2, lon2) <= radiusMeters
}

func haversineMeters(lat1, lon1, lat2, lon2 float64) float64 {
	rad := math.Pi / 180.0
	dLat := (lat2 - lat1) * rad
	dLon := (lon2 - lon1) * rad
	a := math.Sin(dLat/2)*math.Sin(dLat/2) +
		math.Cos(lat1*rad)*math.Cos(lat2*rad)*
			math.Sin(dLon/2)*math.Sin(dLon/2)
	c := 2 * math.Atan2(math.Sqrt(a), math.Sqrt(1-a))
	return earthRadiusMeters * c
}

func upsertSpotVisit(
	app *pocketbase.PocketBase,
	userID string,
	spotID string,
	source string,
	capsuleID string,
) (*core.Record, error) {
	existing, err := app.FindFirstRecordByFilter(
		"user_spot_visits",
		"user = {:user} && spot = {:spot}",
		dbx.Params{"user": userID, "spot": spotID},
	)
	if err == nil && existing != nil {
		updated := false
		if capsuleID != "" && existing.GetString("capsule") == "" {
			existing.Set("capsule", capsuleID)
			updated = true
		}
		if source != "" && existing.GetString("source") != source && existing.GetString("source") == "" {
			existing.Set("source", source)
			updated = true
		}
		if updated {
			if saveErr := app.Save(existing); saveErr != nil {
				return nil, saveErr
			}
		}
		return existing, nil
	}

	col, err := app.FindCollectionByNameOrId("user_spot_visits")
	if err != nil {
		return nil, err
	}

	record := core.NewRecord(col)
	record.Set("user", userID)
	record.Set("spot", spotID)
	record.Set("source", source)
	if capsuleID != "" {
		record.Set("capsule", capsuleID)
	}
	record.Set("visited_at", time.Now().UTC())

	if err := app.Save(record); err != nil {
		return nil, err
	}
	return record, nil
}

// tryMarkNearbyTouristSpots checks all active tourist spots and marks any
// whose radius contains the given lat/lon as visited for the given user.
// Called after capsule bury so a registered capsule auto-completes a spot.
func tryMarkNearbyTouristSpots(
	app *pocketbase.PocketBase,
	userID string,
	capsuleID string,
	lat float64,
	lon float64,
) {
	spots, err := app.FindAllRecords("tourist_spots",
		dbx.HashExp{"is_active": true},
	)
	if err != nil {
		return
	}
	for _, spot := range spots {
		loc := spotLocation(spot)
		if loc.Lat == 0 && loc.Lon == 0 {
			continue
		}
		radius := spotRadiusMeters(spot)
		if !isWithinRadius(lat, lon, loc.Lat, loc.Lon, radius) {
			continue
		}
		if _, err := upsertSpotVisit(app, userID, spot.Id, visitSourceCapsule, capsuleID); err != nil {
			continue
		}
	}
}

var errSpotNotFound = errors.New("tourist spot not found")

// findSpotByCode is kept for future use (e.g. seeding helpers).
func findSpotByCode(app *pocketbase.PocketBase, code string) (*core.Record, error) {
	record, err := app.FindFirstRecordByData("tourist_spots", "code", code)
	if err != nil {
		return nil, errSpotNotFound
	}
	return record, nil
}
