//
//  CustomTraitWindow.swift
//  swift-snapshot-testing
//
//  Created by Kashish Verma on 07/10/25.
//  Copyright © 2025 Carsales.com.au. All rights reserved.
//

import UIKit

/// Custom UIWindow subclass that allows us to override the trait collection
public class CustomTraitWindow: UIWindow {
    var customTraitCollection: UITraitCollection

    override public var traitCollection: UITraitCollection {
        return customTraitCollection
    }

    init(config: ViewImageConfig) {
        self.customTraitCollection = UITraitCollection(traitsFrom: [
            UIWindow().traitCollection,
            config.traits
        ])
        super.init(frame: CGRect(origin: .zero, size: config.size ?? .zero))
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
