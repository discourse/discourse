# Vendored mutant skill

`SKILL.md` is a verbatim copy of [mutant's own SKILL.md](https://github.com/mbj/mutant/blob/main/SKILL.md)
— the author's mutation-testing playbook — so Claude Code auto-loads it when
mutation testing is in use.

**Pinned to mutant commit [`efadfe18`](https://github.com/mbj/mutant/commit/efadfe18d6044f05de8600a243a12f300727d42f)**
(2026-03-17). It is not shipped in the `mutant` gem yet (as of 0.16.x), so we
vendor it rather than load from the gem path. If a future release ships it,
switch to the gem copy and delete `SKILL.md` here.

Keep `SKILL.md` pristine so refreshes stay a clean copy. Anything specific to
this repo lives in [`references/migrations-tooling.md`](references/migrations-tooling.md)
instead — read that alongside the playbook.

## Refresh

```sh
curl -fsSL https://raw.githubusercontent.com/mbj/mutant/<new-sha>/SKILL.md \
  -o .skills/mutant/SKILL.md
```

Then update the pinned SHA above.
