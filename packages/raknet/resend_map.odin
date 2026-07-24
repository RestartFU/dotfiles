package raknet

Resend_Record :: struct {
    packet:    ^Packet,
    timestamp: i64,
}

Resend_Map :: struct {
    unacknowledged: map[UInt24]Resend_Record,
    delays:         map[i64]i64,
}

resend_map_init :: proc() -> Resend_Map {
    return Resend_Map{
        unacknowledged = make(map[UInt24]Resend_Record),
        delays = make(map[i64]i64),
    }
}

resend_map_destroy :: proc(value: ^Resend_Map) {
    delete(value.unacknowledged)
    delete(value.delays)
    value^ = {}
}

resend_map_add :: proc(value: ^Resend_Map, index: UInt24, packet: ^Packet, now_ns: i64) {
    value.unacknowledged[index] = Resend_Record{
        packet = packet,
        timestamp = now_ns,
    }
}

resend_map_remove :: proc(
    value: ^Resend_Map,
    index: UInt24,
    multiplier: i64,
    now_ns: i64,
) -> (packet: ^Packet, found: bool) {
    record, exists := value.unacknowledged[index]
    if !exists {
        return nil, false
    }
    delete_key(&value.unacknowledged, index)
    value.delays[now_ns] = (now_ns - record.timestamp) * multiplier
    return record.packet, true
}

resend_map_acknowledge :: proc(value: ^Resend_Map, index: UInt24, now_ns: i64) -> (
    packet: ^Packet,
    found: bool,
) {
    return resend_map_remove(value, index, 1, now_ns)
}

resend_map_retransmit :: proc(value: ^Resend_Map, index: UInt24, now_ns: i64) -> (
    packet: ^Packet,
    found: bool,
) {
    return resend_map_remove(value, index, 2, now_ns)
}

resend_map_rtt :: proc(value: ^Resend_Map, now_ns: i64) -> i64 {
    RTT_WINDOW_NS :: i64(5_000_000_000)
    for timestamp in value.delays {
        if now_ns - timestamp > RTT_WINDOW_NS {
            delete_key(&value.delays, timestamp)
        }
    }
    if len(value.delays) == 0 {
        return 50_000_000
    }
    total: i64
    for _, delay in value.delays {
        total += delay
    }
    return total / i64(len(value.delays))
}

