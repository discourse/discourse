---
title: Editing submitted forms
short_title: Submitted forms
id: submitted-forms
---

A submitted form stores its definition and typed answers in `Post#form_data`.
The saved definition is independent of later template edits. The answers and definition
produce `raw`; `cooked` is derived through the normal post pipeline.

`Post#form_submission` reads a persisted snapshot without checking answer
completeness. It still checks its structure and value types. System cleanup may
remove a required answer from a deleted post; reading that snapshot must remain
possible. New submissions, `Submission#with_answers` / `for_edit`, and normal
post validation enforce completeness explicitly. A user must supply complete
answers when repairing such a snapshot.

## Updating a form

Do not replace `raw` independently of a form snapshot. Normal validation rejects
such writes, including plugin edits. Permission checks still belong to the caller.

To change answers through Ruby:

```ruby
submission = post.form_submission.with_answers(answers)
PostRevisor.new(post).revise!(
  user,
  { raw: submission.render, form_data: submission.to_h },
)
```

The editing endpoint accepts `post[form_template_data]` containing JSON
`{ "answers": { ... } }`. Clients cannot supply a replacement definition.
A supplied `post[form_state_token]` detects concurrent edits. Explicit overwrite
omits that token, like the existing `original_text` check. Drafts retain the
token from the state they were editing; refreshing it silently would lose conflict detection.

## Automatic text rewrites

`Submission#rewrite_text` applies an existing text rewriter to textual answers,
display labels, choices, and literal output. It leaves field identifiers, tag
identities, and template expressions intact. Render the returned submission again:
conditions and filters evaluate the new values, so the resulting output need not
equal a substitution in the previous output.

For a live post, use `Post#rewritten_content` to obtain matching attributes for
both ordinary posts and forms:

```ruby
post.with_lock do
  content = post.rewritten_content { |text| text.gsub(old_reference, new_reference) }
  post.assign_attributes(content)
  post.save!
end
```

The helper does not select records or persist them. The caller chooses whether to
create a revision, invalidate cooked output, or rebake. Select candidates from
saved answers as well as rendered output: hidden answers have no `quoted_posts`,
`group_mentions`, or rendered-link entry. Multiple identity remappings must use
one pass over the original text so overlapping old/new identifiers do not cascade.

Keep complete mentions, quote markup, hashtags, and image references in textual
answers when they need automatic rewriting. Arbitrary template expressions that
construct an identifier from otherwise unrelated values do not establish a
structured reference to that account or upload. Rewriting template programs or
inferring such identities is outside this API.

Existing username and display-name jobs also rewrite historical snapshots and
grace-period originals. Hotlinked-image localization, image replacement, and
hashtag remapping update live snapshots with their rendered text. Post moves also
remap quote references in live snapshots across topics, including references to
chronologically shifted posts. Group renaming includes omitted answers, and the
deleted-post upload-cleanup automation removes markup from saved answers too.

New submissions are limited to 64 KB, including the definition. System rewrites
may expand saved snapshots beyond that intake limit. Such snapshots remain
readable and editable, but answer edits cannot increase their size further.
Once they shrink below the intake limit, the normal limit applies again.

## Lifecycle and access

- Form posts remain topic first posts. Moves preserve the snapshot; post merging
  already rejects first posts.
- Author deletion clears live form state and stores it in the deletion revision.
  Recovery restores the matching text and snapshot.
- Upload references include saved answers omitted from output. Markdown is parsed
  separately for each answer so one answer cannot consume another's markup.
- Interactive editing and history require edit permission. Webhooks exclude form
  state. Account exports include the author's saved and queued form state.
- Full snapshots are stored separately from revision YAML. Public
  history queries exclude that column.

Administrative import and repair scripts that bypass validation must preserve
the same relationship between answers and text. Database backups preserve the
snapshot columns normally; ordinary rendered-content serializers and search use
`raw` or `cooked`, not omitted answers.

## Rewrite boundaries

A new rendered string cannot be mapped back to answers in general: output may
omit, repeat, filter, or conditionally render an answer. Keep structured answers
as the source of truth and pass the transformation itself to the rewrite API.
Model callbacks cannot enforce this for SQL updates or `update_columns`.

The following administrative paths bypass the rewrite API and require explicit
form handling before use on saved submissions:

- `DbHelper.remap` and `DbHelper.regexp_replace` operate on SQL text columns;
  they do not visit JSONB snapshots. This also affects storage-migration callers.
- `Upload.migrate_to_new_scheme` and the legacy inline-image conversion in
  `FileStore::ToS3Migration` write rendered text directly.
- The `posts:remap`, inline-upload repair, and import normalization tasks operate
  on rendered text, sometimes with validation disabled.

Raw-only plugin edits through normal validation are rejected for form posts.
Such plugins must either edit structured answers explicitly or supply a text
transformation; silently applying a rendered-text diff to every answer is unsafe.
Historical snapshots and grace-period caches have separate lifecycle semantics;
`rewritten_content` changes neither. A job that intentionally rewrites history
must also handle `PostRevision#rewrite_form_data` and cached originals explicitly.
