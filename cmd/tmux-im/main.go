// tmux-im: Pure storage layer for tmux pane input method state
// Works with tmux-im.sh which handles the actual IM switching
package main

import (
	"encoding/json"
	"flag"
	"fmt"
	"os"
	"path/filepath"
	"strconv"
	"strings"
	"time"
)

const (
	defaultIM   = "com.apple.keylayout.ABC"
	defaultTTL  = 24 * time.Hour
	defaultFile = "~/.cache/tmux-im/store.json"
)

type Record struct {
	IM string `json:"im"`
	TS int64  `json:"ts"`
}

type Store struct {
	Records map[string]Record `json:"records"`
}

func main() {
	if err := run(); err != nil {
		fmt.Fprintln(os.Stderr, "error:", err)
		os.Exit(1)
	}
}

func run() error {
	var (
		listFlag bool
		helpFlag bool
	)

	flag.BoolVar(&listFlag, "l", false, "list all records")
	flag.BoolVar(&helpFlag, "h", false, "show help")
	flag.Parse()

	if helpFlag {
		printUsage()
		return nil
	}

	cfg := loadConfig()

	if listFlag {
		return listRecords(cfg)
	}

	args := flag.Args()

	if len(args) == 0 {
		printUsage()
		return nil
	}

	paneKey := args[0]

	if len(args) == 1 {
		// Get: output stored IM or default
		return getIM(cfg, paneKey)
	}

	// Set: store the provided IM
	return setIM(cfg, paneKey, args[1])
}

func getIM(cfg *Config, paneKey string) error {
	store, err := loadStore(cfg.File)
	if err != nil {
		fmt.Println(cfg.DefaultIM)
		return nil
	}

	rec, ok := store.Records[paneKey]
	if !ok || isExpired(rec.TS, cfg.TTL) {
		fmt.Println(cfg.DefaultIM)
		return nil
	}

	fmt.Println(rec.IM)
	return nil
}

func setIM(cfg *Config, paneKey, im string) error {
	store, err := loadStore(cfg.File)
	if err != nil {
		store = &Store{Records: make(map[string]Record)}
	}

	// Opportunistic cleanup: remove expired records on write
	// Handles pane ID reuse after pane close
	now := time.Now().Unix()
	for k, v := range store.Records {
		if isExpired(v.TS, cfg.TTL) {
			delete(store.Records, k)
		}
	}

	store.Records[paneKey] = Record{
		IM: im,
		TS: now,
	}

	return saveStore(cfg.File, store)
}

func listRecords(cfg *Config) error {
	store, err := loadStore(cfg.File)
	if err != nil {
		fmt.Println("{}")
		return nil
	}

	data, err := json.MarshalIndent(store, "", "  ")
	if err != nil {
		return err
	}
	fmt.Println(string(data))
	return nil
}

func isExpired(ts int64, ttl time.Duration) bool {
	return time.Now().Unix()-ts > int64(ttl.Seconds())
}

type Config struct {
	File      string
	TTL       time.Duration
	DefaultIM string
}

func loadConfig() *Config {
	cfg := &Config{
		File:      defaultFile,
		TTL:       defaultTTL,
		DefaultIM: defaultIM,
	}

	if f := os.Getenv("TMUX_IM_FILE"); f != "" {
		cfg.File = f
	}

	if t := os.Getenv("TMUX_IM_TTL"); t != "" {
		if sec, err := strconv.Atoi(t); err == nil {
			cfg.TTL = time.Duration(sec) * time.Second
		}
	}

	if d := os.Getenv("TMUX_IM_DEFAULT"); d != "" {
		cfg.DefaultIM = d
	}

	// Expand ~
	if strings.HasPrefix(cfg.File, "~/") {
		home, _ := os.UserHomeDir()
		cfg.File = filepath.Join(home, cfg.File[2:])
	}

	return cfg
}

func loadStore(path string) (*Store, error) {
	data, err := os.ReadFile(path)
	if err != nil {
		return nil, err
	}

	var store Store
	if err := json.Unmarshal(data, &store); err != nil {
		return nil, err
	}

	if store.Records == nil {
		store.Records = make(map[string]Record)
	}

	return &store, nil
}

func saveStore(path string, store *Store) error {
	// Ensure directory exists
	dir := filepath.Dir(path)
	if err := os.MkdirAll(dir, 0755); err != nil {
		return err
	}

	data, err := json.MarshalIndent(store, "", "  ")
	if err != nil {
		return err
	}

	return os.WriteFile(path, data, 0644)
}

func printUsage() {
	fmt.Println(`tmux-im - tmux pane input method store

Usage:
  tmux-im <pane_key>           Get IM for pane
  tmux-im <pane_key> <im>      Set IM for pane

Options:
  -l  List all records
  -h  Show help

Environment:
  TMUX_IM_FILE     Storage path (default: ~/.cache/tmux-im/store.json)
  TMUX_IM_TTL      TTL in seconds (default: 86400)
  TMUX_IM_DEFAULT  Default IM (default: com.apple.keylayout.ABC)`)
}
