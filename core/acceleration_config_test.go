package main

import (
	"encoding/json"
	"os"
	"testing"

	"github.com/metacubex/mihomo/config"
	"github.com/metacubex/mihomo/constant"
)

func TestCompiledAccelerationConfiguration(t *testing.T) {
	fixture := os.Getenv("ACCEL_CONFIG_FIXTURE")
	if fixture == "" {
		t.Skip("set ACCEL_CONFIG_FIXTURE to Dart-compiled JSON")
	}
	constant.SetHomeDir(t.TempDir())
	data, err := os.ReadFile(fixture)
	if err != nil {
		t.Fatal(err)
	}
	raw := config.DefaultRawConfig()
	if err := json.Unmarshal(data, raw); err != nil {
		t.Fatal(err)
	}
	if len(raw.Rule) == 0 {
		t.Fatal("compiled JSON did not populate the core rule field")
	}
	if _, err := config.ParseRawConfig(raw); err != nil {
		t.Fatal(err)
	}
}

func TestInvalidConfigPreservesPreviousProtection(t *testing.T) {
	constant.SetHomeDir(t.TempDir())
	before := &config.Config{}
	currentConfig = before
	raw := config.DefaultRawConfig()
	raw.Rule = []string{"NOT-A-RULE,example.test,REJECT"}
	if err := setupConfig(&SetupParams{Config: raw}); err == nil {
		t.Fatal("invalid rule should fail validation")
	}
	if currentConfig != before {
		t.Fatal("failed configuration replaced the previous protected configuration")
	}
}
