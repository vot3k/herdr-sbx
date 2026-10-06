#!/bin/sh
# Run as root inside a sandbox. Ubuntu's packaged nodejs (+dfsg) is built without TypeScript
# type stripping, so `node --test test/*.test.ts` fails on every file there. Install the official
# latest Node 22 into /usr/local (ahead of /usr/bin on PATH), verified against its SHASUMS256.
# No-op when the node on PATH already strips types.
set -eu
command -v node >/dev/null && [ "$(node -p process.features.typescript 2>/dev/null)" != false ] && exit 0
case $(uname -m) in aarch64|arm64) a=arm64 ;; x86_64) a=x64 ;; *) echo "ensure-node-ts: unsupported arch" >&2; exit 1 ;; esac
base=https://nodejs.org/dist/latest-v22.x
sums=$(curl -fsSL "$base/SHASUMS256.txt")
f=$(printf '%s\n' "$sums" | awk -v s="linux-$a.tar.gz" '{ if (substr($2, length($2)-length(s)+1) == s) print $2 }')
cd /tmp && curl -fsSLO "$base/$f"
printf '%s\n' "$sums" | grep " $f\$" | sha256sum -c - >/dev/null
tar -xzf "$f" -C /usr/local --strip-components=1 --exclude CHANGELOG.md --exclude LICENSE --exclude README.md
rm -f "$f"
