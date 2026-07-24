package raknet_wire

import mcpe_runtime "mcpe:runtime"

UInt24 :: distinct u32

UINT24_MASK :: u32(0x00ff_ffff)

uint24_inc :: proc(value: ^UInt24) -> UInt24 {
    old := value^
    value^ = UInt24(u32(value^) + 1)
    return old
}

load_u16_be :: proc(data: []u8) -> u16 {
    return u16(data[0]) << 8 | u16(data[1])
}

load_u32_be :: proc(data: []u8) -> u32 {
    return u32(data[0]) << 24 |
           u32(data[1]) << 16 |
           u32(data[2]) << 8 |
           u32(data[3])
}

load_u64_be :: proc(data: []u8) -> u64 {
    return u64(load_u32_be(data[:4])) << 32 | u64(load_u32_be(data[4:8]))
}

load_u16_le :: proc(data: []u8) -> u16 {
    return u16(data[0]) | u16(data[1]) << 8
}

load_u24_le :: proc(data: []u8) -> UInt24 {
    return UInt24(u32(data[0]) | u32(data[1]) << 8 | u32(data[2]) << 16)
}

store_u16_be :: proc(data: []u8, value: u16) {
    data[0] = u8(value >> 8)
    data[1] = u8(value)
}

store_u32_be :: proc(data: []u8, value: u32) {
    data[0] = u8(value >> 24)
    data[1] = u8(value >> 16)
    data[2] = u8(value >> 8)
    data[3] = u8(value)
}

store_u64_be :: proc(data: []u8, value: u64) {
    store_u32_be(data[:4], u32(value >> 32))
    store_u32_be(data[4:8], u32(value))
}

store_u16_le :: proc(data: []u8, value: u16) {
    data[0] = u8(value)
    data[1] = u8(value >> 8)
}

store_u24_le :: proc(data: []u8, value: UInt24) {
    raw := u32(value)
    data[0] = u8(raw)
    data[1] = u8(raw >> 8)
    data[2] = u8(raw >> 16)
}

Reader :: struct {
    data:   []u8,
    offset: int,
}

reader :: proc(data: []u8) -> Reader {
    return Reader{data = data}
}

remaining :: proc(r: ^Reader) -> int {
    return len(r.data) - r.offset
}

read_bytes :: proc(r: ^Reader, count: int) -> (value: []u8, err: mcpe_runtime.Error) {
    if count < 0 || remaining(r) < count {
        err = mcpe_runtime.make_error(.Unexpected_EOF, "raknet.read_bytes")
        return
    }
    value = r.data[r.offset:r.offset + count]
    r.offset += count
    return
}

read_u8 :: proc(r: ^Reader) -> (value: u8, err: mcpe_runtime.Error) {
    data := read_bytes(r, 1) or_return
    return data[0], nil
}

read_u16_be :: proc(r: ^Reader) -> (value: u16, err: mcpe_runtime.Error) {
    data := read_bytes(r, 2) or_return
    return load_u16_be(data), nil
}

read_u24_le :: proc(r: ^Reader) -> (value: UInt24, err: mcpe_runtime.Error) {
    data := read_bytes(r, 3) or_return
    return load_u24_le(data), nil
}

read_u32_be :: proc(r: ^Reader) -> (value: u32, err: mcpe_runtime.Error) {
    data := read_bytes(r, 4) or_return
    return load_u32_be(data), nil
}

read_u64_be :: proc(r: ^Reader) -> (value: u64, err: mcpe_runtime.Error) {
    data := read_bytes(r, 8) or_return
    return load_u64_be(data), nil
}

Writer :: struct {
    data: [dynamic]u8,
}

writer :: proc(capacity: int = 256) -> Writer {
    return Writer{data = make([dynamic]u8, 0, capacity)}
}

writer_destroy :: proc(w: ^Writer) {
    delete(w.data)
    w^ = {}
}

write_u8 :: proc(w: ^Writer, value: u8) {
    append(&w.data, value)
}

write_bytes :: proc(w: ^Writer, value: []u8) {
    append(&w.data, ..value)
}

write_zeroes :: proc(w: ^Writer, count: int) {
    for _ in 0..<count {
        append(&w.data, 0)
    }
}

write_u16_be :: proc(w: ^Writer, value: u16) {
    append(&w.data, u8(value >> 8), u8(value))
}

write_u24_le :: proc(w: ^Writer, value: UInt24) {
    raw := u32(value)
    append(&w.data, u8(raw), u8(raw >> 8), u8(raw >> 16))
}

write_u32_be :: proc(w: ^Writer, value: u32) {
    append(
        &w.data,
        u8(value >> 24),
        u8(value >> 16),
        u8(value >> 8),
        u8(value),
    )
}

write_u64_be :: proc(w: ^Writer, value: u64) {
    write_u32_be(w, u32(value >> 32))
    write_u32_be(w, u32(value))
}
