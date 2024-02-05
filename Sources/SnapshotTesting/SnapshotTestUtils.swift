//
//  SnapshotTestUtils.swift
//
//  Created by Trent Fitzgibbon on 23/8/2022.
//  Copyright © 2022 Carsales.com.au. All rights reserved.
//

import SwiftUI
import UIKit

/// Utilities for performing snapshot tests in a consistent manner.
@MainActor
public class SnapshotTestUtils {

    /// Whether or not to record all new reference images
    public static let isRecording = false
    /// NOTE: All snapshots should be recorded using a iPhone 15 Pro 17.0.1 simulator, same device as CI/CD

    /// The recommeneded accessibility sizes to use for snapshot tests
    public static let accessibilitySizes: [DynamicTypeSize] = [
        .xSmall,
        .large,
        .xxxLarge,
        .accessibility5
    ]

    public static let minimalAccessibilitySizes: [DynamicTypeSize] = [
        .large,
        .accessibility5
    ]

    public struct ImageConfig {
        let imageConfig: ViewImageConfig
        let name: String

        public init(imageConfig: ViewImageConfig, name: String) {
            self.imageConfig = imageConfig
            self.name = name
        }
    }

    /// The precision used during image comparisons. We can only use 100% here if allowing subpixel threshold > 0
    public static let precision: Float = 1.0

    /// The percentage a pixel must match the source pixel to be considered a match. [98-99% mimics the precision of the human]
    /// - Note: There are differences in GPU rendering pipelines on Intel vs Apple silicon, so only enforce 100% when run on apple silicon
    public static let perceptualPrecision: Float = utsname.arm64 ? 1.0 : 0.8

    /// Delay to wait for UI to render before snapshotting
    public static let renderDelay: UInt64 = 100_000_000 // 100ms
    public static let windowDelay: UInt64 = 500_000_000 // 500ms
    public static let snapshotDelay: CGFloat = 0.1 // 100ms

    // Simulated device configurations
    public static let iPhoneConfig = ImageConfig(imageConfig: .iPhone13ProMax, name: "iPhone")
    public static let iPadConfig = ImageConfig(imageConfig: .iPadPro12_9(.portrait), name: "iPad")
    public static let canvasConfig = ImageConfig(
        imageConfig: ViewImageConfig(size: CGSize(width: 768, height: 768)),
        name: "Canvas"
    )

    /// Generate the test name to use in file written to disk
    public static func combinedTestName(for name: String, config: ImageConfig, typeSize: DynamicTypeSize, doccTypeSizes: [DynamicTypeSize]) -> String {
        var typeIndex: String?
        if let index = accessibilitySizes.firstIndex(of: typeSize) {
            typeIndex = "\(index)"
        }
        let traits = config.imageConfig.traits.userInterfaceStyle == .dark ? "Dark" : "Light"
        let testName = [name, config.name, traits, typeIndex, typeSize.title].compactMap({ $0 }).joined(separator: "-")
        let suffix = doccTypeSizes.contains(typeSize) ? "-Docc" : ""
        return "\(testName)\(suffix)"
    }

    /// Assert a standard set of snapshots given a closure that creates a view controller
    ///
    /// - Parameters:
    ///    - viewControllerFactory: The closure called to create the viewController to use for the snapshot tests
    ///    - scrollViewAccessor: The closure called to access the scrollView. This is used to simulate scrolling so all content of the viewController can be seen in the snapshots. Default value is nil.
    ///    - imageConfigs: An array of ImageConfigs representing the devices used for the snapshots. Default value is a custom canvas config [canvasConfig, canvasConfig.darkMode,]
    ///    - typeSize: The DynamicTypeSize for the current snapshot. Used only for generating the name to use in file written to disk. Default value is `.large`
    ///    - doccTypeSizes: A DynamicTypeSize array used only for adding a suffix `-Docc` in the file name generated. If `typeSize` is contained in this array, the generated file name will have a `-Docc` suffix. Default value is empty array.
    ///    - useTemporaryWindow: A bool property that when set to true, will add the view controller to a window before snapshotting, to allow full view lifecycle events. Default value is false
    ///    - file: StaticString, currently unused
    ///    - testName: The string used for generating the name to use in file written to disk. Default value is the function that called `assertSnapshots`.
    ///    - line: UInt, currently unused
    public static func assertSnapshots(viewControllerFactory: () -> UIViewController,
                                       scrollViewAccessor: (UIViewController) -> UIScrollView? = { _ in nil },
                                       imageConfigs: [ImageConfig] = [canvasConfig, canvasConfig.darkMode],
                                       typeSize: DynamicTypeSize = .large,
                                       doccTypeSizes: [DynamicTypeSize] = [],
                                       useTemporaryWindow: Bool = false,
                                       file: StaticString = #file,
                                       testName: String = #function,
                                       line: UInt = #line) async throws {

        // Disable animations and image downloading for duration of snapshots
        let existingAnimationsEnabled = UIView.areAnimationsEnabled
        UIView.setAnimationsEnabled(false)
        defer {
            UIView.setAnimationsEnabled(existingAnimationsEnabled)
        }

        // Snapshot UI images on multiple devices
        for config in imageConfigs {
            // Create VC, perform initial layout and give chance for mocked network requests to complete
            let viewController = viewControllerFactory()
            viewController.view.tintAdjustmentMode = .normal
            viewController.view.layoutIfNeeded()
            try await Task.sleep(nanoseconds: renderDelay)

            if useTemporaryWindow {
                // Add the view controller to a window before snapshotting, to allow full view lifecycle events,
                // especially helpful in SwiftUI with async Task closures
                // Use a large height (10000) to layout hopefully all the views, including lazy ones
                var size = CGSize(width: 375, height: 10000)
                if let configSize = config.imageConfig.size {
                    size.width = configSize.width
                }
                let window = UIWindow(frame: CGRect(origin: .zero, size: size))
                window.rootViewController = viewController

                viewController.beginAppearanceTransition(true, animated: false)
                viewController.endAppearanceTransition()
                viewController.view.setNeedsLayout()
                viewController.view.layoutIfNeeded()

                window.makeKeyAndVisible()

                // Wait for layout to complete on view
                try await Task.sleep(nanoseconds: windowDelay)
            }

            // Assert view controller content as single image
            assertSnapshot(matching: viewController,
                           as: .wait(for: snapshotDelay, on: .reducedImage(on: config.imageConfig)),
                           record: isRecording,
                           file: file,
                           testName: combinedTestName(for: testName, config: config, typeSize: typeSize, doccTypeSizes: doccTypeSizes),
                           line: line)

            // Assert every part of scroll view content, using the first snapshot to detect the
            // offset of the scrollview for safe areas (post being added to snapshot window)
            if let scrollView = scrollViewAccessor(viewController), let size = config.imageConfig.size {
                let scrollViewOrigin = scrollView.convert(scrollView.frame, to: viewController.view).origin
                let pageSize = Int(size.height - scrollViewOrigin.y)
                let pages = Int((scrollView.contentSize.height / CGFloat(pageSize)).rounded(.up))
                for page in 1..<pages {
                    scrollView.setContentOffset(CGPoint(x: 0, y: page * pageSize), animated: false)
                    assertSnapshot(matching: viewController,
                                   as: .wait(for: snapshotDelay, on: .reducedImage(on: config.imageConfig)),
                                   record: isRecording,
                                   file: file,
                                   testName: combinedTestName(for: testName, config: config, typeSize: typeSize, doccTypeSizes: doccTypeSizes),
                                   line: line)
                }
                scrollView.setContentOffset(CGPoint(x: 0, y: 0), animated: false)
            }
        }
    }
}

extension SnapshotTestUtils.ImageConfig {
    /// Convenience dark mode modifier of existing image config
    public var darkMode: SnapshotTestUtils.ImageConfig {
        var imageConfig = imageConfig
        imageConfig.traits = UITraitCollection(traitsFrom: [.init(userInterfaceStyle: .dark), imageConfig.traits])
        return SnapshotTestUtils.ImageConfig(imageConfig: imageConfig, name: name)
    }
}

extension Snapshotting where Value == UIViewController, Format == UIImage {
    /// Custom snapshotting strategy to save space
    public static func reducedImage(
        on config: ViewImageConfig,
        traits: UITraitCollection = .init()
    )
    -> Snapshotting {
        // Snapshot requiring 100% match, but allowing minor subpixel deviation
        let base = Snapshotting<UIViewController, UIImage>.image(on: config,
                                                                 precision: SnapshotTestUtils.precision,
                                                                 perceptualPrecision: SnapshotTestUtils.perceptualPrecision,
                                                                 size: nil,
                                                                 traits: traits)
        return Snapshotting<UIViewController, UIImage>(pathExtension: base.pathExtension, diffing: base.diffing) { value in
            return Async<UIImage> { callback in
                base.snapshot(value).run { snapshot in
                    let resized = downsampledImage(snapshot) ?? snapshot
                    callback(resized)
                }
            }
        }
    }

    /// Downsample snapshot image for smaller file sizes
    private static func downsampledImage(_ image: UIImage) -> UIImage? {
        // Re-render snapshot at @1 scale and with no alpha channel to save space
        let newSize = CGSize(width: image.size.width / image.scale, height: image.size.height / image.scale)
        UIGraphicsBeginImageContextWithOptions(newSize, true, image.scale)
        defer { UIGraphicsEndImageContext() }

        // Use interpolation quality that gives best file size but still shows single pixel borders
        let context = UIGraphicsGetCurrentContext()!
        context.interpolationQuality = .medium

        image.draw(in: CGRect(origin: CGPoint.zero, size: newSize))
        return UIGraphicsGetImageFromCurrentImageContext()
    }

}

extension utsname {
    static var machineName: String {
        var utsname = utsname()
        uname(&utsname)
        return withUnsafePointer(to: &utsname.machine) {
            $0.withMemoryRebound(to: CChar.self, capacity: Int(_SYS_NAMELEN)) {
                String(cString: $0)
            }
        }
    }

    /// Whether the physical machine running this code is ARM64
    static var arm64: Bool {
        machineName == "arm64"
    }
}
