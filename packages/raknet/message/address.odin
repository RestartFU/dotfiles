package raknet_message

import wire "mcpe:raknet/wire"
import mcpe_runtime "mcpe:runtime"

Address_Family :: enum u8 {
    IPv4 = 4,
    IPv6 = 6,
}

Address :: struct {
    family:   Address_Family,
    address:  [16]u8,
    port:     u16,
    scope_id: u32,
}

System_Addresses :: [20]Address

ADDRESS_V4_SIZE :: 1 + 4 + 2
ADDRESS_V6_SIZE :: 1 + 2 + 2 + 4 + 16 + 4

address_v4 :: proc(a, b, c, d: u8, port: u16) -> Address {
    result: Address
    result.family = .IPv4
    result.address[0] = a
    result.address[1] = b
    result.address[2] = c
    result.address[3] = d
    result.port = port
    return result
}

address_v6 :: proc(bytes: [16]u8, port: u16, scope_id: u32 = 0) -> Address {
    return Address{
        family = .IPv6,
        address = bytes,
        port = port,
        scope_id = scope_id,
    }
}

address_size :: proc(address: Address) -> int {
    if address.family == .IPv6 {
        return ADDRESS_V6_SIZE
    }
    return ADDRESS_V4_SIZE
}

system_addresses_size :: proc(addresses: System_Addresses) -> (size: int) {
    for address in addresses {
        size += address_size(address)
    }
    return
}

write_address :: proc(w: ^wire.Writer, address: Address) {
    if address.family == .IPv6 {
        wire.write_u8(w, 6)
        // RakNet writes Windows AF_INET6 (23), little endian.
        wire.write_u8(w, 23)
        wire.write_u8(w, 0)
        wire.write_u16_be(w, address.port)
        wire.write_u32_be(w, 0)
        for value in address.address {
            wire.write_u8(w, value)
        }
        wire.write_u32_be(w, address.scope_id)
        return
    }

    wire.write_u8(w, 4)
    wire.write_u8(w, ~address.address[0])
    wire.write_u8(w, ~address.address[1])
    wire.write_u8(w, ~address.address[2])
    wire.write_u8(w, ~address.address[3])
    wire.write_u16_be(w, address.port)
}

read_address :: proc(r: ^wire.Reader) -> (address: Address, err: mcpe_runtime.Error) {
    family := wire.read_u8(r) or_return
    if family == 4 || family == 0 {
        bytes := wire.read_bytes(r, 4) or_return
        address.family = .IPv4
        for value, index in bytes {
            address.address[index] = ~value
        }
        address.port = wire.read_u16_be(r) or_return
        return
    }
    if family != 6 {
        err = mcpe_runtime.make_error(.Malformed, "wire.read_address", "unknown address family")
        return
    }

    _ = wire.read_bytes(r, 2) or_return // AF_INET6.
    address.family = .IPv6
    address.port = wire.read_u16_be(r) or_return
    _ = wire.read_bytes(r, 4) or_return // Flow info.
    bytes := wire.read_bytes(r, 16) or_return
    copy(address.address[:], bytes)
    address.scope_id = wire.read_u32_be(r) or_return
    return
}
