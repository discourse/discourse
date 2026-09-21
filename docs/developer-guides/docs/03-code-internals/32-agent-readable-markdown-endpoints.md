---
title: Agent-readable Markdown endpoints
---

# Agent-readable Markdown endpoints

When the server-only `experimental_markdown_endpoints` site setting is enabled, Discourse can return supported public and authorized content as `text/markdown`.

The setting is hidden from the admin UI and defaults to off during internal testing. It can be enabled through the Rails console with `SiteSetting.experimental_markdown_endpoints = true`. The intended rollout is to enable the feature by default once it is ready.

Clients can request Markdown in either of these ways:

- append `.md` to a supported URL, such as `/t/example/123.md` or `/latest.md`;
- send `Accept: text/markdown` to the corresponding HTML URL.

An explicit `.md` suffix takes precedence over the `Accept` header. Without the suffix, HTML wins ties and wildcard requests. A higher-quality JSON preference also wins over Markdown. Markdown responses include `Vary: Accept`.

Supported resources are topics (`/t/:slug/:id` and `/t/:id`), individual numbered posts, `/latest`, `/hot`, `/top`, canonical category lists (`/c/:slug/:id`, including nested categories), and tag lists (`/tag/:tag` and `/tag/:slug/:id`). The `.md` suffix and `Accept` negotiation support the same route shapes. Use `/top.md?period=yearly` for a top period. Other list filters, category/tag filter subroutes, user activity, and topic aliases such as `last`, `summary`, and `print` do not advertise or negotiate Markdown.

The homepage `/` is a special case: when Markdown is preferred via `Accept`, it serves the latest-topic list regardless of the configured HTML homepage. HTML homepage responses advertise `/latest.md`. The normal HTML homepage is unchanged; there is no `/.md` alias.

Topics retain `TopicView` pagination and include previous/next `.md` links. Individual-post URLs contain only that post. Topic filters, including author and reply filters, are retained in discovery and pagination links. Topic lists expose their native previous/next URLs as links on the supported Markdown route, preserving list filters and subfolder paths. Category next-page links use the category loader's pagination state and scoped lookahead, not the number of rendered parent and child entries.

Post attribution uses a level-three "Author:" heading with an avatar and linked username, followed by a level-four "Post date:" heading with the timestamp. Avatars are not included in topic lists; lists include reply counts (the normal post count minus the first post) and "Last updated:" timestamps based on the last post date. Timestamps use the reader's saved timezone, falling back to the application timezone (UTC by default), and include a timezone abbreviation. They link to the post or topic with an exact ISO 8601 timestamp as the Markdown link title. Image display sizes and title tooltips depend on the Markdown viewer.

Each topic-list item's author, reply count, and timestamp are wrapped in `<div class="topic-metadata">`, excluding its title and excerpt. Each post's author and timestamp headings are wrapped in `<div class="post-metadata">`, excluding the post body. Blank lines around the wrapper contents preserve Markdown parsing in CommonMark/GFM viewers with raw HTML enabled. Viewers may strip the wrappers or their classes during sanitization.

`/categories.md` and `/tags.md` provide directories with names, short descriptions, and links to the corresponding Markdown topic lists. Both support `Accept: text/markdown` on their extensionless URLs and advertise their Markdown representation on HTML responses. Topic-list responses link to these directories; the tags link is omitted when tagging is disabled.

Directories reuse the HTML/JSON controller loaders, including their permissions, ordering, localization, and plugin customizations. Categories follow the configured category layout and native `?page=2` pagination; `?include_subcategories=true` includes the children supplied by that loader. Parent links appear when both entries are present. Tags combine the existing top-level and grouped/category-associated entries into a single deduplicated list, without separate Markdown pagination. Admins can see unused and private-message-only tags when the normal tag directory permits them.

The normal controller queries and authorization checks run before Markdown rendering. This includes topic, category, personal-message, whisper, tag, hidden-post, and deleted-post rules. The representation does not create a separate public-content index.

Supported HTML responses advertise their Markdown counterpart with an HTTP `Link` header and a `<link rel="alternate" type="text/markdown">` element. RSS feeds include an equivalent `atom:link`. Discovery URLs retain supported list filters but omit authentication and unrelated parameters.

Cooked post HTML is converted to GitHub-flavored Markdown after serializer redaction and localization. Posts and their localizations are preloaded before rendering, and list creators are preloaded with the topic page. Only transformed post bodies are cached. Cache keys include a digest of the exact effective cooked HTML, converter version, locale, base URL, and asset host so rebakes, CDN changes, and reader-specific redaction cannot reuse stale output.

The negotiation and discovery contract follows the [Accept Markdown reference](https://acceptmarkdown.com/reference): quality values determine the preferred representation, explicit `q=0` excludes Markdown, and `Vary: Accept` applies to negotiated HTML/JSON/Markdown responses, redirects, and errors. HTML remains the default for ties and wildcards. This feature preserves existing handling of unsupported Accept types rather than adding a strict `406` mode.
