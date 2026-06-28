# AccuKnox eBPF Assignment (Minimal Setup)

This repository contains clean, humanized, and highly-simplified eBPF solutions in Go and C.

## 🛠️ Requirements & Dependencies
Install dependencies on Ubuntu 20.04/22.04+:
```bash
sudo apt update && sudo apt install -y clang llvm libbpf-dev golang-go make curl netcat-openbsd
```

---
 Problem 1: Drop Packets on TCP Port (XDP)
Drops incoming/outgoing packets on a configurable TCP port.

### Compile & Build
```bash
cd problem1
go generate
go build -o drop_port
```

### Run & Verify
1. Attach to loopback interface `lo` and block port `4040`:
   ```bash
   sudo ./drop_port 4040 lo
   ```
2. In a separate terminal, test connection to listener `nc -l 4040`:
   ```bash
   nc -zv localhost 4040
   ```
   *Result:* Connection hangs or times out (dropped). Other ports work fine.

---

##  Problem 2: Allow Only Port 4040 for a Process (Cgroup)
Allows traffic **only** on port `4040` for process named `myprocess`. Traffic to other ports is blocked.

### Compile & Build
```bash
cd ../problem2
go generate
go build -o process_filter
```

### Run & Verify
1. Start the policy monitor for `myprocess` (default):
   ```bash
   sudo ./process_filter myprocess
   ```
2. Build a dummy binary named `myprocess`:
   ```bash
   echo 'package main; import ("net"; "fmt"; "os"); func main() { _, err := net.Dial("tcp", os.Args[1]); fmt.Println("Result:", err) }' > dummy.go
   go build -o myprocess dummy.go
   ```
3. Test connectivity with `myprocess`:
   - Connect to `localhost:8080`:
     ```bash
     ./myprocess localhost:8080
     ```
     *Result:* `Result: dial tcp 127.0.0.1:8080: connect: permission denied`
   - Connect to `localhost:4040`:
     ```bash
     ./myprocess localhost:4040
     ```
     *Result:* `Result: <nil>` (Successful connection!)
4. Other processes (like `curl` or standard `nc`) are not affected.

---

##  Problem 3: Go Concurrency Code Explanation
Detailed explanation of Go channel structures, worker pools, concurrency mechanics, and race conditions.

The full explanation is written in:
👉 **[problem3.md](file:///Users/sabyasacheethakur/Desktop/accuknox%20assignment/problem3.md)**
