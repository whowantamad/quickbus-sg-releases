// Download raw LTA DataMall tables (BusStops, BusServices, BusRoutes),
// save the exact LTA schema to ./sg_transit_snapshot.json, and compile
// a pre-indexed SQLite3 database to ./sg_transit.db for the Flutter app.
//
// Usage:
//   go run scripts/rebuild_snapshot.go [-json sg_transit_snapshot.json] [-db sg_transit.db] [-key LTA_KEY]
//
// After running, copy the SQLite3 database into Flutter assets:
//   cp sg_transit.db flutter_project/assets/sg_transit.db
package main

import (
	"bufio"
	"bytes"
	"context"
	"crypto/sha256"
	"encoding/binary"
	"encoding/hex"
	"encoding/json"
	"flag"
	"fmt"
	"io"
	"net"
	"net/http"
	"os"
	"os/exec"
	"path/filepath"
	"sort"
	"strings"
	"sync"
	"time"
)

type LTABusStop struct {
	BusStopCode string  `json:"BusStopCode"`
	RoadName    string  `json:"RoadName"`
	Description string  `json:"Description"`
	Latitude    float64 `json:"Latitude"`
	Longitude   float64 `json:"Longitude"`
}

type LTABusService struct {
	ServiceNo       string `json:"ServiceNo"`
	Operator        string `json:"Operator"`
	Direction       int    `json:"Direction"`
	Category        string `json:"Category"`
	OriginCode      string `json:"OriginCode"`
	DestinationCode string `json:"DestinationCode"`
	AMPeakFreq      string `json:"AM_Peak_Freq"`
	AMOffPeakFreq   string `json:"AM_OffPeak_Freq"`
	PMPeakFreq      string `json:"PM_Peak_Freq"`
	PMOffPeakFreq   string `json:"PM_OffPeak_Freq"`
	LoopDesc        string `json:"LoopDesc"`
}

type LTABusRoute struct {
	ServiceNo    string  `json:"ServiceNo"`
	Operator     string  `json:"Operator"`
	Direction    int     `json:"Direction"`
	StopSequence int     `json:"StopSequence"`
	BusStopCode  string  `json:"BusStopCode"`
	Distance     float64 `json:"Distance"`
	WDFirstBus   string  `json:"WD_FirstBus"`
	WDLastBus    string  `json:"WD_LastBus"`
	SATFirstBus  string  `json:"SAT_FirstBus"`
	SATLastBus   string  `json:"SAT_LastBus"`
	SUNFirstBus  string  `json:"SUN_FirstBus"`
	SUNLastBus   string  `json:"SUN_LastBus"`
}

type RawLTASnapshot struct {
	VersionHash string          `json:"versionHash"`
	GeneratedAt string          `json:"generatedAt"`
	BusStops    []LTABusStop    `json:"BusStops"`
	BusServices []LTABusService `json:"BusServices"`
	BusRoutes   []LTABusRoute   `json:"BusRoutes"`
}

type hashInput struct {
	BusStops    []LTABusStop    `json:"BusStops"`
	BusServices []LTABusService `json:"BusServices"`
	BusRoutes   []LTABusRoute   `json:"BusRoutes"`
}

func newHTTPClient() *http.Client {
	dialer := &net.Dialer{
		Timeout:   8 * time.Second,
		KeepAlive: 30 * time.Second,
	}
	transport := &http.Transport{
		Proxy: http.ProxyFromEnvironment,
		DialContext: func(ctx context.Context, network, addr string) (net.Conn, error) {
			// Force IPv4 so unreachable IPv6 AAAA records never stall requests
			return dialer.DialContext(ctx, "tcp4", addr)
		},
		MaxIdleConns:          32,
		MaxIdleConnsPerHost:   16,
		IdleConnTimeout:       60 * time.Second,
		TLSHandshakeTimeout:   8 * time.Second,
		ExpectContinueTimeout: 1 * time.Second,
	}
	return &http.Client{
		Transport: transport,
		Timeout:   15 * time.Second,
	}
}

func fetchBytes(client *http.Client, url string, headers map[string]string) ([]byte, error) {
	var lastErr error
	for attempt := 0; attempt < 3; attempt++ {
		req, err := http.NewRequest("GET", url, nil)
		if err != nil {
			return nil, err
		}
		req.Header.Set("User-Agent", "QuickBusSG-SnapshotBuilder/2.0")
		for k, v := range headers {
			req.Header.Set(k, v)
		}
		resp, err := client.Do(req)
		if err == nil {
			body, readErr := io.ReadAll(resp.Body)
			resp.Body.Close()
			if resp.StatusCode == http.StatusOK && readErr == nil {
				return body, nil
			}
			lastErr = fmt.Errorf("HTTP %d from %s", resp.StatusCode, url)
		} else {
			lastErr = err
		}
		time.Sleep(time.Duration(attempt+1) * 350 * time.Millisecond)
	}
	return nil, lastErr
}

func fetchLTAPaginated[T any](
	client *http.Client,
	endpoint string,
	key string,
	extract func([]byte) ([]T, error),
) ([]T, error) {
	const (
		step    = 500
		workers = 8
	)
	baseURL := "https://datamall2.mytransport.sg/ltaodataservice/" + endpoint
	headers := map[string]string{
		"AccountKey": key,
		"accept":     "application/json",
	}

	pages := make(map[int][]T)
	var mu sync.Mutex
	nextSkip := 0
	done := false

	for !done {
		var wg sync.WaitGroup
		var firstErr error
		batchSkips := make([]int, workers)
		for i := 0; i < workers; i++ {
			batchSkips[i] = nextSkip + i*step
		}
		nextSkip += workers * step

		for _, skip := range batchSkips {
			wg.Add(1)
			go func(s int) {
				defer wg.Done()
				url := fmt.Sprintf("%s?$skip=%d", baseURL, s)
				raw, err := fetchBytes(client, url, headers)
				if err != nil {
					mu.Lock()
					if firstErr == nil {
						firstErr = err
					}
					mu.Unlock()
					return
				}
				rows, err := extract(raw)
				if err != nil {
					mu.Lock()
					if firstErr == nil {
						firstErr = err
					}
					mu.Unlock()
					return
				}
				mu.Lock()
				pages[s] = rows
				if len(rows) < step {
					done = true
				}
				mu.Unlock()
			}(skip)
		}
		wg.Wait()
		if firstErr != nil {
			return nil, firstErr
		}
		total := 0
		for _, r := range pages {
			total += len(r)
		}
		fmt.Printf("\r  Fetched %-11s: %d rows...", endpoint, total)
	}
	fmt.Println()

	skips := make([]int, 0, len(pages))
	for s := range pages {
		skips = append(skips, s)
	}
	sort.Ints(skips)

	var out []T
	for _, s := range skips {
		rows := pages[s]
		if len(rows) == 0 {
			break
		}
		out = append(out, rows...)
		if len(rows) < step {
			break
		}
	}
	return out, nil
}

func sqlEscape(s string) string {
	return "'" + strings.ReplaceAll(strings.TrimSpace(s), "'", "''") + "'"
}

func buildSQLiteDB(dbPath string, snap RawLTASnapshot, userVersion int32) error {
	sqliteBin, err := exec.LookPath("sqlite3")
	if err != nil {
		return fmt.Errorf("sqlite3 CLI not found in PATH: %w", err)
	}

	tmpPath := dbPath + ".tmp"
	_ = os.Remove(tmpPath)

	var sqlBuf bytes.Buffer
	sqlBuf.Grow(8 * 1024 * 1024)

	sqlBuf.WriteString("PRAGMA page_size = 4096;\n")
	sqlBuf.WriteString("PRAGMA journal_mode = OFF;\n")
	sqlBuf.WriteString("PRAGMA synchronous = OFF;\n")
	fmt.Fprintf(&sqlBuf, "PRAGMA user_version = %d;\n", userVersion)
	sqlBuf.WriteString("BEGIN TRANSACTION;\n")

	sqlBuf.WriteString(`
CREATE TABLE meta (
  key TEXT PRIMARY KEY,
  value TEXT NOT NULL
);

CREATE TABLE BusStops (
  BusStopCode TEXT PRIMARY KEY,
  RoadName TEXT NOT NULL,
  Description TEXT NOT NULL,
  Latitude REAL NOT NULL,
  Longitude REAL NOT NULL
);

CREATE TABLE BusServices (
  ServiceNo TEXT NOT NULL,
  Operator TEXT NOT NULL,
  Direction INTEGER NOT NULL,
  Category TEXT NOT NULL,
  OriginCode TEXT NOT NULL,
  DestinationCode TEXT NOT NULL,
  AM_Peak_Freq TEXT NOT NULL,
  AM_OffPeak_Freq TEXT NOT NULL,
  PM_Peak_Freq TEXT NOT NULL,
  PM_OffPeak_Freq TEXT NOT NULL,
  LoopDesc TEXT NOT NULL,
  PRIMARY KEY (ServiceNo, Direction)
);

CREATE TABLE BusRoutes (
  ServiceNo TEXT NOT NULL,
  Operator TEXT NOT NULL,
  Direction INTEGER NOT NULL,
  StopSequence INTEGER NOT NULL,
  BusStopCode TEXT NOT NULL,
  Distance REAL NOT NULL,
  WD_FirstBus TEXT NOT NULL,
  WD_LastBus TEXT NOT NULL,
  SAT_FirstBus TEXT NOT NULL,
  SAT_LastBus TEXT NOT NULL,
  SUN_FirstBus TEXT NOT NULL,
  SUN_LastBus TEXT NOT NULL,
  PRIMARY KEY (ServiceNo, Direction, StopSequence)
);
`)

	fmt.Fprintf(&sqlBuf, "INSERT INTO meta (key, value) VALUES ('versionHash', %s);\n", sqlEscape(snap.VersionHash))
	fmt.Fprintf(&sqlBuf, "INSERT INTO meta (key, value) VALUES ('generatedAt', %s);\n", sqlEscape(snap.GeneratedAt))
	fmt.Fprintf(&sqlBuf, "INSERT INTO meta (key, value) VALUES ('stopCount', '%d');\n", len(snap.BusStops))
	fmt.Fprintf(&sqlBuf, "INSERT INTO meta (key, value) VALUES ('serviceCount', '%d');\n", len(snap.BusServices))
	fmt.Fprintf(&sqlBuf, "INSERT INTO meta (key, value) VALUES ('routeRowCount', '%d');\n", len(snap.BusRoutes))

	for _, s := range snap.BusStops {
		code := strings.TrimSpace(s.BusStopCode)
		if code == "" {
			continue
		}
		fmt.Fprintf(
			&sqlBuf,
			"INSERT OR REPLACE INTO BusStops VALUES (%s, %s, %s, %.6f, %.6f);\n",
			sqlEscape(code),
			sqlEscape(s.RoadName),
			sqlEscape(s.Description),
			s.Latitude,
			s.Longitude,
		)
	}

	for _, svc := range snap.BusServices {
		svcNo := strings.TrimSpace(svc.ServiceNo)
		if svcNo == "" {
			continue
		}
		dir := svc.Direction
		if dir <= 0 {
			dir = 1
		}
		fmt.Fprintf(
			&sqlBuf,
			"INSERT OR REPLACE INTO BusServices VALUES (%s, %s, %d, %s, %s, %s, %s, %s, %s, %s, %s);\n",
			sqlEscape(svcNo),
			sqlEscape(svc.Operator),
			dir,
			sqlEscape(svc.Category),
			sqlEscape(svc.OriginCode),
			sqlEscape(svc.DestinationCode),
			sqlEscape(svc.AMPeakFreq),
			sqlEscape(svc.AMOffPeakFreq),
			sqlEscape(svc.PMPeakFreq),
			sqlEscape(svc.PMOffPeakFreq),
			sqlEscape(svc.LoopDesc),
		)
	}

	for _, r := range snap.BusRoutes {
		svcNo := strings.TrimSpace(r.ServiceNo)
		code := strings.TrimSpace(r.BusStopCode)
		if svcNo == "" || code == "" {
			continue
		}
		dir := r.Direction
		if dir <= 0 {
			dir = 1
		}
		fmt.Fprintf(
			&sqlBuf,
			"INSERT OR REPLACE INTO BusRoutes VALUES (%s, %s, %d, %d, %s, %.2f, %s, %s, %s, %s, %s, %s);\n",
			sqlEscape(svcNo),
			sqlEscape(r.Operator),
			dir,
			r.StopSequence,
			sqlEscape(code),
			r.Distance,
			sqlEscape(r.WDFirstBus),
			sqlEscape(r.WDLastBus),
			sqlEscape(r.SATFirstBus),
			sqlEscape(r.SATLastBus),
			sqlEscape(r.SUNFirstBus),
			sqlEscape(r.SUNLastBus),
		)
	}

	sqlBuf.WriteString("CREATE INDEX idx_bus_routes_stop ON BusRoutes(BusStopCode);\n")
	sqlBuf.WriteString("COMMIT;\n")
	sqlBuf.WriteString("VACUUM;\n")

	cmd := exec.Command(sqliteBin, tmpPath)
	cmd.Stdin = &sqlBuf
	var stderr bytes.Buffer
	cmd.Stderr = &stderr
	if err := cmd.Run(); err != nil {
		_ = os.Remove(tmpPath)
		return fmt.Errorf("sqlite3 failed: %v (%s)", err, strings.TrimSpace(stderr.String()))
	}

	if err := os.Rename(tmpPath, dbPath); err != nil {
		_ = os.Remove(tmpPath)
		return err
	}
	return nil
}

func resolveLTAKey(cliKey string) string {
	if strings.TrimSpace(cliKey) != "" {
		return strings.TrimSpace(cliKey)
	}
	if envKey := strings.TrimSpace(os.Getenv("LTA_DATAMALL_KEY")); envKey != "" && envKey != "YOUR_LTA_DATAMALL_ACCOUNT_KEY" {
		return envKey
	}
	for _, rel := range []string{"flutter_project/.env", ".env"} {
		f, err := os.Open(rel)
		if err != nil {
			continue
		}
		scanner := bufio.NewScanner(f)
		for scanner.Scan() {
			line := strings.TrimSpace(scanner.Text())
			if strings.HasPrefix(line, "LTA_DATAMALL_KEY=") {
				val := strings.TrimPrefix(line, "LTA_DATAMALL_KEY=")
				val = strings.Trim(val, `"'`)
				if val != "" && val != "YOUR_LTA_DATAMALL_ACCOUNT_KEY" {
					f.Close()
					return val
				}
			}
		}
		f.Close()
	}
	return ""
}

func main() {
	jsonFlag := flag.String("json", "sg_transit_snapshot.json", "Output path for raw LTA JSON snapshot")
	dbFlag := flag.String("db", "sg_transit.db", "Output path for compiled SQLite3 database")
	keyFlag := flag.String("key", "", "LTA DataMall AccountKey (defaults to LTA_DATAMALL_KEY in flutter_project/.env)")
	flag.Parse()

	jsonPath, err := filepath.Abs(*jsonFlag)
	if err != nil {
		jsonPath = *jsonFlag
	}
	dbPath, err := filepath.Abs(*dbFlag)
	if err != nil {
		dbPath = *dbFlag
	}

	ltaKey := resolveLTAKey(*keyFlag)
	if ltaKey == "" {
		fmt.Fprintln(os.Stderr, "Error: LTA_DATAMALL_KEY not found in -key flag, environment, or flutter_project/.env")
		os.Exit(1)
	}

	client := newHTTPClient()
	fmt.Println("Fetching live LTA DataMall tables (BusStops, BusServices, BusRoutes)...")
	t0 := time.Now()

	rawStops, err := fetchLTAPaginated(client, "BusStops", ltaKey, func(b []byte) ([]LTABusStop, error) {
		var r struct {
			Value []LTABusStop `json:"value"`
		}
		err := json.Unmarshal(b, &r)
		return r.Value, err
	})
	if err != nil {
		fmt.Fprintf(os.Stderr, "Error fetching BusStops: %v\n", err)
		os.Exit(1)
	}

	rawServices, err := fetchLTAPaginated(client, "BusServices", ltaKey, func(b []byte) ([]LTABusService, error) {
		var r struct {
			Value []LTABusService `json:"value"`
		}
		err := json.Unmarshal(b, &r)
		return r.Value, err
	})
	if err != nil {
		fmt.Fprintf(os.Stderr, "Error fetching BusServices: %v\n", err)
		os.Exit(1)
	}

	rawRoutes, err := fetchLTAPaginated(client, "BusRoutes", ltaKey, func(b []byte) ([]LTABusRoute, error) {
		var r struct {
			Value []LTABusRoute `json:"value"`
		}
		err := json.Unmarshal(b, &r)
		return r.Value, err
	})
	if err != nil {
		fmt.Fprintf(os.Stderr, "Error fetching BusRoutes: %v\n", err)
		os.Exit(1)
	}

	fmt.Printf("  Downloaded all LTA tables in %.2fs\n", time.Since(t0).Seconds())

	// Sort deterministically by LTA primary keys
	sort.Slice(rawStops, func(i, j int) bool {
		return rawStops[i].BusStopCode < rawStops[j].BusStopCode
	})
	sort.Slice(rawServices, func(i, j int) bool {
		if rawServices[i].ServiceNo != rawServices[j].ServiceNo {
			return rawServices[i].ServiceNo < rawServices[j].ServiceNo
		}
		return rawServices[i].Direction < rawServices[j].Direction
	})
	sort.Slice(rawRoutes, func(i, j int) bool {
		if rawRoutes[i].ServiceNo != rawRoutes[j].ServiceNo {
			return rawRoutes[i].ServiceNo < rawRoutes[j].ServiceNo
		}
		if rawRoutes[i].Direction != rawRoutes[j].Direction {
			return rawRoutes[i].Direction < rawRoutes[j].Direction
		}
		return rawRoutes[i].StopSequence < rawRoutes[j].StopSequence
	})

	// Validate row counts before writing
	if len(rawStops) < 4000 || len(rawServices) < 500 || len(rawRoutes) < 20000 {
		fmt.Fprintf(
			os.Stderr,
			"Validation failed: BusStops=%d, BusServices=%d, BusRoutes=%d\n",
			len(rawStops), len(rawServices), len(rawRoutes),
		)
		os.Exit(1)
	}

	hashBytes, err := json.Marshal(hashInput{
		BusStops:    rawStops,
		BusServices: rawServices,
		BusRoutes:   rawRoutes,
	})
	if err != nil {
		fmt.Fprintf(os.Stderr, "Error marshaling hash payload: %v\n", err)
		os.Exit(1)
	}
	sum := sha256.Sum256(hashBytes)
	versionHash := "v4-lta-" + hex.EncodeToString(sum[:])[:16]
	userVersion := int32(binary.BigEndian.Uint32(sum[:4]) & 0x7fffffff)
	if userVersion == 0 {
		userVersion = 1
	}
	generatedAt := time.Now().UTC().Format("2006-01-02T15:04:05.000Z")

	snapshot := RawLTASnapshot{
		VersionHash: versionHash,
		GeneratedAt: generatedAt,
		BusStops:    rawStops,
		BusServices: rawServices,
		BusRoutes:   rawRoutes,
	}

	// 1. Save exact LTA JSON snapshot
	jsonBytes, err := json.Marshal(snapshot)
	if err != nil {
		fmt.Fprintf(os.Stderr, "Error marshaling JSON snapshot: %v\n", err)
		os.Exit(1)
	}
	if err := os.MkdirAll(filepath.Dir(jsonPath), 0o755); err != nil {
		fmt.Fprintf(os.Stderr, "Error creating directory for JSON: %v\n", err)
		os.Exit(1)
	}
	if err := os.WriteFile(jsonPath, jsonBytes, 0o644); err != nil {
		fmt.Fprintf(os.Stderr, "Error writing %s: %v\n", jsonPath, err)
		os.Exit(1)
	}

	// 2. Compile SQLite3 database
	tDB := time.Now()
	if err := os.MkdirAll(filepath.Dir(dbPath), 0o755); err != nil {
		fmt.Fprintf(os.Stderr, "Error creating directory for DB: %v\n", err)
		os.Exit(1)
	}
	if err := buildSQLiteDB(dbPath, snapshot, userVersion); err != nil {
		fmt.Fprintf(os.Stderr, "Error building SQLite3 database: %v\n", err)
		os.Exit(1)
	}
	dbStat, err := os.Stat(dbPath)
	if err != nil {
		fmt.Fprintf(os.Stderr, "Error stating %s: %v\n", dbPath, err)
		os.Exit(1)
	}

	jsonMB := float64(len(jsonBytes)) / (1024.0 * 1024.0)
	dbMB := float64(dbStat.Size()) / (1024.0 * 1024.0)
	fmt.Printf("\n✓ Saved raw LTA JSON : %s (%.2f MB)\n", jsonPath, jsonMB)
	fmt.Printf("✓ Built SQLite3 DB   : %s (%.2f MB in %.2fs)\n", dbPath, dbMB, time.Since(tDB).Seconds())
	fmt.Printf("  versionHash        : %s (user_version=%d)\n", versionHash, userVersion)
	fmt.Printf("  generatedAt        : %s\n", generatedAt)
	fmt.Printf("  BusStops           : %d rows\n", len(rawStops))
	fmt.Printf("  BusServices        : %d rows\n", len(rawServices))
	fmt.Printf("  BusRoutes          : %d rows\n", len(rawRoutes))

	assetDBPath, _ := filepath.Abs("flutter_project/assets/sg_transit.db")
	fmt.Println("\nTo update the app's bundled SQLite3 asset, run:")
	fmt.Printf("  cp %s %s\n", dbPath, assetDBPath)
}
