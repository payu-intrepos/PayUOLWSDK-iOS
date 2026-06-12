Pod::Spec.new do |s|
  s.name                = "PayUIndia-OLWCore-SDK"
  s.version             = "1.0.0.alpha.5"
  s.license             = "MIT"
  s.homepage            = "https://github.com/payu-intrepos/PayUOLWSDK-iOS"
  s.author              = { "PayU" => "mobile.integration@payu.in"  }

  s.summary             = "Open loop wallet core SDK for iOS"
  s.description         = "Open loop wallet core SDK for iOS"

  s.source              = { :git => "https://github.com/payu-intrepos/PayUOLWSDK-iOS.git",
                            :tag => "#{s.version}"
                          }
  s.documentation_url   = "https://devguide.payu.in/mobile-sdk-ios/introduction-to-payu-mobile-sdk/"
  s.platform            = :ios , "15.0"
  s.vendored_frameworks = 'PayUOLWCoreKit.xcframework'
  s.dependency            'PayUIndia-CrashReporter', '~> 4.0'
  s.dependency            'PayUIndia-NetworkReachability', '~> 2.1'
  s.dependency            'PayUIndia-Analytics', '4.1.0.alpha.1'
  s.dependency            'PayUIndia-OLWParams-SDK', '1.0.0.alpha.4'
end
