//
//  Item.swift
//  NCFScanner
//
//  Created by Angel Izquierdo on 11/4/26.
//

import Foundation
import SwiftData

@Model
final class Item {
    var timestamp: Date
    
    init(timestamp: Date) {
        self.timestamp = timestamp
    }
}
