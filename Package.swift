// swift-tools-version:5.5
// The swift-tools-version declares the minimum version of Swift required to build this package.
// SPM dependency pins are generated from versions.yaml (see docs/RELEASE_AUTOMATION.md).

import PackageDescription

let package = Package(
    name: "PayUIndia-OLW-SDK",
    platforms: [.iOS(.v15)],
    products: [
        // Products define the executables and libraries a package produces, and make them visible to other packages.
        .library(
            name: "PayUIndia-OLWCore-SDK",
            targets: ["PayUIndia-OLWCore-SDKTarget"]),
        .library(
            name: "PayUIndia-OLWUI-SDK",
            targets: ["PayUIndia-OLWUI-SDKTarget"])
    ],
    dependencies: [
        // BEGIN:GENERATED_SPM_DEPS
        // Generated from versions.yaml — run: ruby scripts/release/sync-versions.rb
        .package(name: "PayUIndia-NetworkReachability", url: "https://github.com/payu-intrepos/PayUNetworkReachability-iOS.git", from: "2.1.1"),
        .package(name: "PayUIndia-Analytics", url: "https://github.com/payu-intrepos/PayUAnalytics-iOS.git", branch: "alpha"),
        .package(name: "PayUIndia-CrashReporter", url: "https://github.com/payu-intrepos/PayUCrashReporter-iOS.git", from: "4.0.3"),
        .package(name: "PayUIndia-Custom-Browser", url: "https://github.com/payu-intrepos/iOS-Custom-Browser.git", branch: "alpha"),
        .package(name: "PayUIndia-DL-SDK", url: "https://github.com/payu-intrepos/PayUDesignLibraryiOS.git", branch: "alpha"),
        .package(name: "PayUIndia-PPI-SDK", url: "https://github.com/payu-intrepos/PPIManageriOS.git", branch: "alpha"),
        // END:GENERATED_SPM_DEPS
    ],
    targets: [
        .binaryTarget(name: "PayUOLWCoreKit", path: "./PayUOLWCoreKit.xcframework"),
        .binaryTarget(name: "PayUOLWParamKit", path: "./PayUOLWParamKit.xcframework"),
        .binaryTarget(name: "PayUOLWUIKit", path: "./PayUOLWUIKit.xcframework"),

        .target(
            name: "PayUIndia-OLWUI-SDKTarget",
            dependencies: [
                .product(name: "PayUIndia-Custom-Browser", package: "PayUIndia-Custom-Browser"),
                .product(name: "PayUIndia-DL-SDK", package: "PayUIndia-DL-SDK"),
                .product(name: "PayUIndia-PPI-SDK", package: "PayUIndia-PPI-SDK"),
                "PayUIndia-OLWCore-SDKTarget",
                "PayUOLWUIKit"
            ],
            path: "PayUIndia-OLWUI-SDKWrapper"
        ),
        .target(
            name: "PayUIndia-OLWCore-SDKTarget",
            dependencies: [
                .product(name: "PayUIndia-NetworkReachability", package: "PayUIndia-NetworkReachability"),
                .product(name: "PayUIndia-Analytics", package: "PayUIndia-Analytics"),
                .product(name: "PayUIndia-CrashReporter", package: "PayUIndia-CrashReporter"),
                "PayUOLWCoreKit",
                "PayUOLWParamKit"
            ],
            path: "PayUIndia-OLWCore-SDKWrapper"
        )
    ]
)
