#!/usr/bin/env bash
set -euo pipefail

echo "=== Running GitHub Actions Locally with act ==="
echo ""

if ! command -v act &> /dev/null; then
    echo "❌ 'act' is not installed. Install with: brew install act"
    exit 1
fi

WORKFLOW="${1:-ci}"

case "$WORKFLOW" in
    ci)
        echo "🧪 Running CI pipeline (tests + Docker build)..."
        act push -W .github/workflows/ci.yml --container-architecture linux/amd64
        ;;
    cd)
        VERSION="${2:-v0.0.1-test}"
        echo "🚀 Simulating CD pipeline for tag $VERSION..."
        act push -W .github/workflows/cd.yml --container-architecture linux/amd64 \
            -e <(echo "{\"ref\": \"refs/tags/$VERSION\", \"ref_name\": \"$VERSION\"}")
        ;;
    *)
        echo "Usage: ./scripts/run-ci-local.sh [ci|cd] [version]"
        echo ""
        echo "Examples:"
        echo "  ./scripts/run-ci-local.sh ci           # Run CI pipeline"
        echo "  ./scripts/run-ci-local.sh cd v1.0.0    # Simulate CD for v1.0.0"
        exit 1
        ;;
esac

echo ""
echo "=== Done ==="
