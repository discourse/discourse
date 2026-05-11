# DO NOT MERGE — autoresearch experiment branch

Long-lived target of an automated optimisation loop
(`autoresearch/run.sh`) trying to reduce CI runtime of the system test
suite. Each iteration is rebased onto `fc826da5016e0cde20aa76c48b7f775764ffedbc` and replays every
prior iteration's commit (and any subsequent revert) on top, so the
branch's `git log` is a chronological record of what the model has
tried.

Rebase base: `fc826da5016e0cde20aa76c48b7f775764ffedbc`
