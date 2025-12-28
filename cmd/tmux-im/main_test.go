package main

import (
	"os"
	"path/filepath"
	"testing"
	"time"
)

func TestLoadConfig(t *testing.T) {
	// Test defaults
	cfg := loadConfig()
	if cfg.DefaultIM != defaultIM {
		t.Errorf("expected default IM %s, got %s", defaultIM, cfg.DefaultIM)
	}
	if cfg.TTL != defaultTTL {
		t.Errorf("expected default TTL %v, got %v", defaultTTL, cfg.TTL)
	}

	// Test environment overrides
	t.Setenv("TMUX_IM_DEFAULT", "test.im")
	t.Setenv("TMUX_IM_TTL", "3600")
	t.Setenv("TMUX_IM_FILE", "/tmp/test-im.json")

	cfg = loadConfig()
	if cfg.DefaultIM != "test.im" {
		t.Errorf("expected default IM test.im, got %s", cfg.DefaultIM)
	}
	if cfg.TTL != time.Hour {
		t.Errorf("expected TTL 1h, got %v", cfg.TTL)
	}
	if cfg.File != "/tmp/test-im.json" {
		t.Errorf("expected file /tmp/test-im.json, got %s", cfg.File)
	}
}

func TestStoreLoadSave(t *testing.T) {
	tmpDir := t.TempDir()
	path := filepath.Join(tmpDir, "test.json")

	// Test save
	store := &Store{
		Records: map[string]Record{
			"session1:%0": {IM: "im.test", TS: time.Now().Unix()},
		},
	}
	if err := saveStore(path, store); err != nil {
		t.Fatalf("failed to save store: %v", err)
	}

	// Test load
	loaded, err := loadStore(path)
	if err != nil {
		t.Fatalf("failed to load store: %v", err)
	}

	rec, ok := loaded.Records["session1:%0"]
	if !ok {
		t.Fatal("expected record not found")
	}
	if rec.IM != "im.test" {
		t.Errorf("expected IM im.test, got %s", rec.IM)
	}
}

func TestIsExpired(t *testing.T) {
	now := time.Now().Unix()
	ttl := time.Hour

	// Not expired
	if isExpired(now, ttl) {
		t.Error("record should not be expired")
	}

	// Expired
	if !isExpired(now-3601, ttl) {
		t.Error("record should be expired")
	}
}

func TestSetGetIM(t *testing.T) {
	tmpDir := t.TempDir()
	path := filepath.Join(tmpDir, "test.json")

	cfg := &Config{
		File:      path,
		TTL:       time.Hour,
		DefaultIM: defaultIM,
	}

	paneKey := "testsession:%1"

	// Set IM
	if err := setIM(cfg, paneKey, "im.rime.test"); err != nil {
		t.Fatalf("failed to set IM: %v", err)
	}

	// Load and verify
	store, err := loadStore(path)
	if err != nil {
		t.Fatalf("failed to load store: %v", err)
	}

	rec, ok := store.Records[paneKey]
	if !ok {
		t.Fatal("record not found")
	}
	if rec.IM != "im.rime.test" {
		t.Errorf("expected IM im.rime.test, got %s", rec.IM)
	}
}

func TestLoadStoreNotExist(t *testing.T) {
	_, err := loadStore("/nonexistent/path.json")
	if err == nil {
		t.Error("expected error for non-existent file")
	}
}

func TestLoadStoreInvalidJSON(t *testing.T) {
	tmpDir := t.TempDir()
	path := filepath.Join(tmpDir, "invalid.json")

	if err := os.WriteFile(path, []byte("not json"), 0644); err != nil {
		t.Fatalf("failed to write file: %v", err)
	}

	_, err := loadStore(path)
	if err == nil {
		t.Error("expected error for invalid JSON")
	}
}
