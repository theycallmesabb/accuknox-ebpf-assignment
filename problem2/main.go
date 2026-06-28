package main

import (
	"fmt"
	"log"
	"os"

	"github.com/cilium/ebpf/link"
	"github.com/cilium/ebpf/rlimit"
)

//go:generate go run github.com/cilium/ebpf/cmd/bpf2go -target bpfel bpf filter.c

type bpfConfigT struct {
	ProcessName [16]byte
	AllowedPort uint32
}

func main() {
	proc := "myprocess"
	if len(os.Args) > 1 {
		proc = os.Args[1]
	}

	_ = rlimit.RemoveMemlock()
	var objs bpfObjects
	_ = loadBpfObjects(&objs, nil)
	defer objs.Close()

	var cfg bpfConfigT
	copy(cfg.ProcessName[:], proc)
	cfg.AllowedPort = 4040

	key := uint32(0)
	_ = objs.ConfigMap.Update(&key, &cfg, 0)

	lConn, err1 := link.AttachCgroup(link.CgroupOptions{Path: "/sys/fs/cgroup", Attach: link.AttachCGroupInet4Connect, Program: objs.HandleConnect4})
	lBind, err2 := link.AttachCgroup(link.CgroupOptions{Path: "/sys/fs/cgroup", Attach: link.AttachCGroupInet4Bind, Program: objs.HandleBind4})
	if err1 != nil || err2 != nil {
		log.Fatalf("Attach failed. Run as root: err1=%v, err2=%v", err1, err2)
	}
	defer lConn.Close()
	defer lBind.Close()

	fmt.Printf("Policy active: Only port 4040 allowed for process '%s'. Ctrl+C to stop.\n", proc)
	select {}
}
