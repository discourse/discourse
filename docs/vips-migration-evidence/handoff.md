# Migration handoff

All twelve draft PRs are published. Grok, Claude Code and Codex accepted the final cumulative source on the third review pass with no outstanding findings. The regression fix restores 8-bit cropped output when metadata is stripped; unstripped 16-bit output remains unchanged.

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

Merge order differs from review-risk order: follow the linear stack 01 animation → 02 SVG dimensions → 03 SVG assets → 04 OG → 05 HEIF → 06 ICO → 07 JPEG → 08 orientation → 09 downsize → 10 resize → 11 crop → 12 quality. No PR has been merged.

Integration worktree: `/tmp/discourse-vips-migration-01a0846e`; branch `tgxworld/vips-animation-detection`; final commit `81f71327e66f0db320939fc8def0826e2e4ea1e0`. The integration branch is cumulative and was not published as an animation-only PR.

Evidence worktree: `/tmp/discourse-vips-evidence-01a0846e`; branch `tgxworld/vips-migration-evidence`. Operation PR descriptions contain immutable before/after reports and production-image benchmarks. The evidence branch is not intended for merging.

DV `vips-migration-01a0846e` is retained and running. It remains mounted to the integration worktree at `/var/www/discourse`, on branch `tgxworld/vips-animation-detection`. App URL: http://vips-migration-01a0846e.dv.localhost . No task worktree or runtime was removed. The disposable Codex review snapshot was cleaned up after its completed review; Grok and Claude conversations remain available.

Final coordinator commands included `tgx-dv test --name vips-migration-01a0846e spec/lib/discourse_vips_spec.rb spec/models/optimized_image_vips_spec.rb` (90 passing examples), targeted caller/reproduction probes, `tgx-dv lint --name vips-migration-01a0846e spec/lib/discourse_vips_spec.rb spec/models/optimized_image_vips_spec.rb`, and `dv run --name vips-migration-01a0846e -- bundle exec rubocop script/discourse_vips_worker`. Earlier cumulative verification passed 263 examples; the final crop change was then covered by the 90-example run and PR CI.

Production timings ran through the supplied SSH host with Landlock in `discourse/base:2.0.20260812-0036`, digest `sha256:837e8ed4b5916baa36856b842ad84fe262b6b1b5550701f8844b13cc7acad7a5`, as the unprivileged `discourse` user. This is the official launcher default; a custom deployed-image override was not independently confirmed. Font availability and renderer-specific output differences are disclosed in each report. Some small operations are slower with libvips; no universal speedup is claimed.

The current CI head map is retained in `published-prs.json`; all twelve exact heads have canonical GREEN verdicts.
