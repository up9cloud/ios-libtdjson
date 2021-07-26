import libtdjson
// https://gist.github.com/nyg/b6a80bf79e72599230c312c69e963e60
func toLong(ptr: UnsafeMutableRawPointer) -> Int {
    // return unsafeBitCast(ptr, to: Int.self)
    return Int(bitPattern: ptr)
}
func toPtr(long: Int) -> UnsafeMutableRawPointer {
    // return unsafeBitCast(long, to: UnsafeMutableRawPointer.self)
    return UnsafeMutableRawPointer(bitPattern: long)!
}
// https://core.telegram.org/tdlib/docs/td__json__client_8h.html
class JsonClient {
    public static func td_json_client_create() -> Int {
        let client = libtdjson.td_json_client_create()!
        return toLong(ptr: client)
    }
    public static func td_json_client_send(clientId: Int, request: String) {
        let client = toPtr(long: clientId)
        libtdjson.td_json_client_send(client, request)
    }
    public static func td_json_client_receive(clientId: Int, timeout: Double) -> String? {
        let client = toPtr(long: clientId)
        let lock = NSLock()
        lock.lock()
        let res = libtdjson.td_json_client_receive(client, timeout)
        lock.unlock()
        if res != nil {
            return String(cString: res!)
        }
        return nil
    }
    public static func td_json_client_execute(clientId: Int, request: String) -> String? {
        let client = toPtr(long: clientId)
        if let res = libtdjson.td_json_client_execute(client, request) {
            return String(cString: res)
        }
        return nil
    }
    public static func td_json_client_destroy(clientId: Int) {
        let client = toPtr(long: clientId)
        libtdjson.td_json_client_destroy(client)
    }
    public static func td_create_client_id() -> Int {
        return libtdjson.td_create_client_id()
    }
    public static func td_send(clientId: Int, request: String) {
        libtdjson.td_send(clientId, request)
    }
    public static func td_receive(timeout: Double) -> String? {
        let lock = NSLock()
        lock.lock()
        let res = libtdjson.td_receive(timeout)
        lock.unlock()
        if res != nil {
            return String(cString: res!)
        }
        return nil
    }
    public static func td_execute(request: String) -> String {
        let res = libtdjson.td_execute(request)
        return String(cString: res!)
    }
}
