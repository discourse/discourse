# Availability derivation and verification

Authority: the supplied `mcp-content-restrictions-plan.md`, “Goal and decisions”, section 8 (“Per-tool decisions”), and section 11 (“In-repo plugins”). The original was read from `/private/tmp/claude-501/-Users-saquetim-code-discourse-core-discourse/aa3b6208-6d40-4d2f-bae0-36a0dc3eab20/scratchpad/`. The operative rules are preserved below so this audit does not depend on that scratch file surviving.

Availability expresses the planned behavior for the submitted arguments. It is independent of current CONTENT declarations, primitive_usable?, and ContentPolicy. Predictions describe where unit 1 currently disagrees with that oracle. In particular, an orphan forum row is a predicted implementation failure, never a reason to mark an intended usable primitive blocked.

All 116 fixture rows were reclassified, including 107 core and nine plugin primitives. Each fixture carries its rule name, plan basis, and blocked_when condition. The standalone regression compares every blocked set against explicit plan-based lists; there is no default blocked/usable classification. The live-registry meta-example checks completeness before filtering any availability.

## Applied rules

- `any`: blocked in all six configurations. Thirteen exit-path writes, three chat tools, and arbitrary SQL (17 primitives). Theme create/update count as writes even when they only change a name.
- `pm_off`: blocked in pm_off and pm_off_and_forum. Five dedicated PM tools plus membership-request handling (six primitives). Membership join and suspension/silence without a custom PM message remain usable.
- `forum`: blocked under every forum_content configuration. All three tag-group writes, including delete, because forum_content always affects tags, even with only category selectors or an allowlist.
- `never`: usable with these arguments in every configuration; output/target assertions still apply.

Section 8 explicitly lists webhook ping/delete as U, while its exit-path row names create/update/redeliver. Therefore ping is usable in this table, despite unit 1 currently marking exit_paths unenforced. Section 8 also certifies content-free reports; signups is this fixture, so the former phase-specific PM-off block was removed. Section 11 certifies event listing as well as reactions/solved/voting, so all four remain usable under forum rules. These decisions add predictions beyond the cells named in the supplied run.

| Rule | Plan basis | Blocked when |
| --- | --- | --- |
| `identity` | Section 8 U: current-user identity, users and user admin. | `never` |
| `search` | Section 8 E: restrict_posts plus post-filter; side-loaded metadata and has_more follow filtered results. | `never` |
| `topic_query` | Section 8 E: PolicyTopicQuery; PM list additionally disabled by PM-off scope override (Decisions; unit 1 S4). | `never` |
| `visible_target` | Section 8 E: visible_topic!/visible_post!; allowed target usable, restricted target identical to missing. | `never` |
| `latest_posts` | Section 8 E: scope_posts on LatestPostsQuery public posts. | `never` |
| `counters` | Section 8 R: omit content-derived counters. | `never` |
| `catalog` | Section 8 E: hide restricted categories/tags and omit forum counts; PM-off removes PM-only tags. | `never` |
| `user_stream` | Section 8 E: extra_where and scope_categories; accounts remain visible. | `never` |
| `summary` | Section 8 E: PolicyUserSummary; omit content-derived stats and crawled titles under any rule (section 3). | `never` |
| `draft` | Section 8 E: draft_allowed?; restricted get is found:false, saves skip PM backup. | `never` |
| `snapshots` | Section 8 E: live topic scope and known polymorphic/output keys. | `never` |
| `pm_scope` | Decisions PM switch and unit 1 S4: dedicated PM tools are blocked under PM-off; section 8 E: forum rules check targets/filter lists. | `pm_off` |
| `post_write` | Section 8 E and Writes: allowed/prospective targets and reference-free agent prose; restricted targets identical to missing. | `never` |
| `user_write` | Section 8 E: grant-check upload IDs and check text references; fixture supplies reference-free bio. | `never` |
| `upload` | Section 8 E: upload grants; fixture supplies new base64 bytes, not a URL or existing upload. | `never` |
| `status` | Section 8 U: user status. | `never` |
| `moderation` | Section 8 E/U: custom PM message refused under PM-off; fixtures supply reason only, or undo moderation. | `never` |
| `reviewables` | Section 8 E: policy scope; check conversation meta_topic as well as target. | `never` |
| `revision` | Section 8 E: visible post and redacted category/tag diffs. | `never` |
| `reviewable_action` | Section 8 E: scoped find_reviewable!; ignore_and_do_nothing fixture sends no PM and deletes no account. | `never` |
| `report_catalog` | Section 8 U: reports list. | `never` |
| `report` | Section 8 E: static content-free report allowlist. Fixture requests signups, not PM counts; usable under all six configurations. | `never` |
| `webhook_metadata` | Section 8 R/E: redact category/tag IDs; events are metadata-only (include_content absent). | `never` |
| `exit_path` | Decisions and section 8 D exit_paths (unit 1 S33): webhook create/update/redeliver, ALL theme writes, site-setting updates disabled while ANY rule is active. | `any` |
| `webhook_safe` | Section 8 U explicitly permits webhook ping/delete; Decisions disables create/update/redeliver. Ping has no stored content payload. | `never` |
| `settings` | Section 8 R: redact governed category/tag/topic values and internal URLs. | `never` |
| `theme_read` | Section 8 U: theme reads. | `never` |
| `source` | Section 8 U: authoring guides, source and research prompt. | `never` |
| `groups` | Section 8 U: other group tools; fixtures change membership/owners without reading restricted posts. | `never` |
| `group_defaults` | Section 8 R/E: redact notification category/tag defaults and PM counters; fixtures write bio/name, not default lists. | `never` |
| `group_requests` | Section 8 R: omit membership request reason under ANY rule. | `never` |
| `group_membership` | Section 8 E: request refused under PM-off; fixture uses join, so remains usable. | `never` |
| `group_request_action` | Section 8 E: handling requests is refused under PM-off; otherwise check the request PM against full policy. | `pm_off` |
| `group_posts` | Section 8 E: scope_posts. | `never` |
| `tag_group_write` | Section 8 D tags: create/update/delete are unenforced for tags. Every forum_content rule affects tags, including allowlist/category-only configs; PM-off alone does not. | `forum` |
| `category` | Section 8 E: visible category and definition; prospective parent for create; no reparenting in fixtures. | `never` |
| `chat` | Decisions and section 11: chat uncertified in v1, blocked while ANY rule is active. | `any` |
| `query` | Section 11: data-explorer get_query is none; query definition metadata stays usable. | `never` |
| `sql` | Section 11: data-explorer run_query is unbounded, blocked under ANY rule. | `any` |
| `plugin_action` | Section 11: reactions/solved/voting enforce topics and PMs; other kinds untouched. Allowed targets remain usable under every rule. | `never` |
| `events` | Section 11: events scope_posts, topics/PMs enforced and other kinds untouched; listing remains usable. | `never` |

## Every primitive

`U` = usable; `B` = policy-blocked. “Forum” applies separately to allowlist, denied_category, denied_tag and combined; their availability columns are identical. Target visibility still differs by configuration.

| Primitive | Rule | PM off | Forum | PM off + forum |
| --- | --- | --- | --- | --- |
| `tool:discourse_current_user_get` | `identity` | U | U | U |
| `tool:discourse_search` | `search` | U | U | U |
| `tool:discourse_filter_topics` | `topic_query` | U | U | U |
| `tool:discourse_search_posts` | `search` | U | U | U |
| `tool:discourse_read_topic_posts` | `visible_target` | U | U | U |
| `tool:discourse_get_post_replies` | `visible_target` | U | U | U |
| `tool:discourse_list_latest_posts` | `latest_posts` | U | U | U |
| `tool:discourse_get_topic_view_stats` | `visible_target` | U | U | U |
| `tool:discourse_list_directory_items` | `counters` | U | U | U |
| `tool:discourse_read_topic` | `visible_target` | U | U | U |
| `tool:discourse_read_post` | `visible_target` | U | U | U |
| `tool:discourse_topic_list` | `topic_query` | U | U | U |
| `tool:discourse_category_list` | `catalog` | U | U | U |
| `tool:discourse_tag_list` | `catalog` | U | U | U |
| `tool:discourse_get_user` | `identity` | U | U | U |
| `tool:discourse_list_user_posts` | `user_stream` | U | U | U |
| `tool:discourse_get_user_summary` | `summary` | U | U | U |
| `tool:discourse_list_user_actions` | `user_stream` | U | U | U |
| `tool:discourse_get_draft` | `draft` | U | U | U |
| `tool:discourse_bookmark_list` | `snapshots` | U | U | U |
| `tool:discourse_notification_list` | `snapshots` | U | U | U |
| `tool:discourse_list_private_messages` | `pm_scope` | B | U | B |
| `tool:discourse_read_private_message` | `pm_scope` | B | U | B |
| `tool:discourse_create_topic` | `post_write` | U | U | U |
| `tool:discourse_create_post` | `post_write` | U | U | U |
| `tool:discourse_update_post` | `post_write` | U | U | U |
| `tool:discourse_update_topic` | `post_write` | U | U | U |
| `tool:discourse_update_user` | `user_write` | U | U | U |
| `tool:discourse_upload_file` | `upload` | U | U | U |
| `tool:discourse_create_private_message` | `pm_scope` | B | U | B |
| `tool:discourse_reply_private_message` | `pm_scope` | B | U | B |
| `tool:discourse_invite_to_private_message` | `pm_scope` | B | U | B |
| `tool:discourse_post_set_deleted` | `post_write` | U | U | U |
| `tool:discourse_save_draft` | `draft` | U | U | U |
| `tool:discourse_delete_draft` | `draft` | U | U | U |
| `tool:discourse_user_status_set` | `status` | U | U | U |
| `tool:discourse_set_topic_pin` | `post_write` | U | U | U |
| `tool:discourse_set_topic_closed` | `post_write` | U | U | U |
| `tool:discourse_suspend_user` | `moderation` | U | U | U |
| `tool:discourse_unsuspend_user` | `moderation` | U | U | U |
| `tool:discourse_silence_user` | `moderation` | U | U | U |
| `tool:discourse_unsilence_user` | `moderation` | U | U | U |
| `tool:discourse_get_review_queue_count` | `reviewables` | U | U | U |
| `tool:discourse_list_reviewables` | `reviewables` | U | U | U |
| `tool:discourse_list_reviewable_topics` | `reviewables` | U | U | U |
| `tool:discourse_get_reviewable` | `reviewables` | U | U | U |
| `tool:discourse_get_user_moderation_summary` | `counters` | U | U | U |
| `tool:discourse_get_post_revision` | `revision` | U | U | U |
| `tool:discourse_perform_reviewable_action` | `reviewable_action` | U | U | U |
| `tool:discourse_list_reports` | `report_catalog` | U | U | U |
| `tool:discourse_get_report` | `report` | U | U | U |
| `tool:discourse_list_webhooks` | `webhook_metadata` | U | U | U |
| `tool:discourse_get_webhook` | `webhook_metadata` | U | U | U |
| `tool:discourse_list_webhook_events` | `webhook_metadata` | U | U | U |
| `tool:discourse_create_webhook` | `exit_path` | B | B | B |
| `tool:discourse_update_webhook` | `exit_path` | B | B | B |
| `tool:discourse_delete_webhook` | `webhook_safe` | U | U | U |
| `tool:discourse_ping_webhook` | `webhook_safe` | U | U | U |
| `tool:discourse_redeliver_webhook_event` | `exit_path` | B | B | B |
| `tool:discourse_list_site_settings` | `settings` | U | U | U |
| `tool:discourse_update_site_setting` | `exit_path` | B | B | B |
| `tool:discourse_set_theme_code` | `exit_path` | B | B | B |
| `tool:discourse_get_theme` | `theme_read` | U | U | U |
| `tool:discourse_create_theme` | `exit_path` | B | B | B |
| `tool:discourse_update_theme` | `exit_path` | B | B | B |
| `tool:discourse_list_authoring_guides` | `source` | U | U | U |
| `tool:discourse_read_authoring_guide` | `source` | U | U | U |
| `tool:discourse_source_version` | `source` | U | U | U |
| `tool:discourse_read_source` | `source` | U | U | U |
| `tool:discourse_search_source` | `source` | U | U | U |
| `tool:discourse_list_themes` | `theme_read` | U | U | U |
| `tool:discourse_delete_theme` | `exit_path` | B | B | B |
| `tool:discourse_install_theme` | `exit_path` | B | B | B |
| `tool:discourse_sync_remote_theme` | `exit_path` | B | B | B |
| `tool:discourse_upload_theme_asset` | `exit_path` | B | B | B |
| `tool:discourse_update_theme_setting` | `exit_path` | B | B | B |
| `tool:discourse_update_theme_translations` | `exit_path` | B | B | B |
| `tool:discourse_list_groups` | `groups` | U | U | U |
| `tool:discourse_get_group` | `group_defaults` | U | U | U |
| `tool:discourse_list_group_members` | `groups` | U | U | U |
| `tool:discourse_list_group_membership_requests` | `group_requests` | U | U | U |
| `tool:discourse_create_group` | `group_defaults` | U | U | U |
| `tool:discourse_update_group` | `group_defaults` | U | U | U |
| `tool:discourse_delete_group` | `groups` | U | U | U |
| `tool:discourse_manage_group_members` | `groups` | U | U | U |
| `tool:discourse_invite_group_members` | `groups` | U | U | U |
| `tool:discourse_manage_group_owners` | `groups` | U | U | U |
| `tool:discourse_manage_group_membership` | `group_membership` | U | U | U |
| `tool:discourse_handle_group_membership_request` | `group_request_action` | B | U | B |
| `tool:discourse_list_group_posts` | `group_posts` | U | U | U |
| `tool:discourse_search_tag_groups` | `catalog` | U | U | U |
| `tool:discourse_list_tag_groups` | `catalog` | U | U | U |
| `tool:discourse_get_tag_group` | `catalog` | U | U | U |
| `tool:discourse_create_tag_group` | `tag_group_write` | U | B | B |
| `tool:discourse_update_tag_group` | `tag_group_write` | U | B | B |
| `tool:discourse_delete_tag_group` | `tag_group_write` | U | B | B |
| `tool:discourse_get_category` | `category` | U | U | U |
| `tool:discourse_create_category` | `category` | U | U | U |
| `tool:discourse_update_category` | `category` | U | U | U |
| `tool:discourse_delete_category` | `category` | U | U | U |
| `tool:discourse_list_users` | `identity` | U | U | U |
| `tool:discourse_create_user` | `identity` | U | U | U |
| `tool:discourse_manage_user_activation` | `identity` | U | U | U |
| `resource_template:discourse.topic` | `visible_target` | U | U | U |
| `resource_template:discourse.post` | `visible_target` | U | U | U |
| `prompt:discourse.research_topic` | `source` | U | U | U |
| `prompt:discourse.draft_reply` | `visible_target` | U | U | U |
| `tool:chat_channel_list` | `chat` | B | B | B |
| `tool:discourse_get_chat_messages` | `chat` | B | B | B |
| `tool:chat_message_create` | `chat` | B | B | B |
| `tool:discourse_get_query` | `query` | U | U | U |
| `tool:discourse_run_query` | `sql` | B | B | B |
| `tool:discourse_reactions_post_reaction_set` | `plugin_action` | U | U | U |
| `tool:discourse_solved_solution_set` | `plugin_action` | U | U | U |
| `tool:discourse_topic_voting_vote_set` | `plugin_action` | U | U | U |
| `tool:discourse_calendar_event_list` | `events` | U | U | U |

## Updated predictions

Exact RED key-to-reason maps and their disjoint GREEN complements are in `expected_status.json`. The eight current :none declarations are current_user_get, the two authoring-guide tools, the three source tools, discourse.research_topic, and data-explorer get_query. Every planned-usable forum cell other than those eight is RED because the forum_content row is orphaned at unit 1.

| Configuration | RED | GREEN |
| --- | ---: | ---: |
| `pm_off` | 3 | 113 |
| `allowlist` | 88 | 28 |
| `denied_category` | 88 | 28 |
| `denied_tag` | 88 | 28 |
| `combined` | 88 | 28 |
| `pm_off_and_forum` | 82 | 34 |

PM-off RED keys: `tool:discourse_get_user_summary` (crawled title), `tool:discourse_get_report` (content-free report blocked), `tool:discourse_ping_webhook` (ping blocked). The forum configurations include the four certified plugin rows in their orphan-veto RED set. No correctly blocked exit-path, PM-scope or tag-group write is predicted RED merely for being blocked.

The old prediction counts were 1 / 83 / 83 / 83 / 83 / 76 (409 RED total). They are now 3 / 88 / 88 / 88 / 88 / 82 (437 RED total), with 259 GREEN. The supplied observed failures numbered 5 / 90 / 90 / 92 / 92 / 88; those included availability-table defects and were not copied into predictions. The added calibration verifies the crawled title at the actual summary output boundary.

## Validation

The final scoped Rails run used LOAD_PLUGINS=1 and RAILS_DB=discourse_test_mcp_content:
24 examples, six failing matrix examples, zero pending and zero load errors; RSpec duration 52.35s.
All fourteen harness examples, both enrichment examples, and both canary setup/completeness examples
pass. Each of the seven unrestricted output calibrations passed before rules were installed. The
437 observed RED cells match the exact predicted key sets; all other 259 cells are GREEN. See
`verification.json` for observed keys, timing, and the synthetic PM-off redirect token/title evidence.

The supplied older observed file has no PM-off summary failure. On the current tree, even before
changing the output checks, the PM-off matrix returned the crawled title in the admin summary and
failed its existing restricted-token assertion. The new unrestricted output calibration passed as
well. Thus the leak is reproducible and remains predicted RED; the reason for the older GREEN
observation is unresolved rather than attributed to an unverified mechanism.

The first Rails-loaded harness run reproduced both wrong-arity constant-stub failures. Explicitly
binding RSpec's constant helper exposed a Mocha/RSpec anything-matcher collision; the same two
examples then failed on I18n arguments. Both examples pass after the stub fixes. The blocked-error
regression was observed failing first for legitimate HTTP 400, then for the legitimate HTTP 200
tool error. The final helper compares the full response against the exact envelope for its status:
HTTP 400 requires code -32602; HTTP 200 requires only the policy text, isError true, resultType
complete and the exact server metadata. Both require empty headers and reject extra output. This
preserves the plan's error requirement for both certification-gate and implementation refusals.

The plan-availability regression failed before fixture corrections. Mutation checks then rejected:
(1) tag-group blocking limited to configurations with denied tags; (2) blocking certified plugin
rows under forum rules; (3) checking only for the policy-error message while accepting malformed
or extra output. Each mutation was restored immediately. The restored standalone harness passes
14 examples. Ruby lint and formatting pass for all three changed Ruby files.

Prediction reconciliation against the supplied original maps: PM-off adds report and ping; each
forum-only configuration adds ping, events, reactions, solved and voting; PM-off plus forum adds
those five and the content-free report. None of the original RED keys was removed. The unpredicted
exit-path/PM/tag-group failures from the supplied run become correctly blocked GREEN cells. All
three tag-group writes were checked under all five forum configurations, including delete in the
allowlist and denied_category rows.
