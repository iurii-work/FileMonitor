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
	private var fileLogWindowControllers = [FileLogWindowController]()

	@IBAction func openFile(_ sender: Any) {
		let openPanel = NSOpenPanel()
		openPanel.canChooseDirectories = true
		openPanel.directoryURL = FileManager.default.homeDirectoryForCurrentUser
		if openPanel.runModal() == .OK, let fileURL = openPanel.url {
			let fileLogWindowController = FileLogWindowController(windowNibName: .fileLogWindow)
			fileLogWindowController.completionHandler = {
				[unowned self] in
				self.fileLogWindowControllers.removeAll { $0 === fileLogWindowController }
			}
			fileLogWindowController.fileURL = fileURL
			self.fileLogWindowControllers.append(fileLogWindowController)
			fileLogWindowController.showWindow(self)
		}
	}
}

extension ApplicationDelegate: NSApplicationDelegate {
	func applicationShouldOpenUntitledFile(_ application: NSApplication) -> Bool {
		self.openFile(self)
		return false
	}
}
