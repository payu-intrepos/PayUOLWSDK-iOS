Pod::Spec.new do |s|
  s.name                = "PayUIndia-OLWUI-SDK"
  s.version             = "1.0.0.alpha.3"
  s.license             = "MIT"
  s.homepage            = "https://github.com/payu-intrepos/PayUOLWSDK-iOS"
  s.author              = { "PayU" => "mobile.integration@payu.in"  }

  s.summary             = "Open loop wallet for iOS with UI"
  s.description         = "Open loop wallet SDK for iOS with UI"

  s.source              = { :git => "https://github.com/payu-intrepos/PayUOLWSDK-iOS.git",
                            :tag => "#{s.version}"
                          }
  s.documentation_url   = "https://devguide.payu.in/mobile-sdk-ios/introduction-to-payu-mobile-sdk/"
  s.platform            = :ios , "15.0"
  s.vendored_frameworks = 'PayUOLWUIKit.xcframework'
  s.dependency            'PayUIndia-OLWCore-SDK', '1.0.0.alpha.2'
  s.dependency            'PayUIndia-Custom-Browser', '11.3.1.alpha.1'
  s.dependency            'PayUIndia-DL-SDK', '1.0.0.alpha.1'
  s.dependency            'PayUIndia-PPI-SDK', '1.2.0.alpha.1'
end
