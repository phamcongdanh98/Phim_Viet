import Foundation
import PhimVietFFI

/// Lý do kết thúc từ (khớp `PV_BOUNDARY_*`).
public enum Boundary: Equatable {
    case space, enter, tab
    case char(UnicodeScalar)
    case mouse, focus, other

    var ffi: (Int32, UInt32) {
        switch self {
        case .space: return (Int32(PV_BOUNDARY_SPACE), 0)
        case .enter: return (Int32(PV_BOUNDARY_ENTER), 0)
        case .tab: return (Int32(PV_BOUNDARY_TAB), 0)
        case .char(let c): return (Int32(PV_BOUNDARY_CHAR), c.value)
        case .mouse: return (Int32(PV_BOUNDARY_MOUSE), 0)
        case .focus: return (Int32(PV_BOUNDARY_FOCUS), 0)
        case .other: return (Int32(PV_BOUNDARY_OTHER), 0)
        }
    }
}

public enum EngineOutput: Equatable {
    /// Engine không xử lý — đưa phím cho ứng dụng.
    case unchanged
    /// Chữ hiển thị mới của từ đang gõ.
    case composing(String)
    /// Từ kết thúc với chữ chốt; `passThrough` → đưa phím cho ứng dụng.
    case commit(String, passThrough: Bool)
}

/// Giao diện engine mà `CompositionSession` cần (cho phép thay bằng engine giả khi test).
public protocol CompositionEngine: AnyObject {
    var isComposing: Bool { get }
    func process(_ key: UnicodeScalar, shift: Bool, caps: Bool) -> EngineOutput
    func backspace() -> EngineOutput
    func commit(_ boundary: Boundary) -> EngineOutput
    func restoreRaw() -> EngineOutput
    func reset()
    @discardableResult func setConfig(json: String) -> Bool
}

/// Engine Rust qua C ABI (`ffi/include/phimviet.h`). Mỗi chuỗi trả về được giải phóng đúng một lần.
public final class RustEngine: CompositionEngine {
    private let handle: OpaquePointer

    public init?() {
        guard let h = pv_engine_new() else { return nil }
        handle = h
    }

    deinit {
        pv_engine_free(handle)
    }

    private func take(_ r: PvResult) -> EngineOutput {
        defer { pv_string_free(r.text) }
        let s = r.text.map { String(cString: $0) } ?? ""
        switch r.kind {
        case Int32(PV_COMPOSING): return .composing(s)
        case Int32(PV_COMMIT): return .commit(s, passThrough: r.pass_through)
        default: return .unchanged
        }
    }

    public var isComposing: Bool { pv_is_composing(handle) }

    public func process(_ key: UnicodeScalar, shift: Bool, caps: Bool) -> EngineOutput {
        var flags: UInt32 = 0
        if shift { flags |= UInt32(PV_FLAG_SHIFT) }
        if caps { flags |= UInt32(PV_FLAG_CAPS) }
        return take(pv_process(handle, key.value, flags))
    }

    public func backspace() -> EngineOutput { take(pv_backspace(handle)) }

    public func commit(_ boundary: Boundary) -> EngineOutput {
        let (b, c) = boundary.ffi
        return take(pv_commit(handle, b, c))
    }

    public func restoreRaw() -> EngineOutput { take(pv_restore_raw(handle)) }

    public func reset() { pv_reset(handle) }

    @discardableResult
    public func setConfig(json: String) -> Bool {
        json.withCString { pv_set_config(handle, $0) } == 0
    }

    public static var version: String { String(cString: pv_version()) }
}
