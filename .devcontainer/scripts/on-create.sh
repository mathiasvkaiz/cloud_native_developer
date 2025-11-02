#!/usr/bin/env bash
set -euo pipefail

# Placeholder for one-time container initialization steps.
# Currently ensures git is ready for the vscode user.

if [ -n "${GIT_AUTHOR_NAME:-}" ] && [ -n "${GIT_AUTHOR_EMAIL:-}" ]; then
  git config --global user.name "$GIT_AUTHOR_NAME"
  git config --global user.email "$GIT_AUTHOR_EMAIL"
fi

