//
//  MainSwiftUIView.swift
//  App Demo
//
//  Created by zhaoxin on 2021/8/23.
//

import SwiftUI
import ZIPFoundation

public struct MainSwiftUIView: View {
    public init(showCloseButton:Bool = false, appInfos:[AppInfo]) {
        self.showCloseButton = showCloseButton
        self.appInfos = appInfos
    }
    
    public init(showCloseButton:Bool = false) {
        self.showCloseButton = showCloseButton
    }
    
    var showCloseButton:Bool
    
    @Environment(\.presentationMode) private var presentationMode
    @Environment(\.openURL) private var openURL
    
    @State var appInfos = [AppInfo]()
    @State private var filteredAppInfos = [AppInfo]()
    @State public var platform:RunningPlatform = .all
    
    @State private var fileHolder:URL? = nil
    
    public var body: some View {
        VStack {
            HStack {
                if showCloseButton {
                    Button {
                        presentationMode.wrappedValue.dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .resizable()
                            .frame(width: 20, height: 20, alignment: .center)
                            .aspectRatio(contentMode: .fit)
                            .foregroundColor(.red)
                            .padding([.leading, .trailing], 10)
                    }
                    .buttonStyle(.borderless)
                    .help(Text("Close"))
                }
                
                Spacer()
                
                Button(action: fileBug, label: {
                    Image(systemName: "ladybug")
                        .resizable()
                        .frame(width: 24, height: 24, alignment: .center)
                        .help(Text("Report an issue to developer", bundle: .module))
                }).buttonStyle(PlainButtonStyle())
                
                Button(action: buyMeACoffee, label: {
                    HStack {
                        Image("bmc-logo", bundle: .module)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 24, height: 24, alignment: .center)
                            .help(Text("Buy developer a coffee", bundle: .module))
                            
                    }
                }).buttonStyle(PlainButtonStyle())
                
                Button(action: follow, label: {
                    Image("twitter", bundle: .module)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 24, height: 24, alignment: .center)
                        .help(Text("Follow developer on Twitter", bundle: .module))
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
                
                DispatchQueue.main.async {
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
                    
                    debugPrint("tableview loaded.")
                }
            })
        }
    }
    
    private func replaceSlashWithColon(_ str:inout String) {
        str = str.replacingOccurrences(of: "/", with: ":")
    }
    
    private func prepareAppInfos() {
        filteredAppInfos = appInfos.filter({  // remove current app
            if let bundleId = Bundle.main.bundleIdentifier,
               bundleId == $0.bundleId {
                return false
            }
            
            return true
        }).filter({
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
        
        debugPrint("reload tableview.")
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
//        alert.messageText = NSLocalizedString("Buy a coffee for the developer！", bundle: .module, comment: "")
        alert.informativeText = NSLocalizedString("Thank you. But Apple only allows this in IAP.", bundle: .module, comment: "")
        alert.addButton(withTitle: NSLocalizedString("OK", bundle: .module, comment: ""))
//        alert.addButton(withTitle: NSLocalizedString("Buy", bundle: .module, comment: ""))
//        alert.addButton(withTitle: NSLocalizedString("Close", bundle: .module, comment: ""))
//        let replyButton = alert.runModal()
//        if replyButton == .alertFirstButtonReturn {
//            openURL(URL(string: "https://buymeacoffee.com/owenzhao")!)
//        }
    }
    
    private func fileBug() {
        let id = Bundle.main.bundleIdentifier!
        let appName:String
        
        switch id {
        case "com.parussoft.iOS-Poster-2":
            appName = NSLocalizedString("Poster 2", bundle: .module, comment: "")
        case "com.parussoft.Poster":
            appName = NSLocalizedString("Poster 2", bundle: .module, comment: "")
        case "com.parussoft.SubRee":
            appName = NSLocalizedString("SubRee", bundle: .module, comment: "")
        case "com.parussoft.App-Demo":
            appName = NSLocalizedString("App Demo", bundle: .module, comment: "")
        case "com.parussoft.Xliff-Tool":
            appName = NSLocalizedString("Xliff Tool", bundle: .module, comment: "")
        default:
            appName = id
        }
        
        let mailTo = "owenzx+feedback@gmail.com"
        let title = String.localizedStringWithFormat(NSLocalizedString("Feedback for App %@", bundle: .module, comment: ""), appName)
        let detail = NSLocalizedString("Please use Chinese or English.", bundle: .module, comment: "")
        
        let service = NSSharingService(named: NSSharingService.Name.composeEmail)!
        service.subject = title
        service.recipients = [mailTo]
        service.perform(withItems: [detail])
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
                DispatchQueue.main.async {
                    let alert = NSAlert()
                    alert.alertStyle = .critical
                    alert.messageText = "Server Error"
                    alert.beginSheetModal(for: NSApp.mainWindow!, completionHandler: nil)
                }
                
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
                var newName = name
                replaceSlashWithColon(&newName)
                let jsonURL = URL(string: newName.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed)! + ".json", relativeTo: jsonFolder)
                download(jsonURL!)
            }
            
            // save temp files
            if fm.fileExists(atPath: outputURL.path) {
                try! FileManager.default.removeItem(at: outputURL)
            }
            
            try! fm.copyItem(at: downloadFileURL!, to: outputURL)
            
            debugPrint("download file copied.")
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
                assertionFailure("\(error!)")
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse, (200..<299).contains(httpResponse.statusCode) else {
                assertionFailure("\(error!)")
                return
            }
            
            self.fileHolder = fileURL
            
            let decoder = JSONDecoder()
            let jsonData = try! Data(contentsOf: fileHolder!)
            let appInfo = try! decoder.decode(AppInfo.self, from: jsonData)

            if let index = appInfos.firstIndex(where: {
                $0.name == appInfo.name
            }) {
                appInfos.replaceSubrange(index..<(index+1), with: [appInfo])
            } else {
                appInfos.append(appInfo)
            }
            
            DispatchQueue.main.async {
                prepareAppInfos()
            }
            
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
            try! FileManager.default.copyItem(at: fileHolder!, to: url)
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
                    appStoreURL: "",
                    bundleId: "com.parussoft.Poster"),
            AppInfo(icon: png2json(name: "subree"),
                    name: NSLocalizedString("SubRee", comment: ""),
                    version: "1.1.1",
                    changelog: "some logs",
                    homeURL: "",
                    appStoreURL: "",
                    bundleId: "com.parussoft.subree")
        ]).environment(\.locale, .init(identifier: "zh"))
        .frame(width: 800, height: 600, alignment: .center)
        
        MainSwiftUIView(showCloseButton: true,
                        appInfos: [
            AppInfo(icon: png2json(name: "poster2_mac"),
                    name: NSLocalizedString("Poster 2", comment: ""),
                    version: "2.8.12",
                    changelog: "* Removed the unintended alert after posting finished. ",
                    homeURL:"",
                    appStoreURL: "",
                    bundleId: "com.parussoft.Poster"),
            AppInfo(icon: png2json(name: "subree"),
                    name: NSLocalizedString("SubRee", comment: ""),
                    version: "1.1.1",
                    changelog: "some logs",
                    homeURL: "",
                    appStoreURL: "",
                    bundleId: "com.parussoft.subree")
        ])
        .environment(\.locale, .init(identifier: "zh"))
        .frame(width: 800, height: 600, alignment: .center)
        
        
    }
    
    static func png2json(name:String) -> String {
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
