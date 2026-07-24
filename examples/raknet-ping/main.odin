package raknet_ping_example

import "core:fmt"
import "core:os"
import raknet "mcpe:raknet"
import mcpe_runtime "mcpe:runtime"

main :: proc() {
    if len(os.args) != 2 {
        fmt.eprintln("usage: raknet-ping <host:port>")
        return
    }
    response, err := raknet.ping(os.args[1])
    if err != nil {
        defer mcpe_runtime.destroy_error(err)
        fmt.eprintf("ping failed during %s: %s\n", err.operation, err.message)
        return
    }
    defer delete(response)
    fmt.println(string(response))
}

