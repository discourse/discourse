---
title: Install plugins in your non-Docker development environment
short_title: Non-Docker plugins
id: non-docker-plugins

---
(This guide only covers non-docker dev install.  For Docker dev :whale:  see https://meta.discourse.org/t/beginners-guide-to-install-discourse-for-development-using-docker/102009?u=merefield)

If you've followed the [instructions to set up your local discourse](https://meta.discourse.org/t/how-do-i-set-up-a-local-discourse-development-environment/182882/1), you can install a plugin locally:

   1. Stop your local server if it's running.

   1. Download the plugin repo and save it your `/plugins` folder. Alternatively, you can [use a symlink](https://meta.discourse.org/t/beginners-guide-to-creating-discourse-plugins-part-4-git-setup/31272#creating-a-symlink-3).

   1. If the plugin includes migrations (you'll see them in `db/migrate`), run them with: `LOAD_PLUGINS=1 bundle exec rake db:migrate` from discourse root, not the plugin folder.

   1. Re-start the server.

   1. If the plugin has settings, you can edit them by going to `http://localhost:4200/admin/plugins` and clicking on "Settings" next to its name.

If you'd like to install a plugin in production, [follow this guide](https://meta.discourse.org/t/install-plugins-in-discourse/19157/1).
