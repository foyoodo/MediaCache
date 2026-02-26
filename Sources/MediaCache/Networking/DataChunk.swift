import Foundation

final class DataChunk {

    let chunkSize: Int
    let bufferCapacity: Int

    private let buffer: UnsafeMutableBufferPointer<UInt8>

    private var writtenBytes: Int = 0

    var onChunk: ((Data) -> Void)?

    init(chunkSize: Int, bufferCapacity: Int) {
        self.chunkSize = chunkSize
        self.bufferCapacity = bufferCapacity
        self.buffer = .allocate(capacity: bufferCapacity)
    }

    deinit {
        buffer.deallocate()
    }

    func append(data: Data) {
        if data.count >= bufferCapacity - writtenBytes {
            flush()
            onChunk?(data)
        } else {
            data.copyBytes(to: buffer.baseAddress!.advanced(by: writtenBytes), count: data.count)
            writtenBytes += data.count
            emitChunk()
        }
    }

    private func emitChunk() {
        guard writtenBytes >= chunkSize else { return }

        let chunk = Data(bytes: buffer.baseAddress!, count: writtenBytes)
        onChunk?(chunk)

        writtenBytes = 0
    }

    func flush() {
        guard writtenBytes > 0 else { return }
        let chunk = Data(bytes: buffer.baseAddress!, count: writtenBytes)
        onChunk?(chunk)
        writtenBytes = 0
    }
}
