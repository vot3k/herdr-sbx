#!/usr/bin/env zsh
# Link the scripts onto PATH; herdr's popup binding calls them by name.
set -euo pipefail
for f in ${0:A:h}/bin/*; do ln -sfn "$f" ~/.local/bin/${f:t}; done
