# Problem Statement 3: Go Code Explanation

## Code Snippet

```go
package main

import "fmt"

func main() {
    cnp := make(chan func(), 10)
    for i := 0; i < 4; i++ {
        go func() {
            for f := range cnp {
                f()
            }
        }()
    }
    cnp <- func() {
        fmt.Println("HERE1")
    }
    fmt.Println("Hello")
}
```

---

## 1. What the Code Does

This code implements a **Worker Pool pattern** — a common concurrency design in Go:

- A buffered channel (`cnp`) acts as a **task queue** that holds functions to be executed.
- **4 worker goroutines** are spawned, each continuously waiting on the channel to receive and execute tasks.
- The main thread sends one task (printing `"HERE1"`) into the queue, prints `"Hello"`, and exits.

---

## 2. Core Constructs Explained

| Construct | Explanation |
|---|---|
| `make(chan func(), 10)` | Creates a buffered channel holding up to 10 functions before blocking |
| `go func() { ... }()` | Spawns a new goroutine — a lightweight concurrent thread managed by the Go runtime |
| `for f := range cnp` | Blocks and waits for functions from the channel; exits only when the channel is closed |
| `cnp <- func() { ... }` | Sends a function literal (closure) into the channel |

---

## 3. Real-World Use Cases

- **Worker Pools / Concurrency Throttling** — Limit parallel tasks to avoid overloading resources (e.g., capping concurrent DB queries, file uploads, or API calls to exactly 4 at a time).
- **Asynchronous Task Queuing** — Decouple task submission from execution (e.g., an HTTP server enqueues heavy jobs to a channel and returns a fast response to the client, while background workers process the tasks).

---

## 4. Significance of Key Components

### The `for` loop with 4 iterations
Spawns exactly **4 worker goroutines**, setting a hard concurrency limit of 4 — at most 4 tasks will ever run in parallel simultaneously.

### `make(chan func(), 10)` — buffer of 10
Allows the producer (main thread) to send up to **10 tasks without blocking**, even if no workers are ready yet. The 11th send will block until a worker frees a slot.

---

## 5. Why is `"HERE1"` Not Printed?

This is due to Go's **process lifecycle model**:

1. `main()` sends the function into the channel.
2. `main()` immediately prints `"Hello"`.
3. `main()` returns — **the entire process exits**, killing all goroutines instantly.
4. The Go scheduler never gets a chance to context-switch to a worker goroutine to pick up and execute the task.

---

## 6. Fixed Version (using `sync.WaitGroup`)

```go
package main

import (
    "fmt"
    "sync"
)

func main() {
    cnp := make(chan func(), 10)
    var wg sync.WaitGroup

    for i := 0; i < 4; i++ {
        go func() {
            for f := range cnp {
                f()
                wg.Done() // signal task completion
            }
        }()
    }

    wg.Add(1) // one task being sent
    cnp <- func() {
        fmt.Println("HERE1")
    }

    wg.Wait()  // block until task is done
    close(cnp) // cleanly shut down workers
    fmt.Println("Hello")
}
```

### Output:
```
HERE1
Hello
```

`sync.WaitGroup` forces `main()` to wait for all tasks to complete before exiting, guaranteeing `"HERE1"` is printed.
