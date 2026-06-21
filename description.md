Problem statement: -How can you help me automate my releases.
- Want a solution which can release iOS SDK (xcframework) in cocoa pod and SPM, without human involvement  or less.
- I have multiple SDKs which are dependent others SDKs,
- Faced challenges to current SDKs version number, every time has to check GitHub to check current tag.
- Faced challenges on version number, as my SDKs are using with multiple nested SDKs, [for example : PayUIndia-PPI-SDK (= 1.2.0.alpha.2) was resolved to 1.2.0.alpha.2, which depends on PayUIndia-Analytics (= 4.1.0)) during validation.]
- I have to change source tree author for git hub [github used for release sdk] and gitlab is private for our development.

*Note:
 - I don’t want to share any kind of password or login to server or remote, it can be local in my laptop or run time input.

Create a plan with md file and elaborate, let me know if any thing need from my side.

Here is my project tree:
.
├── description.md
├── Package.resolved
├── Package.swift
├── PayUIndia-OLWCore-SDK-Release.sh
├── PayUIndia-OLWCore-SDK.podspec
├── PayUIndia-OLWCore-SDKWrapper
│   ├── dummy.m
│   └── include
│       └── dummy.h
├── PayUIndia-OLWParams-SDK-Release.sh
├── PayUIndia-OLWParams-SDK.podspec
├── PayUIndia-OLWUI-SDK-Release.sh
├── PayUIndia-OLWUI-SDK.podspec
├── PayUIndia-OLWUI-SDKWrapper
│   ├── dummy.m
│   └── include
│       └── dummy.h
├── PayUOLWCoreKit.xcframework
│   ├── Info.plist
│   ├── ios-arm64
│   │   ├── dSYMs
│   │   └── PayUOLWCoreKit.framework
│   └── ios-arm64_x86_64-simulator
│       └── PayUOLWCoreKit.framework
├── PayUOLWParamKit.xcframework
│   ├── Info.plist
│   ├── ios-arm64
│   │   ├── dSYMs
│   │   └── PayUOLWParamKit.framework
│   └── ios-arm64_x86_64-simulator
│       └── PayUOLWParamKit.framework
├── PayUOLWUIKit.xcframework
│   ├── Info.plist
│   ├── ios-arm64
│   │   ├── dSYMs
│   │   └── PayUOLWUIKit.framework
│   └── ios-arm64_x86_64-simulator
│       └── PayUOLWUIKit.framework
├── README.md
└── SampleApp
    └── SwiftSampleApp
        └── OLWSwiftSampleApp