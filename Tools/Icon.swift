import CoreGraphics
import ImageIO
import Foundation
import UniformTypeIdentifiers
let destination = CommandLine.arguments[1]
try FileManager.default.createDirectory(atPath: destination, withIntermediateDirectories: true)
func render(_ size: Int, dark: Bool) -> CGImage {
    let cs=CGColorSpaceCreateDeviceRGB()
    let c=CGContext(data:nil,width:size,height:size,bitsPerComponent:8,bytesPerRow:size*4,space:cs,bitmapInfo:CGImageAlphaInfo.premultipliedLast.rawValue)!
    c.scaleBy(x:CGFloat(size)/1024,y:CGFloat(size)/1024)
    let outer=CGPath(roundedRect:CGRect(x:60,y:60,width:904,height:904),cornerWidth:204,cornerHeight:204,transform:nil)
    c.addPath(outer); c.clip()
    let colors=dark ? [CGColor(gray:0.20,alpha:1),CGColor(gray:0.08,alpha:1)] : [CGColor(gray:0.98,alpha:1),CGColor(gray:0.87,alpha:1)]
    let bg=CGGradient(colorsSpace:cs,colors:colors as CFArray,locations:[0,1])!
    c.drawLinearGradient(bg,start:CGPoint(x:512,y:964),end:CGPoint(x:512,y:60),options:[.drawsBeforeStartLocation,.drawsAfterEndLocation])
    let ink=CGColor(gray:dark ? 0.92 : 0.20,alpha:1)
    c.setStrokeColor(ink); c.setFillColor(ink); c.setLineWidth(28)
    c.addPath(CGPath(roundedRect:CGRect(x:184,y:322,width:656,height:380),cornerWidth:56,cornerHeight:56,transform:nil)); c.strokePath()
    // An original keyboard drawing in the same simple outline vocabulary as system icons.
    for row in 0..<3 {
        for col in 0..<11 {
            let key=CGRect(x:226+52*col,y:612-72*row,width:36,height:36)
            c.addPath(CGPath(roundedRect:key,cornerWidth:7,cornerHeight:7,transform:nil)); c.fillPath()
        }
    }
    for rect in [CGRect(x:226,y:396,width:64,height:36),CGRect(x:306,y:396,width:52,height:36),CGRect(x:374,y:396,width:276,height:36),CGRect(x:666,y:396,width:52,height:36),CGRect(x:734,y:396,width:64,height:36)] {
        c.addPath(CGPath(roundedRect:rect,cornerWidth:7,cornerHeight:7,transform:nil)); c.fillPath()
    }
    return c.makeImage()!
}
let sizes=[("icon_16x16.png",16),("icon_16x16@2x.png",32),("icon_32x32.png",32),("icon_32x32@2x.png",64),("icon_128x128.png",128),("icon_128x128@2x.png",256),("icon_256x256.png",256),("icon_256x256@2x.png",512),("icon_512x512.png",512),("icon_512x512@2x.png",1024)]
func bigEndian(_ v:UInt32)->Data { var number=v.bigEndian; return withUnsafeBytes(of:&number) { Data($0) } }
func writeICNS(_ directory:URL,_ output:URL) throws {
    var chunks=Data()
    for (type,file) in [("icp4","icon_16x16.png"),("icp5","icon_32x32.png"),("icp6","icon_32x32@2x.png"),("ic07","icon_128x128.png"),("ic08","icon_256x256.png"),("ic09","icon_512x512.png"),("ic10","icon_512x512@2x.png"),("ic11","icon_16x16@2x.png"),("ic12","icon_32x32@2x.png"),("ic13","icon_128x128@2x.png"),("ic14","icon_256x256@2x.png")] {
        let png=try Data(contentsOf:directory.appendingPathComponent(file))
        chunks.append(Data(type.utf8)); chunks.append(bigEndian(UInt32(png.count+8))); chunks.append(png)
    }
    var icns=Data("icns".utf8); icns.append(bigEndian(UInt32(chunks.count+8))); icns.append(chunks)
    try icns.write(to:output)
}
let darkURL=URL(fileURLWithPath:destination)
let parent=darkURL.deletingLastPathComponent()
let lightURL=parent.appendingPathComponent("AppIcon-Light.iconset")
try FileManager.default.createDirectory(at:lightURL,withIntermediateDirectories:true)
for (dark,folder) in [(true,darkURL),(false,lightURL)] {
    for (filename,size) in sizes {
        let out=CGImageDestinationCreateWithURL(folder.appendingPathComponent(filename) as CFURL,UTType.png.identifier as CFString,1,nil)!
        CGImageDestinationAddImage(out,render(size,dark:dark),nil); CGImageDestinationFinalize(out)
    }
    try writeICNS(folder,parent.appendingPathComponent(dark ? "AppIcon.icns" : "AppIcon-Light.icns"))
}
try Data(contentsOf:lightURL.appendingPathComponent("icon_512x512@2x.png")).write(to:parent.appendingPathComponent("Icon-Light.png"))
