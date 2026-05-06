# DO NOT MERGE — autoresearch experiment branch

This branch is the long-lived target of an automated optimisation loop
(`autoresearch/run.sh`) trying to reduce CI runtime of the system test
suite. Each commit on the branch is one experiment. Force-pushes are
expected.

The associated draft PR has base = `main`, head = this branch. Do not
review individual commits; cherry-pick winning commits into real PRs.

Pinned base SHA (`origin/main` at bootstrap time): `3c35398a111e4acc081da1f8cbfc1b8f7bb9bf71`
