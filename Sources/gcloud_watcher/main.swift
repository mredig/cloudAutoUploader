import Foundation

let fm = FileManager.default
var watchedFiles = [URL: Int]()
var workingFiles = Set<URL>()

func main() {
	let args = getArgs()

	let readme = createReadme(in: args.directory)

	while true {
		updateDirectory(args.directory, ignoringReadme: readme)
		sleep(1)
	}
}

func updateDirectory(_ directory: URL, ignoringReadme readme: URL) {
	let currentFiles = scrapeDirectory(at: directory, skipHiddenFiles: false)
	//check filesizes
	for item in currentFiles {
		// check that it's not a stupid resource fork file
		guard !item.lastPathComponent.hasPrefix("._") && item != readme else {
			continue
		}
		// check if directory or not as that makes a difference in handling
		let isDir = isDirectory(item: item)

		// get size
		let currentSize: Int
		if isDir {
			currentSize = getSize(ofDirectory: item)
			guard currentSize != 0 else {
				if watchedFiles[item] != nil {
					delete(itemAt: item)
				}
				continue
			}
		} else {
			currentSize = getSize(ofFile: item)
		}

		// if size is stored and is the same as it was previously, that means that it's not changed since the last check - safe bet that it's done copying to the staging area, so it should be safe to start the upload
		if let oldSize = watchedFiles[item] {
			if oldSize == currentSize && !workingFiles.contains(item), oldSize != 0 {
				workingFiles.insert(item)
				print("uploading \(item)")
				rcloneFile(item)
			}
		} else {
			print("new file: \(item)")
		}
		watchedFiles[item] = currentSize
	}

	//remove files that have been uploaded
	for (watchedFile, _) in watchedFiles {
		if !currentFiles.contains(watchedFile) {
			print("file removed: \(watchedFile)")
			watchedFiles.removeValue(forKey: watchedFile)
			workingFiles.remove(watchedFile)
		}
	}
}

func createReadme(in directory: URL) -> URL {
	let readmeInfo = """
Place files in this folder to upload them to the google cloud autobackup folder.

There is a bug when adding directories that causes smb to fail. I believe that it's got something to do with locking files that in progress copying (both doing `du -b [directory]` and running `stat` on all files for a cumulative calculation during a directory copy operation in code seem to cause it to fail - it MIGHT work with another networking transfer... but not tested)

A slight workaround for this is to create an empty directory (new empty directories won't be uploaded), and then add *FILES* to it *ALL AT ONCE* - once a subsequent scrape occurs, new items will not able to be added (unless they are *already* in progress). This means to shift/comand select multiple files in Finder and move/copy them in *ONE* move.

Another workaround is to simply zip up a directory before uploading. This, of course, will only be acceptable in some scenarios.
"""
	let infoPath = directory.appendingPathComponent("readme.info.md")
	do {
		try readmeInfo.write(to: infoPath, atomically: true, encoding: .utf8)
	} catch {
		print("Error saving readme: \(error)")
	}
	return infoPath
}

func delete(itemAt path: URL) {
	do {
		try fm.removeItem(at: path)
		let lastComponent = path.lastPathComponent
		let metaFile = path.deletingLastPathComponent().appendingPathComponent("._" + lastComponent)
		if fm.fileExists(atPath: metaFile.path) {
			try fm.removeItem(at: metaFile)
		}
	} catch {
		print("Error removing item: \(error)")
	}
}

func scrapeDirectory(at directory: URL, skipHiddenFiles: Bool = true) -> Set<URL> {
	let skipHidden: FileManager.DirectoryEnumerationOptions
	if skipHiddenFiles {
		skipHidden = .skipsHiddenFiles
	} else {
		skipHidden = []
	}
	do {
		let contents = try fm.contentsOfDirectory(at: directory, includingPropertiesForKeys: [], options: skipHidden)
		return Set(contents)
	} catch {
		fatalError("There was an error scraping the directory \(directory): \(error)")
	}
}

func getArgs() -> (directory: URL, nothing: String) {
	guard CommandLine.argc > 1 else {
		fatalError(outputInstructions(false))
	}

	var directoryString = ""
	for index in 0..<CommandLine.argc {
		let index = Int(index)
		let argument = CommandLine.arguments[index]
		if index == 1 {
			directoryString = argument
		}
	}

	let directory = URL(fileURLWithPath: directoryString)
	return (directory, "")
}

func isDirectory(item: URL) -> Bool {
	var isDir: ObjCBool = false
	_ = fm.fileExists(atPath: item.path, isDirectory: &isDir)
	return isDir.boolValue
}

func getSize(ofFile file: URL) -> Int {
	var st = stat()
	let statResult = stat(file.path, &st)
	guard statResult != -1 else { return 0 }
	return Int(st.st_size)
}

func getSize(ofDirectory directory: URL) -> Int {
//	guard scrapeDirectory(at: directory).count != 0 else { return 0 }
//	let result = SystemUtility.shellArrayOut(["du", "-b", directory.path])
//	guard result.returnCode == 0,
//		let sizeStrExtra = result.stdOut.last else { fatalError("Error getting directory size") }
//	let sizeStr = sizeStrExtra.replacingOccurrences(of: ##"\D.*"##, with: "", options: .regularExpression, range: nil)
//	guard let dirSize = Int(sizeStr) else { fatalError("Error converting string size to int") }
//	return dirSize

	let errorHandler = { (url: URL, error: Error) -> Bool in
		print("error scraping url \(url): \(error)")
		return true
	}
	guard let enumerator = fm.enumerator(at: directory, includingPropertiesForKeys: nil, options: [], errorHandler: errorHandler) else { return 0 }
	var outSize = 0
	for plainItem in enumerator.allObjects {
		guard let item = plainItem as? URL else {
			print("not url: \(plainItem)")
			continue
		}
		guard !isDirectory(item: item) else {
			print("skipping directory: \(item)")
			continue
		}
		outSize += getSize(ofFile: item)
	}
	return outSize
}

func rcloneFile(_ file: URL) {
//	let command = "rclone -u moveto GCloudAutoBackup:backups-mredig-nearline/autobackup/"
	let command = "rclone -u --bwlimit 0.25M moveto GCloudAutoBackup:backups-mredig-nearline/autobackup/"
	var commandArgs = command.split(separator: " ").map { String($0) }
	commandArgs.insert(file.path, at: commandArgs.count - 1)
	commandArgs[commandArgs.count - 1] += file.lastPathComponent
//	print(commandArgs)

	DispatchQueue.global().async {
		let info = SystemUtility.shell(commandArgs)
		print(info)
	}
}


@discardableResult func outputInstructions(_ printOut: Bool = true) -> String {
	let instructions = """
Usage: watcher [pathToWatchDirectory]
"""
	if printOut {
		print(instructions)
	}
	return instructions
}

main()
