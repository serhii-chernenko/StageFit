import AppKit

guard CommandLine.arguments.count == 2 else {
    fputs("Usage: make-icon.swift OUTPUT.png\n", stderr)
    exit(2)
}

let side = 1024
let image = NSImage(size: NSSize(width: side, height: side), flipped: false) { rect in
    let background = NSBezierPath(roundedRect: rect.insetBy(dx: 24, dy: 24), xRadius: 220, yRadius: 220)
    NSGradient(starting: NSColor(calibratedRed: 0.27, green: 0.45, blue: 0.98, alpha: 1),
               ending: NSColor(calibratedRed: 0.22, green: 0.25, blue: 0.65, alpha: 1))!
        .draw(in: background, angle: -45)

    // Three small windows suggest Stage Manager's recent-app strip.
    for (index, y) in [590.0, 430.0, 270.0].enumerated() {
        let card = NSBezierPath(roundedRect: NSRect(x: 95, y: y, width: 165, height: 125),
                                xRadius: 26, yRadius: 26)
        NSColor.white.withAlphaComponent(index == 0 ? 0.88 : 0.66).setFill()
        card.fill()
        NSColor(calibratedWhite: 0.74, alpha: 1).setFill()
        NSBezierPath(roundedRect: NSRect(x: 116, y: y + 70, width: 120, height: 14),
                     xRadius: 7, yRadius: 7).fill()
    }

    let main = NSBezierPath(roundedRect: NSRect(x: 310, y: 145, width: 610, height: 720),
                            xRadius: 62, yRadius: 62)
    NSColor.white.setFill()
    main.fill()
    NSColor(calibratedRed: 0.84, green: 0.87, blue: 0.98, alpha: 1).setFill()
    NSBezierPath(roundedRect: NSRect(x: 340, y: 720, width: 550, height: 115),
                 xRadius: 35, yRadius: 35).fill()
    for (index, color) in [NSColor.systemRed, .systemYellow, .systemGreen].enumerated() {
        color.setFill()
        NSBezierPath(ovalIn: NSRect(x: 370 + index * 45, y: 765, width: 24, height: 24)).fill()
    }
    NSColor(calibratedRed: 0.36, green: 0.43, blue: 0.65, alpha: 1).setFill()
    for y in [635.0, 570.0, 505.0, 440.0] {
        NSBezierPath(roundedRect: NSRect(x: 380, y: y, width: 440, height: 20),
                     xRadius: 10, yRadius: 10).fill()
    }
    return true
}

guard let tiff = image.tiffRepresentation,
      let bitmap = NSBitmapImageRep(data: tiff),
      let data = bitmap.representation(using: .png, properties: [:]) else {
    fputs("Could not render icon\n", stderr)
    exit(1)
}
try data.write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
