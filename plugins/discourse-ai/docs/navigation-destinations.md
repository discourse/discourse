# Navigation destinations

The Admin Assistant uses `search_discourse_navigation` to find links to common
pages and destinations contributed by installed plugins. Settings search and
setting reads also return a URL filtered to the exact setting name.

This is an accuracy improvement, not enforcement of every generated link. The
assistant is instructed to copy returned URLs and avoid guessing. Its text is still
streamed without link validation. Dynamic resource destinations, a complete route
catalog, and pre-display validation are outside this first implementation.

## Registering a plugin destination

Register destinations in the contributing plugin's `plugin.rb`:

```ruby
register_navigation_destination(
  "example-portal",
  path: "/admin/example-portal",
  title: "example_plugin.navigation.portal.title",
  description: "example_plugin.navigation.portal.description",
  keywords: %w[portal subscription],
) { |guardian| guardian.is_admin? }
```

`title` and `description` are server translation keys owned by the contributing
plugin. Describe what the administrator can do on the page. Keywords supplement
the translated title and description, which are searched in the current locale and
English. The result ID is namespaced automatically using the plugin's name.

Paths must be static local paths, without the installation's base path, query
parameters, or dynamic segments. The resolver adds `Discourse.base_url` at lookup
time, preserving subfolder installations. Registration does not verify that the
route exists: the contributing plugin must test its path against its actual page.

The availability block is required and receives the requesting user's Guardian.
Check applicable permissions and feature availability there. The registry also
omits disabled plugins. Predicates and absolute URLs are evaluated for each lookup;
resolved results are not cached across sites or users. Register each ID once.

The registry is a core API and does not depend on the AI plugin being installed or
initialized. Private plugins can keep their definitions and tests in their own
repositories. Only matching destination metadata is sent to the model.

## Search behavior

The tool is administrator-only and accepts up to 200 characters of keywords.
Matches are ranked by the number of matching terms, with a stable ID tie-breaker,
and limited to eight destinations. An empty match set does not authorize the model
to construct a URL. Use `search_settings` for individual settings.

Core destinations currently cover settings, users, groups, review, invites,
categories, tags, themes, authentication, and backups. Tags are omitted when
tagging is disabled, and invites are omitted when the requesting user cannot invite.
Public hosting pricing questions use the website tool; managing
the current site's account or billing uses local navigation search.
