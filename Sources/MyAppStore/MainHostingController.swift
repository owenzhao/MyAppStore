//
//  MainHostingController.swift
//  App Demo
//
//  Created by zhaoxin on 2021/8/23.
//

import Cocoa
import SwiftUI

public class MainHostingController: NSHostingController<MainSwiftUIView> {
    @objc required dynamic init?(coder: NSCoder) {
        super.init(coder: coder, rootView: MainSwiftUIView())
    }
    
    public override init(rootView: MainSwiftUIView) {
        super.init(rootView: rootView)
    }
    
    public override func viewWillAppear() {
        super.viewWillAppear()
        
        if let window = view.window {
            window.title = NSLocalizedString("Developer Other Apps", bundle: .module, comment: "")
            var frame = window.frame
            frame.size = NSSize(width: 800, height: 600)
            window.setFrame(frame, display: false, animate: false)
            window.center()
        }
    }
}
