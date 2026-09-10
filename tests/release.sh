#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
export RELEASE_TEST_LOG="$work/calls"
# Record publication requests without contacting a registry.
make() { printf '%s\n' "$*" >> "$RELEASE_TEST_LOG"; }
export -f make
check_release() {
    local ref=$1 expected=$2
    : > "$RELEASE_TEST_LOG"
    GITHUB_REF="$ref" POSTGRES_VER=17.6 LATEST_ALIAS=latest LATEST_MAJOR=1 bash .github/actions/release.sh
    [[ $(cat "$RELEASE_TEST_LOG") == "$expected" ]]
}
check_release refs/pull/2/merge ''
check_release refs/heads/feature/example ''
check_release refs/heads/main 'buildx-imagetools-create TAG=17 STABILITY_TAG= IMAGETOOLS_TAG=17.6
buildx-imagetools-create TAG=17 STABILITY_TAG= IMAGETOOLS_TAG=17
buildx-imagetools-create TAG=17 STABILITY_TAG= IMAGETOOLS_TAG=latest'
check_release refs/tags/0.1.0 'buildx-imagetools-create TAG=17 STABILITY_TAG=0.1.0 IMAGETOOLS_TAG=17.6-0.1.0
buildx-imagetools-create TAG=17 STABILITY_TAG=0.1.0 IMAGETOOLS_TAG=17-0.1.0'
# Verify release manifests consume immutable architecture tags, matching the build and push targets.
unset -f make
result=$(make -n buildx-imagetools-create TAG=17 STABILITY_TAG=0.1.0 IMAGETOOLS_TAG=17.6-0.1.0)
[[ "$result" == *'supabase-postgres:17.6-0.1.0'* ]]
[[ "$result" == *'wodby/supabase-postgres:17-0.1.0-amd64 wodby/supabase-postgres:17-0.1.0-arm64'* ]]
[[ $(make -n push ARCH=arm64 STABILITY_TAG=0.1.0) == 'docker push wodby/supabase-postgres:17-0.1.0-arm64' ]]
make check-version
if make check-version POSTGRES_VER=18.6 >/dev/null 2>&1; then
    echo 'Mismatched PostgreSQL bundle version was accepted' >&2; exit 1
fi
echo 'Release tag selection and pinned bundle checks passed.'
