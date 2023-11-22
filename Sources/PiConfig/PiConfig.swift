//
//  PiConfig.swift
//  
//
//  Created by John Biggs on 17.11.23.
//

import Foundation
import Parsing

public struct PiConfig {
    public typealias Defines = [Property: String?]

    public struct Property: Hashable, Comparable, CustomStringConvertible {
        public static func < (lhs: Self, rhs: Self) -> Bool {
            lhs.rawValue < rhs.rawValue
        }

        public let rawValue: String

        public init(rawValue: String) {
            self.rawValue = rawValue
        }

        public var description: String {
            rawValue
        }

        public static let inherited: Self = .init(rawValue: "inherited")
    }

    public struct Value: Hashable, CustomStringConvertible {
        typealias StringOrReference = Either<String, Property>

        let interpolatedItems: [StringOrReference]

        public var description: String {
            interpolatedItems.reduce(into: "") { partialResult, item in
                switch item {
                case let .left(string):
                    partialResult += string
                case let .right(variable):
                    partialResult += "$(\(variable))"
                }
            }
        }

        var references: [Property] {
            interpolatedItems.compactMap(\.right)
        }

        static let falseyValues: Set<String> = ["NO", "false", "0"]
    }

    public struct MatchValue: RawRepresentable, Hashable, CustomStringConvertible {
        public let rawValue: String

        public init(rawValue: String) {
            self.rawValue = rawValue
        }

        public var description: String {
            rawValue
        }
    }

    public enum Condition: Hashable, CustomStringConvertible {
        case falsey(Property)
        case truthy(Property)
        case equals(Property, MatchValue)

        var property: Property {
            switch self {
            case let .falsey(property), let .truthy(property), let .equals(property, _):
                return property
            }
        }

        static func set(_ property: Property, value: String?) -> Set<Self> {
            var result: Set<Self> = []
            if let value {
                result.insert(Value.falseyValues.contains(value) ? .falsey(property) : .truthy(property))
                result.insert(.equals(property, .init(rawValue: value)))
            } else {
                result.insert(.falsey(property))
            }

            return result
        }

        public var description: String {
            switch self {
            case .truthy(let property):
                return "[\(property)]"
            case .falsey(let property):
                return "[!\(property)]"
            case let .equals(property, value):
                return "[\(property)=\(value)]"
            }
        }
    }

    public struct Element: CustomStringConvertible {
        public let property: Property
        public let conditions: Set<Condition>
        public let value: Value

        public var description: String {
            "\(property)\(conditions.map(\.description).joined()) = \(value)"
        }
    }

    public let configItems: [Element]

    init(configItems: [Element]) {
        self.configItems = configItems
    }

    public enum Error: Swift.Error {
        case cycle([Property])
        case conditionalAssignment(ofProperty: Property, conditions: [Condition], couldConflictWith: [Property])
        case noInheritedValue(ofElement: Element)
        case noDefaultValueProvided(forProperty: Property)
    }
}

extension PiConfig.Error: CustomStringConvertible {
    public var description: String {
        switch self {
        case .cycle(let properties):
            return "Cycle detected among properties \(properties.map(\.description).joined(separator: ", "))."
        case let .conditionalAssignment(property, conditions, conflictingProperties):
            return """
                Property assignment \(property)\(conditions.map(\.description).joined()) could conflict \
                with conditions in the same assignment for properties \
                \(conflictingProperties.map(\.description).joined(separator: ", ")).
                """
        case .noInheritedValue(let element):
            return """
                Element references an inherited value, but has no parent: \(element)
                """

        case .noDefaultValueProvided(let property):
            return """
                No default value was provided for \(property).
                """
        }
    }
}

extension PiConfig.Element {
    public init(property: PiConfig.Property, conditions: [PiConfig.Condition]?, value: PiConfig.Value) {
        self.property = property
        self.conditions = Set(conditions ?? [])
        self.value = value
    }
}

extension PiConfig.Property: ExpressibleByStringLiteral {
    public init(stringLiteral value: StringLiteralType) {
        self = Self(rawValue: String(value))
    }
}

extension PiConfig.Defines {
    func includes(_ property: Key) -> Bool {
        // Because the dictionary is a map of Property -> String?, where `nil` indicates that we've evaluated the
        // property and determined that it's not defined, we can't check `defines[property] == nil`, because that says
        // either the value hasn't been evaluated, or we've evaluated it and determined that it's not defined.
        //
        // So instead we use the hack below:
        // If the outer value is nil, then the map will not be evaluated. Function returns false.
        // Otherwise, if the outer value is non-nil, then the value has been defined, the map will return (), which is
        // not equal to nil, so the function returns true.
        self[property].map { _ in () } != nil
    }
}
