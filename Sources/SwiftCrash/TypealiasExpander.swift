import SwiftType

class TypealiasProvider {
    var aliases: [String: SwiftType] = [:]
    
    func unalias(_ name: String) -> SwiftType? {
        return aliases[name]
    }
}

class TypealiasExpander {
    // Used to discover cycles in alias expansion
    private var aliasesInStack: [String] = []
    
    private var source: TypealiasProvider
    
    init(aliasesSource: TypealiasProvider) {
        self.source = aliasesSource
    }
    
    func expand(in type: SwiftType) -> SwiftType {
        return type.map { type -> SwiftType in
            switch type {
            case .nominal(let nominal):
                return .nominal(expand(inNominal: nominal))
            case .nested(let nested):
                return .nested(.fromCollection(nested.map(expand(inNominal:))))
            default:
                return type
            }
        }
    }
    
    private func expand(inString string: String) -> String {
        guard let aliased = source.unalias(string) else {
            return string
        }
        
        return pushingAlias(string) {
            return typeNameIn(swiftType: aliased).map(expand(inString:)) ?? string
        }
    }
    
    private func expand(inNominal nominal: NominalSwiftType) -> NominalSwiftType {
        switch nominal {
        case .typeName(let name):
            return .typeName(expand(inString: name))
            
        case let .generic(name, parameters):
            return .generic(expand(inString: name),
                            parameters: .fromCollection(parameters.map(expand)))
        }
    }
    
    private func pushingAlias<T>(_ name: String, do work: () -> T) -> T {
        if aliasesInStack.contains(name) {
            fatalError("""
                Cycle found while expanding typealises: \
                \(aliasesInStack.joined(separator: " -> ")) -> \(name)
                """)
        }
        
        aliasesInStack.append(name)
        defer {
            aliasesInStack.removeLast()
        }
        
        return work()
    }
}

func typeNameIn(swiftType: SwiftType) -> String? {
    let swiftType = swiftType.deepUnwrapped
    
    switch swiftType {
    case .nominal(let nominalType):
        return typeNameIn(nominalType: nominalType)
        
    // Other Swift types are not supported, at the moment.
    default:
        return nil
    }
}

func typeNameIn(nominalType: NominalSwiftType) -> String {
    nominalType.typeNameValue
}
