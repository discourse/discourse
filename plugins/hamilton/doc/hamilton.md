# Hamilton guide

## Installation and configuration

Hamilton loads from `plugins/hamilton/` when Discourse starts with plugins enabled.
Use the copy supplied with the Discourse source tree; no separate plugin clone,
Ruby bundle, or JavaScript dependency installation is needed inside this directory.
Restart Discourse after updating plugin Ruby code.

Administrators can toggle `hamilton_enabled` in site settings. It defaults to
`true` and is exposed to the client. Disabling it makes the example endpoint
return HTTP 404.

## Implemented behavior and authorization

`GET /hamilton/examples.json` returns HTTP 200 with `{"hello":"world"}` while
Hamilton is enabled. This is an example endpoint; it does not read or write product
data. Hamilton currently adds no user interface or other product workflows.

The endpoint inherits Discourse's `ApplicationController` protections and uses
`requires_plugin` to enforce the enable setting. It has no additional role or
group restriction. Anonymous visitors can access it on a public site; Discourse's
`login_required` setting restricts access on private sites. Site setting changes
use Discourse's existing administrative authorization.

## Architecture

- `plugin.rb` declares plugin metadata, registers `hamilton_enabled`, defines the
  `Hamilton` namespace, and loads the Rails engine.
- `lib/hamilton/engine.rb` isolates the engine namespace and configures autoloading.
- `config/routes.rb` mounts the engine at `/hamilton` and routes the example request
  to `Hamilton::ExamplesController#index`.
- `config/settings.yml` and `config/locales/` provide the setting and translations.
- `package.json` uses the repository's workspace Discourse types dependency.
  `tsconfig.json` references the core frontend project and maps Hamilton imports.
  Dependency versions, lint configuration, and CI are managed by the parent
  Discourse repository, following the bundled plugin structure.

There are no plugin-specific database tables, migrations, or background jobs.

## Tests

Run from the Discourse repository root:

```sh
RAILS_ENV=test bin/rspec plugins/hamilton/spec/requests/examples_controller_spec.rb
RAILS_ENV=test bin/rspec plugins/hamilton/spec/system/core_features_spec.rb
```

Request specs cover the JSON response, the disabled-plugin response, and access
when login is required. The system spec runs Discourse's shared core-feature
checks with Hamilton enabled to catch integration regressions. There are currently
no Hamilton JavaScript tests.

The system suite uses the repository's browser test setup and built frontend
assets. After changing JavaScript or templates, build assets before running it:

```sh
pnpm --dir frontend/discourse build
LOAD_PLUGINS=1 bin/rake assets:precompile:build_plugins
```
