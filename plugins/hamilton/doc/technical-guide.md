# Hamilton technical guide

## Implemented behavior and constraints

Hamilton provides a configurable greeting, public product documentation, and the original example JSON endpoint:

- `GET /hamilton` displays **Hello world** by default. Administrators can change the client-exposed `hamilton_greeting` setting at `/admin/plugins/hamilton/settings`. The greeting renders as plain text.
- `/hamilton/docs`, `/hamilton/docs/guide`, and `/hamilton/docs/roadmap` serve the README, product guide, and roadmap. These documentation pages are public even when Discourse requires login.
- `GET /hamilton/examples.json` returns HTTP 200 with `{"hello":"world"}` when the plugin is enabled and Discourse allows the request. This fixed payload is independent of the greeting setting.
- The `hamilton_enabled` site setting defaults to `true` and is exposed to the Discourse client, but is hidden from the settings UI. Disabling it makes Hamilton pages and the example endpoint return HTTP 404 through Discourse's `requires_plugin` check.

Modeling and simulation features are planned in the roadmap. There are no Hamilton-specific database tables, migrations, custom product persistence, background jobs, or external service integrations. Greeting configuration persists through Discourse's standard site settings.

## Runtime and deployment

Hamilton runs inside a Discourse installation, in the same Rails application and Ruby processes. It is not a standalone application and has no separate server or deployment artifact. It uses Discourse's PostgreSQL and Redis environment and its normal web and background processing infrastructure; Hamilton adds no separate service requirement.

The current checkout's root `Gemfile` requires Ruby `>= 3.4` and `< 4.1` and Rails components `~> 8.1.0`. The root `package.json` declares Node.js `>= 20`, pnpm `^12`, and pins the package manager to `pnpm@12.11.2`. Use the host Discourse checkout's lockfiles and dependency setup when building and testing the integrated application. Hamilton has no separate Ruby bundle or JavaScript dependency installation step.

The plugin header declares version `0.0.1` and no minimum Discourse version. Use the copy supplied with the Discourse source tree and verify compatibility with the intended Discourse version before deployment.

### Installation

1. Use the Hamilton directory supplied with the host Discourse checkout at `plugins/hamilton`, with `plugin.rb` directly inside that directory. No separate plugin clone is needed.
2. Start or rebuild Discourse with plugins enabled so Rails loads Hamilton's settings, routes, translations, and assets. For a containerized production installation, use the host installation's normal application rebuild procedure.
3. Visit `/hamilton` and confirm the default greeting. Sign in if the site requires login. Administrators can change the greeting at `/admin/plugins/hamilton/settings`.
4. Visit `/hamilton/docs` to read the public product documentation, and request `/hamilton/examples.json` to check the fixed example response.

Hamilton currently has no plugin-specific migration or data import step. Restart or rebuild the host application after installing or updating server code and rebuild assets after frontend changes. The hidden `hamilton_enabled` setting can be changed server-side; disabling it stops Hamilton pages and the example endpoint from responding successfully without uninstalling the files.

## Authorization

`Hamilton::PagesController` and `Hamilton::ExamplesController` inherit Discourse's `ApplicationController` and declare `requires_plugin Hamilton::PLUGIN_NAME`. Discourse checks whether Hamilton is enabled before their actions run.

The greeting and example endpoint follow Discourse's normal login requirements and add no staff or group restriction. On a public site, anonymous visitors can access both. With `login_required` enabled, an anonymous greeting-page request redirects to login and an anonymous example JSON request returns HTTP 403. Documentation actions explicitly skip the login redirect, allowing anonymous visitors to read the README, guide, and roadmap even on a login-required site. Other inherited Discourse request checks still apply.

Only administrators can change `hamilton_greeting`, through Discourse's standard site settings UI and API. Regular users, moderators, and anonymous requests cannot change it. Hamilton adds no custom write endpoint.

Documentation filenames are fixed server-side; request parameters cannot select arbitrary files. Markdown is cooked on the server before display. The greeting uses an escaped translation placeholder so HTML characters appear as text.

The example action returns a fixed public payload, takes no product input, and changes no state. Enabling Hamilton is an availability switch, not a per-user permission system. Any future product resource or write action will need its own server-side authorization and input validation.

## Architecture

All Hamilton implementation files live under `plugins/hamilton/`.

| Path | Responsibility |
| --- | --- |
| `plugin.rb` | Declares plugin metadata, registers `hamilton_enabled`, the stylesheet and admin settings route, defines `Hamilton::PLUGIN_NAME`, and loads the Rails engine. |
| `lib/hamilton/engine.rb` | Defines an isolated `Hamilton` Rails engine and its autoload configuration. It supports loading a scheduled-job directory if one is added; none currently exists. |
| `config/routes.rb` | Mounts the engine at `/hamilton` and routes greeting, documentation, and example requests. |
| `app/controllers/hamilton/pages_controller.rb` | Serves the application shell and cooked Markdown JSON for fixed documentation files. Rewrites the README's guide and roadmap links to their application routes, respecting Discourse's base path. |
| `app/controllers/hamilton/examples_controller.rb` | Applies the plugin enable check and renders the fixed JSON response. |
| `config/settings.yml` | Defines the hidden enable setting and configurable greeting, both exposed to the client. |
| `config/locales/` | Supplies English setting text, the admin settings category label, and translated UI copy. |
| `assets/` | Defines the Ember routes, greeting and documentation templates, navigation, and styles. |
| `doc/` | Contains the product guide, roadmap, and this technical reference. |
| `spec/requests/` | Tests page and documentation responses, plugin disabling, login requirements, administrative setting access, and the example endpoint. |
| `spec/system/` | Tests the greeting and documentation UI, setting changes and literal HTML display, and Discourse's shared core-feature browser examples. |

A request enters Discourse, matches the mounted Hamilton engine route, and passes the inherited controller checks and plugin enable check. Page requests render the application shell for Ember; documentation JSON requests read and cook a fixed Markdown file; the example action renders its fixed JSON response. No Hamilton storage or asynchronous work occurs in these paths.

## Testing

Run commands from the Discourse repository root inside the development container, with the host application's dependencies, test database, Redis, Chromium, and compiled frontend assets available.

Run the focused request suite to check Hamilton's server behavior, including the README and its guide and roadmap links:

```sh
RAILS_ENV=test bin/rspec plugins/hamilton/spec/requests
```

Run the system suite for the default greeting, documentation navigation and direct reloads, public documentation on login-required sites, administrator greeting changes, and literal HTML display:

```sh
RAILS_ENV=test bin/rspec plugins/hamilton/spec/system
```

The system suite also runs Discourse's shared core-feature examples with Hamilton enabled. These cover login, reading and writing topics, likes, profiles, search, and expected plugin JavaScript asset loading. There are currently no Hamilton-specific JavaScript tests.

After changing frontend JavaScript or templates, rebuild the host and plugin assets before browser tests:

```sh
pnpm --dir frontend/discourse build
LOAD_PLUGINS=1 bin/rake assets:precompile:build_plugins
RAILS_ENV=test bin/rspec plugins/hamilton/spec/system/core_features_spec.rb
```

Documentation-only changes do not require rebuilding frontend assets. Run repository lint against the changed files, for example:

```sh
bin/lint --fix plugins/hamilton/README.md plugins/hamilton/doc/technical-guide.md
```

For manual endpoint verification, check the JSON response on an enabled public site, repeat after disabling Hamilton, and check an anonymous JSON request with Discourse's login requirement enabled. These checks exercise different controls from the core-feature browser suite.

## Documentation location

Keep Hamilton product guides in `plugins/hamilton/doc/` and link them from `plugins/hamilton/README.md`. Update the guide alongside changes to implemented behavior, installation requirements, access rules, architecture, or test coverage. Describe future features as proposals until their behavior exists in the plugin.
