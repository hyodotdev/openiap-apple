.PHONY: test build clean example

test:
	swift test

build:
	swift build

clean:
	swift package clean
	rm -rf .build

example:
	cd Example && xcodebuild -scheme OpenIapExample -destination 'platform=iOS Simulator,name=iPhone 15' build

test-example:
	cd Example && xcodebuild -scheme OpenIapExample -destination 'platform=iOS Simulator,name=iPhone 15' test

open:
	open Package.swift

open-example:
	open Example/Martie.xcodeproj

open-workspace:
	open OpenIAP.xcworkspace