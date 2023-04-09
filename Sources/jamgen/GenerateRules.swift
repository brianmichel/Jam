import ArgumentParser
import Foundation
import Jam
import OSLog

private let logger = Logger(subsystem: "me.foureyes.jam.gen", category: "GenerateRules")

enum FileFormat: String, ExpressibleByArgument {
    case webKitCompatible = "webkit"
    case chromiumCompatible = "chromium"
}

@main
struct GenerateRules: AsyncParsableCommand {
    enum GeneratorError: Error {
        case unsupportedOutputType
        case noParsedRules
    }
    @Option(help: "The input EasyList file you would like to parse into rules.")
    var inputFile: String

    @Option(help: "The output file you would like to write the rules into.")
    var outputFile: String

    @Option(help: "The output file format to write. Valid options are 'webkit' or 'chromium'.")
    var outputType: FileFormat

    mutating func run() async throws {
        guard outputType == .webKitCompatible else {
            throw GeneratorError.unsupportedOutputType
        }

        #if os(macOS)
        let expandedInput = inputFile.expandTildeInPath
        let expandedOutput = outputFile.expandTildeInPath
        #else
        let expandedInput = inputFile
        let expandedOutput = outputFile
        #endif

        let output = outputType

        print(
        """
        \n
               /$$  /$$$$$$  /$$$$$$/$$$$   /$$$$$$   /$$$$$$  /$$$$$$$
              |__/ |____  $$| $$_  $$_  $$ /$$__  $$ /$$__  $$| $$__  $$
               /$$  /$$$$$$$| $$ \\ $$ \\ $$| $$  \\ $$| $$$$$$$$| $$  \\ $$
              | $$ /$$__  $$| $$ | $$ | $$| $$  | $$| $$_____/| $$  | $$
              | $$|  $$$$$$$| $$ | $$ | $$|  $$$$$$$|  $$$$$$$| $$  | $$
              | $$ \\_______/|__/ |__/ |__/ \\____  $$ \\_______/|__/  |__/
         /$$  | $$                         /$$  \\ $$
        |  $$$$$$/                        |  $$$$$$/
         \\______/                          \\______/

        Generating Rules:
        Input File: \(expandedInput)
        Output File: \(expandedOutput)
        Output Type: \(output.rawValue)
        \n
        """
        )

        let parser = RuleParser()
        let parsed = await parser.parse(file: expandedInput)
        guard parsed.count > 0 else {
            throw GeneratorError.noParsedRules
        }

        print("Parsed \(parsed.count) rules...")

        let rules = try outputType.generator!.generateData(for: parsed)

        print("Writing \(rules.count.formatted(.byteCount(style: .file))) bytes to \(expandedOutput)")

        let manager = FileManager()
        guard manager.createFile(atPath: expandedOutput, contents: rules) else {
            print("Unable to write file to disk.")
            return
        }

        print("Successfully wrote rules file to \(expandedOutput)")
    }
}

extension FileFormat {
    var generator: RuleGenerator? {
        switch self {
        case .chromiumCompatible:
            return nil
        case .webKitCompatible:
            return WebKitRuleGenerator()
        }
    }
}

#if os(macOS)
extension String {
    var expandTildeInPath: String {
        let manager = FileManager()
        return replacingOccurrences(of: "~", with: manager.homeDirectoryForCurrentUser.path)
    }
}
#endif
