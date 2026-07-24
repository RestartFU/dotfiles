package raknet

import "core:slice"
import mcpe_runtime "mcpe:runtime"

ACK_RANGE  :: u8(0)
ACK_SINGLE :: u8(1)
MAX_ACKNOWLEDGEMENT_PACKETS :: 8192

Acknowledgement :: struct {
    packets: [dynamic]UInt24,
}

acknowledgement_init :: proc(capacity: int = 0) -> Acknowledgement {
    return Acknowledgement{packets = make([dynamic]UInt24, 0, capacity)}
}

acknowledgement_destroy :: proc(ack: ^Acknowledgement) {
    delete(ack.packets)
    ack^ = {}
}

acknowledgement_add :: proc(ack: ^Acknowledgement, index: UInt24) {
    append(&ack.packets, index)
}

acknowledgement_write_record :: proc(
    w: ^Writer,
    first, last: UInt24,
    records: ^u16,
) {
    if first == last {
        write_u8(w, ACK_SINGLE)
        write_u24_le(w, first)
    } else {
        write_u8(w, ACK_RANGE)
        write_u24_le(w, first)
        write_u24_le(w, last)
    }
    records^ += 1
}

acknowledgement_write :: proc(ack: ^Acknowledgement, w: ^Writer, mtu: u16) -> int {
    length_offset := len(w.data)
    write_u16_be(w, 0)
    if len(ack.packets) == 0 {
        return 0
    }

    slice.sort(ack.packets[:])
    first, last := ack.packets[0], ack.packets[0]
    records: u16
    consumed := 0

    for packet, index in ack.packets {
        if len(w.data) >= int(mtu) - 7 {
            break
        }
        consumed += 1
        if index == 0 {
            continue
        }
        if u32(packet) == u32(last) + 1 {
            last = packet
            continue
        }
        acknowledgement_write_record(w, first, last, &records)
        first, last = packet, packet
    }
    acknowledgement_write_record(w, first, last, &records)
    store_u16_be(w.data[length_offset:length_offset + 2], records)
    return consumed
}

acknowledgement_read :: proc(ack: ^Acknowledgement, data: []u8) -> mcpe_runtime.Error {
    if len(data) < 2 {
        return mcpe_runtime.make_error(.Unexpected_EOF, "raknet.acknowledgement_read")
    }
    r := reader(data)
    record_count := read_u16_be(&r) or_return
    for _ in 0..<int(record_count) {
        kind := read_u8(&r) or_return
        switch kind {
        case ACK_RANGE:
            start := read_u24_le(&r) or_return
            end := read_u24_le(&r) or_return
            if end < start {
                return mcpe_runtime.make_error(.Limit_Exceeded, "raknet.acknowledgement_read", "descending acknowledgement range")
            }
            count := int(u32(end) - u32(start)) + 1
            if len(ack.packets) + count > MAX_ACKNOWLEDGEMENT_PACKETS {
                return mcpe_runtime.make_error(.Limit_Exceeded, "raknet.acknowledgement_read", "maximum acknowledgement packets exceeded")
            }
            for raw := u32(start); raw <= u32(end); raw += 1 {
                append(&ack.packets, UInt24(raw))
            }
        case ACK_SINGLE:
            if len(ack.packets) + 1 > MAX_ACKNOWLEDGEMENT_PACKETS {
                return mcpe_runtime.make_error(.Limit_Exceeded, "raknet.acknowledgement_read", "maximum acknowledgement packets exceeded")
            }
            append(&ack.packets, read_u24_le(&r) or_return)
        case:
            // Upstream ignores unknown record kinds without consuming a body.
        }
    }
    return nil
}

