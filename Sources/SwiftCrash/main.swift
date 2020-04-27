import SwiftType

func mergeTypeSignatures(_ type1: SwiftType,
                         _ type2: inout SwiftType,
                         expander: TypealiasExpander) {
    
    let type1Unaliased = expander.expand(in: type1)
    var type2Unaliased = expander.expand(in: type2)
    
    // Merge block types
    // TODO: Figure out what to do when two block types have different type
    // attributes.
    switch (type1Unaliased.deepUnwrapped, type2Unaliased.deepUnwrapped) {
    case (let .block(t1Ret, t1Params, t1Attributes), var .block(ret, params, attributes))
        where t1Params.count == params.count:
        mergeTypeSignatures(t1Ret, &ret, expander: expander)
        
        for (i, p1) in t1Params.enumerated() {
            mergeTypeSignatures(p1, &params[i], expander: expander)
        }
        
        attributes.formUnion(t1Attributes)
        
        type2 = SwiftType
            .block(returnType: ret,
                   parameters: params,
                   attributes: attributes)
            .withSameOptionalityAs(type2)
        
        type2Unaliased = expander.expand(in: type2)
    default:
        break
    }
    
    if !type1.isNullabilityUnspecified && type2.isNullabilityUnspecified {
        let type1NonnullDeep =
            SwiftType.asNonnullDeep(type1Unaliased.deepUnwrapped,
                                    removeUnspecifiedsOnly: true)
        
        let type2NonnullDeep =
            SwiftType.asNonnullDeep(type2Unaliased.deepUnwrapped,
                                    removeUnspecifiedsOnly: true)
        
        if type1NonnullDeep == type2NonnullDeep {
            type2 = type2NonnullDeep.withSameOptionalityAs(type1)
        }
    }
    
    // Do a final check: If the resulting type2 is the same as an unaliased
    // type1 signature, favor using the typealias in the final type signature.
    if type2 == type1Unaliased {
        type2 = type1
    }
}

func main() {
    let type1: SwiftType = .block(returnType: .void,
                                  parameters: ["NSURLRequest"],
                                  attributes: [.autoclosure])
    
    var type2: SwiftType = .nullabilityUnspecified(.block(returnType: .void,
                                                          parameters: ["NSURLRequest"],
                                                          attributes: [.autoclosure]))

    let expander = TypealiasExpander(aliasesSource: TypealiasProvider())

    mergeTypeSignatures(type1, &type2, expander: expander)

    print(type2)
}

main()
