package exif

import (
	"encoding/json"
	"fmt"
	"os/exec"
	"strconv"
	"strings"
	"time"
)

// exiftoolOutput is the JSON structure returned by exiftool -json.
type exiftoolOutput struct {
	DateTimeOriginal    string `json:"DateTimeOriginal"`
	CreateDate          string `json:"CreateDate"`
	Make                string `json:"Make"`
	Model               string `json:"Model"`
	GPSLatitude         any    `json:"GPSLatitude"`
	GPSLongitude        any    `json:"GPSLongitude"`
	GPSLatitudeRef      string `json:"GPSLatitudeRef"`
	GPSLongitudeRef     string `json:"GPSLongitudeRef"`
	ImageWidth          int    `json:"ImageWidth"`
	ImageHeight         int    `json:"ImageHeight"`
	ExifImageWidth      int    `json:"ExifImageWidth"`
	ExifImageHeight     int    `json:"ExifImageHeight"`
}

// runExiftool calls exiftool and parses the output into Metadata.
func runExiftool(path string) (Metadata, error) {
	cmd := exec.Command("exiftool", "-json", "-n", path)
	out, err := cmd.Output()
	if err != nil {
		return Metadata{}, fmt.Errorf("exiftool: %w", err)
	}

	var results []exiftoolOutput
	if err := json.Unmarshal(out, &results); err != nil || len(results) == 0 {
		return Metadata{}, fmt.Errorf("parse exiftool output: %w", err)
	}
	r := results[0]

	var meta Metadata

	// Date: prefer DateTimeOriginal, then CreateDate
	for _, raw := range []string{r.DateTimeOriginal, r.CreateDate} {
		if raw == "" {
			continue
		}
		t := parseExiftoolDate(raw)
		if t != nil {
			meta.TakenAt = t
			break
		}
	}

	meta.CameraMake = r.Make
	meta.CameraModel = r.Model

	if r.ImageWidth > 0 {
		meta.Width = r.ImageWidth
	}
	if r.ExifImageWidth > 0 {
		meta.Width = r.ExifImageWidth
	}
	if r.ImageHeight > 0 {
		meta.Height = r.ImageHeight
	}
	if r.ExifImageHeight > 0 {
		meta.Height = r.ExifImageHeight
	}

	lat := parseGPS(r.GPSLatitude)
	lon := parseGPS(r.GPSLongitude)
	if lat != 0 && lon != 0 {
		if strings.ToUpper(r.GPSLatitudeRef) == "S" {
			lat = -lat
		}
		if strings.ToUpper(r.GPSLongitudeRef) == "W" {
			lon = -lon
		}
		meta.GPSLat = &lat
		meta.GPSLon = &lon
	}

	return meta, nil
}

// parseExiftoolDate handles formats like "2023:07:04 14:30:00" and RFC3339.
func parseExiftoolDate(s string) *time.Time {
	formats := []string{
		"2006:01:02 15:04:05",
		"2006:01:02 15:04:05-07:00",
		time.RFC3339,
		"2006-01-02 15:04:05",
	}
	for _, f := range formats {
		if t, err := time.ParseInLocation(f, s, time.Local); err == nil {
			return &t
		}
	}
	return nil
}

// parseGPS converts the exiftool GPS value (float or string) to float64.
func parseGPS(v any) float64 {
	switch val := v.(type) {
	case float64:
		return val
	case string:
		f, _ := strconv.ParseFloat(val, 64)
		return f
	}
	return 0
}
