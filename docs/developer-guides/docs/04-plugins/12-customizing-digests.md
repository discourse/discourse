---
title: Customizing digest emails
short_title: Digest emails
id: customizing-digests
---

Plugins can register the `:user_digest_content` modifier to customize digest content without replacing `UserNotifications#digest`:

```ruby
register_modifier(:user_digest_content) do |content, user, since|
  content.merge(
    topics: content[:topics].where(category_id: category_ids_for(user)),
    template: "my_plugin/digest",
    template_locals: { introduction: introduction_for(user) },
  )
end
```

The modifier runs inside the recipient's locale, after default content selection and before localization, excerpt preparation, and the decision to send an email. Return the content hash, retaining keys you do not change:

| Key                  | Value                                                                                                                                                    |
| -------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `topics`             | A bounded relation or array of `Topic` records. Core uses the first `digest_topics` records as popular topics and the remainder as other new topics.     |
| `posts`              | A bounded relation or array of reply `Post` records.                                                                                                     |
| `template`           | Optional Rails template path with both `.html.erb` and `.text.erb` variants. By default, Core renders its standard digest templates.                     |
| `template_locals`    | A hash passed to both custom template variants. Use this for additional content and counts.                                                              |
| `subject_key`        | Optional translation key, accepting `email_prefix` and `date`. The usual `_improved` variant is used when present and simple email subjects are enabled. |
| `has_custom_content` | Set to `true` when additional content should cause a digest to be sent even without topics or replies. Defaults to `false`.                              |

Custom HTML templates provide the email body; Core supplies the email layout. Custom templates can render Core's digest partials, whose topic/reply localization and excerpts have already been prepared. Additional content passed through locals is the plugin's responsibility to format and localize.

Core retains ownership of recipient locale, unsubscribe headers, topic/post metadata, localization, excerpts, and email construction. It sends a digest when popular topics, replies, or `has_custom_content` are present. Without a modifier, the usual requirement for new topics remains unchanged.

The modifier does **not** authorize replacement content. Prefer narrowing the existing `topics` and `posts` relations, which already apply the recipient's permissions and email preferences. If replacing them, apply appropriate permission, visibility, muting, and suppression rules yourself. Apply query limits before loading records; Core's topic split is not a database limit. Additional content must likewise be authorized for the recipient and bounded before rendering.
