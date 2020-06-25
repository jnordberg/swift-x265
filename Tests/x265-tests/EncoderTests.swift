import x265
import XCTest

final class EncoderTests: XCTestCase {
    func testEncode() throws {
        let params = Params()
        params.preset(name: "veryfast")
        try params.parse(key: "fps", value: "10")
        params.width = 1080
        params.height = 720
        let out = Pipe()
        let encoder = try Encoder(params: params, output: out.fileHandleForWriting)
        // TODO: encode some test frames
        try encoder.finalize()
    }
}
