//
//  DynamicTypeSize+Title.swift
//
//  Created by Trent Fitzgibbon on 07/3/2023.
//  Copyright © 2023 Carsales.com.au. All rights reserved.
//

import SwiftUI

extension DynamicTypeSize {
    var title: String {
        switch self {
        case .xSmall: return "xSmall"
        case .small: return "small"
        case .medium: return "medium"
        case .large: return "default"
        case .xLarge: return "xLarge"
        case .xxLarge: return "xxLarge"
        case .xxxLarge: return "xxxLarge"
        case .accessibility1: return "accessibility1"
        case .accessibility2: return "accessibility2"
        case .accessibility3: return "accessibility3"
        case .accessibility4: return "accessibility4"
        case .accessibility5: return "accessibility5"
        @unknown default:
            return "unknown"
        }
    }
}
