package mcpe_runtime

Error_Kind :: enum u16 {
    None,
    Cancelled,
    Closed,
    Timeout,
    Invalid_Argument,
    Unexpected_EOF,
    Malformed,
    Limit_Exceeded,
    Address,
    Network,
    Protocol,
    Authentication,
    Storage,
    Native,
    Internal,
}

Error_Detail :: struct {
    kind:        Error_Kind,
    operation:   string,
    native_code: i64,
    message:     string,
}

Error :: ^Error_Detail

error_is_none :: proc(err: Error) -> bool {
    return err == nil
}

make_error :: proc(
    kind: Error_Kind,
    operation: string,
    message: string = "",
    native_code: i64 = 0,
) -> Error {
    detail := new(Error_Detail)
    detail^ = Error_Detail{
        kind = kind,
        operation = operation,
        native_code = native_code,
        message = message,
    }
    return detail
}

destroy_error :: proc(err: Error) {
    if err != nil {
        free(err)
    }
}
