#!/usr/bin/env bash
set -euo pipefail

VERSION="${1:-}"
RELEASE_BRANCH=""

if [[ -z "$VERSION" || ! "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "❌ Uso: ./promote-release.sh 1.2.3"
  exit 1
fi

RELEASE_BRANCH="release/v$VERSION"

git checkout develop
git pull origin develop
git checkout -b "$RELEASE_BRANCH"
git push origin "$RELEASE_BRANCH"

echo "✅ Branch '$RELEASE_BRANCH' criada a partir de 'develop' e enviada para o remoto"
