#!/usr/bin/env bash
# Verify the image built inside Wodby CI matches the outer scan/push reference.
set -euo pipefail
cd "$(dirname "$0")/.."
test_dir=$(mktemp -d)
trap 'rm -rf "$test_dir"' EXIT
cat > "$test_dir/docker" <<'MOCK'
#!/usr/bin/env bash
[[ "$1" != create ]] || printf '%s\n' test-workspace
exit 0
MOCK
cat > "$test_dir/wodby" <<'MOCK'
#!/usr/bin/env python3
import os, subprocess, sys
# Wodby CI forwards only explicit -e arguments into its build container.
env = {'PATH': os.environ['PATH']}
args = sys.argv[1:]
for index, arg in enumerate(args):
    if arg == '-e':
        name, value = args[index + 1].split('=', 1)
        env[name] = value
subprocess.run(['make', '--no-print-directory', '-s', 'image-ref'], env=env, check=True)
MOCK
chmod +x "$test_dir/docker" "$test_dir/wodby"
check() {
    local revision=$1 legacy=$2 expected actual
    expected=$(IMAGE_REVISION="$revision" STABILITY_TAG="$legacy" ARCH=amd64 POSTGRES_VER=17.6 make --no-print-directory -s image-ref)
    actual=$(PATH="$test_dir:$PATH" IMAGE_REVISION="$revision" STABILITY_TAG="$legacy" ARCH=amd64 POSTGRES_VER=17.6 bash scripts/test-supabase-ci.sh)
    [[ "$actual" == "$expected" ]] || { printf 'Expected %s, got %s\n' "$expected" "$actual" >&2; exit 1; }
}
check '' ''
check r0 ''
check r23 9.8.7
# Leave IMAGE_REVISION unset to exercise the legacy Makefile fallback.
expected=$(env -u IMAGE_REVISION STABILITY_TAG=9.8.7 ARCH=amd64 POSTGRES_VER=17.6 make --no-print-directory -s image-ref)
actual=$(env -u IMAGE_REVISION PATH="$test_dir:$PATH" STABILITY_TAG=9.8.7 ARCH=amd64 POSTGRES_VER=17.6 bash scripts/test-supabase-ci.sh)
[[ "$actual" == "$expected" ]]
printf '%s\n' 'CI build references match scan/push references'
