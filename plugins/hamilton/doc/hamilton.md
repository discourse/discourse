# Hamilton guide

## Installation and configuration

Hamilton loads from `plugins/hamilton/` when Discourse starts with plugins enabled.
Use the copy supplied with the Discourse source tree; no separate plugin clone,
Ruby bundle, or JavaScript dependency installation is needed inside this directory.
Restart Discourse after updating plugin Ruby code and rebuild assets after frontend changes.

At `/admin/plugins/hamilton/settings`, administrators can edit **Hamilton greeting**,
a string with default value `world`. After saving, visit or reload `/hamilton` to
see `Hello` followed by that value in large, centered text. The value is displayed
as plain text, including any HTML characters. Navigation links connect the greeting
and documentation pages.

## Documentation and authorization

`/hamilton/docs` renders the plugin README as Markdown. Its guide link opens this
guide at `/hamilton/docs/guide`. The README also links to the high-level roadmap
at `/hamilton/docs/roadmap`, covering planned goals and milestones. These pages are
public, including for anonymous visitors on sites with `login_required` enabled. Future user-facing product guides
belong in `doc/` and should be linked from the README.

The greeting follows Discourse's normal login requirements. Signed-in users have no
additional role restriction. Only administrators can change the greeting through
Discourse's standard site settings UI and API; moderators and regular users cannot.

The existing `hamilton_enabled` setting remains available server-side and is hidden
from the settings UI. It defaults to `true`; disabling it returns HTTP 404 for
Hamilton pages and the existing `/hamilton/examples.json` endpoint. The example
endpoint continues to return `{"hello":"world"}` independently of the greeting.

## Architecture

- `plugin.rb` declares metadata, the enable setting, the stylesheet, and the generated
  plugin admin settings route. There is no custom settings form or write endpoint.
- The isolated Rails engine mounts at `/hamilton`. `PagesController` supplies the
  application shell for direct page visits and cooked Markdown JSON for documentation.
  Documentation filenames are fixed server-side; request parameters never select files.
- The Ember route map supplies the greeting and documentation routes. The greeting
  reads the client-exposed `hamilton_greeting` setting and uses an escaped translation
  placeholder. Documentation uses server-cooked Markdown as trusted HTML.
- `config/settings.yml` and `config/locales/` define settings and translated UI copy.
- `ExamplesController` retains the original example JSON endpoint.

There are no plugin-specific database tables, migrations, or background jobs.

## Tests

Run from the Discourse repository root:

```sh
RAILS_ENV=test bin/rspec plugins/hamilton/spec/requests
RAILS_ENV=test bin/rspec plugins/hamilton/spec/system
```

Request specs cover page loading, public documentation on login-required sites,
README, guide, and roadmap content, disabled-plugin behavior, administrative
setting access, and the existing example endpoint. System specs cover the default greeting,
navigation to documentation and the roadmap (including direct page reloads),
admin greeting changes, literal HTML display, and Discourse's shared core-feature checks.

After changing JavaScript or templates, build assets before system tests:

```sh
pnpm --dir frontend/discourse build
LOAD_PLUGINS=1 bin/rake assets:precompile:build_plugins
```
