# Lovelace product guide

## Installation and configuration

Lovelace lives in `plugins/lovelace/` in the Discourse source tree and loads with
Discourse. Use the containing Discourse installation and its dependencies; the
plugin has no separate Ruby bundle or JavaScript dependency installation.

Administrators can enable or disable it with the `lovelace_enabled` site setting,
which defaults to `true` and is exposed to the client.

## Implemented behavior and authorization

The current implementation is a minimal foundation. `GET /lovelace/examples.json`
returns HTTP 200 with `{"hello":"world"}` when the plugin is enabled. It is accessible
to anonymous visitors on public sites and signed-in users. When the site requires
login, anonymous JSON requests receive HTTP 403 through Discourse's application
controller. Disabling the plugin causes
signed-in requests to the endpoint to return HTTP 404. There are no additional
Lovelace roles, write operations, or product UI yet.

## Architecture

`plugin.rb` declares the plugin metadata, registers the enable setting, and loads
`Lovelace::Engine`. The isolated Rails engine provides the `Lovelace` namespace;
`config/routes.rb` mounts it at `/lovelace`. `ExamplesController` inherits from
Discourse's `ApplicationController` and uses `requires_plugin` to enforce plugin
availability. There are no plugin database tables or background jobs.

The JavaScript package uses the same workspace dependency on Discourse's types as
other bundled plugins. Its TypeScript configuration references the local
`frontend/discourse` project. Linting, formatting, dependencies, and CI are managed
by the containing Discourse repository.

## Tests

Run commands from the Discourse repository root:

```sh
LOAD_PLUGINS=1 RAILS_ENV=test bin/rspec plugins/lovelace/spec/requests/examples_controller_spec.rb
LOAD_PLUGINS=1 RAILS_ENV=test bin/rspec plugins/lovelace/spec/system/core_features_spec.rb
```

The request specs exercise the endpoint's JSON response, public and private site access, and
disabled-plugin response. The system spec uses Discourse's shared core-feature
suite to check that the enabled plugin coexists with normal forum interactions.
