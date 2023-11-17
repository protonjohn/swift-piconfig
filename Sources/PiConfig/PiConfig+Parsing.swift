//
//  PiConfig+Parsing.swift
//
//  Created by John Biggs on 16.11.23.
//

import Foundation
import Parsing

extension PiConfig.Property {
    static let allowedInitialCharacters: CharacterSet = .letters.union(.underscore)

    static let parser = Parse(input: Substring.self, Self.init(rawValue:)) {
        Peek {
            Prefix(1, while: Self.allowedInitialCharacters.contains(character:))
        }
        CharacterSet.alphanumerics.union(.underscore).map(String.init)
    }

    static let reference = Parse {
        "$("
        Self.parser
        ")"
    }
}

extension PiConfig.Value {
    static let parser = Parse(Self.init(interpolatedItems:)) {
        Many {
            Not {
                "//"
            }

            OneOf {
                PiConfig.Property.reference.map(StringOrReference.right)
                OneOf {
                    PrefixUpTo("$(").map(String.init)
                    PrefixUpTo("//").map {
                        String($0.trimmingSuffix(in: .whitespaces))
                    }
                    Rest().map(String.init)
                }.map(StringOrReference.left)
            }

            Skip {
                Optionally {
                    "//"
                    Rest()
                }
            }
        }
    }
}

extension PiConfig.MatchValue: Particle {
    static let allowedCharacters: CharacterSet = .alphanumerics
}

extension PiConfig.Condition {
    static let parser = Parse {
        "["
        OneOf {
            Parse(Self.equals) {
                PiConfig.Property.parser
                "="
                PiConfig.MatchValue.parser
            }

            Parse(Self.falsey) {
                "!"
                PiConfig.Property.parser
            }

            PiConfig.Property.parser.map(Self.truthy)
        }
        "]"
    }
}

extension PiConfig.Element {
    static let parser = Parse(Self.init) {
        PiConfig.Property.parser
        
        Optionally {
            Many {
                PiConfig.Condition.parser
            }
        }
        Skip {
            Whitespace(.horizontal)
        }
        "="
        Skip {
            Whitespace(.horizontal)
        }

        PiConfig.Value.parser
    }
}

extension PiConfig {
    static let comments = Parse(input: Substring.self) {
        Skip {
            Optionally {
                Many {
                    Whitespace()
                    "//"
                    PrefixUpTo("\n")
                }
            }
            Whitespace()
        }
    }

    static let parser = Parse(Self.init(configItems:)) {
        Self.comments

        Many {
            OneOf {
                PrefixUpTo("\n")
                Rest()
            }.pipe {
                PiConfig.Element.parser
            }
        } separator: {
            Self.comments
            Whitespace()
        }
        
        Self.comments
    }
}

public extension PiConfig {
    init(parsing contents: String) throws {
        self = try Self.parser.parse(contents[...])
    }
}

protocol Particle: RawRepresentable where RawValue == String {
    static var allowedCharacters: CharacterSet { get }

    init(rawValue: String)
}

extension Particle {
    static var parser: AnyParser<Substring, Self> {
        Self.allowedCharacters.map { Self(rawValue: String($0)) }.eraseToAnyParser()
    }
}

extension CharacterSet {
    func contains(character: Character) -> Bool {
        character.unicodeScalars.allSatisfy(contains(_:))
    }

    static let underscore: CharacterSet = {
        var result: CharacterSet = CharacterSet()
        result.insert("_")
        return result
    }()
}

extension StringProtocol {
    func trimmingSuffix(in set: CharacterSet) -> Self.SubSequence {
        var trimmed = self[...]
        while let last = trimmed.last, set.contains(character: last) {
            trimmed = trimmed.dropLast()
        }

        return trimmed
    }
}
