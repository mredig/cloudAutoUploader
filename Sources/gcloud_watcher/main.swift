import Foundation

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
	let currentFiles = scrapeDirectory(at: directory)
	//check filesizes
	for file in currentFiles {
		let currentSize = getSize(ofFile: file)
		// compare values
		if let oldSize = watchedFiles[file] {
			if oldSize == currentSize && !workingFiles.contains(file) {
				workingFiles.insert(file)
				print("uploading \(file)")
				rcloneFile(file)
			}
		} else {
			print("new file: \(file)")
		}
		watchedFiles[file] = currentSize
	}

	//remove files no longer listed
	for (watchedFile, _) in watchedFiles {
		if !currentFiles.contains(watchedFile) {
			print("file removed: \(watchedFile)")
			watchedFiles.removeValue(forKey: watchedFile)
			workingFiles.remove(watchedFile)
		}
	}
}

func scrapeDirectory(at directory: URL) -> Set<URL> {
	let fm = FileManager.default

	do {
		let contents = try fm.contentsOfDirectory(at: directory, includingPropertiesForKeys: [], options: .skipsHiddenFiles)
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

func rcloneFile(_ file: URL) {
	let command = "rclone moveto GCloudAutoBackup:backups-mredig-nearline/autobackup/"
	var commandArgs = command.split(separator: " ").map { String($0) }
	commandArgs.insert(file.path, at: 2)
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
