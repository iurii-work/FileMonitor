//
//  ApplicationDelegate.swift
//  FileMonitor
//
//  Created by Iurii Skoliar on 7/28/20.
//  Copyright © 2020 Iurii Skoliar. All rights reserved.
//

import Cocoa

@NSApplicationMain
class ApplicationDelegate: NSObject {
	@IBAction func openFile(_ sender: Any) {
		let openPanel = NSOpenPanel()
		openPanel.canChooseDirectories = true
		openPanel.directoryURL = FileManager.default.homeDirectoryForCurrentUser
		if openPanel.runModal() == .OK, let fileURL = openPanel.url {
			print("TODO: Open file (\(fileURL.path))")
		}
	}
}

extension ApplicationDelegate: NSApplicationDelegate {
	func applicationShouldOpenUntitledFile(_ application: NSApplication) -> Bool {
		self.openFile(self)
		return false
	}
}
