# DO NOT MERGE — autoresearch experiment branch

This branch is the long-lived target of an automated optimisation loop
(`autoresearch/run.sh`) trying to reduce CI runtime of the system test
suite. Each commit on the branch is one experiment. Force-pushes are
expected.

The associated draft PR has base = `main`, head = this branch. Do not
review individual commits; cherry-pick winning commits into real PRs.

Pinned base SHA (`origin/main` at bootstrap time): `30f548a01f8560cc198378c9c2adf894be73201e`
