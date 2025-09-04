#!/bin/bash

# Usage: ./scripts/bump-version.sh [major|minor|patch|x.x.x]

set -e

# Get current version
CURRENT_VERSION=$(cat VERSION)
echo "Current version: $CURRENT_VERSION"

# Parse version components
IFS='.' read -r -a VERSION_PARTS <<< "$CURRENT_VERSION"
MAJOR="${VERSION_PARTS[0]}"
MINOR="${VERSION_PARTS[1]}"
PATCH="${VERSION_PARTS[2]}"

# Determine new version
if [ -z "$1" ]; then
    echo "Usage: $0 [major|minor|patch|x.x.x]"
    exit 1
fi

case "$1" in
    major)
        NEW_VERSION="$((MAJOR + 1)).0.0"
        ;;
    minor)
        NEW_VERSION="${MAJOR}.$((MINOR + 1)).0"
        ;;
    patch)
        NEW_VERSION="${MAJOR}.${MINOR}.$((PATCH + 1))"
        ;;
    *)
        # Direct version number provided
        NEW_VERSION="$1"
        ;;
esac

echo "New version: $NEW_VERSION"

# Update VERSION file
echo "$NEW_VERSION" > VERSION

# Update openiap.podspec
sed -i '' "s/s.version.*=.*'.*'/s.version          = '$NEW_VERSION'/" openiap.podspec

# Update README.md - CocoaPods installation
sed -i '' "s/pod 'openiap', '~> [0-9.]*'/pod 'openiap', '~> $NEW_VERSION'/" README.md

# Update README.md - Swift Package Manager
sed -i '' "s/.package(url: \"https:\/\/github.com\/hyodotdev\/openiap-apple.git\", from: \"[0-9.]*\")/.package(url: \"https:\/\/github.com\/hyodotdev\/openiap-apple.git\", from: \"$NEW_VERSION\")/" README.md

# Commit changes
git add VERSION openiap.podspec README.md
git commit -m "Bump version to $NEW_VERSION"

# Push commits
git push origin main

# Create and push tag (with check)
if git rev-parse "refs/tags/$NEW_VERSION" >/dev/null 2>&1; then
    echo "⚠️  Tag $NEW_VERSION already exists locally, deleting and recreating..."
    git tag -d "$NEW_VERSION"
fi

git tag "$NEW_VERSION"

# Try to push tag, ignore error if already exists
if ! git push origin "$NEW_VERSION" 2>/dev/null; then
    echo "ℹ️  Tag $NEW_VERSION already exists on remote (probably from CocoaPods release)"
else
    echo "✅ Tag $NEW_VERSION pushed successfully"
fi

echo "✅ Version bumped to $NEW_VERSION and pushed!"
echo "📦 Ready to create a GitHub Release with tag $NEW_VERSION"