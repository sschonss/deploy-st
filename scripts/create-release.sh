#!/usr/bin/env bash
set -euo pipefail

if [ $# -eq 0 ]; then
    echo "Usage: ./scripts/create-release.sh <version>"
    echo "Example: ./scripts/create-release.sh 1.0.0"
    exit 1
fi

VERSION="$1"
TAG="v${VERSION}"

echo "=== Creating Release ${TAG} ==="
echo ""

if ! git diff-index --quiet HEAD --; then
    echo "❌ Error: You have uncommitted changes. Commit or stash them first."
    exit 1
fi

if git rev-parse "$TAG" >/dev/null 2>&1; then
    echo "❌ Error: Tag $TAG already exists."
    exit 1
fi

echo "🏷️  Creating tag $TAG..."
git tag -a "$TAG" -m "Release $TAG"

echo "🚀 Pushing tag to origin..."
git push origin "$TAG"

echo ""
echo "=== Release $TAG Created ==="
echo ""
echo "The CD pipeline will now:"
echo "  1. Build Docker images"
echo "  2. Push to ghcr.io"
echo "  3. Create GitHub Release"
echo "  4. Update staging values"
echo ""
echo "Monitor: https://github.com/sschonss/deploy-st/actions"
