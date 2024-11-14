---
title: Set up a multisite development environment
short_title: Multisite setup
id: multisite-setup

---
It's possible to run discourse in multisite mode in development. A multisite server uses a different DB and hostname for each site that it serves. This is useful if you are developing a feature or a plugin that should be multisite compatible.

All you need to do is add an appropriate `config/multisite.yml` file. i.e:

```yaml
---
alternate:
  adapter: postgresql
  database: discourse_alternate
  host_names:
  - alternate.localhost
```

To run rake tasks against these extra sites, simply add the `RAILS_DB` environment variable with the name of the site that you are targeting:
```bash
RAILS_DB=alternate rake db:create
RAILS_DB=alternate rake db:migrate
```

Some rake tasks are special in that, when RAILS_DB isn't specified in development, they run across all sites:
```
rake db:create
rake db:migrate
```

*In general, however, running rake tasks without `RAILS_DB` set will target the default site.*

To access the site, you'll need to run ember-cli with the `--forward-host` option.

```
bin/ember-cli -u --forward-host
```

You may now be able to view the your new site at http://alternate.localhost:4200, but if you cannot, you may need to add `alternate.localhost` to your `/etc/hosts` file or equivalent.
