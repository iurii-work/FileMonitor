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
	@IBOutlet private var eventsController: NSArrayController!
	@objc dynamic var fileURL: URL?

	func log(event: FileEvent) {
		self.eventsController.addObject(event)
	}
}

extension NSNib.Name {
	static let fileLogWindow = NSNib.Name("FileLogWindow")
}

extension FileLogWindowController: NSTableViewDelegate {
	func tableView(_ tableView: NSTableView, shouldSelectRow row: Int) -> Bool { false }
}

extension FileLogWindowController: NSWindowDelegate {
	func windowWillClose(_ notification: Notification) {
		if let completionHandler = self.completionHandler {
			completionHandler()
		}
	}
}
