package raknet_message

import wire "mcpe:raknet/wire"
import mcpe_runtime "mcpe:runtime"

Connected_Ping :: struct {
    ping_time: i64,
}

marshal_connected_ping :: proc(pk: Connected_Ping) -> [9]u8 {
    result: [9]u8
    result[0] = ID_CONNECTED_PING
    wire.store_u64_be(result[1:], u64(pk.ping_time))
    return result
}

unmarshal_connected_ping :: proc(data: []u8) -> (pk: Connected_Ping, err: mcpe_runtime.Error) {
    if len(data) < 8 {
        err = mcpe_runtime.make_error(.Unexpected_EOF, "wire.unmarshal_connected_ping")
        return
    }
    pk.ping_time = i64(wire.load_u64_be(data))
    return
}

Connected_Pong :: struct {
    ping_time: i64,
    pong_time: i64,
}

marshal_connected_pong :: proc(pk: Connected_Pong) -> [17]u8 {
    result: [17]u8
    result[0] = ID_CONNECTED_PONG
    wire.store_u64_be(result[1:9], u64(pk.ping_time))
    wire.store_u64_be(result[9:17], u64(pk.pong_time))
    return result
}

unmarshal_connected_pong :: proc(data: []u8) -> (pk: Connected_Pong, err: mcpe_runtime.Error) {
    if len(data) < 16 {
        err = mcpe_runtime.make_error(.Unexpected_EOF, "wire.unmarshal_connected_pong")
        return
    }
    pk.ping_time = i64(wire.load_u64_be(data[:8]))
    pk.pong_time = i64(wire.load_u64_be(data[8:16]))
    return
}

Connection_Request :: struct {
    client_guid:  i64,
    request_time: i64,
    secure:       bool,
}

marshal_connection_request :: proc(pk: Connection_Request) -> [18]u8 {
    result: [18]u8
    result[0] = ID_CONNECTION_REQUEST
    wire.store_u64_be(result[1:9], u64(pk.client_guid))
    wire.store_u64_be(result[9:17], u64(pk.request_time))
    result[17] = 1 if pk.secure else 0
    return result
}

unmarshal_connection_request :: proc(data: []u8) -> (pk: Connection_Request, err: mcpe_runtime.Error) {
    if len(data) < 17 {
        err = mcpe_runtime.make_error(.Unexpected_EOF, "wire.unmarshal_connection_request")
        return
    }
    pk.client_guid = i64(wire.load_u64_be(data[:8]))
    pk.request_time = i64(wire.load_u64_be(data[8:16]))
    pk.secure = data[16] != 0
    return
}

