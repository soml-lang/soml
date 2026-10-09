#!/bin/sh
# Replaces a copy of the conformance suite in an implementation with the suite in this repository, and writes the commit it came from to `commit` in the copy.
#
#	../soml/sync-conformance.sh test/conformance
set -eu

if [ $# -ne 1 ]; then
	echo 'Usage: sync-conformance.sh <directory>' >&2
	exit 1
fi

repository=$(dirname "$0")
destination=$1

# The copy is replaced with `--delete`, so refuse a directory that is not an earlier copy.
if [ -e "$destination" ] && [ -n "$(ls -A "$destination")" ] && [ ! -f "$destination/invalid-reasons.json" ]; then
	echo "$destination is not empty and is not a copy of the suite" >&2
	exit 1
fi

mkdir -p "$destination"
rsync --archive --delete "$repository/conformance/" "$destination/"

commit=$(git -C "$repository" rev-parse HEAD)

if [ -n "$(git -C "$repository" status --porcelain -- conformance)" ]; then
	commit="$commit with uncommitted changes"
fi

echo "$commit" > "$destination/commit"
