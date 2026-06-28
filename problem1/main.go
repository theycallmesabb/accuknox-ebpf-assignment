package main

import (
	"fmt"
	"log"
	"net"
	"os"
	"strconv"

	"github.com/cilium/ebpf/link"
	"github.com/cilium/ebpf/rlimit"
)

//go:generate go run github.com/cilium/ebpf/cmd/bpf2go -target bpfel bpf drop.c

func main() {
	if len(os.Args) < 2 {
		log.Fatal("Usage: sudo ./drop_port <port> [interface]")
	}
	portVal, _ := strconv.Atoi(os.Args[1])
	ifaceName := "lo"
	if len(os.Args) > 2 {
		ifaceName = os.Args[2]
	}

	_ = rlimit.RemoveMemlock()
	iface, _ := net.InterfaceByName(ifaceName)

	var objs bpfObjects
	_ = loadBpfObjects(&objs, nil)
	defer objs.Close()

	l, _ := link.AttachXDP(link.XDPOptions{Interface: iface.Index, Program: objs.XdpDropPort})
	defer l.Close()

	key, val := uint32(0), uint32(portVal)
	_ = objs.ConfigMap.Update(&key, &val, 0)

	fmt.Printf("XDP attached to %s. Dropping TCP port %d. Press Ctrl+C to stop.\n", ifaceName, portVal)
	select {}
}
