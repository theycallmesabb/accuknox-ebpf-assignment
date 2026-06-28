// +build ignore

#include <linux/bpf.h>
#include <bpf/bpf_helpers.h>
#include <bpf/bpf_endian.h>

char LICENSE[] SEC("license") = "GPL";

struct config_t {
    char process_name[16];
    __u32 allowed_port;
};

struct {
    __uint(type, BPF_MAP_TYPE_ARRAY);
    __uint(max_entries, 1);
    __type(key, __u32);
    __type(value, struct config_t);
} config_map SEC(".maps");

static __always_inline int check_traffic(struct bpf_sock_addr *ctx) {
    __u32 key = 0;
    struct config_t *cfg = bpf_map_lookup_elem(&config_map, &key);
    if (!cfg || cfg->process_name[0] == '\0') return 1;

    char comm[16] = {};
    bpf_get_current_comm(&comm, sizeof(comm));

    int match = 1;
    for (int i = 0; i < 16; i++) {
        if (comm[i] != cfg->process_name[i]) { match = 0; break; }
        if (cfg->process_name[i] == '\0') break;
    }

    if (match && bpf_ntohs((__u16)ctx->user_port) != (__u16)cfg->allowed_port) {
        bpf_printk("Blocked port %d for %s\n", bpf_ntohs(ctx->user_port), comm);
        return 0; // Drop
    }
    return 1; // Allow
}

SEC("cgroup/connect4")
int handle_connect4(struct bpf_sock_addr *ctx) { return check_traffic(ctx); }

SEC("cgroup/bind4")
int handle_bind4(struct bpf_sock_addr *ctx) { return check_traffic(ctx); }
