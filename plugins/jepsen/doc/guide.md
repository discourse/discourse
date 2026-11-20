# Jepsen product guide

## Installation and settings

Jepsen runs inside Discourse from `plugins/jepsen`. Use the plugin included in the
Discourse checkout; it does not need a separate Ruby bundle or JavaScript package
installation. Restart Discourse after adding or updating the plugin.

The `jepsen_enabled` setting appears under **Plugins** in the admin site settings.
It defaults to enabled, matching the bundled checklist plugin. Administrators can
disable it to make the Jepsen endpoint return HTTP 404. An existing saved value
continues to take precedence over the default.

## Implemented behavior and authorization

`GET /jepsen/examples` (also available as `/jepsen/examples.json`) returns HTTP 200
with `{"hello":"world"}`. This is an example endpoint; no additional product
features or dedicated user interface are implemented.

On a public site, anonymous visitors and signed-in users can read this response.
On a site with `login_required` enabled, visitors must sign in. There are no
additional Jepsen role restrictions, and the endpoint does not change any data.
Only administrators can change the site setting through Discourse administration.

## Architecture

`plugin.rb` declares the plugin, connects its enabled setting, loads the isolated
Rails engine, and mounts it at `/jepsen` after Discourse initializes.
`config/routes.rb` defines the engine's example route.
`app/controllers/jepsen/examples_controller.rb` uses Discourse's application
controller and `requires_plugin` guard to enforce the setting before returning JSON.

Like the bundled checklist plugin, Jepsen uses the repository's shared development
tooling. Its package manifest refers to the workspace Discourse types, and its
TypeScript configuration references the core frontend project. Separate plugin
lockfiles, lint configurations, and standalone CI workflows are unnecessary.

## Tests

Run tests from the Discourse repository root:

```sh
LOAD_PLUGINS=1 RAILS_ENV=test bin/rspec plugins/jepsen/spec/requests
LOAD_PLUGINS=1 RAILS_ENV=test bin/rspec plugins/jepsen/spec/system
```

The request specs cover the enabled default, JSON response, signed-in access,
disabling the plugin, and login-required sites. The system specs exercise shared
Discourse core features with Jepsen enabled, including login, likes, profiles,
topics, replies, and search.

The settings system spec checks that an administrator can find Jepsen under
Plugins and save a disabled value that remains visible after refreshing.
