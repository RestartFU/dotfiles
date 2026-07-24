package raknet_message

import wire "mcpe:raknet/wire"
import mcpe_runtime "mcpe:runtime"

Connection_Request_Accepted :: struct {
    client_address:   Address,
    system_index:     u16,
    system_addresses: System_Addresses,
    ping_time:        i64,
    pong_time:        i64,
}

marshal_connection_request_accepted :: proc(pk: Connection_Request_Accepted) -> wire.Writer {
    capacity := 1 + address_size(pk.client_address) + 2 +
                system_addresses_size(pk.system_addresses) + 16
    w := wire.writer(capacity)
    wire.write_u8(&w, ID_CONNECTION_REQUEST_ACCEPTED)
    write_address(&w, pk.client_address)
    wire.write_u16_be(&w, pk.system_index)
    for address in pk.system_addresses {
        write_address(&w, address)
    }
    wire.write_u64_be(&w, u64(pk.ping_time))
    wire.write_u64_be(&w, u64(pk.pong_time))
    return w
}

unmarshal_connection_request_accepted :: proc(data: []u8) -> (
    pk: Connection_Request_Accepted,
    err: mcpe_runtime.Error,
) {
    r := wire.reader(data)
    pk.client_address = read_address(&r) or_return
    pk.system_index = wire.read_u16_be(&r) or_return
    for index in 0..<len(pk.system_addresses) {
        if wire.remaining(&r) == 16 {
            break
        }
        pk.system_addresses[index] = read_address(&r) or_return
    }
    pk.ping_time = i64(wire.read_u64_be(&r) or_return)
    pk.pong_time = i64(wire.read_u64_be(&r) or_return)
    return
}

New_Incoming_Connection :: struct {
    server_address:   Address,
    system_addresses: System_Addresses,
    ping_time:        i64,
    pong_time:        i64,
}

marshal_new_incoming_connection :: proc(pk: New_Incoming_Connection) -> wire.Writer {
    capacity := 1 + address_size(pk.server_address) +
                system_addresses_size(pk.system_addresses) + 16
    w := wire.writer(capacity)
    wire.write_u8(&w, ID_NEW_INCOMING_CONNECTION)
    write_address(&w, pk.server_address)
    for address in pk.system_addresses {
        write_address(&w, address)
    }
    wire.write_u64_be(&w, u64(pk.ping_time))
    wire.write_u64_be(&w, u64(pk.pong_time))
    return w
}

unmarshal_new_incoming_connection :: proc(data: []u8) -> (
    pk: New_Incoming_Connection,
    err: mcpe_runtime.Error,
) {
    r := wire.reader(data)
    pk.server_address = read_address(&r) or_return
    for index in 0..<len(pk.system_addresses) {
        if wire.remaining(&r) == 16 {
            break
        }
        pk.system_addresses[index] = read_address(&r) or_return
    }
    pk.ping_time = i64(wire.read_u64_be(&r) or_return)
    pk.pong_time = i64(wire.read_u64_be(&r) or_return)
    return
}

Incompatible_Protocol_Version :: struct {
    server_protocol: u8,
    server_guid:     i64,
}

marshal_incompatible_protocol_version :: proc(pk: Incompatible_Protocol_Version) -> [26]u8 {
    result: [26]u8
    result[0] = ID_INCOMPATIBLE_PROTOCOL_VERSION
    result[1] = pk.server_protocol
    copy(result[2:18], UNCONNECTED_MAGIC[:])
    wire.store_u64_be(result[18:26], u64(pk.server_guid))
    return result
}

unmarshal_incompatible_protocol_version :: proc(data: []u8) -> (
    pk: Incompatible_Protocol_Version,
    err: mcpe_runtime.Error,
) {
    if len(data) < 25 {
        err = mcpe_runtime.make_error(.Unexpected_EOF, "wire.unmarshal_incompatible_protocol_version")
        return
    }
    pk.server_protocol = data[0]
    pk.server_guid = i64(wire.load_u64_be(data[17:25]))
    return
}

