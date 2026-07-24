package mcpe_runtime

Random_U64_Proc :: proc "odin" (user_data: rawptr) -> u64

Random_Source :: struct {
    user_data: rawptr,
    next_u64:  Random_U64_Proc,
}

random_u64 :: proc(source: Random_Source) -> u64 {
    assert(source.next_u64 != nil)
    return source.next_u64(source.user_data)
}

