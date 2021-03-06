import CUV

enum ConnectionError: ErrorProtocol {
    case CouldNotAccept
}

func alloc_buffer(handle: UnsafeMutablePointer<uv_handle_t>, size: size_t, buffer: UnsafeMutablePointer<uv_buf_t>) {
    let ptr = UnsafeMutablePointer<Int8>(allocatingCapacity: size)
    buffer.pointee = uv_buf_init(ptr, UInt32(size))
}

func on_client_read(stream: UnsafeMutablePointer<uv_stream_t>, size: Int, buffer: UnsafePointer<uv_buf_t>) {
    let data = stream.pointee.data
    let callback = unsafeBitCast(data, to: ConnectionCallback.self)
    let connection = callback.connection
    connection?.read(stream, size: size, buffer: buffer)
}

func on_client_write(writeStream: UnsafeMutablePointer<uv_write_t>, status: Int32) {
    let data = writeStream.pointee.data
    let callback = unsafeBitCast(data, to: ConnectionCallback.self)
    let connection = callback.connection
    connection?.close(writeStream)
}

func on_close(handle: UnsafeMutablePointer<uv_handle_t>) {
    let data = handle.pointee.data
    let callback = unsafeBitCast(data, to: ConnectionCallback.self)
    if let connection = callback.connection {
        connection.delegate.connectionDidFinish(connection)
    }
}

class ConnectionCallback {
    
    weak var connection: Connection?
    
}

protocol ConnectionDelegate {
    func connection(connection: Connection, didReadData data: Data)
    func connectionDidFinish(connection: Connection)
}

final public class Connection: Hashable {
    
    let identifier: Int
    
    var client: UnsafeMutablePointer<uv_tcp_t>
    
    public var data: Data
    
    let delegate: ConnectionDelegate
    
    let connection: UnsafeMutablePointer<uv_stream_t>
    
    var writeBuffer: UnsafeMutablePointer<uv_buf_t>?
    
    var callback: ConnectionCallback
    
    public var hashValue: Int {
        return identifier
    }
    
    init(connection: UnsafeMutablePointer<uv_stream_t>, delegate: ConnectionDelegate, identifier: Int) {
        
        client = UnsafeMutablePointer<uv_tcp_t>(allocatingCapacity: 1)
        
        self.identifier = identifier
        
        data = Data(bytes: [])
        
        self.connection = connection
        
        self.delegate = delegate
        
        callback = ConnectionCallback()
        
        callback.connection = self
    }
    
    deinit {
        client.deinitialize(count: 1)
    }
    
    func beginRead() throws {
        client.pointee.data = unsafeBitCast(callback, 
                                           to: UnsafeMutablePointer<Void>.self)

        uv_tcp_init(uv_default_loop(), client)
        
        let stream = UnsafeMutablePointer<uv_stream_t>(client)
        
        guard uv_accept(self.connection, stream) == 0 else {
            uv_close(UnsafeMutablePointer<uv_handle_t>(stream), nil)
            throw ConnectionError.CouldNotAccept
        }
        
        uv_read_start(stream, alloc_buffer, on_client_read)
    }
    
    func read(stream: UnsafeMutablePointer<uv_stream_t>, size: Int, 
              buffer: UnsafePointer<uv_buf_t>) {
        
        data.append(buffer.pointee.base, length: size)
        
        buffer.pointee.base.deinitialize(count: size)
        
        delegate.connection(self, didReadData: data)
    }
    
    public func writeData(data: Data) {
        
        let writeRequest = 
            UnsafeMutablePointer<uv_write_t>(allocatingCapacity: 1)
        
        let mutableBytes = UnsafeMutablePointer<UInt8>(data.bytes)
        
        let pointer = UnsafeMutablePointer<Int8>(mutableBytes)
        
        var buffer = uv_buf_t(base: pointer, len: data.bytes.count)

        writeRequest.pointee.data = unsafeBitCast(callback, 
                                                  to: UnsafeMutablePointer<Void>.self)
        let stream = UnsafeMutablePointer<uv_stream_t>(client)
        uv_write(writeRequest, stream, &buffer, 1, on_client_write)
    }
    
    func close(writeRequest: UnsafeMutablePointer<uv_write_t>) {
        writeRequest.deallocateCapacity(1)
        let handle = UnsafeMutablePointer<uv_handle_t>(client)
        uv_close(handle, on_close)
    }
}

public func == (lhs: Connection, rhs: Connection) -> Bool {
    return lhs.identifier == rhs.identifier
}
