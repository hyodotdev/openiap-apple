Pod::Spec.new do |s|
  s.name             = 'IosIAP'
  s.version          = '1.0.0'
  s.summary          = 'iOS In-App Purchase library using StoreKit 2'
  s.description      = <<-DESC
    IosIAP is a modern Swift library for handling iOS in-app purchases using StoreKit 2.
    It provides a clean, async/await based API for managing products, purchases, and subscriptions.
  DESC

  s.homepage         = 'https://github.com/hyodotdev/ios-iap'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'hyodotdev' => 'hyo@hyo.dev' }
  s.source           = { :git => 'https://github.com/hyodotdev/ios-iap.git', :tag => s.version.to_s }

  s.ios.deployment_target = '13.0'
  s.osx.deployment_target = '10.15'
  s.tvos.deployment_target = '13.0'
  s.watchos.deployment_target = '6.0'

  s.swift_version = '5.0'
  s.source_files = 'Sources/**/*.swift'
  
  s.frameworks = 'StoreKit'
  s.requires_arc = true
end