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
	lazy var fileMonitor = FileMonitor(delegate: self)

	@IBAction func openFile(_ sender: Any) {
		let openPanel = NSOpenPanel()
		openPanel.canChooseDirectories = true
		openPanel.directoryURL = FileManager.default.homeDirectoryForCurrentUser
		if openPanel.runModal() == .OK, let fileURL = openPanel.url?.standardizedFileURL {
			let filePath = fileURL.path
			self.fileMonitor.attachFile(at: filePath)
			let fileLogWindowController = FileLogWindowController(windowNibName: .fileLogWindow)
			fileLogWindowController.completionHandler = {
				[unowned self] in
				self.fileLogWindowControllers.removeAll { $0 === fileLogWindowController }
				self.fileMonitor.detachFile(at: filePath)
			}
			fileLogWindowController.fileURL = fileURL
			self.fileLogWindowControllers.append(fileLogWindowController)
			fileLogWindowController.showWindow(self)
		}
	}
}

extension ApplicationDelegate: FileMonitorDelegateProtocol {
	func fileMonitor(_ fileMonitor: FileMonitor, event: FileEvent) {
		DispatchQueue.main.async {
			self.fileLogWindowControllers.forEach { (fileLogWindowController) in
				if let fileURL = fileLogWindowController.fileURL, event.path.hasPrefix(fileURL.path) {
					fileLogWindowController.log(event: event)
				}
			}
		}
	}
}

extension ApplicationDelegate: NSApplicationDelegate {
#if !TEST
	func applicationShouldOpenUntitledFile(_ application: NSApplication) -> Bool {
		self.openFile(self)
		return false
	}
#endif
}
