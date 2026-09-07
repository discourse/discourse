---
title: Pinning plugin and theme versions for older Discourse installs (d-compat branches)
short_title: Version compatibility
id: version-compatibility
---

### 📖 Background

Theme and plugin developers generally want to target the `latest` release of Discourse, without worrying about backwards compatibility. But sites running older Discourse releases still need a version of the theme/plugin that works for them.

To bridge that gap, Discourse can be told to check out an older 'pinned' version of the theme/plugin. There are two mechanisms for this, checked in order:

1. **`d-compat/<YYYY>.<M>` git branches** in the theme/plugin repository (the primary method — recommended for all new pins).
2. **A `.discourse-compatibility` YAML file** in the root of the repository (the original mechanism, still supported as a fallback).

If both exist, the branch wins.

### 🌿 The `d-compat/<YYYY>.<M>` branch system

Discourse releases use date-based versions like `2025.5`, `2025.6`, etc. When Discourse updates a plugin or theme from git, it asks the repository: "do you have a branch named `d-compat/<YYYY>.<M>` matching my version?" (e.g. `d-compat/2025.5` for Discourse `2025.5.x`). If so, Discourse checks out the tip of that branch instead of `main`.

The lookup only runs when the local checkout is on the repo's **default branch**. If you've intentionally pinned to a different branch, the d-compat logic is skipped and your pin is respected.

To support an older Discourse version with this system:

1. Create a branch named `d-compat/<YYYY>.<M>` from a commit that's known to work on that version (e.g. `git checkout -b d-compat/2025.5 <commit>`).
2. Push it to `origin`. You may want to protect the branch from accidental deletion.
3. Land any backport commits onto that branch. Discourse instances on `2025.5.x` will pick them up automatically on the next update; instances on newer Discourse will keep tracking the default branch.

You don't need to touch `.discourse-compatibility` at all when using branches.

### ⚙️ Automated branch creation (`create-d-compat-branch.yml`)

In practice you rarely need to create these branches by hand. The default theme and plugin skeletons include a [`d-compat-branch.yml` workflow](https://github.com/discourse/discourse-plugin-skeleton/blob/main/.github/workflows/d-compat-branch.yml) which runs daily, checks for new versions of Discourse core, and pushes matching `d-compat/<YYYY>.<M>` branches as needed.

If your repository was created from an older copy of the skeletons, just copy the [`d-compat-branch.yml`](https://github.com/discourse/discourse-plugin-skeleton/blob/main/.github/workflows/d-compat-branch.yml) file into your `.github/workflows` directory to get it working.

### :git_merged: Backporting a fix to a `d-compat` branch

When you've landed a fix on the default branch that also needs to reach sites on an older Discourse release:

1. Branch off the target d-compat branch and cherry-pick the fix:

   ```bash
   git fetch origin
   git checkout -b backport/my-fix-2025.5 origin/d-compat/2025.5
   git cherry-pick <commit-sha>
   git push -u origin backport/my-fix-2025.5
   ```

2. Open a PR with `d-compat/2025.5` as the **base branch** (not `main`). Get it reviewed and merged the same way you would any other PR.
3. Repeat for each older `d-compat/<YYYY>.<M>` branch that needs the fix.

Sites on `2025.5.x` will pick up the merged commit on their next update.

[details="Legacy fallback: the `.discourse-compatibility` file"]

If no matching `d-compat` branch exists, Discourse falls back to a YAML `.discourse-compatibility` file in the repo root, mapping Discourse versions to git refs of your plugin/theme:

```yaml
< 3.2.0.beta2-dev: abcde
```

Discourse picks the lowest entry that matches the running core version, so anyone on `< 3.2.0.beta2-dev` checks out commit `abcde`. Use `<` (or the legacy `<=`, the default when no operator is given) to specify the version bound. Reach for this only if the branch-based system can't express what you need.

[/details]
