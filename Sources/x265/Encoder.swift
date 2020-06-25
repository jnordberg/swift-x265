import Foundation
import libx265

public class Params {
    public enum Error: Int32, Swift.Error {
        case badName = -1 // X265_PARAM_BAD_NAME
        case badValue = -2 // X265_PARAM_BAD_VALUE
    }

    public enum LogLevel: Int32 {
        case none = -1 // X265_LOG_NONE
        case error = 0 // X265_LOG_ERROR
        case warning = 1 // X265_LOG_WARNING
        case info = 2 // X265_LOG_INFO
        case debug = 3 // X265_LOG_DEBUG
        case full = 4 // X265_LOG_FULL
    }

    public enum ColorSpace: Int32 {
        /// yuv 4:0:0 planar
        case i400 = 0 // X265_CSP_I400
        /// yuv 4:2:0 planar
        case i420 = 1 // X265_CSP_I420
        /// yuv 4:2:2 planar
        case i422 = 2 // X265_CSP_I422
        /// yuv 4:4:4 planar
        case i444 = 3 // X265_CSP_I444
    }

    public let ref: UnsafeMutablePointer<x265_param>

    public init() {
        ref = x265_param_alloc()!
        x265_param_default(ref)
        // only supported csp at the moment
        ref.pointee.internalCsp = ColorSpace.i420.rawValue
        ref.pointee.bRepeatHeaders = 1
    }

    deinit {
        x265_param_free(self.ref)
    }

    public var logLevel: LogLevel {
        get { LogLevel(rawValue: ref.pointee.logLevel)! }
        set { ref.pointee.logLevel = newValue.rawValue }
    }

    public var csp: ColorSpace {
        get { ColorSpace(rawValue: ref.pointee.internalCsp)! }
        set { ref.pointee.internalCsp = newValue.rawValue }
    }

    public var width: Int32 {
        get { ref.pointee.sourceWidth }
        set { ref.pointee.sourceWidth = newValue }
    }

    public var height: Int32 {
        get { ref.pointee.sourceHeight }
        set { ref.pointee.sourceHeight = newValue }
    }

    public func parse(key: String, value: String? = nil) throws {
        let res = x265_param_parse(ref, key, value)
        if res != 0 {
            throw Error(rawValue: res)!
        }
    }

    /// - Note: This resets other params, call it first.
    public func preset(name: String? = nil, tune: String? = nil) {
        let ret = x265_param_default_preset(ref, name, tune)
        print(ret, ref)
    }
}

public class Encoder {
    enum Error: Swift.Error {
        case unsupportedCsp(Params.ColorSpace)
        case invalidFrameData
        case unexpectedEncoderError
    }

    public let ref: OpaquePointer
    public let pic: UnsafeMutablePointer<x265_picture>
    public let params: Params
    public let output: FileHandle

    /// - Attention: x265 has some global state that makes using multiple instances hard.
    ///              Behaviour is undefined if you allocate more than one encoder at once
    ///              using this library.
    public init(params: Params, output: FileHandle) throws {
        self.params = params
        self.output = output
        guard params.csp == .i420 else {
            throw Error.unsupportedCsp(params.csp)
        }
        guard let ref = x265_encoder_open_swift(params.ref) else {
            throw Error.unexpectedEncoderError
        }
        self.ref = ref
        pic = x265_picture_alloc()
        x265_picture_init(params.ref, pic)
        pic.pointee.stride.0 = params.width
        pic.pointee.stride.1 = params.width / 2
        pic.pointee.stride.2 = params.width / 2
    }

    deinit {
        x265_picture_free(self.pic)
        x265_encoder_close(self.ref)
        x265_cleanup()
    }

    var ppNal: UnsafeMutablePointer<x265_nal>?
    var piNal: UInt32 = 0

    public func write(_ frame: Data) throws {
        var frame = frame
        let uOffset = Int(params.width * params.height)
        let vOffset = uOffset * 5 / 4
        try frame.withUnsafeMutableBytes { (ptr: UnsafeMutableRawBufferPointer) in
            // TODO: make sure data is correct size
            guard let addr = ptr.baseAddress else {
                throw Error.invalidFrameData
            }
            self.pic.pointee.planes.0 = addr
            self.pic.pointee.planes.1 = addr.advanced(by: uOffset)
            self.pic.pointee.planes.2 = addr.advanced(by: vOffset)
        }
        let ret = x265_encoder_encode(ref, &ppNal, &piNal, pic, nil)
        guard ret != -1 else {
            throw Error.unexpectedEncoderError
        }
        flush()
    }

    public func finalize() throws {
        var ret: Int32
        while true {
            ret = x265_encoder_encode(ref, &ppNal, &piNal, nil, nil)
            if ret == -1 {
                throw Error.unexpectedEncoderError
            } else if ret == 0 {
                break
            }
            flush()
        }
    }

    func flush() {
        for i in 0 ..< Int(piNal) {
            let p = ppNal!.advanced(by: i).pointee
            let d = Data(
                bytesNoCopy: p.payload,
                count: Int(p.sizeBytes),
                deallocator: .none
            )
            output.write(d)
        }
    }
}
