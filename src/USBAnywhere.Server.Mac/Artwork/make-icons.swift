// USBAnywhere project: oscarlosu-lab (SnakeFoxu) — https://github.com/oscarlosu-lab
// Licensed under GPL-3.0; see the repository LICENSE.
// Copyright 2026 Denis Arnst (Sapd) — https://github.com/Sapd
// GPL-3.0. Companion vector mark; this does not modify the generated app artwork.
import AppKit
import Foundation

final class MenuMark: NSView {
    override var isFlipped: Bool { true }
    override func draw(_ dirtyRect: NSRect) {
        NSColor.black.set()
        let cable = NSBezierPath()
        cable.move(to: NSPoint(x: 6.5, y: 11))
        cable.line(to: NSPoint(x: 6.5, y: 16))
        cable.curve(to: NSPoint(x: 14.5, y: 16), controlPoint1: NSPoint(x: 6.5, y: 23), controlPoint2: NSPoint(x: 11.5, y: 22))
        cable.line(to: NSPoint(x: 15.5, y: 13))
        cable.line(to: NSPoint(x: 21, y: 6))
        cable.move(to: NSPoint(x: 15.5, y: 13)); cable.line(to: NSPoint(x: 21, y: 20))
        cable.lineWidth = 1.9; cable.lineCapStyle = .round; cable.lineJoinStyle = .round; cable.stroke()
        // Filled circles preserve alpha-only rendering and read cleanly at 18 points.
        for (x,y) in [(15.5,13.0),(21.0,6.0),(21.0,20.0)] {
            NSBezierPath(ovalIn: NSRect(x:x-2.1,y:y-2.1,width:4.2,height:4.2)).fill()
        }
        let tip = NSBezierPath(roundedRect: NSRect(x:4,y:1.5,width:5,height:5), xRadius:0.6,yRadius:0.6)
        tip.windingRule = .evenOdd
        tip.appendRect(NSRect(x:5,y:3,width:1,height:1.5)); tip.appendRect(NSRect(x:7,y:3,width:1,height:1.5))
        tip.fill()
        NSBezierPath(roundedRect: NSRect(x:3,y:5.5,width:7,height:6),xRadius:1.2,yRadius:1.2).fill()
    }
}
let output = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory:true)
try FileManager.default.createDirectory(at:output,withIntermediateDirectories:true)
let mark = MenuMark(frame:NSRect(x:0,y:0,width:24,height:24))
let pdf = mark.dataWithPDF(inside:mark.bounds)
try pdf.write(to:output.appendingPathComponent("MenuBarIconTemplate.pdf"))
// Preview both appearances without changing the user's system appearance.
let preview = NSImage(size:NSSize(width:288,height:96),flipped:false) { rect in
    NSColor.white.setFill(); NSRect(x:0,y:0,width:144,height:96).fill()
    NSColor(calibratedWhite:0.12,alpha:1).setFill(); NSRect(x:144,y:0,width:144,height:96).fill()
    let image = NSImage(data:pdf)!
    image.draw(in:NSRect(x:20,y:26,width:44,height:44))
    image.draw(in:NSRect(x:88,y:39,width:18,height:18))
    let white = NSImage(size:NSSize(width:24,height:24),flipped:false) { bounds in
        image.draw(in:bounds); NSColor.white.setFill(); bounds.fill(using:.sourceIn); return true
    }
    white.draw(in:NSRect(x:164,y:26,width:44,height:44))
    white.draw(in:NSRect(x:232,y:39,width:18,height:18))
    return true
}
let bitmap = NSBitmapImageRep(data:preview.tiffRepresentation!)!
try bitmap.representation(using:.png,properties:[:])!.write(to:output.appendingPathComponent("MenuBarPreview.png"))
