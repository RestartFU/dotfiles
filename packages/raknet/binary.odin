package raknet

import wire "mcpe:raknet/wire"

UInt24 :: wire.UInt24
UINT24_MASK :: wire.UINT24_MASK
Reader :: wire.Reader
Writer :: wire.Writer

uint24_inc     :: wire.uint24_inc
load_u16_be    :: wire.load_u16_be
load_u32_be    :: wire.load_u32_be
load_u64_be    :: wire.load_u64_be
load_u16_le    :: wire.load_u16_le
load_u24_le    :: wire.load_u24_le
store_u16_be   :: wire.store_u16_be
store_u32_be   :: wire.store_u32_be
store_u64_be   :: wire.store_u64_be
store_u16_le   :: wire.store_u16_le
store_u24_le   :: wire.store_u24_le
reader         :: wire.reader
remaining      :: wire.remaining
read_bytes     :: wire.read_bytes
read_u8        :: wire.read_u8
read_u16_be    :: wire.read_u16_be
read_u24_le    :: wire.read_u24_le
read_u32_be    :: wire.read_u32_be
read_u64_be    :: wire.read_u64_be
writer         :: wire.writer
writer_destroy :: wire.writer_destroy
write_u8       :: wire.write_u8
write_bytes    :: wire.write_bytes
write_zeroes   :: wire.write_zeroes
write_u16_be   :: wire.write_u16_be
write_u24_le   :: wire.write_u24_le
write_u32_be   :: wire.write_u32_be
write_u64_be   :: wire.write_u64_be
