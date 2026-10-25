---
title: Editing submitted forms
short_title: Submitted forms
id: submitted-forms
---

A submitted form stores its definition and typed answers in `Post#form_data`.
The saved definition is independent of later template edits. The answers and definition
produce `raw`; `cooked` is derived through the normal post pipeline.

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

Keep complete mentions, quote markup, hashtags, and image references in textual
answers when they need automatic rewriting. Arbitrary template expressions that
construct an identifier from otherwise unrelated values do not establish a
structured reference to that account or upload. Rewriting template programs or
inferring such identities is outside this API.

Existing username and display-name jobs also rewrite historical snapshots and
grace-period originals. Hotlinked-image localization, image replacement, and
hashtag remapping update live snapshots with their rendered text.

## Lifecycle and access

- Form posts remain topic first posts. Moves preserve the snapshot; post merging
  already rejects first posts.
- Author deletion clears live form state and stores it in the deletion revision.
  Recovery restores the matching text and snapshot.
- Upload references include saved answers omitted from output. Markdown is parsed
  separately for each answer so one answer cannot consume another's markup.
- Interactive editing and history require edit permission. Webhooks exclude form
  state. Account exports include the author's saved and queued form state.
- Full snapshots are bounded and stored separately from revision YAML. Public
  history queries exclude that column.

Administrative import and repair scripts that bypass validation must preserve
the same relationship between answers and text. Database backups preserve the
snapshot columns normally; ordinary rendered-content serializers and search use
`raw` or `cooked`, not omitted answers.
