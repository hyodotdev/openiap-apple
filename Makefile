.PHONY: test build clean example

test:
	swift test

build:
	swift build

clean:
	swift package clean
	rm -rf .build

example:
	cd Example && xcodebuild -scheme IosIAPExample -destination 'platform=iOS Simulator,name=iPhone 15' build

test-example:
	cd Example && xcodebuild -scheme IosIAPExample -destination 'platform=iOS Simulator,name=iPhone 15' test

open:
	open Package.swift

open-example:
	open Example/IosIAPExample.xcodeproj

open-workspace:
	open IosIAP.xcworkspace