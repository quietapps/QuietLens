#!/usr/bin/env swift
// Adds transparent outer padding to an existing macOS app icon set so the
// baked-in squircle floats at the correct visual weight in the Dock (macOS 26+).
//
// Usage:
//   swift scripts/pad-icon.swift <appiconset_dir> [pad_fraction]
//
// pad_fraction defaults to 0.09 (9% each side → 82% art area, matching QuietFinance).
import AppKit
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

let args = CommandLine.arguments
guard args.count >= 2 else {
    print("Usage: swift pad-icon.swift <path_to_AppIcon.appiconset> [pad_fraction]")
    exit(1)
}
let iconsetPath = args[1]
let pad = args.count >= 3 ? (Double(args[2]) ?? 0.09) : 0.09

let fm = FileManager.default
let iconsetURL = URL(fileURLWithPath: iconsetPath)

// Collect all PNG files in the appiconset
guard let entries = try? fm.contentsOfDirectory(at: iconsetURL, includingPropertiesForKeys: nil) else {
    print("Cannot read \(iconsetPath)"); exit(1)
}
let pngs = entries.filter { $0.pathExtension == "png" }

func addPadding(to sourceURL: URL, pad: CGFloat) throws {
    guard let src = NSImage(contentsOf: sourceURL),
          let cgSrc = src.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
        print("⚠️  Cannot load \(sourceURL.lastPathComponent)"); return
    }

    let origW = cgSrc.width
    let origH = cgSrc.height
    guard origW == origH else {
        print("⚠️  Skipping non-square \(sourceURL.lastPathComponent)"); return
    }
    let size = CGFloat(origW)
    let artSize = size * (1 - 2 * pad)
    let artOff  = size * pad

    let colorSpace = CGColorSpaceCreateDeviceRGB()
    guard let ctx = CGContext(
        data: nil,
        width: origW, height: origH,
        bitsPerComponent: 8, bytesPerRow: 0,
        space: colorSpace,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else { print("⚠️  Cannot create context for \(sourceURL.lastPathComponent)"); return }

    // Draw original image scaled into the inset art area; outer ring stays transparent
    ctx.draw(cgSrc, in: CGRect(x: artOff, y: artOff, width: artSize, height: artSize))

    guard let result = ctx.makeImage(),
          let dest = CGImageDestinationCreateWithURL(sourceURL as CFURL,
                                                     UTType.png.identifier as CFString, 1, nil)
    else { print("⚠️  Cannot write \(sourceURL.lastPathComponent)"); return }
    CGImageDestinationAddImage(dest, result, nil)
    guard CGImageDestinationFinalize(dest) else {
        print("⚠️  Finalize failed \(sourceURL.lastPathComponent)"); return
    }
    print("✓ \(sourceURL.lastPathComponent) (\(origW)px, pad=\(Int(pad*100))%)")
}

for png in pngs.sorted(by: { $0.lastPathComponent < $1.lastPathComponent }) {
    try? addPadding(to: png, pad: CGFloat(pad))
}
print("\nDone. Rebuild in Xcode (⌘R).")
