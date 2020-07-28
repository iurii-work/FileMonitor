//
//  FileLogWindowController.swift
//  FileMonitor
//
//  Created by Iurii Skoliar on 7/28/20.
//  Copyright © 2020 Iurii Skoliar. All rights reserved.
//

import Cocoa

class FileLogWindowController: NSWindowController {
	var completionHandler: (() -> Void)?
	@objc dynamic var fileURL: URL?
}

extension NSNib.Name {
	static let fileLogWindow = NSNib.Name("FileLogWindow")
}

extension FileLogWindowController: NSWindowDelegate {
	func windowWillClose(_ notification: Notification) {
		if let completionHandler = self.completionHandler {
			completionHandler()
		}
	}
}
