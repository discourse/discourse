# Setup audit

This historical setup audit is superseded for current availability, predictions, and run status by
[AVAILABILITY_AUDIT.md](AVAILABILITY_AUDIT.md). The revised harness has fourteen examples; both
constant-helper and matcher collisions found by the Rails-loaded run have regressions.

This is a source audit of the unit 2 harness, not a successful Rails run. The supplied local run
reported 17 examples and eight setup failures. The current standalone suite has twelve passing
examples; adding five regressions makes the full suite 22 examples.

## Fabrication coverage

An AST walk of every Ruby file in this directory finds 42 literal `Fabricate` call sites using 25
distinct fabricators. The source search also includes ignored files and multiline calls. The table
groups all 25 direct fabricators and their inherited/nested defaults. Shared fabricators are unchanged.

| Direct fabricators | Defaults and setup constraints checked |
| --- | --- |
| `admin`, `user` | `user_fabricator.rb`: sequenced usernames/emails, nonempty full name, password, active user, TL1 default; admin inherits TL4 and admin status. Explicit `refresh_auto_groups: true` supplies staff/trust group membership for the token and recipient. The inactive activation target intentionally has `active: false`. `Access.eligible_scopes_by_user` ensures admin scope rows before granting. |
| `category`, `category_with_definition` | `category_fabricator.rb`: sequenced names, six-digit colors and user association; definition variant creates its topic/post in the model callback. Category names fit 50 characters, slugs derive from unique names, and the child has a real top-level parent within the default nesting limit of two. The manually tagged definition uses a category without an automatic definition and assigns its canary topic. |
| `topic`, `private_message_topic`, `post` | `topic_fabricator.rb` and `post_fabricator.rb`: sequenced default titles, explicit author/category, and PM sender/recipient `topic_allowed_user` records. Canary text is unique and passes the actual `TextSentinel`; the default reply uses the fabricator's stock-body validation path. The membership request PM also explicitly adds the admin to its allowed users before the approval action. |
| `group`, `group_request` | `group_fabricator.rb` and `group_request_fabricator.rb`: sequenced valid group names, explicit requester/group/reason. The request group gets an owner before enabling membership requests, satisfying `Group#can_allow_membership_requests`. The ordinary group allows public join/exit. Joining as an existing member is an accepted no-op in `GroupSelfMembership.join`. The invitee is initially outside both groups; request savepoints restore membership after mutations. |
| `web_hook`, `web_hook_event` | `web_hook_fabricator.rb` supplies HTTPS, valid content type, a long enough secret and seeded post event types. The hook is inactive. Event defaults include status 200; its callback updates and saves the same hook. Destination fingerprint is read after seeding. Fixtures for ping/redelivery/create are policy-blocked in every configuration. |
| `theme`, `theme_with_remote_url` | `theme_fabricator.rb` sequences names and supplies a user; the remote variant adds `remote_theme` with a URL. Seed settings YAML declares an integer default, and English translations declare the key used by the fixture. Code revision comes from `ThemeSupport.code_revision` after save. Remote synchronization is blocked in every matrix configuration, although its argument-resolution fabricator still runs. |
| `tag`, `tag_group` | `tag_fabricator.rb` / `tag_group_fabricator.rb`: fixed `legal-hold` is valid and not reserved; group names are sequenced. TagGroup's create callback initializes permissions, retained by partial updates. The tag is associated after forced search indexing. |
| `notification`, `user_action`, `bookmark` | Their fabricators receive actual user/post/topic targets. Notification data is serialized JSON and type defaults to mentioned; user action type is explicit. Bookmark names fit the 100-character limit, targets are distinct, and the default reminder is one day ahead. Nine bookmarks are below the default 2,000 limit. |
| `draft` | `draft_fabricator.rb` has a nonlocal `return` in the default key block. Both call sites override `draft_key`, `sequence` and serialized `data`, so that block is never evaluated. Ten topic keys per build are distinct and match the key read by the fixture. `owner` and `revisions` defaults need no associations. The actual gem/default-block evaluation was checked separately without Rails. |
| `reviewable_flagged_post` | `reviewable_fabricator.rb`: supplies created-by user, pending reviewable status and target type; explicit target/topic/target-created-by prevent unrelated target posts. Its nested `reviewable_score` supplies user, reviewed-by, type, score and status, and the association fills the reviewable ID. Calibration's conversation score is explicitly made pending and linked to the PM. Each post has its own reviewable. |
| `post_revision` | `post_revision_fabricator.rb`: revision number two, explicit post/user; canary modifications are a hash. Each post gets one revision; public/private versions are advanced to two to match reads. |
| `badge`, `user_badge` | `badge_fabricator.rb` sequences badge names and nested `badge_type` names; `user_badge_fabricator.rb` supplies granted-at, with explicit user, granting admin and post. Each grant has its own badge, avoiding the single-grant badge/user uniqueness constraint. |
| `upload` | `upload_fabricator.rb`: sequenced SHA1/URL, size, dimensions and extension; explicit user and nonempty `.txt` filename. Validation uses the filename's extension, authorized by the harness. The inherited `.png` extension/dimensions do not trigger an image conversion for this filename. The callback creates `UserUpload`; the harness attaches a separate `UploadReference` to the post. No file is needed merely to persist this fabricator. |
| `category_channel` | `plugins/chat/spec/fabricators/chat_fabricator.rb`: inherits channel name, open status, and type derived from the explicit category. Name length and generated slug fit model limits. No chat message/thread fabricator is invoked. This branch runs only if `Chat::Channel` is defined. All chat primitives are blocked under every active rule. |

`DiscourseTopicVoting::CategorySetting.create!` is guarded by its model constant and followed by a
voting-cache reset. The allowed topic is regular and differs from the category definition topic;
the admin has TL4 voting capacity. The reply belongs to another active user, giving reaction and
solution fixtures a real reply target. `DiscourseDataExplorer::Query.create!` is separately guarded
and receives the required name plus SQL and user. The standalone regression exercises these three
plugin branches both present and absent. It captures arguments, not model validation.

## Uniqueness and schemas

The six matrix builds and seventh calibration build are separate RSpec examples. Rails test setup
uses transactional fixtures. Fixed category/topic/post/upload IDs are distinct within each table
in a build; reuse between examples relies on their outer rollback. Fabrication sequences continue
for default names, emails, hashes and URLs. Literal request names/titles are evaluated inside
request savepoints, and each cell has a further rollback transaction. Thus their deliberate reuse
does not introduce a collision between these seven examples in an isolated test database.

A source-declaration evaluation covered 107 core primitives plus nine plugin primitives, including
the group schema generated from `GroupUpdater::NOTIFICATION_DEFAULT_LEVELS`. Implementation methods
and Rails callbacks were not executed. All 116 fixture rows match the declarations, all 97 declared
top-level ID fields and eight nested ID fields have classifications (105 total). Base arguments and
restricted/missing variants pass JSON Schema after recursive placeholder substitution with representative
values of the seeded shape. The omitted top-level fields were the regular group category preference
and three chat fields. The eight nested fields are `tags[].id` / `parent_tag.id` on both tag-group
writes and `theme_fields[].type_id` / `theme_fields[].upload_id` on both theme writes. The type ID is
an enum; tag and upload IDs get governed probes. Theme probes include valid name, target and upload
field type siblings. `canary_spec.rb` still validates actual resolved values against the live registry.

Plugin registration search included all ignored Ruby sources under `plugins`, and matched nine
`register_mcp_tool` declarations. Plugin enablement settings in the harness match their availability
closures. Core tagging/status switches are enabled. Source/guide tools still require the checkout
and guide files at runtime; those paths exist in this worktree.

## Remaining setup risks

- Database persistence, database constraints, callback interactions and plugin initialization cannot
  be proved by captured arguments or declarations. The full Rails run remains required.
- Fixed high IDs and fixed request names assume an isolated test database. Preexisting rows at
  those IDs/names, or unusually advanced database/Fabrication sequences, can still collide. The
  seven harness builds themselves do not create those cross-example collisions when rollback works.
- The redirect calibration depends on WebMock, DNS interception, HTML title crawling, deferred
  work, and local URL handling together. Their real integration was not executed here.
- Savepoint rollback does not itself revert process caches, Redis, queued work or filesystem
  writes. The harness explicitly restores settings and clears caches/Redis/jobs, but completeness
  of all plugin-specific state restoration requires the multi-cell Rails run.
- Theme ZIP generation/import, upload content sniffing/storage, compiler/cache writes and plugin
  callbacks need runtime verification. Some fixtures are intentionally blocked before those
  operations, but argument resolution still creates a remote theme and exports a ZIP.
- A different plugin load set, missing seed rows, absent repository/guide files, or customized
  site validation settings can change setup prerequisites. The live registry/availability checks
  intentionally fail rather than silently omit required cells.
