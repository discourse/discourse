# Rhodes guide

## Installation and settings

Rhodes lives in `plugins/rhodes/` inside the Discourse checkout and loads with
Discourse's bundled plugins. Use the checkout's Ruby and JavaScript dependencies
and build process; there is no separate plugin dependency installation.
Restart Discourse after installing or updating the plugin.

Administrators can find `rhodes_enabled` in the Plugins site settings group.
It defaults to enabled and is exposed to the client. Disabling it makes the
Rhodes example endpoint return HTTP 404. An explicitly saved setting continues
to take precedence over the default.

## Implemented behavior and authorization

`GET /rhodes/examples.json` returns HTTP 200 with `{"hello":"world"}` when
Rhodes is enabled. The extensionless `/rhodes/examples` path also returns JSON.
This is an example endpoint; no product interface or data mutations exist yet.

Anonymous visitors and signed-in users can access the endpoint on a public site.
Discourse's site-wide login requirement still applies: anonymous JSON requests
receive HTTP 403 when `login_required` is enabled. Only administrators can change
the site setting through Discourse's administration interface.

## Architecture

`plugin.rb` declares the plugin metadata and enable setting, loads the isolated
`Rhodes::Engine`, and mounts it at `/rhodes` after initialization.
`config/routes.rb` defines the engine's example route.
`app/controllers/rhodes/examples_controller.rb` uses `requires_plugin` to enforce
the enable setting and returns the static example response.

`config/settings.yml` defines the setting; `config/locales/server.en.yml` supplies
its English description. The plugin package uses the checkout's Discourse types,
and `tsconfig.json` references the core frontend project. Dependency management,
lint configuration, and continuous integration belong to the Discourse checkout.

## Tests

Run from the Discourse checkout:

```sh
RAILS_ENV=test bin/rspec plugins/rhodes/spec/requests
RAILS_ENV=test bin/rspec plugins/rhodes/spec/system
```

Request specs cover the default example response, signed-in access, disabling
Rhodes, and the site-wide login requirement. The system spec exercises the
shared core-feature checks with Rhodes enabled, including login, likes, profiles,
topics, and search. System specs require built frontend and plugin assets.

An admin system spec verifies that the setting appears in the Plugins group with
its description, starts enabled, and can be disabled and saved.
