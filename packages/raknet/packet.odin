package raknet

import mcpe_runtime "mcpe:runtime"

BIT_FLAG_DATAGRAM       :: u8(0x80)
BIT_FLAG_ACK            :: u8(0x40)
BIT_FLAG_NACK           :: u8(0x20)
BIT_FLAG_NEEDS_B_AND_AS :: u8(0x04)
SPLIT_FLAG              :: u8(0x10)

Reliability :: enum u8 {
    Unreliable,
    Unreliable_Sequenced,
    Reliable,
    Reliable_Ordered,
    Reliable_Sequenced,
}

reliability_is_reliable :: proc(value: Reliability) -> bool {
    return value == .Reliable ||
           value == .Reliable_Ordered ||
           value == .Reliable_Sequenced
}

reliability_is_sequenced :: proc(value: Reliability) -> bool {
    return value == .Unreliable_Sequenced ||
           value == .Reliable_Sequenced
}

reliability_is_sequenced_or_ordered :: proc(value: Reliability) -> bool {
    return reliability_is_sequenced(value) || value == .Reliable_Ordered
}

Packet :: struct {
    reliability:    Reliability,
    message_index:  UInt24,
    sequence_index: UInt24,
    order_index:    UInt24,
    content:        []u8,
    split:          bool,
    split_count:    u32,
    split_index:    u32,
    split_id:       u16,
}

write_packet :: proc(w: ^Writer, packet: ^Packet) {
    header := u8(packet.reliability) << 5
    if packet.split {
        header |= SPLIT_FLAG
    }
    write_u8(w, header)
    write_u16_be(w, u16(len(packet.content)) << 3)

    if reliability_is_reliable(packet.reliability) {
        write_u24_le(w, packet.message_index)
    }
    if reliability_is_sequenced(packet.reliability) {
        write_u24_le(w, packet.sequence_index)
    }
    if reliability_is_sequenced_or_ordered(packet.reliability) {
        write_u24_le(w, packet.order_index)
        write_u8(w, 0)
    }
    if packet.split {
        write_u32_be(w, packet.split_count)
        write_u16_be(w, packet.split_id)
        write_u32_be(w, packet.split_index)
    }
    write_bytes(w, packet.content)
}

read_packet :: proc(data: []u8) -> (
    packet: Packet,
    consumed: int,
    err: mcpe_runtime.Error,
) {
    if len(data) < 3 {
        err = mcpe_runtime.make_error(.Unexpected_EOF, "raknet.read_packet")
        return
    }

    header := data[0]
    packet.split = header & SPLIT_FLAG != 0
    raw_reliability := (header & 0xe0) >> 5
    if raw_reliability > u8(Reliability.Reliable_Sequenced) {
        err = mcpe_runtime.make_error(.Malformed, "raknet.read_packet", "unknown reliability")
        return
    }
    packet.reliability = Reliability(raw_reliability)
    content_size := int(load_u16_be(data[1:3]) >> 3)
    if content_size == 0 {
        err = mcpe_runtime.make_error(.Malformed, "raknet.read_packet", "packet content length is zero")
        return
    }

    r := reader(data[3:])
    if reliability_is_reliable(packet.reliability) {
        packet.message_index = read_u24_le(&r) or_return
    }
    if reliability_is_sequenced(packet.reliability) {
        packet.sequence_index = read_u24_le(&r) or_return
    }
    if reliability_is_sequenced_or_ordered(packet.reliability) {
        packet.order_index = read_u24_le(&r) or_return
        _ = read_u8(&r) or_return
    }
    if packet.split {
        packet.split_count = read_u32_be(&r) or_return
        packet.split_id = read_u16_be(&r) or_return
        packet.split_index = read_u32_be(&r) or_return
    }

    packet.content = read_bytes(&r, content_size) or_return
    consumed = 3 + r.offset
    return
}

PACKET_ADDITIONAL_SIZE :: 1 + 3 + 1 + 2 + 3 + 3 + 1
SPLIT_ADDITIONAL_SIZE  :: 4 + 2 + 4

split_content :: proc(data: []u8, mtu: u16) -> (
    fragments: [dynamic][]u8,
    err: mcpe_runtime.Error,
) {
    if mtu <= PACKET_ADDITIONAL_SIZE {
        err = mcpe_runtime.make_error(.Invalid_Argument, "raknet.split_content", "MTU too small")
        return
    }
    max_size := int(mtu) - PACKET_ADDITIONAL_SIZE
    if len(data) > max_size {
        max_size -= SPLIT_ADDITIONAL_SIZE
    }
    if max_size <= 0 {
        err = mcpe_runtime.make_error(.Invalid_Argument, "raknet.split_content", "MTU too small for split packet")
        return
    }
    if len(data) == 0 {
        fragments = make([dynamic][]u8, 0)
        return
    }

    fragment_count := (len(data) + max_size - 1) / max_size
    fragments = make([dynamic][]u8, 0, fragment_count)
    offset := 0
    for offset < len(data) {
        end := min(offset + max_size, len(data))
        append(&fragments, data[offset:end])
        offset = end
    }
    return
}
