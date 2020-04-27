public typealias NestedSwiftType = [NominalSwiftType]
public typealias GenericArgumentSwiftType = [SwiftType]

/// Represents a Swift type structure
indirect public enum SwiftType: Hashable {
    case nominal(NominalSwiftType)
    case tuple(TupleSwiftType)
    case block(returnType: SwiftType, parameters: [SwiftType], attributes: Set<BlockTypeAttribute>)
    case optional(SwiftType)
    case implicitUnwrappedOptional(SwiftType)
    case nullabilityUnspecified(SwiftType)
}

extension SwiftType: ExpressibleByStringLiteral {
    public init(stringLiteral value: String) {
        self = .nominal(.typeName(value))
    }
}

/// A nominal Swift type, which is either a plain typename or a generic type.
public enum NominalSwiftType: Hashable {
    case typeName(String)
    case generic(String, parameters: GenericArgumentSwiftType)
}

extension NominalSwiftType: ExpressibleByStringLiteral {
    public init(stringLiteral value: String) {
        self = .typeName(value)
    }
}

/// A tuple swift type, which either represents an empty tuple or two or more
/// Swift types.
public enum TupleSwiftType: Hashable {
    case types([SwiftType])
    case empty
}

/// An attribute for block types.
public enum BlockTypeAttribute: Hashable, CustomStringConvertible {
    public var description: String {
        switch self {
        case .autoclosure:
            return "@autoclosure"
            
        case .escaping:
            return "@escaping"
            
        case .convention(let c):
            return "@convention(\(c.rawValue))"
        }
    }
    
    case autoclosure
    case escaping
    case convention(Convention)
    
    public enum Convention: String, Hashable {
        case block
        case c
    }
}

public extension SwiftType {
    var isNullabilityUnspecified: Bool {
        switch self {
        case .nullabilityUnspecified:
            return true
        default:
            return false
        }
    }
    
    /// If this type is an `.optional` or `.implicitUnwrappedOptional` type,
    /// returns an unwrapped version of self.
    /// The return is then recursively unwrapped again until a non-optional base
    /// type is reached.
    var deepUnwrapped: SwiftType {
        switch self {
        case .optional(let type),
             .implicitUnwrappedOptional(let type),
             .nullabilityUnspecified(let type):
            return type.deepUnwrapped
            
        default:
            return self
        }
    }
    
    /// Returns this type, wrapped in the same optionality depth as another given
    /// type.
    ///
    /// In case the other type is not an optional type, returns this type with
    /// no optionality.
    func withSameOptionalityAs(_ type: SwiftType) -> SwiftType {
        type.wrappingOther(self.deepUnwrapped)
    }
    
    /// In case this type represents an optional value, returns a new optional
    /// type with the same optionality as this type, but wrapping over a given
    /// type.
    ///
    /// If this type is not optional, `type` is returned, instead.
    ///
    /// Lookup is deep, and returns the same optionality chain as this type's.
    func wrappingOther(_ type: SwiftType) -> SwiftType {
        switch self {
        case .optional(let inner):
            return .optional(inner.wrappingOther(type))
        case .implicitUnwrappedOptional(let inner):
            return .implicitUnwrappedOptional(inner.wrappingOther(type))
        case .nullabilityUnspecified(let inner):
            return .nullabilityUnspecified(inner.wrappingOther(type))
        default:
            return type
        }
    }
    
    /// Maps this type, applying a given transforming closure to any nested types
    /// and finally the root type this type represents.
    func map(_ transform: (SwiftType) -> SwiftType) -> SwiftType {
        switch self {
        case .implicitUnwrappedOptional(let inner):
            return .implicitUnwrappedOptional(inner.map(transform))
        case .optional(let inner):
            return .optional(inner.map(transform))
        case .nullabilityUnspecified(let inner):
            return .nullabilityUnspecified(inner.map(transform))
        case let .block(returnType, parameters, attributes):
            return .block(returnType: returnType.map(transform),
                          parameters: parameters.map { $0.map(transform) },
                          attributes: attributes)
        default:
            return transform(self)
        }
    }
    
    static let void = SwiftType.tuple(.empty)
    
    /// Returns a type that is the same as the input, but with any .optional,
    /// .implicitUnwrappedOptional, or .nullabilityUnspecified types unwrapped
    /// to non optional, inclusing block parameters.
    ///
    /// - Parameters:
    ///   - type: The input type
    ///   - removeImplicitsOnly: Whether to only remove nullability unspecified
    ///   optionals, keeping other optional kinds in place.
    /// - Returns: The deeply unwrapped version of the input type.
    static func asNonnullDeep(_ type: SwiftType,
                              removeUnspecifiedsOnly: Bool = false) -> SwiftType {
        
        var result: SwiftType = type
        
        if removeUnspecifiedsOnly {
            if case .nullabilityUnspecified(let inner) = type {
                result = inner
            }
        } else {
            result = type.deepUnwrapped
        }
        
        switch result {
        case let .block(returnType, parameters, attributes):
            let returnType =
                asNonnullDeep(returnType,
                              removeUnspecifiedsOnly: removeUnspecifiedsOnly)
            
            let parameters = parameters.map {
                asNonnullDeep($0, removeUnspecifiedsOnly: removeUnspecifiedsOnly)
            }
            
            result = .block(returnType: returnType,
                            parameters: parameters,
                            attributes: attributes)
            
        default:
            break
        }
        
        return result
    }
}

extension NominalSwiftType: CustomStringConvertible {
    public var description: String {
        switch self {
        case .typeName(let name):
            return name
            
        case let .generic(name, params):
            return name + "<" + params.map(\.description).joined(separator: ", ") + ">"
        }
    }
    
    public var typeNameValue: String {
        switch self {
        case .typeName(let typeName),
             .generic(let typeName, _):
            
            return typeName
        }
    }
}

extension SwiftType: CustomStringConvertible {
    public var description: String {
        switch self {
        case .nominal(let type):
            return type.description
            
        case let .block(returnType, parameters, attributes):
            let sortedAttributes =
                attributes.sorted { $0.description < $1.description }
            
            let attributeString =
                sortedAttributes.map(\.description).joined(separator: " ")
            
            return
                (attributeString.isEmpty ? "" : attributeString + " ")
                    + "("
                    + parameters.map(\.description).joined(separator: ", ")
                    + ") -> "
                    + returnType.description
            
        case .optional(let type):
            return type.description + "?"
            
        case .implicitUnwrappedOptional(let type):
            return type.description + "!"
            
        case .nullabilityUnspecified(let type):
            return type.description + "!"
            
        case .tuple(.empty):
            return "Void"
            
        case let .tuple(.types(inner)):
            return "(" + inner.map(\.description).joined(separator: ", ") + ")"
        }
    }
}
