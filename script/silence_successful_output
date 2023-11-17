#!/bin/bash

# Run a command and write stdout/stderr to a temporary file. Print the output only if the command exits with a non-zero exit status

tmp=$(mktemp)

echo "[silence_successful_output] Running '$@' with output silenced..." >&2

("$@") 2>&1 &> "$tmp"
STATUS=$?

if (( $STATUS )) ; then
  echo "[silence_successful_output] '$@' failed! Output:" >&2
  cat "$tmp" >&2
else
  echo "[silence_successful_output] '$@' succeeded!"
fi

rm "$tmp"

exit $STATUS
