package mcpe_runtime

import "core:time"

Clock_Now_Proc :: proc "odin" (user_data: rawptr) -> i64

Clock :: struct {
    user_data: rawptr,
    now:       Clock_Now_Proc,
}

system_now_ns :: proc "odin" (_: rawptr) -> i64 {
    epoch := time.unix(0, 0)
    return i64(time.diff(epoch, time.now()))
}

system_clock :: proc() -> Clock {
    return Clock{now = system_now_ns}
}

clock_now :: proc(clock: Clock) -> i64 {
    if clock.now == nil {
        return system_now_ns(nil)
    }
    return clock.now(clock.user_data)
}

