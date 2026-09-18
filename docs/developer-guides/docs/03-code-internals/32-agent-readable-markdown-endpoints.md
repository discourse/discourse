---
title: Agent-readable Markdown endpoints
---

# Agent-readable Markdown endpoints

When the server-only `experimental_markdown_endpoints` site setting is enabled, Discourse can return supported public and authorized content as `text/markdown`.

Clients can request Markdown in either of these ways:

- append `.md` to a supported URL, such as `/t/example/123.md` or `/latest.md`;
- send `Accept: text/markdown` to the corresponding HTML URL.

An explicit `.md` suffix takes precedence over the `Accept` header. Without the suffix, HTML wins ties and wildcard requests. A higher-quality JSON preference also wins over Markdown. Markdown responses include `Vary: Accept`.

Supported resources are canonical topics (`/t/:slug/:id`), individual numbered posts, root and topic-list filters, top periods, canonical category lists, canonical tag lists, and a user's topics at `/u/:username/activity`. The `.md` suffix and `Accept` negotiation support the same route shapes. Topic representations contain every post visible to the requesting user; individual-post URLs contain only that post. Topic lists retain their normal query parameters and pagination. Aliases such as topic `last`, `summary`, and `print` views and JSON API routes do not advertise or negotiate Markdown.

The normal controller queries and authorization checks run before Markdown rendering. This includes topic, category, personal-message, whisper, tag, hidden-post, deleted-post, and profile-visibility rules. The representation does not create a separate public-content index.

Supported HTML responses advertise their Markdown counterpart with an HTTP `Link` header and a `<link rel="alternate" type="text/markdown">` element. RSS feeds include an equivalent `atom:link`. Discovery URLs retain supported list filters but omit authentication and unrelated parameters.

Cooked post HTML is converted to GitHub-flavored Markdown after serializer redaction and localization. Posts and their localizations are preloaded before rendering, and list creators are preloaded with the topic page. Only transformed post bodies are cached. Cache keys include a digest of the exact effective cooked HTML, converter version, locale, base URL, and asset host so rebakes, CDN changes, and reader-specific redaction cannot reuse stale output.
