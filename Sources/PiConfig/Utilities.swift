//
//  Utilities.swift
//  
//
//  Created by John Biggs on 17.11.23.
//

import Foundation

enum Either<Left: Hashable, Right: Hashable>: Hashable {
    case left(Left)
    case right(Right)

    init(_ left: Left) {
        self = .left(left)
    }

    init(_ right: Right) {
        self = .right(right)
    }

    var left: Left? {
        guard case .left(let left) = self else {
            return nil
        }

        return left
    }

    var right: Right? {
        guard case .right(let right) = self else {
            return nil
        }

        return right
    }
}
