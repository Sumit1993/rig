#!/bin/bash
# commit.sh MSG [PATHS...] stages the paths (all changes if none), commits, prints SHA and stat.
msg=${1:?usage: commit.sh "<message>" [paths...]}; shift
if [ $# -gt 0 ]; then git add -- "$@"; else git add -A; fi
git commit -q -m "$msg" < /dev/null || exit $?
git log -1 --format='%h %s' && git show --stat --format= HEAD
