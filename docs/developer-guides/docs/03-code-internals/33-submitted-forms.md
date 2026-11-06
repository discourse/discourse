---
title: Editing submitted forms
short_title: Submitted forms
id: submitted-forms
---

A post created from a form template keeps the template definition and the typed
answers in `Post#form_data`. The saved definition is independent of later
template edits, so the form can be reopened after the template changes or is
deleted.

`raw` remains the source of truth for the post. `form_data` is a hint for the
editor: `Post#form_submission` returns the saved submission only while its
rendered output still equals the post's `raw`. Anything that rewrites `raw`
without updating `form_data` (an edit through the markdown composer, a staff
revert, a content remap) makes the post fall back to ordinary markdown editing.

## Updating a form

To change answers through Ruby, render the new submission and revise both
fields together:

```ruby
submission = post.form_submission.with_answers(answers)
PostRevisor.new(post).revise!(
  user,
  { raw: submission.render, form_data: submission.to_h },
)
```

`PUT /posts/:id` accepts `post[form_template_data]` (`{ "answers": { ... } }`);
clients cannot supply a definition. `original_text` detects concurrent edits to
the rendered post; `post[original_form_answers]` does the same for answers the
output template omits. A form edit sent without either check overwrites `raw`
from the saved definition, which is how "overwrite" recovers a form after
another edit.

`form_data` is a tracked field in `PostRevisor`, so revisions record it next to
`raw` and a revert restores both, including the original snapshot cached during
the editing grace period.

A rewrite that should keep the form editable applies the same transformation to
the answers with `Submission#rewrite_answers`, as the hotlinked-image job does;
other rewrites rely on the fallback.

## Lifecycle and access

- Submissions are limited to 64 KB, including the definition. A submission over
  the limit is rejected with a message asking for shorter answers.
- The editor payload (`PostSerializer#form_submission`) is included only for
  users who can edit the post. Webhooks never include it. Account exports
  include the author's saved and queued form state.
- Queued posts carry `form_data` in their payload; reviewers can edit metadata
  but not the rendered text, which is recreated from the form after approval.
