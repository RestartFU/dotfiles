package raknet

Packet_Queue :: struct {
    lowest:  UInt24,
    highest: UInt24,
    entries: map[UInt24][]u8,
}

packet_queue_init :: proc() -> Packet_Queue {
    return Packet_Queue{entries = make(map[UInt24][]u8)}
}

packet_queue_destroy :: proc(queue: ^Packet_Queue) {
    delete(queue.entries)
    queue^ = {}
}

packet_queue_put :: proc(queue: ^Packet_Queue, index: UInt24, packet: []u8) -> bool {
    if index < queue.lowest {
        return false
    }
    if _, exists := queue.entries[index]; exists {
        return false
    }
    if index >= queue.highest {
        queue.highest = UInt24(u32(index) + 1)
    }
    queue.entries[index] = packet
    return true
}

packet_queue_fetch :: proc(queue: ^Packet_Queue) -> [dynamic][]u8 {
    packets := make([dynamic][]u8)
    index := queue.lowest
    for index < queue.highest {
        packet, exists := queue.entries[index]
        if !exists {
            break
        }
        delete_key(&queue.entries, index)
        append(&packets, packet)
        index = UInt24(u32(index) + 1)
    }
    queue.lowest = index
    return packets
}

packet_queue_window_size :: proc(queue: ^Packet_Queue) -> UInt24 {
    return UInt24(u32(queue.highest) - u32(queue.lowest))
}

