package exif

import (
	"fmt"
	"log"
	"os"
	"strings"
	"time"

	exiflib "github.com/dsoprea/go-exif/v3"
	exifcommon "github.com/dsoprea/go-exif/v3/common"
)

// Metadata holds the fields we care about from EXIF or file info.
type Metadata struct {
	TakenAt     *time.Time
	CameraMake  string
	CameraModel string
	GPSLat      *float64
	GPSLon      *float64
	Width       int
	Height      int
}

// rawExtensions are formats where native EXIF parsing may fail; exiftool is used.
var rawExtensions = map[string]bool{
	".raf": true,
	".orf": true,
	".rw2": true,
}

// Read extracts metadata from the file at path.
// It never returns an error — missing fields are left as zero values.
func Read(path string) Metadata {
	ext := strings.ToLower(getExt(path))

	var meta Metadata

	// Try native Go EXIF parser for most formats
	if !rawExtensions[ext] {
		if m, ok := readNative(path); ok {
			meta = m
		}
	}

	// Fall back to exiftool for missing fields or unsupported RAW formats
	if meta.TakenAt == nil || rawExtensions[ext] {
		if m, ok := readExiftool(path); ok {
			merge(&meta, m)
		}
	}

	// Last resort: use file modification time
	if meta.TakenAt == nil {
		if info, err := os.Stat(path); err == nil {
			t := info.ModTime()
			meta.TakenAt = &t
		}
	}

	return meta
}

// readNative uses dsoprea/go-exif/v3 to extract metadata.
func readNative(path string) (Metadata, bool) {
	rawExif, err := exiflib.SearchFileAndExtractExif(path)
	if err != nil {
		return Metadata{}, false
	}

	tags, _, err := exiflib.GetFlatExifData(rawExif, nil)
	if err != nil {
		return Metadata{}, false
	}

	var meta Metadata
	var gpsLat, gpsLon float64
	var hasLat, hasLon bool
	var latNeg, lonNeg bool

	for _, tag := range tags {
		switch tag.TagName {
		case "DateTimeOriginal", "DateTime":
			if meta.TakenAt == nil {
				meta.TakenAt = parseExifDate(tag.FormattedFirst)
			}
		case "Make":
			if meta.CameraMake == "" {
				meta.CameraMake = strings.Trim(tag.FormattedFirst, `"`)
			}
		case "Model":
			if meta.CameraModel == "" {
				meta.CameraModel = strings.Trim(tag.FormattedFirst, `"`)
			}
		case "PixelXDimension", "ExifImageWidth":
			if meta.Width == 0 {
				meta.Width = parseIntVal(tag.Value)
			}
		case "PixelYDimension", "ExifImageHeight":
			if meta.Height == 0 {
				meta.Height = parseIntVal(tag.Value)
			}
		case "GPSLatitude":
			if v, ok := parseGPSRationals(tag.Value); ok {
				gpsLat = v
				hasLat = true
			}
		case "GPSLongitude":
			if v, ok := parseGPSRationals(tag.Value); ok {
				gpsLon = v
				hasLon = true
			}
		case "GPSLatitudeRef":
			latNeg = strings.TrimSpace(tag.FormattedFirst) == "S"
		case "GPSLongitudeRef":
			lonNeg = strings.TrimSpace(tag.FormattedFirst) == "W"
		}
	}

	if hasLat && hasLon {
		if latNeg {
			gpsLat = -gpsLat
		}
		if lonNeg {
			gpsLon = -gpsLon
		}
		meta.GPSLat = &gpsLat
		meta.GPSLon = &gpsLon
	}

	return meta, true
}

// merge fills in zero fields of dst from src.
func merge(dst *Metadata, src Metadata) {
	if dst.TakenAt == nil {
		dst.TakenAt = src.TakenAt
	}
	if dst.CameraMake == "" {
		dst.CameraMake = src.CameraMake
	}
	if dst.CameraModel == "" {
		dst.CameraModel = src.CameraModel
	}
	if dst.GPSLat == nil {
		dst.GPSLat = src.GPSLat
	}
	if dst.GPSLon == nil {
		dst.GPSLon = src.GPSLon
	}
	if dst.Width == 0 {
		dst.Width = src.Width
	}
	if dst.Height == 0 {
		dst.Height = src.Height
	}
}

// readExiftool shells out to exiftool (if installed) for richer metadata.
func readExiftool(path string) (Metadata, bool) {
	m, err := runExiftool(path)
	if err != nil {
		log.Printf("exiftool fallback skipped for %s: %v", path, err)
		return Metadata{}, false
	}
	return m, true
}

// ---- helpers ----------------------------------------------------------------

// parseExifDate handles the standard EXIF date format "2006:01:02 15:04:05".
func parseExifDate(s string) *time.Time {
	formats := []string{
		"2006:01:02 15:04:05",
		"2006-01-02 15:04:05",
		time.RFC3339,
	}
	for _, f := range formats {
		if t, err := time.ParseInLocation(f, s, time.Local); err == nil {
			return &t
		}
	}
	return nil
}

// parseGPSRationals converts a dsoprea/go-exif GPS rational slice to decimal degrees.
func parseGPSRationals(v any) (float64, bool) {
	switch rv := v.(type) {
	case []exifcommon.Rational:
		if len(rv) == 3 {
			deg := float64(rv[0].Numerator) / float64(max(rv[0].Denominator, 1))
			min := float64(rv[1].Numerator) / float64(max(rv[1].Denominator, 1))
			sec := float64(rv[2].Numerator) / float64(max(rv[2].Denominator, 1))
			return deg + min/60.0 + sec/3600.0, true
		}
	case float64:
		return rv, true
	}
	return 0, false
}

// parseIntVal extracts an integer from common EXIF tag value types.
func parseIntVal(v any) int {
	switch n := v.(type) {
	case uint32:
		return int(n)
	case uint16:
		return int(n)
	case int:
		return n
	case int64:
		return int(n)
	case fmt.Stringer:
		_ = n
	}
	return 0
}

func getExt(path string) string {
	for i := len(path) - 1; i >= 0 && path[i] != '/'; i-- {
		if path[i] == '.' {
			return path[i:]
		}
	}
	return ""
}
