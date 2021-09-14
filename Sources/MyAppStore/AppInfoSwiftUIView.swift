//
//  AppInfoSwiftUIView.swift
//  All Apps
//
//  Created by zhaoxin on 2021/7/20.
//

import SwiftUI
import Compression
import QRCodeKit

struct AppInfoSwiftUIView: View {
    static let appInfoRemoved = Notification.Name("appInfoRemoved")
    
    @Binding var appInfo:AppInfo
    
    var body: some View {
        VStack {
            HStack {
                appInfo.getImage()
                    .resizable()
                    .frame(width: 64, height: 64, alignment: .center)
                VStack(alignment: .leading) {
                    HStack {
                        Text(appInfo.lang.flag).font(.title)
                        Text(appInfo.platform.icon).font(.title)
                    }
                    Text(appInfo.name).font(.title2)
                    Text(appInfo.version)
                }
                Spacer()
                Button(action: download, label: {
                    Text("Download", bundle: .module)
                })
            }
            HStack {
                Text(appInfo.changelog)
                    .multilineTextAlignment(.leading)
                    .lineLimit(3)
                    .font(.title3)
                Spacer()
                Button(action: more, label: {
                    Text("More", bundle: .module)
                })
            }

        }.padding()
    }
    
    private func setEditing() {
        appInfo.isEditing.toggle()
    }
    
    private func download() {
        // for iOS app, show a picture with barcode and copy url option
        if appInfo.platform == .iOS {
            let alert = NSAlert()
            alert.alertStyle = .informational
            alert.messageText = "Scan To Download"
            
            alert.addButton(withTitle: "Copy URL")
            alert.addButton(withTitle: "Close")
            let imageView = NSImageView(frame: NSRect(x: 0, y: 0, width: 120, height: 120))
            imageView.image = {
                var qrcode = QRCode(URL(string: appInfo.appStoreURL.addingPercentEncoding(withAllowedCharacters: .urlFragmentAllowed)!)!)!
                qrcode.size = imageView.bounds.size
                qrcode.color = .black
                
                return qrcode.image
            }()
            alert.accessoryView = imageView
            
            alert.beginSheetModal(for: NSApp.mainWindow!, completionHandler: { response in
                if response == .alertFirstButtonReturn {
                    print("first button")
                } else {
                    print("second button")
                }
            })
        } else {
            NSWorkspace.shared.open(URL(string: appInfo.appStoreURL.addingPercentEncoding(withAllowedCharacters: .urlFragmentAllowed)!)!)
        }
    }
    
    private func remove() {
        NotificationCenter.default.post(name: AppInfoSwiftUIView.appInfoRemoved, object: self, userInfo: ["AppInfo":appInfo])
    }
    
    private func more() {
        NSWorkspace.shared.open(URL(string: appInfo.homeURL.addingPercentEncoding(withAllowedCharacters: .urlFragmentAllowed)!)!)
    }
}

public struct AppInfo:Identifiable, Equatable, Hashable, Codable {
    public var id = UUID()
    public var platform:RunningPlatform = .iOS
    public var lang:Language = .en
    public var icon:String = ""
    public var name:String = ""
    public var version:String = ""
    public var changelog:String = ""
    public var homeURL:String = ""
    public var appStoreURL:String = ""
    
    public var isEditing = false
    
    func getImage() -> Image {
        if icon.isEmpty {
            return Image(systemName: "app")
        }
        
        return Image(nsImage: NSImage(data: Data(base64Encoded: icon)!)!)
    }
    
    mutating func setIcon(url:URL) {
        let data = try! Data(contentsOf: url)
        icon = data.base64EncodedString()
    }
    
    func compress(_ str:String) -> Data {
        var sourceBuffer = Array(str.utf8)
        let destinationBuffer = UnsafeMutablePointer<UInt8>.allocate(capacity: str.count)
        let algorithm = COMPRESSION_LZFSE
        let compressedSize = compression_encode_buffer(destinationBuffer, str.count,
                                                       &sourceBuffer, str.count,
                                                       nil,
                                                       algorithm)
        if compressedSize == 0 {
            fatalError("Encoding failed.")
        }
        
        return Data(bytesNoCopy: destinationBuffer,
                    count: compressedSize,
                    deallocator: .none)
    }
    
    func decompress(_ data:Data) -> String {
        let algorithm = COMPRESSION_LZFSE
        let encodedSourceData = data
        let decodedCapacity = 8_000_000
        let decodedDestinationBuffer = UnsafeMutablePointer<UInt8>.allocate(capacity: decodedCapacity)
        let decodedString: String = encodedSourceData.withUnsafeBytes { encodedSourceBuffer in
            let typedPointer = encodedSourceBuffer.bindMemory(to: UInt8.self)
            let decodedCharCount = compression_decode_buffer(decodedDestinationBuffer, decodedCapacity,
                                                             typedPointer.baseAddress!, encodedSourceData.count,
                                                             nil,
                                                             algorithm)
            
            print("Buffer decompressedCharCount", decodedCharCount)
            
            return String(cString: decodedDestinationBuffer)
        }
        
        return decodedString
    }
}

public enum Language: String, CaseIterable, Identifiable, Codable {
    case zh_Hans
    case en
    
    var flag:String {
        switch self {
        case .zh_Hans:
            return "🇨🇳"
        case .en:
            return "🇺🇸"
        }
    }

    public var id: String { self.rawValue }
}

public enum RunningPlatform: String, CaseIterable, Identifiable, Codable {
    case iOS
    case macOS
    case watchOS
    case tvOS
    case all
    
    var icon:String {
        switch self {
        case .iOS:
            return "📱"
        case .macOS:
            return "💻"
        case .watchOS:
            return "⌚️"
        case .tvOS:
            return "📺"
        case .all:
            return "💻📱"
        }
    }
    
    public var id: String { self.rawValue }
    public var localizedString:String {
        switch self {
        case .all:
            return NSLocalizedString("all", bundle: .module, comment: "")
        default:
            return self.rawValue
        }
    }
}

struct AppInfoSwiftUIView_Previews: PreviewProvider {
    static var previews: some View {
        AppInfoSwiftUIView(appInfo: .constant(AppInfo(icon: png2json(name: "poster2_mac"),
                                            name: NSLocalizedString("Poster 2", comment: ""),
                                            version: "2.8.12",
                                            changelog: "* Removed the unintended alert after posting finished. ",
                                            homeURL:"",
                                            appStoreURL: "")))
            .environment(\.locale, .init(identifier: "zh"))
    }
    
    static func png2json(name:String) -> String {
        print(Bundle.main.bundleIdentifier ?? "")
//        let url = Bundle.main.url(forResource: name, withExtension: "png")!
        let url = Bundle.module.url(forResource: name, withExtension: "png")!
        let data = try! Data(contentsOf: url)
        
        return data.base64EncodedString()
    }
}
