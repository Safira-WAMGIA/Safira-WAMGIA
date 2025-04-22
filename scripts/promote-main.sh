#!/usr/bin/env bash
set -euo pipefail

VERSION="${1:-}"

if [[ -z "$VERSION" || ! "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "❌ Uso: ./promote-main.sh 1.2.3"
  exit 1
fi

RELEASE_BRANCH="release/v$VERSION"
TAG="v$VERSION"

git checkout main
git pull origin main
git merge --no-ff "$RELEASE_BRANCH" -m "🔀 Merge release $VERSION"

git tag -a "$TAG" -m "🏁 Versão estável $TAG"
git push origin main
git push origin "$TAG"

echo "✅ Merge concluído e tag '$TAG' enviada!"
echo "ℹ️ Agora o CI em 'main' pode gerar a release com base nessa tag."
