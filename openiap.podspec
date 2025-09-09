Pod::Spec.new do |s|
  s.name             = 'openiap'
  s.version          = '1.1.7'
  s.summary          = 'OpenIAP - Modern Swift library for in-app purchases'
  s.description      = <<-DESC
    OpenIAP is a modern Swift library for handling in-app purchases using StoreKit 2.
    Supports iOS and macOS with a simple and intuitive API.
  DESC

  s.homepage         = 'https://github.com/hyodotdev/openiap-apple'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'hyodotdev' => 'hyo@hyo.dev' }
  s.source           = { :git => 'https://github.com/hyodotdev/openiap-apple.git', :tag => s.version.to_s }

  s.ios.deployment_target = '15.0'
  s.osx.deployment_target = '14.0'

  s.swift_version = '5.9'
  s.source_files = 'Sources/**/*.swift'
  
  s.frameworks = 'StoreKit'
  s.requires_arc = true
  s.module_name = 'OpenIAP'
end