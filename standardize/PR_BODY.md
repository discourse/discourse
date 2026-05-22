Long-lived branch where an automated loop (`standardize/run.sh`) walks
through rspec spec files and brings each one into compliance with the
guidelines at `.skills/discourse-writing-rspec-tests/SKILL.md`.

Each commit = one spec file's standardization. Per-file rationale lives in
`standardize/state/runs/<file_id>/rationale.md` (local to the operator's
box).

Force-pushes do **not** happen on this branch — each commit is additive.
Split into reviewable chunks by cherry-picking ranges into smaller PRs.
