# Glimmer conversion campaign

Use [SKILL.md](SKILL.md) for each component. This plan covers selecting targets and
shipping campaign PRs. [PROGRESS.md](PROGRESS.md) records the PRs and the components they
cover.

## Pick targets

Run `git fetch origin main`, then `scripts/rank-targets.py` from the core checkout. It reads
`origin/main` directly and prints the live counts and risk ranking. It excludes files in
open `glimmer-conversion` PRs, select-kit and its subclasses, and subclasses that convert
with a listed base. Use `--list` for the full classic inventory. The ranking weighs
lifecycle and element work, mixins, subclasses, bindings, consumers, and size. Every pick
still gets the [preflight](SKILL.md#preflight).

- **`DEAD?`** means the search found no consumer. Confirm reachability before proposing
  deletion in a separate PR, as in #43390 and #43531.
- **`fields:`** flags possible caller overrides or shared state. Check
  [who reads or writes the value](references/data-flow.md#2-find-who-reads-it-back).
- **`2way:`** needs a data-flow decision. Keep these out of mixed batches.
- **`ts`** suggests a `.gts` result. Budget for a signature, TSDoc, and a ui-kit type test.
- **`BLOCKED`** entries need a dedicated PR or a decision. Remove an entry when its blocker
  is resolved.

`scripts/component-history.py` charts the classic and Glimmer counts over time.

## Batch and open a PR

Batch ten independent conversions into one commit and one PR. Work through each component
individually. Give a conversion its own PR if it needs a data-flow or plugin-API decision,
substantial test changes, or edits to a call site another member of the batch also changes.
A hierarchy goes in one PR. Group ui-kit conversions when they can share a TypeScript review.

Before opening or updating a batch PR, re-run the external sweep for every member on the
final diff and lead the reply with the batch's breakages outside core, one per file with
its fix (see the [report](SKILL.md#report)). Offer to make those fixes in the external
repos. A fix that works on both the classic and the Glimmer base needs no compatibility pin.

When asked to ship, branch from `origin/main` to keep unrelated commits out. If carrying over
changes from another branch, first compare the target files with `origin/main` using
`git diff origin/main HEAD -- <paths>`. Stage only the conversion and its related edits.
Use `0-glimmer-batch-<n>` for a batch or `0-glimmer-<file-name>` for a single conversion.

Use the same subject and body for the commit and the draft PR, without attribution trailers.

- Single conversion: `DEV: Convert <ComponentName> to a glimmer component`
- Single conversion with interface changes or a bug fix:
  `DEV: Modernize <ComponentName> component`
- Batch: `DEV: Convert <n> components to glimmer`

Start the body with the fixed opening and list class names grouped by origin. Put core
components on one bullet and each plugin's components on its own bullet, with the plugin
directory name in parentheses. After the list, add a short sentence for each interface
change or pre-existing bug fixed. Put external follow-ups and behavior differences in the
[user report](SKILL.md#report).

```markdown
Done with the help of our glimmer conversion skill.

* AdminReportTableRow, CategoriesAndLatestTopics, CategoriesAndTopTopics
* SubscriptionsCampaign, SubscriptionsCampaignSidebar (discourse-subscriptions)
```

With `branch`, `subject`, and `body_file` set to the chosen branch, subject, and body path:

```bash
git switch -c "$branch" origin/main
git add -- path/to/component.gjs path/to/related-edit.gjs
{ printf '%s\n\n' "$subject"; cat "$body_file"; } | git commit -F -
git push -u origin "$branch"
gh pr create --draft --base main --title "$subject" --body-file "$body_file" --label glimmer-conversion
```

## Record the PR

Append one top-level PR link to [PROGRESS.md](PROGRESS.md), with one nested bullet per
component. Use short, unambiguous paths such as `ui-kit/d-tap-tile` or
`plugins/discourse-assign/connectors/assigned-list`. Keep `connectors/` in connector paths
to distinguish them from components with the same name.

Run `scripts/refresh-progress.py` after appending. A merged PR gets ☑️, an approved PR gets
✅, and other entries have no mark. The script leaves merged entries alone and rechecks the
rest. Commit the log with the skill, separately from the conversion.

## Next

1. Group ui-kit targets flagged `ts` for TypeScript review.
2. Convert the `edit-category-panel` factory and its panels together.
3. Handle blocked targets individually. Start with the `getTopicFooterButtons` receiver
   contract. Revisit `discourse-root` once the cause of the earlier revert is understood
   (`27408c7e14b` → `9408ea44617`).
4. Ship the external fixes from the conversion reports. One that works on both the classic
   and the Glimmer base can land before the conversion.
