# DO NOT MERGE — autoresearch experiment branch

Long-lived target of an automated optimisation loop
(`autoresearch/run.sh`) trying to reduce CI runtime of the system test
suite. Each iteration is rebased onto `d0db90e146a6487cf0642b6a42e12d4316591055` and replays every
prior iteration's commit (and any subsequent revert) on top, so the
branch's `git log` is a chronological record of what the model has
tried.

Rebase base: `d0db90e146a6487cf0642b6a42e12d4316591055`
