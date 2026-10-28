// A standalone host/probe entry point for Orange's pinned embedded core.
package main

import (
	"flag"
	"fmt"
	"os"
	"os/signal"
	"path/filepath"
	"syscall"

	"github.com/metacubex/mihomo/adapter/inbound"
	"github.com/metacubex/mihomo/config"
	C "github.com/metacubex/mihomo/constant"
	"github.com/metacubex/mihomo/hub/executor"
	"github.com/metacubex/mihomo/listener"
	"github.com/metacubex/mihomo/tunnel"
)

func apply(cfg *config.Config) error {
	if cfg.General.Tun.Enable {
		return fmt.Errorf("standalone probe does not enable TUN")
	}
	executor.ApplyConfig(cfg, true)
	// The embedded entry point deliberately leaves listener lifecycle to Flutter.
	// This process owns only its configured server/mixed listeners, never TUN.
	listener.SetAllowLan(cfg.General.AllowLan)
	listener.SetBindAddress(cfg.General.BindAddress)
	inbound.SetAllowedIPs(cfg.General.LanAllowedIPs)
	inbound.SetDisAllowedIPs(cfg.General.LanDisAllowedIPs)
	inbound.SetSkipAuthPrefixes(cfg.General.SkipAuthPrefixes)
	listener.PatchInboundListeners(cfg.Listeners, tunnel.Tunnel, true)
	listener.ReCreateMixed(cfg.General.MixedPort, tunnel.Tunnel)
	return nil
}

func main() {
	directory := flag.String("d", ".", "private runtime directory")
	file := flag.String("f", "config.json", "configuration file")
	test := flag.Bool("t", false, "validate without listening")
	flag.Parse()
	if err := run(*directory, *file, *test); err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(1)
	}
}

func run(directory, file string, test bool) error {
	directory, err := filepath.Abs(directory)
	if err != nil {
		return err
	}
	if err := os.MkdirAll(directory, 0700); err != nil {
		return err
	}
	C.SetHomeDir(directory)
	raw, err := os.ReadFile(file)
	if err != nil {
		return err
	}
	cfg, err := config.Parse(raw)
	if err != nil {
		return err
	}
	if test {
		fmt.Println("configuration valid")
		return nil
	}
	if err := apply(cfg); err != nil {
		return err
	}
	defer executor.Shutdown()
	signals := make(chan os.Signal, 1)
	signal.Notify(signals, os.Interrupt, syscall.SIGTERM)
	defer signal.Stop(signals)
	<-signals
	return nil
}
