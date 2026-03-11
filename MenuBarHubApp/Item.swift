//
//  Item.swift
//  MenuBarHubApp
//
//  Created by Liwei Xie on 11.3.2026.
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
