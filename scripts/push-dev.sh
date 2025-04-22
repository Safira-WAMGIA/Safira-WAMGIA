#!/usr/bin/env bash
set -euo pipefail

MSG="${1:-Atualização de código}"
BRANCH="develop"

git checkout $BRANCH
git add .
git commit -m "$MSG"
git push origin $BRANCH

echo "✅ Código enviado para '$BRANCH'"
