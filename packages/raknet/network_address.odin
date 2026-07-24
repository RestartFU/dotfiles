package raknet

import "core:net"
import message "mcpe:raknet/message"
import mcpe_runtime "mcpe:runtime"

message_address_from_endpoint :: proc(endpoint: net.Endpoint) -> message.Address {
    switch address in endpoint.address {
    case net.IP4_Address:
        return message.address_v4(
            address[0],
            address[1],
            address[2],
            address[3],
            u16(endpoint.port),
        )
    case net.IP6_Address:
        bytes: [16]u8
        for part, index in address {
            raw := u16(part)
            bytes[index * 2] = u8(raw >> 8)
            bytes[index * 2 + 1] = u8(raw)
        }
        return message.address_v6(bytes, u16(endpoint.port))
    }
    return {}
}

listen_endpoint :: proc(address: string) -> (endpoint: net.Endpoint, err: mcpe_runtime.Error) {
    host, port, ok := net.split_port(address)
    if !ok {
        err = mcpe_runtime.make_error(.Address, "raknet.listen", "invalid address or port")
        return
    }
    if host == "" {
        return net.Endpoint{address = net.IP4_Any, port = port}, nil
    }
    parsed := net.parse_address(host)
    if parsed == nil {
        err = mcpe_runtime.make_error(.Address, "raknet.listen", "listen address must be an IP address")
        return
    }
    return net.Endpoint{address = parsed, port = port}, nil
}

endpoint_ip_bytes :: proc(endpoint: net.Endpoint, output: ^[16]u8) -> []u8 {
    switch address in endpoint.address {
    case net.IP4_Address:
        copy(output[:4], address[:])
        return output[:4]
    case net.IP6_Address:
        for part, index in address {
            raw := u16(part)
            output[index * 2] = u8(raw >> 8)
            output[index * 2 + 1] = u8(raw)
        }
        return output[:]
    }
    return nil
}

