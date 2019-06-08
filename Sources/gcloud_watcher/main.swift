import Foundation


func main() {
	let args = getArgs()
	let allFiles = scrapeDirectory(at: args.directory)
	print(allFiles)
}

func scrapeDirectory(at directory: URL) -> [URL] {
	let fm = FileManager.default

	print("scraping \(directory)")
	do {
		let contents = try fm.contentsOfDirectory(at: directory, includingPropertiesForKeys: [URLResourceKey.fileSizeKey], options: .skipsHiddenFiles)
		return contents
	} catch {
		fatalError("There was an error scraping the directory \(directory): \(error)")
	}
}

func getArgs() -> (directory: URL, nothing: String) {
	guard CommandLine.argc > 1 else {
		fatalError(printInstructions(false))
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


@discardableResult func printInstructions(_ printOut: Bool = true) -> String {
	let instructions = """
Usage: watcher [pathToWatchDirectory]
"""
	if printOut {
		print(instructions)
	}
	return instructions
}

main()
