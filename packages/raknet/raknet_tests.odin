package raknet

import "core:testing"

@(test)
uint24_round_trip :: proc(t: ^testing.T) {
    values := [?]UInt24{0, 1, 0xff, 0xffff, 0xff_ffff}
    for expected in values {
        bytes: [3]u8
        store_u24_le(bytes[:], expected)
        testing.expect_value(t, load_u24_le(bytes[:]), expected)
    }
}

@(test)
binary_endian_round_trip :: proc(t: ^testing.T) {
    w := writer()
    defer writer_destroy(&w)
    write_u16_be(&w, 0x1234)
    write_u32_be(&w, 0x5678_9abc)
    write_u64_be(&w, 0xdef0_1234_5678_9abc)

    r := reader(w.data[:])
    a, a_err := read_u16_be(&r)
    b, b_err := read_u32_be(&r)
    c, c_err := read_u64_be(&r)
    testing.expect(t, a_err == nil)
    testing.expect(t, b_err == nil)
    testing.expect(t, c_err == nil)
    testing.expect_value(t, a, 0x1234)
    testing.expect_value(t, b, 0x5678_9abc)
    testing.expect_value(t, c, 0xdef0_1234_5678_9abc)
}
