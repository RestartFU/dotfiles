package raknet

import "core:crypto"
import "core:hash"
import "core:net"
import "core:sync"
import channel "core:sync/chan"
import "core:thread"
import "core:time"
import message "mcpe:raknet/message"
import mcpe_runtime "mcpe:runtime"

Pong_Data_Proc :: proc "odin" (
    user_data: rawptr,
    remote: net.Endpoint,
) -> []u8

Listen_Config :: struct {
    disable_cookies: bool,
    max_mtu:         u16,
    block_duration:  time.Duration,
    pong_data:       []u8,
    pong_data_proc:  Pong_Data_Proc,
    pong_user_data:  rawptr,
}

Listener :: struct {
    config:      Listen_Config,
    socket:      net.UDP_Socket,
    endpoint:    net.Endpoint,
    id:          i64,
    cookie_salt: u64,
    previous_salt: u64,
    closed:      bool,
    mutex:       sync.Mutex,
    incoming:    channel.Chan(^Conn),
    connections: map[net.Endpoint]^Conn,
    blocks:      map[[16]u8]i64,
    worker:      ^thread.Thread,
    pong_data:   []u8,
}

random_u64 :: proc() -> u64 {
    bytes: [8]u8
    crypto.rand_bytes(bytes[:])
    return load_u64_be(bytes[:])
}

listener_cookie :: proc(listener: ^Listener, remote: net.Endpoint, salt: u64) -> u32 {
    if listener.config.disable_cookies {
        return 0
    }
    data: [26]u8
    store_u16_le(data[8:10], u16(remote.port))
    for index in 0..<8 {
        data[index] = u8(salt >> (index * 8))
    }
    address: [16]u8
    bytes := endpoint_ip_bytes(remote, &address)
    copy(data[10:], bytes)
    return hash.crc32(data[:10 + len(bytes)])
}

listener_ip_key :: proc(remote: net.Endpoint) -> [16]u8 {
    key: [16]u8
    _ = endpoint_ip_bytes(remote, &key)
    return key
}

listener_blocked :: proc(listener: ^Listener, remote: net.Endpoint) -> bool {
    key := listener_ip_key(remote)
    expires, exists := listener.blocks[key]
    if !exists {
        return false
    }
    now := mcpe_runtime.system_now_ns(nil)
    if now >= expires {
        delete_key(&listener.blocks, key)
        return false
    }
    return true
}

block_for :: proc(listener: ^Listener, remote: net.Endpoint, duration: time.Duration) {
    if duration <= 0 {
        return
    }
    if sync.mutex_guard(&listener.mutex) {
        listener.blocks[listener_ip_key(remote)] =
            mcpe_runtime.system_now_ns(nil) + i64(duration)
    }
}

block :: proc(listener: ^Listener, remote: net.Endpoint) {
    block_for(listener, remote, listener.config.block_duration)
}

listener_on_connected :: proc "odin" (user_data: rawptr, conn: ^Conn) {
    listener := (^Listener)(user_data)
    if !channel.send(listener.incoming, conn) {
        close(conn)
    }
}

listener_on_conn_closed :: proc "odin" (user_data: rawptr, conn: ^Conn) {
    listener := (^Listener)(user_data)
    if sync.mutex_guard(&listener.mutex) {
        delete_key(&listener.connections, conn.remote)
    }
}

listen_config :: proc(config: Listen_Config, address: string) -> (
    listener: ^Listener,
    err: mcpe_runtime.Error,
) {
    endpoint := listen_endpoint(address) or_return
    socket, socket_err := net.make_bound_udp_socket(endpoint.address, endpoint.port)
    if socket_err != nil {
        err = network_error("raknet.listen")
        return
    }
    bound, bound_err := net.bound_endpoint(socket)
    if bound_err != nil {
        net.close(socket)
        err = network_error("raknet.listen.bound_endpoint")
        return
    }

    listener = new(Listener)
    listener.config = config
    if listener.config.block_duration == 0 {
        listener.config.block_duration = 10 * time.Second
    }
    listener.config.max_mtu = clamp_mtu(listener.config.max_mtu, MIN_MTU_SIZE)
    listener.socket = socket
    listener.endpoint = bound
    listener.id = i64(random_u64())
    listener.cookie_salt = random_u64()
    listener.previous_salt = random_u64()
    listener.connections = make(map[net.Endpoint]^Conn)
    listener.blocks = make(map[[16]u8]i64)
    listener.pong_data = make([]u8, len(config.pong_data))
    copy(listener.pong_data, config.pong_data)

    incoming, incoming_err := channel.create(channel.Chan(^Conn), 64, context.allocator)
    if incoming_err != .None {
        net.close(socket)
        delete(listener.connections)
        delete(listener.blocks)
        delete(listener.pong_data)
        free(listener)
        listener = nil
        err = mcpe_runtime.make_error(.Internal, "raknet.listen", "create incoming channel")
        return
    }
    listener.incoming = incoming
    listener.worker = thread.create(listener_thread)
    listener.worker.data = listener
    thread.start(listener.worker)
    return
}

listen :: proc(address: string) -> (listener: ^Listener, err: mcpe_runtime.Error) {
    return listen_config({}, address)
}

accept :: proc(listener: ^Listener) -> (conn: ^Conn, err: mcpe_runtime.Error) {
    if listener == nil {
        err = mcpe_runtime.make_error(.Invalid_Argument, "raknet.accept", "nil listener")
        return
    }
    conn, ok := channel.recv(listener.incoming)
    if !ok {
        err = mcpe_runtime.make_error(.Closed, "raknet.accept")
    }
    return
}

listener_address :: proc(listener: ^Listener) -> net.Endpoint {
    return listener.endpoint
}

listener_id :: proc(listener: ^Listener) -> i64 {
    return listener.id
}

set_pong_data :: proc(listener: ^Listener, data: []u8) -> mcpe_runtime.Error {
    if len(data) > max(i16) {
        return mcpe_runtime.make_error(.Limit_Exceeded, "raknet.set_pong_data", "pong data exceeds int16")
    }
    owned := make([]u8, len(data))
    copy(owned, data)
    if sync.mutex_guard(&listener.mutex) {
        delete(listener.pong_data)
        listener.pong_data = owned
    }
    return nil
}

close_listener :: proc(listener: ^Listener) -> mcpe_runtime.Error {
    if listener == nil {
        return nil
    }
    first := false
    if sync.mutex_guard(&listener.mutex) {
        if !listener.closed {
            listener.closed = true
            first = true
        }
    }
    if first {
        net.close(listener.socket)
        channel.close(listener.incoming)
    }
    return nil
}

destroy_listener :: proc(listener: ^Listener) {
    if listener == nil {
        return
    }
    close_listener(listener)
    thread.join(listener.worker)
    thread.destroy(listener.worker)
    for _, conn in listener.connections {
        close(conn)
    }
    delete(listener.connections)
    delete(listener.blocks)
    delete(listener.pong_data)
    channel.destroy(listener.incoming)
    free(listener)
}

listener_send :: proc(listener: ^Listener, data: []u8, remote: net.Endpoint) -> mcpe_runtime.Error {
    if _, send_err := net.send_udp(listener.socket, data, remote); send_err != nil {
        return network_error("raknet.listener.send")
    }
    return nil
}

listener_handle_unconnected :: proc(
    listener: ^Listener,
    data: []u8,
    remote: net.Endpoint,
) -> mcpe_runtime.Error {
    if len(data) == 0 {
        return mcpe_runtime.make_error(.Malformed, "raknet.listener", "zero packet")
    }
    switch data[0] {
    case message.ID_UNCONNECTED_PING, message.ID_UNCONNECTED_PING_OPEN_CONNECTIONS:
        ping := message.unmarshal_unconnected_ping(data[1:]) or_return
        pong_data := listener.pong_data
        if listener.config.pong_data_proc != nil {
            pong_data = listener.config.pong_data_proc(listener.config.pong_user_data, remote)
        }
        if len(pong_data) > max(i16) {
            return mcpe_runtime.make_error(.Limit_Exceeded, "raknet.listener.pong", "pong data exceeds int16")
        }
        pong := message.marshal_unconnected_pong({
            ping_time = ping.ping_time,
            server_guid = listener.id,
            data = pong_data,
        })
        defer writer_destroy(&pong)
        return listener_send(listener, pong.data[:], remote)

    case message.ID_OPEN_CONNECTION_REQUEST_1:
        request := message.unmarshal_open_connection_request_1(data[1:]) or_return
        mtu := min(request.mtu, listener.config.max_mtu)
        if request.client_protocol != PROTOCOL_VERSION {
            response := message.marshal_incompatible_protocol_version({
                server_protocol = PROTOCOL_VERSION,
                server_guid = listener.id,
            })
            listener_send(listener, response[:], remote) or_return
            return mcpe_runtime.make_error(.Protocol, "raknet.listener.request_1", "incompatible protocol")
        }
        response := message.marshal_open_connection_reply_1({
            server_guid = listener.id,
            server_has_security = !listener.config.disable_cookies,
            cookie = listener_cookie(listener, remote, listener.cookie_salt),
            mtu = mtu,
        })
        defer writer_destroy(&response)
        return listener_send(listener, response.data[:], remote)

    case message.ID_OPEN_CONNECTION_REQUEST_2:
        request := message.unmarshal_open_connection_request_2(
            data[1:],
            !listener.config.disable_cookies,
        ) or_return
        if !listener.config.disable_cookies {
            current := listener_cookie(listener, remote, listener.cookie_salt)
            previous := listener_cookie(listener, remote, listener.previous_salt)
            if request.cookie != current && request.cookie != previous {
                return mcpe_runtime.make_error(.Protocol, "raknet.listener.request_2", "invalid cookie")
            }
        }
        if request.client_guid >= 0 {
            return mcpe_runtime.make_error(.Protocol, "raknet.listener.request_2", "client GUID must be negative")
        }
        mtu := min(request.mtu, listener.config.max_mtu)
        response := message.marshal_open_connection_reply_2({
            server_guid = listener.id,
            client_address = message_address_from_endpoint(remote),
            mtu = mtu,
        })
        send_err := listener_send(listener, response.data[:], remote)
        writer_destroy(&response)
        if send_err != nil {
            return send_err
        }

        if sync.mutex_guard(&listener.mutex) {
            if _, exists := listener.connections[remote]; exists {
                return nil
            }
            conn := conn_create(listener.socket, remote, mtu, .Server, false) or_return
            conn.callback_data = listener
            conn.on_connected = listener_on_connected
            conn.on_closed = listener_on_conn_closed
            listener.connections[remote] = conn
            conn_start_threads(conn, false)
        }
        return nil
    }
    if data[0] & BIT_FLAG_DATAGRAM != 0 {
        return nil
    }
    return mcpe_runtime.make_error(.Protocol, "raknet.listener", "unknown unconnected packet")
}

listener_thread :: proc(worker: ^thread.Thread) {
    listener := (^Listener)(worker.data)
    buffer: [1500]u8
    for !sync.atomic_load(&listener.closed) {
        count, remote, receive_err := net.recv_udp(listener.socket, buffer[:])
        if receive_err != nil {
            if sync.atomic_load(&listener.closed) {
                break
            }
            continue
        }
        if count == 0 {
            continue
        }
        if sync.mutex_guard(&listener.mutex) {
            if listener_blocked(listener, remote) {
                continue
            }
            if conn, exists := listener.connections[remote]; exists {
                receive_error := conn_receive(conn, buffer[:count])
                if receive_error != nil {
                    mcpe_runtime.destroy_error(receive_error)
                    close(conn)
                }
                continue
            }
        }
        if handle_err := listener_handle_unconnected(listener, buffer[:count], remote); handle_err != nil {
            mcpe_runtime.destroy_error(handle_err)
            block(listener, remote)
        }
    }
}

