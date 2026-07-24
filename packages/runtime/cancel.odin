package mcpe_runtime

import "core:sync"

Cancel_Token :: struct {
    cancelled: bool,
}

cancel :: proc(token: ^Cancel_Token) {
    sync.atomic_store(&token.cancelled, true)
}

is_cancelled :: proc(token: ^Cancel_Token) -> bool {
    if token == nil {
        return false
    }
    return sync.atomic_load(&token.cancelled)
}
