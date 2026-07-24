package raknet_message

import "core:testing"
import "core:slice"
import wire "mcpe:raknet/wire"

@(test)
address_v4_round_trip :: proc(t: ^testing.T) {
    expected := address_v4(127, 0, 0, 1, 19132)
    w := wire.writer()
    defer wire.writer_destroy(&w)
    write_address(&w, expected)
    r := wire.reader(w.data[:])
    actual, err := read_address(&r)
    testing.expect(t, err == nil)
    testing.expect_value(t, actual, expected)
}

@(test)
unconnected_ping_round_trip :: proc(t: ^testing.T) {
    expected := Unconnected_Ping{ping_time = 1234567, client_guid = -42}
    data := marshal_unconnected_ping(expected)
    actual, err := unmarshal_unconnected_ping(data[1:])
    testing.expect(t, err == nil)
    testing.expect_value(t, actual, expected)
}

@(test)
unconnected_pong_round_trip :: proc(t: ^testing.T) {
    payload := []u8{1, 2, 3, 4}
    expected := Unconnected_Pong{ping_time = 99, server_guid = 123, data = payload}
    w := marshal_unconnected_pong(expected)
    defer wire.writer_destroy(&w)
    actual, err := unmarshal_unconnected_pong(w.data[1:])
    testing.expect(t, err == nil)
    testing.expect_value(t, actual.ping_time, expected.ping_time)
    testing.expect_value(t, actual.server_guid, expected.server_guid)
    testing.expect(t, slice.equal(actual.data, expected.data))
}
