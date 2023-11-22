//
//  Main.swift
//  
//
//  Created by John Biggs on 17.11.23.
//

import Foundation
import ArgumentParser
import PiConfig

@main
struct PiConfigEval: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "piconfig-eval")

    static var fileManager: FileManager = .default
    static var processInfo: ProcessInfo = .processInfo

    @Option(
        name: .shortAndLong,
        help: "Include environment variables in the initial definitions matching the given glob."
    )
    var includeEnv: [String] = []

    @Flag(help: "Verify that the configuration file is sane, without evaluating it.")
    var checkOnly: Bool = false

    @Flag(
        inversion: .prefixedNo,
        help: "If using with '--format json', toggles value interpretation into types other than String."
    )
    var typedValues: Bool = true

    @Option(help: "What the output format should be.")
    var format: OutputFormat = .dotenv

    @Option(
        name: .shortAndLong,
        help: "Where to write the output file (defaults to stdout)."
    )
    var outputFile: String?

    @Option(
        name: [.customShort("D", allowingJoined: true), .long],
        help: "Define a property to a value before interpreting the file."
    )
    var defines: [Define] = []

    @Argument(help: "The configuration file to interpret.")
    var configFile: String

    func run() throws {
        guard let contents = Self.fileManager.contents(atPath: configFile),
              let configString = String(data: contents, encoding: .utf8) else {
            throw ValidationError("Could not get contents of file at path \(configFile).")
        }

        let config = try PiConfig(parsing: configString)
        let state = try config.ingest()

        guard !checkOnly else {
            return
        }

        let initialValues: PiConfig.Defines = includeEnv.reduce(into: [:]) {
            for (key, value) in Self.processInfo.environment {
                guard (fnmatch($1, key, FNM_NOESCAPE)) == 0 else { continue }

                $0[.init(rawValue: key)] = value
            }
        }

        let values = try state.eval(initialValues: defines.reduce(into: initialValues) {
            $0[$1.property] = $1.value
        })

        guard let outputFile = URL(string: outputFile ?? "/dev/stdout") else {
            throw ValidationError("Invalid path \(outputFile!).")
        }

        let handle = try FileHandle(forWritingTo: outputFile)
        switch format {
        case .dotenv:
            for (property, value) in values {
                guard let value else { continue }
                try handle.write("\(property.rawValue) = \(value)\n")
            }
        case .json:
            let jsonDict = values.reduce(into: [String: Any]()) {
                let (key, value) = $1

                guard let value else { return }
                guard typedValues else {
                    $0[key.rawValue] = value
                    return
                }

                let result: Any
                switch value {
                case "true", "YES":
                    result = true
                case "false", "NO":
                    result = false
                default:
                    if let int = Int(value) {
                        result = int
                    } else if let double = Double(value) {
                        result = double
                    } else if value.couldBeJSON,
                        let data = value.data(using: .utf8),
                        let object = try? JSONSerialization.jsonObject(with: data) {
                        result = object
                    } else {
                        result = value
                    }
                }

                $0[key.rawValue] = result
            }

            let data = try JSONSerialization.data(withJSONObject: jsonDict)
            try handle.write(contentsOf: data)
        }
    }
}

enum OutputFormat: String, ExpressibleByArgument {
    case dotenv
    case json
}

struct Define: ExpressibleByArgument {
    public let property: PiConfig.Property
    public let value: String
}

extension Define {
    init?(argument: String) {
        let components = argument.split(separator: "=", maxSplits: 1)

        self.init(
            property: .init(rawValue: String(components.first!)),
            value: components.count > 1 ? String(components[1]) : "YES"
        )
    }
}

extension String {
    var couldBeJSON: Bool {
        return first == "[" && last == "]" ||
            first == "{" && last == "}"
    }
}

extension FileHandle {
    func write(_ string: String) throws {
        try write(contentsOf: string.data(using: .utf8) ?? Data())
    }
}
