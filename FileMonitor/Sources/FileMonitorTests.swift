//
//  FileMonitorTests.swift
//  FileMonitor
//
//  Created by Iurii Skoliar on 7/29/20.
//  Copyright © 2020 Iurii Skoliar. All rights reserved.
//

import XCTest
@testable import FileMonitor

class FileMonitorTests: XCTestCase {
	func testFileEvent() throws {
		let flags: FileEvent.Flags = []
		let path = NSTemporaryDirectory()
		let event = FileEvent(flags: flags, path: path)
		XCTAssertEqual(event.flags, flags)
		XCTAssertEqual(event.path, path)
		XCTAssertNotNil(event.flagsDescription)
	}

	func testFileMonitor() throws {
		// Create folder
		let fileManager = FileManager.default
		let temporaryDirectoryURL = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
		let folderURL = temporaryDirectoryURL.appendingPathComponent(UUID().uuidString, isDirectory: true)
		try fileManager.createDirectory(at: folderURL, withIntermediateDirectories: false, attributes: nil)

		// Start observing folder
		let fileMonitor = FileMonitor(delegate: self)
		self.expectation(forNotification: FileMonitor.didStartObservingNotification, object: fileMonitor)
		let folderPath = folderURL.path
		fileMonitor.attachFile(at: folderPath)
		self.waitForExpectations(timeout: 1.0, handler: nil)

		// Create child folder
		self.expectation(forNotification: FileMonitorTests.fileMonitorEventNotification, object: fileMonitor, handler: {
			guard let event = $0.userInfo?[FileMonitorTests.eventKey] as? FileEvent else {
				return false
			}
			return event.flags.contains(.itemCreated) && (event.path == folderPath)
		})
		var oldChildFolderURL = folderURL.appendingPathComponent(UUID().uuidString, isDirectory: true)
		try fileManager.createDirectory(at: oldChildFolderURL, withIntermediateDirectories: false, attributes: nil)
		self.waitForExpectations(timeout: 1.0, handler: nil)

		// Start observing child folder
		self.expectation(forNotification: FileMonitor.willStopObservingNotification, object: fileMonitor)
		self.expectation(forNotification: FileMonitor.didStartObservingNotification, object: fileMonitor)
		let oldChildFolderPath = oldChildFolderURL.path
		fileMonitor.attachFile(at: oldChildFolderPath)
		self.waitForExpectations(timeout: 1.0, handler: nil)

		// Modify child folder
		self.expectation(forNotification: FileMonitorTests.fileMonitorEventNotification, object: fileMonitor, handler: {
			guard let event = $0.userInfo?[FileMonitorTests.eventKey] as? FileEvent else {
				return false
			}
			return event.flags.isDisjoint(with: [.itemFinderInfoMod, .itemInodeMetaMod, .itemModified, .itemXattrMod]) && (event.path == oldChildFolderPath)
		})
		var oldChildFolderValues = URLResourceValues()
		oldChildFolderValues.contentModificationDate = Date()
		try oldChildFolderURL.setResourceValues(oldChildFolderValues)
		self.waitForExpectations(timeout: 1.0, handler: nil)

		// Stop observing child folder
		self.expectation(forNotification: FileMonitor.willStopObservingNotification, object: fileMonitor)
		self.expectation(forNotification: FileMonitor.didStartObservingNotification, object: fileMonitor)
		fileMonitor.detachFile(at: oldChildFolderPath)
		self.waitForExpectations(timeout: 1.0, handler: nil)

		// Rename child folder
		let newChildFolderURL = folderURL.appendingPathComponent(UUID().uuidString, isDirectory: true)
		let newChildFolderPath = newChildFolderURL.path
		self.expectation(forNotification: FileMonitorTests.fileMonitorEventNotification, object: fileMonitor, handler: {
			guard let event = $0.userInfo?[FileMonitorTests.eventKey] as? FileEvent else {
				return false
			}
			return event.flags.contains(.itemRenamed) && (event.path == newChildFolderPath)
		})
		try fileManager.replaceItem(at: newChildFolderURL, withItemAt: oldChildFolderURL, backupItemName: nil, options: [], resultingItemURL: nil)
		self.waitForExpectations(timeout: 1.0, handler: nil)

		// Remove child folder
		self.expectation(forNotification: FileMonitorTests.fileMonitorEventNotification, object: fileMonitor, handler: {
			guard let event = $0.userInfo?[FileMonitorTests.eventKey] as? FileEvent else {
				return false
			}
			return event.flags.contains(.itemRemoved) && event.path.contains(newChildFolderPath)
		})
		try fileManager.removeItem(at: newChildFolderURL)
		self.waitForExpectations(timeout: 1.0, handler: nil)

		// Stop observing
		self.expectation(forNotification: FileMonitor.willStopObservingNotification, object: fileMonitor)
		fileMonitor.detachFile(at: folderPath)
		self.waitForExpectations(timeout: 1.0, handler: nil)

		// Remove folder
		try fileManager.removeItem(at: folderURL)
	}
}

extension FileMonitorTests: FileMonitorDelegateProtocol {
	static let eventKey = "FileMonitorTests.Event"
	static let fileMonitorEventNotification = Notification.Name("FileMonitorTests.FileMonitorEventNotification")

	func fileMonitor(_ fileMonitor: FileMonitor, event: FileEvent) {
		let userInfo = [FileMonitorTests.eventKey: event]
		NotificationCenter.default.post(name: FileMonitorTests.fileMonitorEventNotification, object: fileMonitor, userInfo: userInfo)
	}
}
