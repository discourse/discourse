# Hopper product guide

## Installation

Hopper loads from `plugins/hopper` as part of the Discourse checkout. Use the
checkout's Ruby and JavaScript dependencies and build process. No separate plugin
Gemfile, dependency installation, or standalone repository is needed.

Restart Discourse after adding or updating the plugin. The `hopper_enabled` site
setting defaults to `true` and is exposed to the client. Administrators can change
it through Discourse site settings.

## Implemented behavior

Hopper currently contains its initial integration only. When enabled,
`GET /hopper/examples.json` returns `{"hello":"world"}`. This example endpoint
does not create or modify records. There are no Hopper product workflows or
frontend components yet.

## Authorization

The example controller inherits Discourse's application controller protections,
including site-wide login requirements. It does not impose an additional staff
or group restriction, so anonymous requests can reach it on a public site.
`requires_plugin "hopper"` rejects requests when `hopper_enabled` is false.
Changing site settings uses Discourse's administrator authorization.

## Architecture

- `plugin.rb` declares plugin metadata, registers the enable setting, defines the
  `Hopper` namespace, and loads the Rails engine.
- `lib/hopper/engine.rb` isolates the `Hopper` namespace.
- `config/routes.rb` mounts the engine at `/hopper` and routes the example request
  to `Hopper::ExamplesController#index`.
- `config/settings.yml` defines the enable setting.
- `package.json` references Discourse's workspace types. `tsconfig.json` extends
  the shared plugin configuration and references the Discourse frontend project.
  Linting and dependency versions come from the containing Discourse repository.

## Tests

Run commands from the Discourse repository root inside the development container:

```sh
RAILS_ENV=test bin/rspec plugins/hopper/spec/system/core_features_spec.rb
```

The system suite enables Hopper and exercises Discourse's shared core feature
checks, including login, topics, replies, likes, profiles, and search. These are
integration smoke tests, rather than coverage of a Hopper product workflow.

After changing frontend JavaScript or templates, rebuild assets before running
browser tests:

```sh
pnpm --dir frontend/discourse build
LOAD_PLUGINS=1 bin/rake assets:precompile:build_plugins
```

Use the repository's `bin/lint` with the changed Hopper file paths for lint checks.
