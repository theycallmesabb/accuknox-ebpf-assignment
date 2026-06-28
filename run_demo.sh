#!/bin/bash
set -e

echo "=================================================="
echo "      AccuKnox eBPF Assignment Automated Demo      "
echo "=================================================="

# 1. Install dependencies
echo "[+] Installing packages..."
sudo apt update -y &>/dev/null
sudo apt install -y clang llvm libbpf-dev golang-go make curl netcat-openbsd &>/dev/null

# 2. Setup modules
echo "[+] Initializing Go modules..."
go mod tidy

# --- Problem 1 Demo ---
echo -e "\n=============================================="
echo "🚀 PROBLEM 1: XDP Configurable TCP Port Drop"
echo "=============================================="
cd problem1
go generate
go build -o drop_port

# Run drop_port in the background blocking port 4040
echo "[+] Launching drop_port program (blocking port 4040) in background..."
sudo ./drop_port 4040 lo &
BPF_PID1=$!
sleep 2

# Start a netcat listener on 4040 in the background
nc -l 4040 &
NC_PID=$!
sleep 1

echo "[+] Testing connection to port 4040 (should fail/time out)..."
# Try connecting with a 2-second timeout
if nc -w 2 -zv localhost 4040; then
    echo "❌ Error: Connection succeeded (packets were NOT dropped)."
else
    echo "✅ Success: Connection timed out/failed (packets successfully dropped!)."
fi

# Clean up Problem 1 background jobs
sudo kill $BPF_PID1 2>/dev/null || true
kill $NC_PID 2>/dev/null || true
cd ..

# --- Problem 2 Demo ---
echo -e "\n=============================================="
echo "🚀 PROBLEM 2: Process-scoped TCP Port Filter"
echo "=============================================="
cd problem2
go generate
go build -o process_filter

# Create dummy myprocess binary
echo 'package main; import ("net"; "fmt"; "os"); func main() { _, err := net.Dial("tcp", os.Args[1]); fmt.Println("Result:", err) }' > dummy.go
go build -o myprocess dummy.go

# Start process filter in background for process name 'myprocess' (only allowing 4040)
echo "[+] Launching process_filter (only allow port 4040 for 'myprocess') in background..."
sudo ./process_filter myprocess &
BPF_PID2=$!
sleep 2

# Start listener on port 8080 and port 4040
nc -l 8080 &
NC_PID_8080=$!
nc -l 4040 &
NC_PID_4040=$!
sleep 1

echo "[+] Testing myprocess connecting to port 8080 (should be BLOCKED)..."
./myprocess localhost:8080

echo "[+] Testing myprocess connecting to port 4040 (should be ALLOWED)..."
./myprocess localhost:4040

echo "[+] Testing standard connection (nc) to port 8080 (should be ALLOWED)..."
if nc -w 2 -zv localhost 8080; then
    echo "✅ Success: Other processes are unaffected."
else
    echo "❌ Error: Normal process was blocked."
fi

# Clean up Problem 2 background jobs
sudo kill $BPF_PID2 2>/dev/null || true
kill $NC_PID_8080 2>/dev/null || true
kill $NC_PID_4040 2>/dev/null || true
cd ..

# --- Kernel Logs ---
echo -e "\n=============================================="
echo "📋 Kernel Debug Logs (Trace Pipe Extracts)"
echo "=============================================="
sudo tail -n 10 /sys/kernel/debug/tracing/trace | grep -E "Dropped|Blocked" || echo "(No matching kernel printk trace logs found)"

echo -e "\n=============================================="
echo "✅ Demo completed successfully!"
echo "=============================================="
