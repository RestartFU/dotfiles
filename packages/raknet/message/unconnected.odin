package raknet_message

import wire "mcpe:raknet/wire"
import mcpe_runtime "mcpe:runtime"

Unconnected_Ping :: struct {
    ping_time:   i64,
    client_guid: i64,
}

marshal_unconnected_ping :: proc(pk: Unconnected_Ping) -> [33]u8 {
    result: [33]u8
    result[0] = ID_UNCONNECTED_PING
    wire.store_u64_be(result[1:9], u64(pk.ping_time))
    copy(result[9:25], UNCONNECTED_MAGIC[:])
    wire.store_u64_be(result[25:33], u64(pk.client_guid))
    return result
}

unmarshal_unconnected_ping :: proc(data: []u8) -> (pk: Unconnected_Ping, err: mcpe_runtime.Error) {
    if len(data) < 32 {
        err = mcpe_runtime.make_error(.Unexpected_EOF, "wire.unmarshal_unconnected_ping")
        return
    }
    pk.ping_time = i64(wire.load_u64_be(data[:8]))
    pk.client_guid = i64(wire.load_u64_be(data[24:32]))
    return
}

Unconnected_Pong :: struct {
    ping_time:   i64,
    server_guid: i64,
    data:        []u8,
}

marshal_unconnected_pong :: proc(pk: Unconnected_Pong) -> wire.Writer {
    w := wire.writer(35 + len(pk.data))
    wire.write_u8(&w, ID_UNCONNECTED_PONG)
    wire.write_u64_be(&w, u64(pk.ping_time))
    wire.write_u64_be(&w, u64(pk.server_guid))
    wire.write_bytes(&w, UNCONNECTED_MAGIC[:])
    wire.write_u16_be(&w, u16(len(pk.data)))
    wire.write_bytes(&w, pk.data)
    return w
}

unmarshal_unconnected_pong :: proc(data: []u8) -> (pk: Unconnected_Pong, err: mcpe_runtime.Error) {
    if len(data) < 32 {
        err = mcpe_runtime.make_error(.Unexpected_EOF, "wire.unmarshal_unconnected_pong")
        return
    }
    pk.ping_time = i64(wire.load_u64_be(data[:8]))
    pk.server_guid = i64(wire.load_u64_be(data[8:16]))
    if len(data) < 34 {
        return
    }
    count := int(wire.load_u16_be(data[32:34]))
    if len(data) < 34 + count {
        err = mcpe_runtime.make_error(.Unexpected_EOF, "wire.unmarshal_unconnected_pong")
        return
    }
    pk.data = data[34:34 + count]
    return
}

