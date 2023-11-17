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
    static var fileManager: FileManager = .default
    static var processInfo: ProcessInfo = .processInfo

    @Flag()
    var allowEnvVars: Bool = false

    @Flag()
    var checkOnly: Bool = false

    @Option()
    var format: OutputFormat = .dotenv

    @Option(name: .shortAndLong)
    var outputFile: String?

    @Option(name: [.customShort("D", allowingJoined: true), .long])
    var defines: [Define] = []

    @Argument()
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

        var initialValues: PiConfig.Defines = [:]
        if allowEnvVars {
            initialValues = Self.processInfo.environment.reduce(into: [:], {
                $0[.init(rawValue: $1.key)] = $1.value
            })
        }

        let values = state.eval(initialValues: defines.reduce(into: initialValues) {
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

                let result: Any
                switch value {
                case "true", "YES":
                    result = true
                case "false", "NO":
                    result = false
                default:
                    guard let value else { return }

                    if let int = Int(value) {
                        result = int
                    } else if let double = Double(value) {
                        result = double
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

extension FileHandle {
    func write(_ string: String) throws {
        try write(contentsOf: string.data(using: .utf8) ?? Data())
    }
}
