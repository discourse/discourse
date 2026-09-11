# Migration handoff

All twelve draft PRs target `main` independently. Each diff contains one migrated operation and the helpers it needs. The setting loops use shared examples with explicit enabled and disabled contexts. Grok, Claude Code and Codex accepted the original cumulative implementation on the third review pass with no outstanding findings; subsequent extraction received a dependency review and separate worker checks. The regression fix restores 8-bit cropped output when metadata is stripped; unstripped 16-bit output remains unchanged.

Review from least to most risky:

| Order | Operation | PR | Branch | Worktree |
| --- | --- | --- | --- | --- |
| 1 | animation | [#43453](https://github.com/discourse/discourse/pull/43453) | `tgxworld/vips-review-01-animation` | `/tmp/discourse-vips-review-01-animation-01a0846e` |
| 2 | svg-dimensions | [#43454](https://github.com/discourse/discourse/pull/43454) | `tgxworld/vips-review-02-svg-dimensions` | `/tmp/discourse-vips-review-02-svg-dimensions-01a0846e` |
| 3 | svg-assets | [#43455](https://github.com/discourse/discourse/pull/43455) | `tgxworld/vips-review-03-svg-assets` | `/tmp/discourse-vips-review-03-svg-assets-01a0846e` |
| 4 | heif | [#43457](https://github.com/discourse/discourse/pull/43457) | `tgxworld/vips-review-05-heif` | `/tmp/discourse-vips-review-05-heif-01a0846e` |
| 5 | ico | [#43462](https://github.com/discourse/discourse/pull/43462) | `tgxworld/vips-review-06-ico` | `/tmp/discourse-vips-review-06-ico-01a0846e` |
| 6 | og | [#43456](https://github.com/discourse/discourse/pull/43456) | `tgxworld/vips-review-04-og` | `/tmp/discourse-vips-review-04-og-01a0846e` |
| 7 | orientation | [#43464](https://github.com/discourse/discourse/pull/43464) | `tgxworld/vips-review-08-orientation` | `/tmp/discourse-vips-review-08-orientation-01a0846e` |
| 8 | jpeg | [#43463](https://github.com/discourse/discourse/pull/43463) | `tgxworld/vips-review-07-jpeg` | `/tmp/discourse-vips-review-07-jpeg-01a0846e` |
| 9 | crop | [#43467](https://github.com/discourse/discourse/pull/43467) | `tgxworld/vips-review-11-crop` | `/tmp/discourse-vips-review-11-crop-01a0846e` |
| 10 | resize | [#43466](https://github.com/discourse/discourse/pull/43466) | `tgxworld/vips-review-10-resize` | `/tmp/discourse-vips-review-10-resize-01a0846e` |
| 11 | downsize | [#43465](https://github.com/discourse/discourse/pull/43465) | `tgxworld/vips-review-09-downsize` | `/tmp/discourse-vips-review-09-downsize-01a0846e` |
| 12 | quality | [#43478](https://github.com/discourse/discourse/pull/43478) | `tgxworld/vips-review-12-quality` | `/tmp/discourse-vips-review-12-quality-01a0846e` |

There is no stacked merge order. Shared helpers appear in several independent diffs and need reconciliation as earlier PRs merge. The quality PR currently covers the caller present on main, `Upload#target_image_quality`; when the orientation and geometry migrations land, their source-quality queries must also be routed through the native estimator. The cumulative integration already demonstrates those final routes. No PR has been merged.

Integration worktree: `/tmp/discourse-vips-migration-01a0846e`; branch `tgxworld/vips-animation-detection`; current commit `57f9cea8d1fcd71ae39cd59fe3362bc27c0e9bd1`. The integration branch is cumulative and was not published as an animation-only PR.

Evidence worktree: `/tmp/discourse-vips-evidence-01a0846e`; branch `tgxworld/vips-migration-evidence`. Operation PR descriptions contain immutable before/after reports and production-image benchmarks. The evidence branch is not intended for merging.

DV `vips-migration-01a0846e` is retained and running. It remains mounted to the integration worktree at `/var/www/discourse`, on branch `tgxworld/vips-animation-detection`. App URL: http://vips-migration-01a0846e.dv.localhost . No task worktree or runtime was removed. The disposable Codex review snapshot was cleaned up after its completed review; Grok and Claude conversations remain available.

Final coordinator commands included `tgx-dv test --name vips-migration-01a0846e spec/lib/discourse_vips_spec.rb spec/models/optimized_image_vips_spec.rb` (90 passing examples), targeted caller/reproduction probes, `tgx-dv lint --name vips-migration-01a0846e spec/lib/discourse_vips_spec.rb spec/models/optimized_image_vips_spec.rb`, and `dv run --name vips-migration-01a0846e -- bundle exec rubocop script/discourse_vips_worker`. Earlier cumulative verification passed 263 examples; the final crop change was then covered by the 90-example run and PR CI.

Production timings ran through the supplied SSH host with Landlock in `discourse/base:2.0.20260812-0036`, digest `sha256:837e8ed4b5916baa36856b842ad84fe262b6b1b5550701f8844b13cc7acad7a5`, as the unprivileged `discourse` user. This is the official launcher default; a custom deployed-image override was not independently confirmed. Font availability and renderer-specific output differences are disclosed in each report. Some small operations are slower with libvips; no universal speedup is claimed.

All twelve independent PR heads have passing full CI; the exact head map and observation times are retained in `published-prs.json`. Missing PNG decoder imports in four extracted specs were fixed and pushed. The frontend failure on #43453, theme-setup failure on #43455, and plugin system timeouts on #43465 and #43467 passed on retry. Earlier triage-only observations and a watcher verdict that contradicted failed timeout checks are not counted as passing coverage. The final check output was verified to contain no failed or pending jobs.

Animation detection retains FastImage as the first check. With the global setting enabled, libvips replaces only the existing ImageMagick fallback; no direct animation routing or APNG parser was added.

The independent-PR follow-up passed 155 focused examples and lint. Each extracted worker passed calls through its actual client and Landlock sandbox; results are in `independent-worker-checks.json`. The broader 258-example run had two failures in unchanged dominant-color backfill examples, also reproduced in isolation and recorded for investigation. The focused run covers all modified shared examples.

After adding the explicit PNG decoder imports, 66 extracted spec examples passed in the retained DV, followed by lint. The worker checks use each independent PR’s own facade, client and sandboxed worker; the RSpec runs use the cumulative integration application.
