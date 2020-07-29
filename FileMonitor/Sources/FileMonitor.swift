//
//  FileMonitor.swift
//  FileMonitor
//
//  Created by Iurii Skoliar on 7/29/20.
//  Copyright © 2020 Iurii Skoliar. All rights reserved.
//

import Foundation

class FileMonitor: NSObject {
	private weak var delegate: FileMonitorDelegateProtocol?
	private var latestEventID: FSEventStreamEventId?
	private let paths = NSCountedSet()
	private var thread: Thread?

	init(delegate: FileMonitorDelegateProtocol) {
		self.delegate = delegate
	}

	func attachFile(at path: String) {
		let paths = self.paths
		if !paths.contains(path) {
			if paths.count == 0 {
				self.latestEventID = FSEventsGetCurrentEventId()
			} else {
				self.suspend()
			}
		}
		paths.add(path)
		if paths.count(for: path) == 1 {
			self.resume(with: paths.allObjects)
		}
	}

	func detachFile(at path: String) {
		let paths = self.paths
		if paths.count(for: path) == 1 {
			self.suspend()
		}
		paths.remove(path)
		if !paths.contains(path) {
			if paths.count == 0 {
				self.latestEventID = nil
			} else {
				self.resume(with: paths.allObjects)
			}
		}
	}
}

protocol FileMonitorDelegateProtocol: AnyObject {
	func fileMonitor(_ fileMonitor: FileMonitor, event: FileEvent)
}

class FileEvent: NSObject {
	struct Flags: Hashable, OptionSet {
		let rawValue: FSEventStreamEventFlags

		init(rawValue: FSEventStreamEventFlags) {
			self.rawValue = rawValue
		}

		init(_ rawValue: Int) {
			self.init(rawValue: FSEventStreamEventFlags(truncatingIfNeeded: rawValue))
		}

		static let eventIDsWrapped = Flags(kFSEventStreamEventFlagEventIdsWrapped)
		static let historyDone = Flags(kFSEventStreamEventFlagHistoryDone)
		static let itemCloned = Flags(kFSEventStreamEventFlagItemCloned)
		static let itemChangeOwner = Flags(kFSEventStreamEventFlagItemChangeOwner)
		static let itemCreated = Flags(kFSEventStreamEventFlagItemCreated)
		static let itemFinderInfoMod = Flags(kFSEventStreamEventFlagItemFinderInfoMod)
		static let itemInodeMetaMod = Flags(kFSEventStreamEventFlagItemInodeMetaMod)
		static let itemIsDir = Flags(kFSEventStreamEventFlagItemIsDir)
		static let itemIsFile = Flags(kFSEventStreamEventFlagItemIsFile)
		static let itemIsHardlink = Flags(kFSEventStreamEventFlagItemIsHardlink)
		static let itemIsLastHardlink = Flags(kFSEventStreamEventFlagItemIsLastHardlink)
		static let itemIsSymlink = Flags(kFSEventStreamEventFlagItemIsSymlink)
		static let itemModified = Flags(kFSEventStreamEventFlagItemModified)
		static let itemRemoved = Flags(kFSEventStreamEventFlagItemRemoved)
		static let itemRenamed = Flags(kFSEventStreamEventFlagItemRenamed)
		static let itemXattrMod = Flags(kFSEventStreamEventFlagItemXattrMod)
		static let kernelDropped = Flags(kFSEventStreamEventFlagKernelDropped)
		static let mount = Flags(kFSEventStreamEventFlagMount)
		static let mustScanSubDirs = Flags(kFSEventStreamEventFlagMustScanSubDirs)
		static let none = Flags(kFSEventStreamEventFlagNone)
		static let ownEvent = Flags(kFSEventStreamEventFlagOwnEvent)
		static let rootChanged = Flags(kFSEventStreamEventFlagRootChanged)
		static let unmount = Flags(kFSEventStreamEventFlagUnmount)
		static let userDropped = Flags(kFSEventStreamEventFlagUserDropped)
	}

	let flags: Flags
	@objc let path: String

	init(flags: Flags, path: String) {
		self.flags = flags
		self.path = path
	}
}

extension FileEvent {
	@objc var flagsDescription: String {
		let map: [Flags: String] = [
			.eventIDsWrapped: "EventIDsWrapped",
			.historyDone: "HistoryDone",
			.itemCloned: "ItemCloned",
			.itemChangeOwner: "ItemChangeOwner",
			.itemCreated: "ItemCreated",
			.itemFinderInfoMod: "ItemFinderInfoMod",
			.itemInodeMetaMod: "ItemInodeMetaMod",
			.itemIsDir: "ItemIsDir",
			.itemIsFile: "ItemIsFile",
			.itemIsHardlink: "ItemIsHardlink",
			.itemIsLastHardlink: "ItemIsLastHardlink",
			.itemIsSymlink: "ItemIsSymlink",
			.itemModified: "ItemModified",
			.itemRemoved: "ItemRemoved",
			.itemRenamed: "ItemRenamed",
			.itemXattrMod: "ItemXattrMod",
			.kernelDropped: "KernelDropped",
			.mount: "Mount",
			.mustScanSubDirs: "MustScanSubDirs",
			.none: "None",
			.ownEvent: "OwnEvent",
			.rootChanged: "RootChanged",
			.unmount: "Unmount",
			.userDropped: "UserDropped"
		]
		let filteredMap = map.filter { self.flags.contains($0.key) }
		return filteredMap.values.sorted().joined(separator: ", ")
	}
}

#if DEBUG
extension FileEvent {
	override var debugDescription: String { "\(self.path): \(self.flagsDescription)" }
}
#endif

extension FileMonitor {
	@objc func observe(paths: [String]) {
		let callback: CoreServices.FSEventStreamCallback = {
			(streamRef, clientCallBackInfo, numberOfEvents, eventPaths, eventFlags, eventIDs) in
			if let clientCallBackInfo = clientCallBackInfo {
				let paths = Unmanaged<CFArray>.fromOpaque(eventPaths).takeUnretainedValue() as! [String]
				let monitor = Unmanaged<FileMonitor>.fromOpaque(clientCallBackInfo).takeUnretainedValue()
				for index in 0..<numberOfEvents {
					let flags = FileEvent.Flags(rawValue: eventFlags[index])
					let path = (paths[index] as NSString).standardizingPath
					let event = FileEvent(flags: flags, path: path)
					monitor.delegate?.fileMonitor(monitor, event: event)
				}
				monitor.latestEventID = FSEventStreamGetLatestEventId(streamRef)
			}
		}
		let info = Unmanaged.passUnretained(self).toOpaque()
		var context = FSEventStreamContext(version: 0, info: info, retain: nil, release: nil, copyDescription: nil)
		let pathsToWatch = paths as CFArray
		let flags = UInt32(kFSEventStreamCreateFlagFileEvents | kFSEventStreamCreateFlagNoDefer | kFSEventStreamCreateFlagUseCFTypes)
		if let latestEventID = self.latestEventID, let eventStream = FSEventStreamCreate(kCFAllocatorDefault, callback, &context, pathsToWatch, latestEventID, 0.0, flags) {
			let runLoop = CFRunLoopGetCurrent() as CFRunLoop
			let mode = CFRunLoopMode.defaultMode as CFRunLoopMode
			FSEventStreamScheduleWithRunLoop(eventStream, runLoop, mode.rawValue)
			FSEventStreamStart(eventStream)
			let seconds = Date.distantFuture.timeIntervalSinceNow
			while CFRunLoopRunInMode(mode, seconds, false) != .stopped { continue }
			FSEventStreamStop(eventStream)
			FSEventStreamUnscheduleFromRunLoop(eventStream, runLoop, mode.rawValue)
			FSEventStreamInvalidate(eventStream)
			FSEventStreamRelease(eventStream)
		}
	}

	func resume(with paths: [Any]) {
		let thread = Thread(target: self, selector: #selector(observe(paths:)), object: paths)
		self.thread = thread
#if TEST
		self.perform(#selector(postDidStartObservingNotification), on: thread, with: nil, waitUntilDone: false)
#endif
		thread.start()
	}

	@objc func stopObserving() {
		CFRunLoopStop(CFRunLoopGetCurrent())
	}

	func suspend() {
		if let thread = self.thread {
#if TEST
			self.perform(#selector(postWillStopObservingNotification), on: thread, with: nil, waitUntilDone: false)
#endif
			self.perform(#selector(stopObserving), on: thread, with: nil, waitUntilDone: false)
			self.thread = nil
		}
	}
}

#if TEST
extension FileMonitor {
	static let didStartObservingNotification = NSNotification.Name("FileMonitor.DidStartObservingNotification")
	static let willStopObservingNotification = NSNotification.Name("FileMonitor.WillStopObservingNotification")

	@objc func postDidStartObservingNotification() {
		NotificationCenter.default.post(Notification(name: FileMonitor.didStartObservingNotification, object: self))
	}

	@objc func postWillStopObservingNotification() {
		NotificationCenter.default.post(Notification(name: FileMonitor.willStopObservingNotification, object: self))
	}
}
#endif
