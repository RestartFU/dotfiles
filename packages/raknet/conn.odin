package raknet

import "core:net"
import "core:sync"
import channel "core:sync/chan"
import "core:thread"
import "core:time"
import message "mcpe:raknet/message"
import mcpe_runtime "mcpe:runtime"

Connection_Mode :: enum {
    Client,
    Server,
}

Connection_Callback :: proc "odin" (user_data: rawptr, conn: ^Conn)

Conn :: struct {
    socket:      net.UDP_Socket,
    remote:      net.Endpoint,
    local:       net.Endpoint,
    owns_socket: bool,
    mode:        Connection_Mode,
    mtu:         u16,

    mutex:          sync.Mutex,
    closed:         bool,
    connected:      bool,
    limits_enabled: bool,
    closing_at_ns:  i64,
    last_activity:  i64,
    rtt_ns:         i64,

    sequence:      UInt24,
    order_index:   UInt24,
    message_index: UInt24,
    split_id:      u32,

    window:          Datagram_Window,
    ordered:         Packet_Queue,
    splits:          Split_Assembler,
    resend:          Resend_Map,
    incoming:        channel.Chan([]u8),
    connected_event: channel.Chan(bool),

    receive_thread: ^thread.Thread,
    tick_thread:    ^thread.Thread,

    callback_data:         rawptr,
    on_connected:          Connection_Callback,
    on_closed:             Connection_Callback,
}

clamp_mtu :: proc(mtu, minimum: u16) -> u16 {
    if mtu == 0 || mtu > MAX_MTU_SIZE {
        return MAX_MTU_SIZE
    }
    return max(mtu, minimum)
}

effective_mtu :: proc(conn: ^Conn) -> u16 {
    return conn.mtu - 28
}

conn_create :: proc(
    socket: net.UDP_Socket,
    remote: net.Endpoint,
    mtu: u16,
    mode: Connection_Mode,
    owns_socket: bool,
) -> (conn: ^Conn, err: mcpe_runtime.Error) {
    conn = new(Conn)
    conn.socket = socket
    conn.remote = remote
    conn.owns_socket = owns_socket
    conn.mode = mode
    conn.mtu = clamp_mtu(mtu, MIN_MTU_SIZE)
    conn.limits_enabled = mode == .Server
    conn.window = datagram_window_init()
    conn.ordered = packet_queue_init()
    conn.splits = split_assembler_init()
    conn.resend = resend_map_init()
    conn.last_activity = mcpe_runtime.system_now_ns(nil)

    incoming, incoming_err := channel.create(channel.Chan([]u8), 4096, context.allocator)
    if incoming_err != .None {
        err = mcpe_runtime.make_error(.Internal, "raknet.conn_create", "create incoming channel")
        free(conn)
        conn = nil
        return
    }
    conn.incoming = incoming
    connected_event, connected_err := channel.create(channel.Chan(bool), 1, context.allocator)
    if connected_err != .None {
        channel.destroy(conn.incoming)
        err = mcpe_runtime.make_error(.Internal, "raknet.conn_create", "create connected channel")
        free(conn)
        conn = nil
        return
    }
    conn.connected_event = connected_event
    conn.local, _ = net.bound_endpoint(socket)
    return
}

conn_start_threads :: proc(conn: ^Conn, start_receiver: bool) {
    if start_receiver && conn.receive_thread == nil {
        conn.receive_thread = thread.create(conn_receive_thread)
        conn.receive_thread.data = conn
        thread.start(conn.receive_thread)
    }
    if conn.tick_thread == nil {
        conn.tick_thread = thread.create(conn_tick_thread)
        conn.tick_thread.data = conn
        thread.start(conn.tick_thread)
    }
}

conn_free_packet :: proc(packet: ^Packet) {
    if packet == nil {
        return
    }
    delete(packet.content)
    free(packet)
}

conn_destroy :: proc(conn: ^Conn) {
    if conn == nil {
        return
    }
    close(conn)
    if conn.receive_thread != nil {
        thread.join(conn.receive_thread)
        thread.destroy(conn.receive_thread)
    }
    if conn.tick_thread != nil {
        thread.join(conn.tick_thread)
        thread.destroy(conn.tick_thread)
    }

    for _, packet in conn.resend.unacknowledged {
        conn_free_packet(packet.packet)
    }
    for _, content in conn.ordered.entries {
        delete(content)
    }
    for {
        content, ok := channel.try_recv(conn.incoming)
        if !ok {
            break
        }
        delete(content)
    }
    datagram_window_destroy(&conn.window)
    packet_queue_destroy(&conn.ordered)
    split_assembler_destroy(&conn.splits)
    resend_map_destroy(&conn.resend)
    channel.destroy(conn.incoming)
    channel.destroy(conn.connected_event)
    free(conn)
}

conn_mark_connected :: proc(conn: ^Conn) {
    if sync.mutex_guard(&conn.mutex) {
        if conn.connected {
            return
        }
        conn.connected = true
    }
    channel.try_send(conn.connected_event, true)
    if conn.on_connected != nil {
        conn.on_connected(conn.callback_data, conn)
    }
}

conn_send_datagram_locked :: proc(conn: ^Conn, packet: ^Packet) -> mcpe_runtime.Error {
    w := writer(int(conn.mtu))
    defer writer_destroy(&w)
    write_u8(&w, BIT_FLAG_DATAGRAM | BIT_FLAG_NEEDS_B_AND_AS)
    sequence := uint24_inc(&conn.sequence)
    write_u24_le(&w, sequence)
    write_packet(&w, packet)

    if reliability_is_reliable(packet.reliability) {
        resend_map_add(&conn.resend, sequence, packet, mcpe_runtime.system_now_ns(nil))
    }
    if _, send_err := net.send_udp(conn.socket, w.data[:], conn.remote); send_err != nil {
        return network_error("raknet.write")
    }
    if !reliability_is_reliable(packet.reliability) {
        conn_free_packet(packet)
    }
    return nil
}

conn_write_reliability :: proc(
    conn: ^Conn,
    data: []u8,
    reliability: Reliability,
) -> (written: int, err: mcpe_runtime.Error) {
    if conn == nil {
        err = mcpe_runtime.make_error(.Invalid_Argument, "raknet.write", "nil connection")
        return
    }
    if sync.mutex_guard(&conn.mutex) {
        if conn.closed {
            err = mcpe_runtime.make_error(.Closed, "raknet.write")
            return
        }

        fragments := split_content(data, effective_mtu(conn)) or_return
        defer delete(fragments)
        order_index: UInt24
        if reliability_is_sequenced_or_ordered(reliability) {
            order_index = uint24_inc(&conn.order_index)
        }
        split_id := u16(conn.split_id)
        if len(fragments) > 1 {
            conn.split_id += 1
        }

        for fragment, split_index in fragments {
            packet := new(Packet)
            packet.reliability = reliability
            packet.order_index = order_index
            packet.content = make([]u8, len(fragment))
            copy(packet.content, fragment)
            if reliability_is_reliable(reliability) {
                packet.message_index = uint24_inc(&conn.message_index)
            }
            packet.split = len(fragments) > 1
            if packet.split {
                packet.split_count = u32(len(fragments))
                packet.split_index = u32(split_index)
                packet.split_id = split_id
            }
            if send_error := conn_send_datagram_locked(conn, packet); send_error != nil {
                if _, stored := conn.resend.unacknowledged[UInt24(u32(conn.sequence) - 1)]; !stored {
                    conn_free_packet(packet)
                }
                err = send_error
                return
            }
            written += len(fragment)
        }
    }
    return
}

write :: proc(conn: ^Conn, data: []u8) -> (written: int, err: mcpe_runtime.Error) {
    return conn_write_reliability(conn, data, .Reliable_Ordered)
}

conn_send_control :: proc(conn: ^Conn, data: []u8) -> mcpe_runtime.Error {
    _, err := write(conn, data)
    return err
}

read_packet_owned :: proc(conn: ^Conn) -> (data: []u8, err: mcpe_runtime.Error) {
    if conn == nil {
        err = mcpe_runtime.make_error(.Invalid_Argument, "raknet.read", "nil connection")
        return
    }
    data, ok := channel.recv(conn.incoming)
    if !ok {
        err = mcpe_runtime.make_error(.Closed, "raknet.read")
    }
    return
}

read :: proc(conn: ^Conn, output: []u8) -> (read_count: int, err: mcpe_runtime.Error) {
    data := read_packet_owned(conn) or_return
    defer delete(data)
    if len(output) < len(data) {
        err = mcpe_runtime.make_error(.Limit_Exceeded, "raknet.read", "buffer too small")
        return
    }
    read_count = copy(output, data)
    return
}

remote_address :: proc(conn: ^Conn) -> net.Endpoint {
    return conn.remote
}

local_address :: proc(conn: ^Conn) -> net.Endpoint {
    return conn.local
}

latency :: proc(conn: ^Conn) -> time.Duration {
    return time.Duration(sync.atomic_load(&conn.rtt_ns) / 2)
}

close :: proc(conn: ^Conn) -> mcpe_runtime.Error {
    if conn == nil {
        return nil
    }
    first_close := false
    if sync.mutex_guard(&conn.mutex) {
        if !conn.closed {
            conn.closed = true
            first_close = true
        }
    }
    if !first_close {
        return nil
    }

    channel.close(conn.incoming)
    channel.close(conn.connected_event)
    if conn.owns_socket {
        net.close(conn.socket)
    }
    if conn.on_closed != nil {
        conn.on_closed(conn.callback_data, conn)
    }
    return nil
}

conn_send_acknowledgement :: proc(conn: ^Conn, packets: []UInt24, flag: u8) -> mcpe_runtime.Error {
    offset := 0
    for offset < len(packets) {
        ack := acknowledgement_init(len(packets) - offset)
        for packet in packets[offset:] {
            acknowledgement_add(&ack, packet)
        }
        w := writer(128)
        write_u8(&w, flag | BIT_FLAG_DATAGRAM)
        consumed := acknowledgement_write(&ack, &w, effective_mtu(conn))
        acknowledgement_destroy(&ack)
        if consumed == 0 {
            writer_destroy(&w)
            return mcpe_runtime.make_error(.Internal, "raknet.send_acknowledgement", "zero acknowledgement progress")
        }
        if _, send_err := net.send_udp(conn.socket, w.data[:], conn.remote); send_err != nil {
            writer_destroy(&w)
            return network_error("raknet.send_acknowledgement")
        }
        writer_destroy(&w)
        offset += consumed
    }
    return nil
}

conn_handle_ack :: proc(conn: ^Conn, data: []u8, negative: bool) -> mcpe_runtime.Error {
    ack := acknowledgement_init()
    defer acknowledgement_destroy(&ack)
    acknowledgement_read(&ack, data) or_return

    if sync.mutex_guard(&conn.mutex) {
        now := mcpe_runtime.system_now_ns(nil)
        for sequence in ack.packets {
            if negative {
                packet, found := resend_map_retransmit(&conn.resend, sequence, now)
                if found {
                    conn_send_datagram_locked(conn, packet) or_return
                }
            } else {
                packet, found := resend_map_acknowledge(&conn.resend, sequence, now)
                if found {
                    conn_free_packet(packet)
                }
            }
        }
    }
    return nil
}

conn_handle_control :: proc(conn: ^Conn, data: []u8) -> (
    handled: bool,
    err: mcpe_runtime.Error,
) {
    if len(data) == 0 {
        return true, mcpe_runtime.make_error(.Malformed, "raknet.handle_packet", "zero packet length")
    }
    switch data[0] {
    case message.ID_CONNECTION_REQUEST:
        if conn.mode != .Server {
            return true, mcpe_runtime.make_error(.Protocol, "raknet.handle_packet", "unexpected connection request")
        }
        request := message.unmarshal_connection_request(data[1:]) or_return
        response := message.marshal_connection_request_accepted({
            client_address = message_address_from_endpoint(conn.remote),
            ping_time = request.request_time,
            pong_time = timestamp(),
        })
        defer writer_destroy(&response)
        return true, conn_send_control(conn, response.data[:])

    case message.ID_CONNECTION_REQUEST_ACCEPTED:
        if conn.mode != .Client {
            return true, mcpe_runtime.make_error(.Protocol, "raknet.handle_packet", "unexpected connection request accepted")
        }
        accepted := message.unmarshal_connection_request_accepted(data[1:]) or_return
        response := message.marshal_new_incoming_connection({
            server_address = message_address_from_endpoint(conn.remote),
            ping_time = accepted.pong_time,
            pong_time = timestamp(),
        })
        send_err := conn_send_control(conn, response.data[:])
        writer_destroy(&response)
        if send_err != nil {
            return true, send_err
        }
        conn_mark_connected(conn)
        return true, nil

    case message.ID_NEW_INCOMING_CONNECTION:
        if conn.mode != .Server {
            return true, mcpe_runtime.make_error(.Protocol, "raknet.handle_packet", "unexpected new incoming connection")
        }
        conn_mark_connected(conn)
        return true, nil

    case message.ID_CONNECTED_PING:
        ping := message.unmarshal_connected_ping(data[1:]) or_return
        pong := message.marshal_connected_pong({
            ping_time = ping.ping_time,
            pong_time = timestamp(),
        })
        return true, conn_send_control(conn, pong[:])

    case message.ID_CONNECTED_PONG:
        _ = message.unmarshal_connected_pong(data[1:]) or_return
        return true, nil

    case message.ID_DISCONNECT_NOTIFICATION:
        close(conn)
        return true, nil

    case message.ID_DETECT_LOST_CONNECTIONS:
        ping := message.marshal_connected_ping({ping_time = timestamp()})
        return true, conn_send_control(conn, ping[:])
    }
    return false, nil
}

conn_deliver_content :: proc(conn: ^Conn, content: []u8) -> mcpe_runtime.Error {
    handled, control_err := conn_handle_control(conn, content)
    if control_err != nil {
        return control_err
    }
    if handled {
        return nil
    }
    owned := make([]u8, len(content))
    copy(owned, content)
    if !channel.send(conn.incoming, owned) {
        delete(owned)
        return mcpe_runtime.make_error(.Closed, "raknet.deliver")
    }
    return nil
}

conn_receive_packet :: proc(conn: ^Conn, packet: ^Packet) -> mcpe_runtime.Error {
    content := packet.content
    content_owned := false
    if packet.split {
        complete: bool
        var split_err: mcpe_runtime.Error
        content, complete, split_err = split_assembler_add(
            &conn.splits,
            packet,
            conn.limits_enabled,
        )
        if split_err != nil {
            return split_err
        }
        if !complete {
            return nil
        }
        content_owned = true
    }
    if content_owned {
        defer delete(content)
    }

    if packet.reliability != .Reliable_Ordered {
        return conn_deliver_content(conn, content)
    }
    queued := make([]u8, len(content))
    copy(queued, content)
    if !packet_queue_put(&conn.ordered, packet.order_index, queued) {
        delete(queued)
        return nil
    }
    if conn.limits_enabled && packet_queue_window_size(&conn.ordered) > MAX_WINDOW_SIZE {
        return mcpe_runtime.make_error(.Limit_Exceeded, "raknet.receive_packet", "ordered window too large")
    }
    packets := packet_queue_fetch(&conn.ordered)
    defer delete(packets)
    for queued_content in packets {
        deliver_err := conn_deliver_content(conn, queued_content)
        delete(queued_content)
        if deliver_err != nil {
            return deliver_err
        }
    }
    return nil
}

conn_receive_datagram :: proc(conn: ^Conn, data: []u8) -> mcpe_runtime.Error {
    if len(data) < 3 {
        return mcpe_runtime.make_error(.Unexpected_EOF, "raknet.receive_datagram")
    }
    sequence := load_u24_le(data[:3])
    now := mcpe_runtime.system_now_ns(nil)
    if !datagram_window_add(&conn.window, sequence, now) {
        return nil
    }
    conn_send_acknowledgement(conn, []UInt24{sequence}, BIT_FLAG_ACK) or_return

    if datagram_window_shift(&conn.window) == 0 {
        delay := max(conn.rtt_ns + conn.rtt_ns / 2, i64(1))
        missing := datagram_window_missing(&conn.window, now, delay)
        if len(missing) > 0 {
            nack_err := conn_send_acknowledgement(conn, missing[:], BIT_FLAG_NACK)
            delete(missing)
            if nack_err != nil {
                return nack_err
            }
        } else {
            delete(missing)
        }
    }
    if conn.limits_enabled && datagram_window_size(&conn.window) > MAX_WINDOW_SIZE {
        return mcpe_runtime.make_error(.Limit_Exceeded, "raknet.receive_datagram", "datagram window too large")
    }

    offset := 3
    for offset < len(data) {
        packet, consumed, read_err := read_packet(data[offset:])
        if read_err != nil {
            return read_err
        }
        conn_receive_packet(conn, &packet) or_return
        offset += consumed
    }
    return nil
}

conn_receive :: proc(conn: ^Conn, data: []u8) -> mcpe_runtime.Error {
    if len(data) == 0 {
        return nil
    }
    sync.atomic_store(&conn.last_activity, mcpe_runtime.system_now_ns(nil))
    if data[0] & BIT_FLAG_ACK != 0 {
        return conn_handle_ack(conn, data[1:], false)
    }
    if data[0] & BIT_FLAG_NACK != 0 {
        return conn_handle_ack(conn, data[1:], true)
    }
    if data[0] & BIT_FLAG_DATAGRAM != 0 {
        return conn_receive_datagram(conn, data[1:])
    }
    return nil
}

conn_receive_thread :: proc(worker: ^thread.Thread) {
    conn := (^Conn)(worker.data)
    buffer: [1500]u8
    for !sync.atomic_load(&conn.closed) {
        count, remote, receive_err := net.recv_udp(conn.socket, buffer[:])
        if receive_err != nil {
            if sync.atomic_load(&conn.closed) {
                return
            }
            continue
        }
        if count == 0 || remote != conn.remote {
            continue
        }
        if receive_error := conn_receive(conn, buffer[:count]); receive_error != nil {
            mcpe_runtime.destroy_error(receive_error)
            close(conn)
            return
        }
    }
}

conn_tick_thread :: proc(worker: ^thread.Thread) {
    conn := (^Conn)(worker.data)
    ticks := 0
    for !sync.atomic_load(&conn.closed) {
        time.sleep(100 * time.Millisecond)
        ticks += 1
        now := mcpe_runtime.system_now_ns(nil)
        if ticks % 3 == 0 {
            if sync.mutex_guard(&conn.mutex) {
                rtt := resend_map_rtt(&conn.resend, now)
                sync.atomic_store(&conn.rtt_ns, rtt)
                delay := rtt + rtt / 2
                resend_sequences := make([dynamic]UInt24)
                for sequence, record in conn.resend.unacknowledged {
                    if now - record.timestamp > delay {
                        append(&resend_sequences, sequence)
                    }
                }
                for sequence in resend_sequences {
                    packet, found := resend_map_retransmit(&conn.resend, sequence, now)
                    if found {
                        if resend_err := conn_send_datagram_locked(conn, packet); resend_err != nil {
                            mcpe_runtime.destroy_error(resend_err)
                        }
                    }
                }
                delete(resend_sequences)
            }
        }
        if ticks % 5 == 0 && sync.atomic_load(&conn.connected) {
            ping := message.marshal_connected_ping({ping_time = timestamp()})
            if ping_err := conn_send_control(conn, ping[:]); ping_err != nil {
                mcpe_runtime.destroy_error(ping_err)
            }
            rtt := sync.atomic_load(&conn.rtt_ns)
            if now - sync.atomic_load(&conn.last_activity) > 5_000_000_000 + rtt * 2 {
                close(conn)
                return
            }
        }
    }
}

