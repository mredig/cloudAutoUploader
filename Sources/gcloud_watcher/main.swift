import Foundation

let fm = FileManager.default
var watchedFiles = [URL: Int]()
var workingFiles = Set<URL>()

func main() {
	let args = getArgs()

	while true {
		updateDirectory(args.directory)
		sleep(1)
	}
}

func updateDirectory(_ directory: URL) {
	let currentFiles = scrapeDirectory(at: directory, skipHiddenFiles: false)
	//check filesizes
	for item in currentFiles {
		// check that it's not a stupid resource fork file
		guard !item.lastPathComponent.hasPrefix("._") else {
			continue
		}
		// check if directory or not as that makes a difference in handling
		var isDir: ObjCBool = false
		_ = fm.fileExists(atPath: item.path, isDirectory: &isDir)

		// get size
		let currentSize: Int
		if isDir.boolValue == true {
			currentSize = getSize(ofDirectory: item)
		} else {
			currentSize = getSize(ofFile: item)
		}

		// if size is stored and is the same as it was previously, that means that it's not changed since the last check - safe bet that it's done copying to the staging area, so it should be safe to start the upload
		if let oldSize = watchedFiles[item] {
			if oldSize == currentSize && !workingFiles.contains(item), oldSize != 0 {
				workingFiles.insert(item)
				print("uploading \(item)")
				rcloneFile(item)
			} else if isDir.boolValue == true, currentSize == 0, oldSize == 0 {
				delete(itemAt: item)
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

func getSize(ofFile file: URL) -> Int {
	var st = stat()
	let statResult = stat(file.path, &st)
	guard statResult != -1 else { return 0 }
	return Int(st.st_size)
}

func getSize(ofDirectory directory: URL) -> Int {
	guard scrapeDirectory(at: directory).count != 0 else { return 0 }
	let result = SystemUtility.shellArrayOut(["du", "-b", directory.path])
	guard result.returnCode == 0,
		let sizeStrExtra = result.stdOut.last else { fatalError("Error getting directory size") }
	let sizeStr = sizeStrExtra.replacingOccurrences(of: ##"\D.*"##, with: "", options: .regularExpression, range: nil)
	guard let dirSize = Int(sizeStr) else { fatalError("Error converting string size to int") }
	return dirSize
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
