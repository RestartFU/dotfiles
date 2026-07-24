package raknet_message

ID_CONNECTED_PING                    :: u8(0x00)
ID_UNCONNECTED_PING                  :: u8(0x01)
ID_UNCONNECTED_PING_OPEN_CONNECTIONS :: u8(0x02)
ID_CONNECTED_PONG                    :: u8(0x03)
ID_DETECT_LOST_CONNECTIONS           :: u8(0x04)
ID_OPEN_CONNECTION_REQUEST_1         :: u8(0x05)
ID_OPEN_CONNECTION_REPLY_1           :: u8(0x06)
ID_OPEN_CONNECTION_REQUEST_2         :: u8(0x07)
ID_OPEN_CONNECTION_REPLY_2           :: u8(0x08)
ID_CONNECTION_REQUEST                :: u8(0x09)
ID_CONNECTION_REQUEST_ACCEPTED       :: u8(0x10)
ID_NEW_INCOMING_CONNECTION           :: u8(0x13)
ID_DISCONNECT_NOTIFICATION           :: u8(0x15)
ID_INCOMPATIBLE_PROTOCOL_VERSION     :: u8(0x19)
ID_UNCONNECTED_PONG                  :: u8(0x1c)

@(rodata)
UNCONNECTED_MAGIC := [16]u8{
    0x00, 0xff, 0xff, 0x00,
    0xfe, 0xfe, 0xfe, 0xfe,
    0xfd, 0xfd, 0xfd, 0xfd,
    0x12, 0x34, 0x56, 0x78,
}
