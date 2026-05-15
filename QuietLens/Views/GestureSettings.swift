import SwiftUI
import AppKit
import Carbon.HIToolbox

enum ShortcutRecorder {
    static func carbonMods(from flags: NSEvent.ModifierFlags) -> UInt {
        var m: UInt = 0
        if flags.contains(.command) { m |= UInt(cmdKey) }
        if flags.contains(.option) { m |= UInt(optionKey) }
        if flags.contains(.shift) { m |= UInt(shiftKey) }
        if flags.contains(.control) { m |= UInt(controlKey) }
        return m
    }
    static func modString(_ m: UInt) -> String {
        var s = ""
        if m & UInt(controlKey) != 0 { s += "⌃" }
        if m & UInt(optionKey) != 0 { s += "⌥" }
        if m & UInt(shiftKey) != 0 { s += "⇧" }
        if m & UInt(cmdKey) != 0 { s += "⌘" }
        return s
    }
    static func keyString(_ k: UInt16) -> String {
        let map: [UInt16: String] = [
            0:"A",1:"S",2:"D",3:"F",4:"H",5:"G",6:"Z",7:"X",8:"C",9:"V",
            11:"B",12:"Q",13:"W",14:"E",15:"R",16:"Y",17:"T",
            31:"O",32:"U",34:"I",35:"P",37:"L",38:"J",40:"K",45:"N",46:"M",
            18:"1",19:"2",20:"3",21:"4",22:"6",23:"5",25:"9",26:"7",28:"8",29:"0",
            49:"Space",36:"↩",53:"⎋",51:"⌫",48:"⇥",
            122:"F1",120:"F2",99:"F3",118:"F4",96:"F5",97:"F6",
            98:"F7",100:"F8",101:"F9",109:"F10",103:"F11",111:"F12",
            123:"←",124:"→",125:"↓",126:"↑"
        ]
        return map[k] ?? "Key\(k)"
    }
}

struct KeyCaptureView: NSViewRepresentable {
    @Binding var active: Bool
    var onCapture: (UInt16, NSEvent.ModifierFlags) -> Void

    func makeNSView(context: Context) -> NSView { CaptureView() }
    func updateNSView(_ nsView: NSView, context: Context) {
        guard let v = nsView as? CaptureView else { return }
        v.onCapture = onCapture
        v.active = active
        if active { DispatchQueue.main.async { v.window?.makeFirstResponder(v) } }
    }
    final class CaptureView: NSView {
        var onCapture: ((UInt16, NSEvent.ModifierFlags) -> Void)?
        var active: Bool = false
        override var acceptsFirstResponder: Bool { true }
        override func keyDown(with event: NSEvent) {
            guard active else { super.keyDown(with: event); return }
            onCapture?(event.keyCode, event.modifierFlags.intersection(.deviceIndependentFlagsMask))
        }
    }
}
