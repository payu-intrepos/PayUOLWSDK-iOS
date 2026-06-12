Pod::Spec.new do |s|
  s.name                = "PayUIndia-OLWParams-SDK"
  s.version             = "1.0.0.alpha.3"
  s.license             = "MIT"
  s.homepage            = "https://github.com/payu-intrepos/PayUOLWSDK-iOS"
  s.author              = { "PayU" => "mobile.integration@payu.in"  }

  s.summary             = "OLW ParamKit for iOS by PayUbiz"
  s.description         = "OLW ParamKit for iOS"

  s.source              = { :git => "https://github.com/payu-intrepos/PayUOLWSDK-iOS.git",
                            :tag => "#{s.version}"
                          }
  s.documentation_url   = "https://devguide.payu.in/mobile-sdk-ios/introduction-to-payu-mobile-sdk/"
  s.platform            = :ios , "15.0"
  s.vendored_frameworks = 'PayUOLWParamKit.xcframework'
end
