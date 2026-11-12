#!/bin/sh

# Trust the mounted workspace regardless of repository name.
git config --global --add safe.directory "$(pwd)"
