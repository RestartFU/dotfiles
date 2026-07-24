package mcpe_benchmarks

import "core:testing"

@(test)
benchmark_harness_exists :: proc(t: ^testing.T) {
    testing.expect(t, true)
}

