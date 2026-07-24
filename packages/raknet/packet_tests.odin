package raknet

import "core:slice"
import "core:testing"

@(test)
packet_round_trip :: proc(t: ^testing.T) {
    content := []u8{0x12, 0x34, 0x56}
    expected := Packet{
        reliability = .Reliable_Ordered,
        message_index = 4,
        order_index = 9,
        content = content,
        split = true,
        split_count = 3,
        split_index = 1,
        split_id = 17,
    }
    w := writer()
    defer writer_destroy(&w)
    write_packet(&w, &expected)
    actual, consumed, err := read_packet(w.data[:])
    testing.expect(t, err == nil)
    testing.expect_value(t, consumed, len(w.data))
    testing.expect_value(t, actual.reliability, expected.reliability)
    testing.expect_value(t, actual.message_index, expected.message_index)
    testing.expect_value(t, actual.order_index, expected.order_index)
    testing.expect_value(t, actual.split_count, expected.split_count)
    testing.expect_value(t, actual.split_index, expected.split_index)
    testing.expect_value(t, actual.split_id, expected.split_id)
    testing.expect(t, slice.equal(actual.content, expected.content))
}

@(test)
packet_split_respects_mtu :: proc(t: ^testing.T) {
    data: [4096]u8
    fragments, err := split_content(data[:], 1400)
    defer delete(fragments)
    testing.expect(t, err == nil)
    testing.expect_value(t, len(fragments), 3)
    for fragment in fragments {
        testing.expect(t, len(fragment) + PACKET_ADDITIONAL_SIZE + SPLIT_ADDITIONAL_SIZE <= 1400)
    }
}

@(test)
acknowledgement_range_round_trip :: proc(t: ^testing.T) {
    expected := acknowledgement_init()
    defer acknowledgement_destroy(&expected)
    values := [?]UInt24{1, 2, 3, 8, 10, 11}
    for value in values {
        acknowledgement_add(&expected, value)
    }

    w := writer()
    defer writer_destroy(&w)
    consumed := acknowledgement_write(&expected, &w, 1400)
    testing.expect_value(t, consumed, len(expected.packets))

    actual := acknowledgement_init()
    defer acknowledgement_destroy(&actual)
    err := acknowledgement_read(&actual, w.data[:])
    testing.expect(t, err == nil)
    testing.expect(t, slice.equal(actual.packets[:], expected.packets[:]))
}

@(test)
ordered_packet_queue :: proc(t: ^testing.T) {
    queue := packet_queue_init()
    defer packet_queue_destroy(&queue)
    a := []u8{1}
    b := []u8{2}
    testing.expect(t, packet_queue_put(&queue, 1, b))
    first := packet_queue_fetch(&queue)
    testing.expect_value(t, len(first), 0)
    delete(first)
    testing.expect(t, packet_queue_put(&queue, 0, a))
    packets := packet_queue_fetch(&queue)
    defer delete(packets)
    testing.expect_value(t, len(packets), 2)
    testing.expect(t, slice.equal(packets[0], a))
    testing.expect(t, slice.equal(packets[1], b))
}

@(test)
datagram_window_reports_gap_after_delay :: proc(t: ^testing.T) {
    window := datagram_window_init()
    defer datagram_window_destroy(&window)
    testing.expect(t, datagram_window_add(&window, 0, 100))
    testing.expect(t, datagram_window_add(&window, 2, 100))
    testing.expect_value(t, datagram_window_shift(&window), 1)
    missing := datagram_window_missing(&window, 300, 100)
    defer delete(missing)
    testing.expect_value(t, len(missing), 1)
    testing.expect_value(t, missing[0], UInt24(1))
}

@(test)
resend_map_tracks_rtt :: proc(t: ^testing.T) {
    resend := resend_map_init()
    defer resend_map_destroy(&resend)
    packet: Packet
    resend_map_add(&resend, 7, &packet, 1_000)
    actual, found := resend_map_acknowledge(&resend, 7, 2_000)
    testing.expect(t, found)
    testing.expect(t, actual == &packet)
    testing.expect_value(t, resend_map_rtt(&resend, 2_000), i64(1_000))
}

@(test)
split_assembler_reassembles_out_of_order :: proc(t: ^testing.T) {
    assembler := split_assembler_init()
    defer split_assembler_destroy(&assembler)

    second := Packet{
        split = true,
        split_count = 2,
        split_index = 1,
        split_id = 5,
        content = []u8{3, 4},
    }
    first := second
    first.split_index = 0
    first.content = []u8{1, 2}

    _, complete, err := split_assembler_add(&assembler, &second, true)
    testing.expect(t, err == nil)
    testing.expect(t, !complete)

    content: []u8
    content, complete, err = split_assembler_add(&assembler, &first, true)
    defer delete(content)
    testing.expect(t, err == nil)
    testing.expect(t, complete)
    testing.expect(t, slice.equal(content, []u8{1, 2, 3, 4}))
}
