Pod::Spec.new do |spec|
  spec.name         = "IosIAP"
  spec.version      = "1.0.0"
  spec.summary      = "iOS In-App Purchase library following OpenIAP specification"
  spec.description  = <<-DESC
    A comprehensive iOS In-App Purchase library that follows the OpenIAP specification.
    Simplifies the integration of in-app purchases in iOS applications with a clean API.
  DESC
  
  spec.homepage     = "https://github.com/hyochan/ios-iap"
  spec.license      = { :type => "MIT", :file => "LICENSE" }
  spec.author       = { "hyochan" => "your-email@example.com" }
  
  spec.ios.deployment_target = "13.0"
  spec.osx.deployment_target = "10.15"
  spec.tvos.deployment_target = "13.0"
  spec.watchos.deployment_target = "6.0"
  
  spec.source       = { :git => "https://github.com/hyochan/ios-iap.git", :tag => "#{spec.version}" }
  spec.source_files = "Sources/IosIAP/**/*.swift"
  
  spec.swift_version = "5.9"
  spec.frameworks = "StoreKit"
  
  spec.requires_arc = true
end