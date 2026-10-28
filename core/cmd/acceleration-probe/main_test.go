package main

import (
	"fmt"
	"io"
	"net"
	"testing"
	"time"

	"github.com/metacubex/mihomo/component/profile/cachefile"
	"github.com/metacubex/mihomo/config"
	C "github.com/metacubex/mihomo/constant"
	"github.com/metacubex/mihomo/hub/executor"
)

func TestStandaloneProbeActuallyStartsItsConfiguredListeners(t *testing.T) {
	C.SetHomeDir(t.TempDir())
	defer func() { cachefile.Cache().Close() }()
	reserve, err := net.Listen("tcp", "127.0.0.1:0")
	if err != nil {
		t.Fatal(err)
	}
	port := reserve.Addr().(*net.TCPAddr).Port
	reserve.Close()
	cfg, err := config.Parse([]byte(fmt.Sprintf(`{"mixed-port":%d,"bind-address":"127.0.0.1","allow-lan":false,"mode":"rule","log-level":"silent","rules":["MATCH,DIRECT"]}`, port)))
	if err != nil {
		t.Fatal(err)
	}
	if err := apply(cfg); err != nil {
		t.Fatal(err)
	}
	defer executor.Shutdown()
	socket, err := net.DialTimeout("tcp", fmt.Sprintf("127.0.0.1:%d", port), time.Second)
	if err != nil {
		t.Fatal(err)
	}
	defer socket.Close()
	socket.SetDeadline(time.Now().Add(time.Second))
	if _, err := socket.Write([]byte{5, 1, 0}); err != nil {
		t.Fatal(err)
	}
	response := make([]byte, 2)
	if _, err := io.ReadFull(socket, response); err != nil {
		t.Fatal(err)
	}
	if response[0] != 5 || response[1] != 0 {
		t.Fatalf("SOCKS handshake failed: %v", response)
	}
}
