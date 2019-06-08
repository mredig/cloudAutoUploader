import Foundation

var watchedFiles = [URL: Int]()

func main() {
	let args = getArgs()
	let allFiles = scrapeDirectory(at: args.directory)
	for file in allFiles {
		print(file)
		let size = getSize(ofFile: file)
		print(size)
//		do {
////			let resourceThings = try file.resourceValues(forKeys: Set([.fileSizeKey, .fileAllocatedSizeKey, .totalFileSizeKey, .totalFileAllocatedSizeKey]))
//			let attr = try FileManager.default.attributesOfItem(atPath: file.absoluteString)
//			let fileSize = attr[FileAttributeKey.size]
//			print(fileSize)
//		} catch {
//			NSLog("Couldn't retrieve size info: \(error)")
//		}
	}
//	print(allFiles)

}

func scrapeDirectory(at directory: URL) -> [URL] {
	let fm = FileManager.default

	print("scraping \(directory)")
	do {
		let contents = try fm.contentsOfDirectory(at: directory, includingPropertiesForKeys: [], options: .skipsHiddenFiles)
		return contents
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
	let statRes = stat(file.path, &st)
	guard statRes != -1 else { return 0 }
	return Int(st.st_size)
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
