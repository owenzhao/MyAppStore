//
//  MainSwiftUIView.swift
//  App Demo
//
//  Created by zhaoxin on 2021/8/23.
//

import SwiftUI
import ZIPFoundation

public struct MainSwiftUIView: View {
    public init(appInfos:[AppInfo]) {
        self.appInfos = appInfos
    }
    
    public init() {
        
    }
    
    @State public var appInfos = [AppInfo]()
    @State private var filteredAppInfos = [AppInfo]()
    @State public var platform:RunningPlatform = .all
    
    public var body: some View {
        VStack {
            HStack {
                Spacer()
                Button(action: fileBug, label: {
                    Image(systemName: "ladybug")
                        .resizable()
                        .frame(width: 24, height: 24, alignment: .center)
                }).buttonStyle(PlainButtonStyle())
                Button(action: buyMeACoffee, label: {
                    HStack {
                        Image("bmc-logo", bundle: .module)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 24, height: 24, alignment: .center)
                            .help("Buy developer a coffee")
                            
                    }
                }).buttonStyle(PlainButtonStyle())
                Button(action: follow, label: {
                    Image("twitter", bundle: .module)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 24, height: 24, alignment: .center)
                        .help("Follow developer on Twitter")
                }).buttonStyle(PlainButtonStyle())
                Picker(selection: $platform, label: Text(platform.icon)) {
                    Text(RunningPlatform.all.localizedString).tag(RunningPlatform.all)
                    Text(RunningPlatform.macOS.localizedString).tag(RunningPlatform.macOS)
                    Text(RunningPlatform.iOS.localizedString).tag(RunningPlatform.iOS)
                }.frame(width: 150, alignment: .trailing)
                .onChange(of: platform, perform: { _ in
                    prepareAppInfos()
                })
            }.padding([.top, .bottom], 8)

            List(filteredAppInfos.indices, id:\.self) { idx in
                Safe($filteredAppInfos, index: idx) { appInfo in
                    VStack {
                        AppInfoSwiftUIView(appInfo: appInfo)
                        
                        if appInfo.wrappedValue != filteredAppInfos.last {
                            LinearGradient(gradient: Gradient(colors: [Color.red, Color.blue]), startPoint: .leading, endPoint: .trailing)
                            .frame(height: 1, alignment: .center)
                        }
                    }
                }
            }.onAppear(perform: {
                // copy resources to cache if no data
                if !checkResources() {
                    let destination = copyResources()
                    unzipResources(url: destination)
                }
                
                // get remote resources
                download()
                
                // read cache automatically
                let fm = FileManager.default
                let cacheFolderURL = fm.urls(for: .cachesDirectory, in: .userDomainMask).first
                let source = URL(fileURLWithPath: "AllApps.json", isDirectory: false, relativeTo: cacheFolderURL)
                let jsonData = try! Data(contentsOf: source)
                let decoder = JSONDecoder()
                let fileList = try! decoder.decode([String:String].self, from: jsonData)
                let subfolder = URL(fileURLWithPath: "jsons", isDirectory: true, relativeTo: cacheFolderURL)
                
                appInfos = fileList.map({ name, version -> AppInfo in
                    var filename = name
                    replaceSlashWithColon(&filename)
                    let url = URL(fileURLWithPath: filename + ".json", isDirectory: false, relativeTo: subfolder)
                    let jsonData = try! Data(contentsOf: url)
                    return try! decoder.decode(AppInfo.self, from: jsonData)
                })
                
                prepareAppInfos()
            })
        }
    }
    
    private func replaceSlashWithColon(_ str:inout String) {
        str = str.replacingOccurrences(of: "/", with: ":")
    }
    
    private func prepareAppInfos() {
        filteredAppInfos = appInfos.filter({
            if let lang = Locale.autoupdatingCurrent.languageCode,
               lang.lowercased().contains("zh") {
                return $0.lang == .zh_Hans
            }
            
            return $0.lang == .en
        }).filter({
            switch platform {
            case .iOS:
                return $0.platform == .iOS
            case .macOS:
                return $0.platform == .macOS
            case .watchOS:
                fatalError()
            case .tvOS:
                fatalError()
            case .all:
                return true
            }
        }).sorted(by: {
            $0.platform.rawValue.localizedCompare($1.platform.rawValue) == .orderedAscending
        })
    }
    
    private func follow() {
        // follow my twitter account.
        NSWorkspace.shared.open(URL(string: "https://twitter.com/owenzhao")!)
    }
    
    private func buyMeACoffee() {
        let alert = NSAlert()
        let bundle = Bundle.module
        alert.icon = bundle.image(forResource: "bmc-logo")
        alert.alertStyle = .informational
        alert.messageText = NSLocalizedString("Buy a coffee for the developer.", bundle: .module, comment: "")
        alert.addButton(withTitle: "OK")
        alert.addButton(withTitle: "Cancel")
        let replyButton = alert.runModal()
        if replyButton == .alertFirstButtonReturn {
            NSWorkspace.shared.open(URL(string: "https://buymeacoffee.com/owenzhao")!)
        }
    }
    
    private func fileBug() {
        
    }
}

extension MainSwiftUIView {
    func checkResources() -> Bool {
        let fm = FileManager.default
        let cacheFolderURL = fm.urls(for: .cachesDirectory, in: .userDomainMask).first
        let cachedFileURL = URL(fileURLWithPath: "AllApps.json", isDirectory: false, relativeTo: cacheFolderURL)
        
        return fm.fileExists(atPath: cachedFileURL.path)
    }
    
    func copyResources() -> URL {
//        let source = Bundle.main.url(forResource: "AllApps", withExtension: "zip")!
        let source = Bundle.module.url(forResource: "AllApps", withExtension: "zip")!
        let fm = FileManager.default
        let cacheFolderURL = fm.urls(for: .cachesDirectory, in: .userDomainMask).first
        let destination = URL(fileURLWithPath: source.lastPathComponent, isDirectory: false, relativeTo: cacheFolderURL)
        if fm.fileExists(atPath: destination.path) {
            try! fm.removeItem(at: destination)
        }
        try! fm.copyItem(at: source, to: destination)
        
        return destination
    }
    
    func unzipResources(url:URL) {
        let fm = FileManager.default
        try! fm.unzipItem(at: url, to: url.deletingLastPathComponent(), preferredEncoding: .utf8)
    }
    
    func download() {
        // download file list
        let url = URL(string: "https://parussoft.com/app_infos/AllApps.json")!
        let session = URLSession.shared.downloadTask(with: url) { [self] downloadFileURL, response, error in
            guard error == nil else {
                DispatchQueue.main.async {
                    let alert = NSAlert(error: error!)
                    alert.beginSheetModal(for: NSApp.mainWindow!, completionHandler: nil)
                }
                
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse, (200..<299).contains(httpResponse.statusCode) else {
                let alert = NSAlert()
                alert.alertStyle = .critical
                alert.messageText = "Server Error"
                alert.beginSheetModal(for: NSApp.mainWindow!, completionHandler: nil)
                return
            }
            
            // move url to my place
            let fm = FileManager.default
            let cacheFolderURL = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
            let fileName = "AllApps.json"
            let outputURL = URL(fileURLWithPath: fileName, isDirectory: false, relativeTo: cacheFolderURL)
            // get new app infos
            var newFileList = getAppInfos(downloadFileURL!)
            
            // comparing which to download
            if fm.fileExists(atPath: outputURL.path) {
                // get old app infos
                let oldFileList = getAppInfos(outputURL)
                
                for (name, version) in oldFileList {
                    if newFileList[name] == version {
                        newFileList[name] = nil
                    }
                }
            }

            // get original fileList
            let source = URL(fileURLWithPath: "AllApps.json", isDirectory: false, relativeTo: cacheFolderURL)
            let jsonData = try! Data(contentsOf: source)
            let decoder = JSONDecoder()
            let fileList = try! decoder.decode([String:String].self, from: jsonData)
            
            var toBeDownloadedFileList = [String:String]()
            
            newFileList.forEach { name, version in
                if let originalVersion = fileList[name],
                   originalVersion == version {
                    // do nothing
                } else {
                    toBeDownloadedFileList[name] = version
                }
            }
            
            let jsonFolder = URL(fileURLWithPath: "jsons", isDirectory: true, relativeTo: url)
            toBeDownloadedFileList.forEach {name, _ in
                let jsonURL = URL(string: name.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed)! + ".json", relativeTo: jsonFolder)
                download(jsonURL!)
            }
            
            // save temp files
            if fm.fileExists(atPath: outputURL.path) {
                try! FileManager.default.removeItem(at: outputURL)
            }
            
            try! fm.copyItem(at: downloadFileURL!, to: outputURL)
        }
        
        session.resume()
    }
    
    func getAppInfos(_ url:URL) -> [String:String] {
        let jsonData = try! Data(contentsOf: url)
        let decoder = JSONDecoder()
        
        return try! decoder.decode([String:String].self, from: jsonData)
    }
    
    func download(_ url:URL) {
        let session = URLSession.shared.downloadTask(with: url) { [self] fileURL, response, error in
            guard error == nil else {
                let alert = NSAlert(error: error!)
                alert.beginSheetModal(for: NSApp.mainWindow!, completionHandler: nil)
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse, (200..<299).contains(httpResponse.statusCode) else {
                let alert = NSAlert()
                alert.alertStyle = .critical
                alert.messageText = "Server Error"
                alert.beginSheetModal(for: NSApp.mainWindow!, completionHandler: nil)
                return
            }
            
            let decoder = JSONDecoder()
            let jsonData = try! Data(contentsOf: fileURL!)
            let appInfo = try! decoder.decode(AppInfo.self, from: jsonData)

            if let index = appInfos.firstIndex(where: {
                $0.name == appInfo.name
            }) {
                appInfos.replaceSubrange(index..<(index+1), with: [appInfo])
            } else {
                appInfos.append(appInfo)
            }
            
            prepareAppInfos()
            
            // save temp files
            let cacheFolderURL = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
            let subFolder = URL(fileURLWithPath: "jsons", isDirectory: true, relativeTo: cacheFolderURL)
            if !FileManager.default.fileExists(atPath: subFolder.path) {
                try! FileManager.default.createDirectory(at: subFolder, withIntermediateDirectories: false, attributes: nil)
            }
            
            var filename = "\(appInfo.name)_\(appInfo.lang)"
            replaceSlashWithColon(&filename)
            let url = URL(fileURLWithPath: filename + ".json", isDirectory: false, relativeTo: subFolder)
            if FileManager.default.fileExists(atPath: url.path) {
                try! FileManager.default.removeItem(at: url)
            }
            try! FileManager.default.copyItem(at: fileURL!, to: url)
        }
        
        session.resume()
    }
}

struct MainSwiftUIView_Previews: PreviewProvider {
    static var previews: some View {
        MainSwiftUIView(appInfos: [
            AppInfo(icon: png2json(name: "poster2_mac"),
                    name: NSLocalizedString("Poster 2", comment: ""),
                    version: "2.8.12",
                    changelog: "* Removed the unintended alert after posting finished. ",
                    homeURL:"",
                    appStoreURL: ""),
            AppInfo(icon: png2json(name: "subree"),
                    name: NSLocalizedString("SubRee", comment: ""),
                    version: "1.1.1",
                    changelog: "some logs",
                    homeURL: "",
                    appStoreURL: "")
        ]).environment(\.locale, .init(identifier: "zh"))
        .frame(width: 800, height: 600, alignment: .center)
    }
    
    static func png2json(name:String) -> String {
//        let url = Bundle.main.url(forResource: name, withExtension: "png")!
        let url = Bundle.module.url(forResource: name, withExtension: "png")!
        let data = try! Data(contentsOf: url)
        
        return data.base64EncodedString()
    }
}

struct Safe<T: RandomAccessCollection & MutableCollection, C: View>: View {
   
   typealias BoundElement = Binding<T.Element>
   private let binding: BoundElement
   private let content: (BoundElement) -> C

   init(_ binding: Binding<T>, index: T.Index, @ViewBuilder content: @escaping (BoundElement) -> C) {
      self.content = content
      self.binding = .init(get: { binding.wrappedValue[index] },
                           set: { binding.wrappedValue[index] = $0 })
   }
   
   var body: some View {
      content(binding)
   }
}
