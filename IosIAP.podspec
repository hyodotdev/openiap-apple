Pod::Spec.new do |s|
  s.name             = 'IosIAP'
  s.version          = '1.0.0'
  s.summary          = '[DEPRECATED] Use openiap instead'
  s.deprecated       = true
  s.deprecated_in_favor_of = 'openiap'
  s.description      = <<-DESC
    [DEPRECATED] This pod has been renamed to 'openiap'.
    Please update your Podfile to use 'openiap' instead of 'IosIAP'.
    
    pod 'openiap', '~> 1.0.0'
    
    IosIAP is now OpenIAP - a modern Swift library for handling in-app purchases using StoreKit 2.
  DESC

  s.homepage         = 'https://github.com/hyodotdev/openiap-apple'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'hyodotdev' => 'hyo@hyo.dev' }
  s.source           = { :git => 'https://github.com/hyodotdev/openiap-apple.git', :tag => s.version.to_s }

  s.ios.deployment_target = '13.0'
  s.osx.deployment_target = '10.15'
  s.tvos.deployment_target = '13.0'
  s.watchos.deployment_target = '6.0'

  s.swift_version = '5.0'
  s.source_files = 'Sources/**/*.swift'
  
  s.frameworks = 'StoreKit'
  s.requires_arc = true
end