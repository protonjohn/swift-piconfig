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

    public struct Property: Hashable, Comparable {
        public static func < (lhs: Self, rhs: Self) -> Bool {
            lhs.rawValue < rhs.rawValue
        }

        public let rawValue: String

        public init(rawValue: String) {
            self.rawValue = rawValue
        }

        public static let inherited: Self = .init(rawValue: "inherited")
    }

    public struct Value: Hashable {
        typealias StringOrReference = Either<String, Property>

        let interpolatedItems: [StringOrReference]

        var stringValue: String {
            interpolatedItems.reduce(into: "") { partialResult, item in
                switch item {
                case let .left(string):
                    partialResult += string
                case let .right(variable):
                    partialResult += "$(\(variable.rawValue))"
                }
            }
        }

        var references: [Property] {
            interpolatedItems.compactMap(\.right)
        }

        static let falseyValues: Set<String> = ["NO", "false", "0"]
    }

    public struct MatchValue: RawRepresentable, Hashable {
        public let rawValue: String

        public init(rawValue: String) {
            self.rawValue = rawValue
        }
    }

    public enum Condition: Hashable {
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

        public static func == (lhs: Self, rhs: Self) -> Bool {
            switch lhs {
            case let .equals(property, value):
                guard case let .equals(rhsProperty, rhsValue) = rhs,
                      property == rhsProperty, value == rhsValue else { return false }
            case let .truthy(property):
                guard case let .truthy(rhsProperty) = rhs,
                      property == rhsProperty else { return false }
            case let .falsey(property):
                guard case let .falsey(rhsProperty) = rhs,
                      property == rhsProperty else { return false }
            }
            return true
        }
    }

    public struct Element {
        public let property: Property
        public let conditions: Set<Condition>
        public let value: Value
    }

    public let configItems: [Element]

    init(configItems: [Element]) {
        self.configItems = configItems
    }

}

public enum EvalError: Error {
    case cycle([PiConfig.Property])
    case conditionalAssignment(ofProperty: PiConfig.Property, conditions: [PiConfig.Condition], couldConflictWith: [PiConfig.Property])
    case noInheritedValue(ofElement: PiConfig.Element)
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
