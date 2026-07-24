package raknet

import "core:net"
import channel "core:sync/chan"
import "core:time"
import message "mcpe:raknet/message"
import mcpe_runtime "mcpe:runtime"

Dialer :: struct {
    max_transient_errors: int,
    max_mtu:              u16,
}

MIN_SUPPORTED_MTU :: u16(576)

dialer_receive :: proc(socket: net.UDP_Socket, buffer: []u8) -> (
    count: int,
    remote: net.Endpoint,
    err: mcpe_runtime.Error,
) {
    count, remote, receive_err := net.recv_udp(socket, buffer)
    if receive_err != nil {
        kind := mcpe_runtime.Error_Kind.Network
        if receive_err == .Timeout {
            kind = .Timeout
        }
        err = network_error("raknet.dial.receive", kind)
    }
    return
}

dialer_discover_mtu :: proc(
    dialer: Dialer,
    socket: net.UDP_Socket,
    remote: net.Endpoint,
) -> (
    mtu: u16,
    server_security: bool,
    cookie: u32,
    err: mcpe_runtime.Error,
) {
    maximum := clamp_mtu(dialer.max_mtu, MIN_SUPPORTED_MTU)
    sizes: [3]u16
    size_count := 0
    sizes[size_count] = maximum
    size_count += 1
    if 1200 < maximum {
        sizes[size_count] = 1200
        size_count += 1
    }
    if MIN_SUPPORTED_MTU < maximum {
        sizes[size_count] = MIN_SUPPORTED_MTU
        size_count += 1
    }

    buffer: [MAX_MTU_SIZE]u8
    for size in sizes[:size_count] {
        for _ in 0..<4 {
            request := message.marshal_open_connection_request_1({
                client_protocol = PROTOCOL_VERSION,
                mtu = size,
            })
            if request.err != nil {
                return 0, false, 0, request.err
            }
            if _, send_err := net.send_udp(socket, request.w.data[:], remote); send_err != nil {
                writer_destroy(&request.w)
                continue
            }
            writer_destroy(&request.w)

            count, _, receive_err := dialer_receive(socket, buffer[:])
            if receive_err != nil {
                mcpe_runtime.destroy_error(receive_err)
                continue
            }
            if count == 0 {
                continue
            }
            switch buffer[0] {
            case message.ID_OPEN_CONNECTION_REPLY_1:
                reply := message.unmarshal_open_connection_reply_1(buffer[1:count]) or_return
                if reply.server_guid == 0 ||
                   reply.mtu < MIN_MTU_SIZE ||
                   reply.mtu > 1500 {
                    continue
                }
                return reply.mtu, reply.server_has_security, reply.cookie, nil
            case message.ID_INCOMPATIBLE_PROTOCOL_VERSION:
                reply := message.unmarshal_incompatible_protocol_version(buffer[1:count]) or_return
                _ = reply
                err = mcpe_runtime.make_error(.Protocol, "raknet.dial", "incompatible RakNet protocol")
                return
            }
        }
    }
    err = mcpe_runtime.make_error(.Timeout, "raknet.dial", "MTU discovery timed out")
    return
}

dialer_open_connection :: proc(
    socket: net.UDP_Socket,
    remote: net.Endpoint,
    client_id: i64,
    mtu: u16,
    server_security: bool,
    cookie: u32,
) -> (negotiated_mtu: u16, err: mcpe_runtime.Error) {
    buffer: [MAX_MTU_SIZE]u8
    for _ in 0..<20 {
        request := message.marshal_open_connection_request_2({
            server_address = message_address_from_endpoint(remote),
            mtu = mtu,
            client_guid = client_id,
            server_has_security = server_security,
            cookie = cookie,
        })
        if _, send_err := net.send_udp(socket, request.data[:], remote); send_err != nil {
            writer_destroy(&request)
            continue
        }
        writer_destroy(&request)

        count, _, receive_err := dialer_receive(socket, buffer[:])
        if receive_err != nil {
            mcpe_runtime.destroy_error(receive_err)
            continue
        }
        if count == 0 || buffer[0] != message.ID_OPEN_CONNECTION_REPLY_2 {
            continue
        }
        reply := message.unmarshal_open_connection_reply_2(buffer[1:count]) or_return
        return reply.mtu, nil
    }
    err = mcpe_runtime.make_error(.Timeout, "raknet.dial", "open connection timed out")
    return
}

dial_config :: proc(
    dialer: Dialer,
    address: string,
    timeout: time.Duration = 10 * time.Second,
) -> (conn: ^Conn, err: mcpe_runtime.Error) {
    if timeout <= 0 {
        err = mcpe_runtime.make_error(.Invalid_Argument, "raknet.dial", "timeout must be positive")
        return
    }
    remote := resolve_endpoint(address) or_return
    socket, socket_err := net.make_unbound_udp_socket(net.family_from_address(remote.address))
    if socket_err != nil {
        err = network_error("raknet.dial.socket")
        return
    }
    keep_socket := false
    defer if !keep_socket {
        net.close(socket)
    }
    if option_err := net.set_option(socket, .Receive_Timeout, 500 * time.Millisecond); option_err != nil {
        err = network_error("raknet.dial.deadline")
        return
    }

    client_id := next_dialer_id()
    mtu, security, cookie := dialer_discover_mtu(dialer, socket, remote) or_return
    mtu = dialer_open_connection(socket, remote, client_id, mtu, security, cookie) or_return
    conn = conn_create(socket, remote, mtu, .Client, true) or_return

    request := message.marshal_connection_request({
        client_guid = client_id,
        request_time = timestamp(),
    })
    if send_err := conn_send_control(conn, request[:]); send_err != nil {
        conn_destroy(conn)
        conn = nil
        err = send_err
        return
    }

    buffer: [1500]u8
    connected := false
    for !connected {
        count, packet_remote, receive_err := dialer_receive(socket, buffer[:])
        if receive_err != nil {
            conn_destroy(conn)
            conn = nil
            err = receive_err
            return
        }
        if packet_remote != remote {
            continue
        }
        if process_err := conn_receive(conn, buffer[:count]); process_err != nil {
            conn_destroy(conn)
            conn = nil
            err = process_err
            return
        }
        _, connected = channel.try_recv(conn.connected_event)
    }

    _ = net.set_option(socket, .Receive_Timeout, time.Duration(0))
    conn_start_threads(conn, true)
    keep_socket = true
    return
}

dial :: proc(address: string) -> (conn: ^Conn, err: mcpe_runtime.Error) {
    return dial_config({}, address)
}

dial_timeout :: proc(address: string, timeout: time.Duration) -> (
    conn: ^Conn,
    err: mcpe_runtime.Error,
) {
    return dial_config({}, address, timeout)
}

dial_context :: proc(
    token: ^mcpe_runtime.Cancel_Token,
    address: string,
    timeout: time.Duration = 10 * time.Second,
) -> (conn: ^Conn, err: mcpe_runtime.Error) {
    if mcpe_runtime.is_cancelled(token) {
        return nil, mcpe_runtime.make_error(.Cancelled, "raknet.dial")
    }
    conn, err = dial_config({}, address, timeout)
    if err == nil && mcpe_runtime.is_cancelled(token) {
        conn_destroy(conn)
        conn = nil
        err = mcpe_runtime.make_error(.Cancelled, "raknet.dial")
    }
    return
}

