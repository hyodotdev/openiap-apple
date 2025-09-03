Pod::Spec.new do |s|
  s.name             = 'open-iap'
  s.version          = '1.0.0'
  s.summary          = 'Cross-platform In-App Purchase library using StoreKit 2'
  s.description      = <<-DESC
    OpenIAP is a modern Swift library for handling in-app purchases using StoreKit 2.
    It provides a clean, async/await based API for managing products, purchases, and subscriptions
    across iOS, macOS, tvOS, and watchOS platforms.
  DESC

  s.homepage         = 'https://github.com/hyodotdev/openiap-ios'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'hyodotdev' => 'hyo@hyo.dev' }
  s.source           = { :git => 'https://github.com/hyodotdev/openiap-ios.git', :tag => s.version.to_s }

  s.ios.deployment_target = '13.0'
  s.osx.deployment_target = '10.15'
  s.tvos.deployment_target = '13.0'
  s.watchos.deployment_target = '6.0'

  s.swift_version = '5.0'
  s.source_files = 'Sources/**/*.swift'
  
  s.frameworks = 'StoreKit'
  s.requires_arc = true
  s.module_name = 'OpenIAP'
end