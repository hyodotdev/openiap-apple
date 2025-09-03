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

# Commit changes
git add VERSION openiap.podspec
git commit -m "Bump version to $NEW_VERSION"

# Create and push tag
git tag "$NEW_VERSION"
git push origin main
git push origin "$NEW_VERSION"

echo "✅ Version bumped to $NEW_VERSION and pushed!"
echo "📦 Ready to create a GitHub Release with tag $NEW_VERSION"