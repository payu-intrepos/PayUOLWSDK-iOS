// swift-tools-version:5.5
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let VERSION_ANALYTICS_KIT: PackageDescription.Version = "4.1.0.alpha.1"
let VERSION_CRASH_REPORTER: PackageDescription.Version = "4.0.3"
let VERSION_NETWORK_REACHABILITY: PackageDescription.Version = "2.1.1"
let VERSION_CUSTOM_BROWSER: PackageDescription.Version = "11.3.0"
let VERSION_DL_SDK: PackageDescription.Version = "1.0.0.alpha.1"


let package = Package(
    name: "PayUIndia-OLW-SDK",
    platforms: [.iOS(.v15)],
    products: [
        // Products define the executables and libraries a package produces, and make them visible to other packages.
        .library(
            name: "PayUIndia-OLWCore-SDK",
            targets: ["PayUIndia-OLWCore-SDKTarget"]),
        .library(
            name: "PayUIndia-OLWParams-SDK",
            targets: ["PayUIndia-OLWParams-SDKTarget"]),
        .library(
            name: "PayUIndia-OLWUI-SDK",
            targets: ["PayUIndia-OLWUI-SDKTarget"]),
    ],
    dependencies: [
        // Dependencies declare other packages that this package depends on.
        .package(name: "PayUIndia-NetworkReachability", url: "https://github.com/payu-intrepos/PayUNetworkReachability-iOS.git", from: VERSION_NETWORK_REACHABILITY),
        .package(name: "PayUIndia-Analytics", url: "https://github.com/payu-intrepos/PayUAnalytics-iOS.git", from: VERSION_ANALYTICS_KIT),
        .package(name: "PayUIndia-CrashReporter", url: "https://github.com/payu-intrepos/PayUCrashReporter-iOS.git", from: VERSION_CRASH_REPORTER),
        .package(name: "PayUIndia-Custom-Browser", url: "https://github.com/payu-intrepos/iOS-Custom-Browser.git", from: VERSION_CUSTOM_BROWSER),
        .package(name: "PayUIndia-DL-SDK", url: "https://github.com/payu-intrepos/PayUDesignLibraryiOS.git", from: VERSION_CUSTOM_BROWSER),
        
    ],
    targets: [
        
        .target(
            name: "PayUIndia-OLWUI-SDKTarget",
            dependencies: [
                .product(name: "PayUIndia-Custom-Browser", package: "PayUIndia-Custom-Browser"),
                .product(name: "PayUIndia-DL-SDK", package: "PayUIndia-DL-SDK"),
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
        ),
        
            .binaryTarget(name: "PayUOLWCoreKit", path: "./PayUOLWCoreKit.xcframework"),
        .binaryTarget(name: "PayUOLWParamKit", path: "./PayUOLWParamKit.xcframework"),
        .binaryTarget(name: "PayUOLWUIKit", path: "./PayUOLWUIKit.xcframework"),
    ]
)
