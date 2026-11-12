#!/bin/sh
set -eu

# Install the exact Bundler version recorded in Gemfile.lock.
if [ -f Gemfile.lock ] && grep -q "BUNDLED WITH" Gemfile.lock; then
    bundler_version="$(awk '/^BUNDLED WITH/ { getline; gsub(/ /, ""); print }' Gemfile.lock)"
    gem install bundler --version "$bundler_version" --no-document
    bundle "_${bundler_version}_" install
else
    bundle install
fi

# Install PowerShell modules for the current user only.
pwsh -NoProfile -Command "Set-PSRepository -Name PSGallery -InstallationPolicy Trusted"
pwsh -NoProfile -Command "Install-Module posh-git -Scope CurrentUser -Force"
pwsh -NoProfile -Command "Add-PoshGitToProfile -AllHosts"

# Global npm tooling. The devcontainers-extra npm-package feature (1.0.4) is
# broken upstream, so install directly; Node comes from the devcontainer feature.
npm install -g git-removed-branches @opencode/cli
