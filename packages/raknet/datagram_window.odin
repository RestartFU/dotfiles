package raknet

Datagram_Window :: struct {
    lowest:  UInt24,
    highest: UInt24,
    entries: map[UInt24]i64,
}

datagram_window_init :: proc() -> Datagram_Window {
    return Datagram_Window{entries = make(map[UInt24]i64)}
}

datagram_window_destroy :: proc(window: ^Datagram_Window) {
    delete(window.entries)
    window^ = {}
}

datagram_window_seen :: proc(window: ^Datagram_Window, index: UInt24) -> bool {
    if index < window.lowest {
        return true
    }
    _, exists := window.entries[index]
    return exists
}

datagram_window_add :: proc(window: ^Datagram_Window, index: UInt24, now_ns: i64) -> bool {
    if datagram_window_seen(window, index) {
        return false
    }
    candidate := UInt24(u32(index) + 1)
    if candidate > window.highest {
        window.highest = candidate
    }
    window.entries[index] = now_ns
    return true
}

datagram_window_shift :: proc(window: ^Datagram_Window) -> (count: int) {
    index := window.lowest
    for index < window.highest {
        if _, exists := window.entries[index]; !exists {
            break
        }
        delete_key(&window.entries, index)
        count += 1
        index = UInt24(u32(index) + 1)
    }
    window.lowest = index
    return
}

datagram_window_missing :: proc(
    window: ^Datagram_Window,
    now_ns: i64,
    since_ns: i64,
) -> [dynamic]UInt24 {
    indices := make([dynamic]UInt24)
    should_mark_missing := false
    raw := i64(u32(window.highest)) - 1
    lower := i64(u32(window.lowest))
    for raw >= lower {
        index := UInt24(raw)
        if seen_at, exists := window.entries[index]; exists {
            if now_ns - seen_at >= since_ns {
                should_mark_missing = true
            }
        } else if should_mark_missing {
            append(&indices, index)
            window.entries[index] = 0
        }
        raw -= 1
    }
    datagram_window_shift(window)
    return indices
}

datagram_window_size :: proc(window: ^Datagram_Window) -> UInt24 {
    return UInt24(u32(window.highest) - u32(window.lowest))
}

