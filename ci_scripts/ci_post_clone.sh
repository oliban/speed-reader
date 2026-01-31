#!/bin/bash

# Xcode Cloud post-clone script
# This runs after Xcode Cloud clones the repository but before building

set -e

echo "Installing Homebrew dependencies..."

# Install XcodeGen via Homebrew
brew install xcodegen

echo "Generating Xcode project..."

# Navigate to the repository root and generate the project
cd "$CI_PRIMARY_REPOSITORY_PATH"
xcodegen generate

echo "Xcode project generated successfully"
