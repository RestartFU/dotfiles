package raknet_message

import wire "mcpe:raknet/wire"
import mcpe_runtime "mcpe:runtime"

Open_Connection_Request_1 :: struct {
    client_protocol: u8,
    mtu:             u16,
}

marshal_open_connection_request_1 :: proc(pk: Open_Connection_Request_1) -> (
    w: wire.Writer,
    err: mcpe_runtime.Error,
) {
    if pk.mtu < 29 {
        err = mcpe_runtime.make_error(.Invalid_Argument, "wire.marshal_open_connection_request_1", "MTU below header size")
        return
    }
    w = wire.writer(int(pk.mtu) - 28)
    wire.write_u8(&w, ID_OPEN_CONNECTION_REQUEST_1)
    wire.write_bytes(&w, UNCONNECTED_MAGIC[:])
    wire.write_u8(&w, pk.client_protocol)
    wire.write_zeroes(&w, int(pk.mtu) - 46)
    return
}

unmarshal_open_connection_request_1 :: proc(data: []u8) -> (
    pk: Open_Connection_Request_1,
    err: mcpe_runtime.Error,
) {
    if len(data) < 17 {
        err = mcpe_runtime.make_error(.Unexpected_EOF, "wire.unmarshal_open_connection_request_1")
        return
    }
    pk.client_protocol = data[16]
    pk.mtu = u16(len(data) + 29)
    return
}

Open_Connection_Reply_1 :: struct {
    server_guid:         i64,
    server_has_security: bool,
    cookie:              u32,
    mtu:                 u16,
}

marshal_open_connection_reply_1 :: proc(pk: Open_Connection_Reply_1) -> wire.Writer {
    extra := 4 if pk.server_has_security else 0
    w := wire.writer(28 + extra)
    wire.write_u8(&w, ID_OPEN_CONNECTION_REPLY_1)
    wire.write_bytes(&w, UNCONNECTED_MAGIC[:])
    wire.write_u64_be(&w, u64(pk.server_guid))
    wire.write_u8(&w, 1 if pk.server_has_security else 0)
    if pk.server_has_security {
        wire.write_u32_be(&w, pk.cookie)
    }
    wire.write_u16_be(&w, pk.mtu)
    return w
}

unmarshal_open_connection_reply_1 :: proc(data: []u8) -> (
    pk: Open_Connection_Reply_1,
    err: mcpe_runtime.Error,
) {
    if len(data) < 27 {
        err = mcpe_runtime.make_error(.Unexpected_EOF, "wire.unmarshal_open_connection_reply_1")
        return
    }
    pk.server_guid = i64(wire.load_u64_be(data[16:24]))
    pk.server_has_security = data[24] != 0
    offset := 25
    if pk.server_has_security {
        if len(data) < 31 {
            err = mcpe_runtime.make_error(.Unexpected_EOF, "wire.unmarshal_open_connection_reply_1")
            return
        }
        pk.cookie = wire.load_u32_be(data[offset:offset + 4])
        offset += 4
    }
    if len(data) < offset + 2 {
        err = mcpe_runtime.make_error(.Unexpected_EOF, "wire.unmarshal_open_connection_reply_1")
        return
    }
    pk.mtu = wire.load_u16_be(data[offset:offset + 2])
    return
}

Open_Connection_Request_2 :: struct {
    server_address:      Address,
    mtu:                 u16,
    client_guid:         i64,
    server_has_security: bool,
    cookie:              u32,
}

marshal_open_connection_request_2 :: proc(pk: Open_Connection_Request_2) -> wire.Writer {
    extra := 5 if pk.server_has_security else 0
    w := wire.writer(27 + address_size(pk.server_address) + extra)
    wire.write_u8(&w, ID_OPEN_CONNECTION_REQUEST_2)
    wire.write_bytes(&w, UNCONNECTED_MAGIC[:])
    if pk.server_has_security {
        wire.write_u32_be(&w, pk.cookie)
        wire.write_u8(&w, 0)
    }
    write_address(&w, pk.server_address)
    wire.write_u16_be(&w, pk.mtu)
    wire.write_u64_be(&w, u64(pk.client_guid))
    return w
}

unmarshal_open_connection_request_2 :: proc(
    data: []u8,
    server_has_security: bool,
) -> (pk: Open_Connection_Request_2, err: mcpe_runtime.Error) {
    r := wire.reader(data)
    pk.server_has_security = server_has_security
    if server_has_security {
        pk.cookie = wire.read_u32_be(&r) or_return
        _ = wire.read_u8(&r) or_return
    }
    pk.server_address = read_address(&r) or_return
    pk.mtu = wire.read_u16_be(&r) or_return
    pk.client_guid = i64(wire.read_u64_be(&r) or_return)
    return
}

Open_Connection_Reply_2 :: struct {
    server_guid:    i64,
    client_address: Address,
    mtu:            u16,
    do_security:    bool,
}

marshal_open_connection_reply_2 :: proc(pk: Open_Connection_Reply_2) -> wire.Writer {
    w := wire.writer(28 + address_size(pk.client_address))
    wire.write_u8(&w, ID_OPEN_CONNECTION_REPLY_2)
    wire.write_bytes(&w, UNCONNECTED_MAGIC[:])
    wire.write_u64_be(&w, u64(pk.server_guid))
    write_address(&w, pk.client_address)
    wire.write_u16_be(&w, pk.mtu)
    wire.write_u8(&w, 1 if pk.do_security else 0)
    return w
}

unmarshal_open_connection_reply_2 :: proc(data: []u8) -> (
    pk: Open_Connection_Reply_2,
    err: mcpe_runtime.Error,
) {
    if len(data) < 24 {
        err = mcpe_runtime.make_error(.Unexpected_EOF, "wire.unmarshal_open_connection_reply_2")
        return
    }
    pk.server_guid = i64(wire.load_u64_be(data[16:24]))
    r := wire.reader(data[24:])
    pk.client_address = read_address(&r) or_return
    pk.mtu = wire.read_u16_be(&r) or_return
    secure := wire.read_u8(&r) or_return
    pk.do_security = secure != 0
    return
}

