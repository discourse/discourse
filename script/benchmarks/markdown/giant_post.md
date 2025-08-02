    [discourse]# ./launcher bootstrap app
    which: no docker.io in (/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin:/root/bin)

    WARNING: We are about to start downloading the Discourse base image
    This process may take anywhere between a few minutes to an hour, depending on your network speed

    Please be patient

    Unable to find image 'samsaffron/discourse:1.0.13' locally
    1.0.13: Pulling from samsaffron/discourse
    ........

    Fast-forward
     .travis.yml                                        |   3 -
     Gemfile                                            |  25 +-
     Gemfile.lock                                       | 298 ++++++-----
     README.md                                          |  23 +-
     .../admin/components/embedding-setting.js.es6      |   5 +
     .../screened_ip_address_form_component.js          |  23 +-
     .../admin/controllers/admin-site-settings.js.es6   |  28 +-
     .../admin/controllers/admin-user-badges.js.es6     |   4 +-
     .../javascripts/admin/models/admin-user.js.es6     |  12 +-
     .../javascripts/admin/models/staff_action_log.js   |   3 +-
     app/assets/javascripts/admin/templates/admin.hbs   |   2 +-
     .../templates/components/embedding-setting.hbs     |   2 +-
     .../admin/templates/components/site-setting.hbs    |   2 +-
     .../javascripts/admin/templates/dashboard.hbs      |   2 +-
     .../javascripts/admin/templates/embedding.hbs      |   9 +-
     .../admin/templates/modal/admin_agree_flag.hbs     |   6 +-
     .../admin/templates/modal/admin_delete_flag.hbs    |   2 +-
     .../javascripts/admin/templates/plugins-index.hbs  |  19 +-
     .../admin/templates/site-settings-category.hbs     |   2 +-
     .../javascripts/admin/templates/site-settings.hbs  |   6 +-
     .../javascripts/admin/templates/site-text-edit.hbs |   2 +-
     .../javascripts/admin/templates/user-index.hbs     |  36 +-
     app/assets/javascripts/discourse.js                |   2 +-
     .../javascripts/discourse/adapters/rest.js.es6     |  14 +-
     .../discourse/components/actions-summary.js.es6    |   4 +-
     .../discourse/components/category-chooser.js.es6   |   2 +-
     .../discourse/components/d-editor-modal.js.es6     |  52 ++
     .../discourse/components/d-editor.js.es6           | 263 ++++++++++
     .../javascripts/discourse/components/d-link.js.es6 |   7 +-
     .../discourse/components/date-picker.js.es6        |  22 +-
     .../components/desktop-notification-config.js.es6  |  60 ++-
     .../discourse/components/image-uploader.js.es6     |   9 +-
     .../discourse/components/menu-panel.js.es6         |   3 +-
     .../discourse/components/notification-item.js.es6  |  10 +-
     .../discourse/components/pagedown-editor.js.es6    |  23 -
     .../discourse/components/post-gutter.js.es6        |  53 +-
     .../discourse/components/post-menu.js.es6          |   9 +-
     .../components/private-message-map.js.es6          |   2 +-
     .../discourse/components/who-liked.js.es6          |   2 +-
     .../discourse/controllers/change-owner.js.es6      |   5 +-
     .../discourse/controllers/composer.js.es6          |   4 +-
     .../controllers/discovery-sortable.js.es6          |   6 +-
     .../discourse/controllers/discovery/topics.js.es6  |  11 +-
     .../discourse/controllers/edit-category.js.es6     |  17 +-
     .../discourse/controllers/full-page-search.js.es6  |   2 +-
     .../javascripts/discourse/controllers/login.js.es6 |  37 +-
     .../discourse/controllers/quote-button.js.es6      |  38 +-
     .../javascripts/discourse/controllers/topic.js.es6 |  52 +-
     .../discourse/controllers/user-card.js.es6         |   1 +
     .../javascripts/discourse/controllers/user.js.es6  |  58 ++-
     .../javascripts/discourse/dialects/dialect.js      |   2 +-
     .../discourse/dialects/quote_dialect.js            |  33 +-
     .../discourse/initializers/enable-emoji.js.es6     |  10 +-
     .../discourse/initializers/load-all-helpers.js.es6 |  17 +-
     .../subscribe-user-notifications.js.es6            |  12 +-
     .../javascripts/discourse/lib/Markdown.Editor.js   |   3 +-
     .../javascripts/discourse/lib/autocomplete.js.es6  |  15 +-
     .../discourse/lib/desktop-notifications.js.es6     |  11 +-
     .../discourse/lib/emoji/emoji-groups.js.es6        |  57 ++
     .../discourse/lib/emoji/emoji-toolbar.js.es6       | 259 ++++------
     .../discourse/lib/key-value-store.js.es6           |  16 +-
     .../discourse/lib/keyboard-shortcuts.js.es6        |  15 +-
     .../javascripts/discourse/models/post.js.es6       |  12 +-
     .../javascripts/discourse/models/topic-list.js.es6 |  56 +-
     .../javascripts/discourse/models/topic.js.es6      |   2 +
     .../javascripts/discourse/models/user.js.es6       |   4 +
     .../pre-initializers/dynamic-route-builders.js.es6 |  47 +-
     .../pre-initializers/sniff-capabilities.js.es6     |  21 +-
     .../discourse/routes/app-route-map.js.es6          |  31 +-
     .../discourse/routes/badges-show.js.es6            |   2 +-
     .../discourse/routes/build-category-route.js.es6   |  44 +-
     .../discourse/routes/build-static-route.js.es6     |  18 +
     .../discourse/routes/build-topic-route.js.es6      |  20 +-
     .../javascripts/discourse/routes/discovery.js.es6  |   4 +
     .../discourse/routes/forgot-password.js.es6        |  27 +-
     .../javascripts/discourse/routes/login.js.es6      |  31 +-
     .../templates/components/category-unread.hbs       |   2 +-
     .../templates/components/d-editor-modal.hbs        |   7 +
     .../discourse/templates/components/d-editor.hbs    |  32 ++
     .../templates/components/edit-category-images.hbs  |   2 +-
     .../components/edit-category-topic-template.hbs    |   2 +-
     .../discourse/templates/components/home-logo.hbs   |   3 -
     .../templates/components/pagedown-editor.hbs       |   4 -
     .../discourse/templates/components/user-menu.hbs   |   4 +-
     .../javascripts/discourse/templates/composer.hbs   |   4 +-
     .../discourse/templates/discovery/topics.hbs       |  23 +-
     .../templates/emoji-selector-autocomplete.raw.hbs  |  10 +-
     .../javascripts/discourse/templates/header.hbs     |   2 +-
     .../discourse/templates/login-preferences.hbs      |   8 +
     .../templates/mobile/discovery/topics.hbs          |  17 +-
     .../templates/mobile/list/topic_list_item.raw.hbs  |  49 +-
     .../discourse/templates/modal/create-account.hbs   |  17 +-
     .../discourse/templates/modal/dismiss-read.hbs     |  10 +
     .../discourse/templates/navigation/category.hbs    |   7 +-
     .../javascripts/discourse/templates/post.hbs       |  13 +-
     .../discourse/templates/queued-posts.hbs           |   2 +-
     .../javascripts/discourse/templates/user/about.hbs |   2 +-
     .../discourse/templates/user/preferences.hbs       |   3 +-
     .../javascripts/discourse/templates/user/user.hbs  |  13 +-
     .../discourse/views/cloaked-collection.js.es6      |   3 +
     .../javascripts/discourse/views/composer.js.es6    |  94 ++--
     .../discourse/views/embedded-post.js.es6           |   2 +
     app/assets/javascripts/discourse/views/post.js.es6 |  13 +-
     .../discourse/views/quote-button.js.es6            |  26 +-
     .../discourse/views/topic-entrance.js.es6          |  21 +-
     .../discourse/views/upload-selector.js.es6         |   6 +-
     app/assets/javascripts/main_include.js             |   6 +-
     app/assets/stylesheets/common.scss                 |   1 +
     .../stylesheets/common/admin/admin_base.scss       |   8 -
     app/assets/stylesheets/common/base/compose.scss    |  12 +-
     app/assets/stylesheets/common/base/discourse.scss  |  18 -
     app/assets/stylesheets/common/base/emoji.scss      |   6 +-
     app/assets/stylesheets/common/base/header.scss     |   6 -
     app/assets/stylesheets/common/base/modal.scss      |   4 -
     app/assets/stylesheets/common/base/onebox.scss     |   2 +-
     .../stylesheets/common/base/topic-admin-menu.scss  |   2 +-
     app/assets/stylesheets/common/base/topic-post.scss |   2 -
     app/assets/stylesheets/common/base/topic.scss      |   8 +-
     app/assets/stylesheets/common/base/upload.scss     |   8 +-
     .../stylesheets/common/components/badges.css.scss  |   8 +-
     app/assets/stylesheets/common/d-editor.scss        |  94 ++++
     app/assets/stylesheets/desktop/compose.scss        |  10 +-
     app/assets/stylesheets/desktop/discourse.scss      |   2 +-
     app/assets/stylesheets/desktop/topic-post.scss     |   8 +-
     app/assets/stylesheets/desktop/topic.scss          |   5 +-
     app/assets/stylesheets/desktop/upload.scss         |   2 +-
     app/assets/stylesheets/desktop/user.scss           |   8 -
     app/assets/stylesheets/mobile.scss                 |   1 +
     app/assets/stylesheets/mobile/alert.scss           |   2 +
     app/assets/stylesheets/mobile/banner.scss          |   4 +-
     app/assets/stylesheets/mobile/discourse.scss       |   3 +-
     app/assets/stylesheets/mobile/emoji.scss           |   3 +
     app/assets/stylesheets/mobile/header.scss          |   4 +-
     app/assets/stylesheets/mobile/topic-list.scss      |  32 +-
     app/assets/stylesheets/mobile/topic-post.scss      |  16 +-
     app/assets/stylesheets/mobile/topic.scss           |   3 +-
     app/assets/stylesheets/mobile/user.scss            |   8 +-
     app/controllers/admin/diagnostics_controller.rb    |  13 +
     app/controllers/admin/email_controller.rb          |   6 +
     app/controllers/admin/embedding_controller.rb      |   4 +
     app/controllers/application_controller.rb          |  15 +-
     app/controllers/categories_controller.rb           |  32 +-
     app/controllers/list_controller.rb                 |  29 +-
     app/controllers/manifest_json_controller.rb        |  15 +
     app/controllers/permalinks_controller.rb           |   2 +-
     app/controllers/post_action_users_controller.rb    |  22 +
     app/controllers/post_actions_controller.rb         |  13 +-
     app/controllers/posts_controller.rb                |  30 +-
     app/controllers/robots_txt_controller.rb           |   9 +-
     app/controllers/topics_controller.rb               |   2 +-
     .../users/omniauth_callbacks_controller.rb         |  25 +-
     app/controllers/users_controller.rb                |  26 +-
     app/helpers/application_helper.rb                  |  22 +-
     app/jobs/regular/post_alert.rb                     |   2 +-
     app/jobs/regular/process_post.rb                   |   4 +-
     app/jobs/scheduled/periodical_updates.rb           |   4 +-
     app/mailers/user_notifications.rb                  |   1 +
     app/models/admin_dashboard_data.rb                 |   1 +
     app/models/anon_site_json_cache_observer.rb        |  12 +
     app/models/badge.rb                                |  28 +-
     app/models/category.rb                             |  19 +-
     app/models/category_group.rb                       |   2 +
     app/models/color_scheme.rb                         |  22 +-
     app/models/group.rb                                |   7 +
     app/models/permalink.rb                            |   2 +-
     app/models/post.rb                                 |  21 +-
     app/models/post_action.rb                          |   6 +-
     app/models/post_action_type.rb                     |  10 +
     app/models/post_analyzer.rb                        |   2 +-
     app/models/report.rb                               |  13 +-
     app/models/screened_ip_address.rb                  |   1 +
     app/models/site.rb                                 |  63 ++-
     app/models/topic.rb                                |  65 ++-
     app/models/topic_featured_users.rb                 |   4 +-
     app/models/topic_link.rb                           |  14 +-
     app/models/topic_link_click.rb                     |   2 +-
     app/models/topic_tracking_state.rb                 |  16 +-
     app/models/topic_user.rb                           |  15 -
     app/models/upload.rb                               |   5 +-
     app/models/user.rb                                 |   4 +-
     app/models/user_history.rb                         |  13 +-
     app/models/user_profile.rb                         |   2 +
     app/models/user_profile_view.rb                    |  47 ++
     app/serializers/admin_detailed_user_serializer.rb  |   2 +-
     app/serializers/application_serializer.rb          |  25 +
     app/serializers/badge_serializer.rb                |  15 +-
     app/serializers/basic_post_serializer.rb           |   6 +-
     app/serializers/post_action_user_serializer.rb     |   7 +-
     app/serializers/post_serializer.rb                 |   2 +-
     app/serializers/site_serializer.rb                 |  26 +-
     app/serializers/topic_view_serializer.rb           |   8 +-
     app/serializers/user_history_serializer.rb         |   1 +
     app/serializers/user_serializer.rb                 |   7 +-
     app/services/badge_granter.rb                      |  10 +-
     app/services/post_alerter.rb                       |   3 +-
     app/services/random_topic_selector.rb              |  16 +-
     app/services/staff_action_logger.rb                |  62 +++
     app/views/common/_discourse_javascript.html.erb    |   5 +
     app/views/layouts/_head.html.erb                   |  11 +-
     app/views/layouts/application.html.erb             |   1 +
     app/views/list/list.erb                            |   3 +-
     app/views/posts/latest.rss.erb                     |   2 +-
     app/views/topics/plain.html.erb                    |   4 +-
     app/views/topics/show.html.erb                     |   4 +-
     app/views/user_notifications/digest.html.erb       |   4 +-
     .../users/omniauth_callbacks/complete.html.erb     |   4 +-
     app/views/users/show.html.erb                      |   4 +-
     config/application.rb                              |   5 +-
     config/database.yml                                |   2 +
     config/discourse_defaults.conf                     |   8 +-
     config/environments/production.rb                  |   2 +-
     config/environments/profile.rb                     |   2 +-
     config/environments/test.rb                        |   2 +-
     config/initializers/04-message_bus.rb              |   2 +-
     config/initializers/i18n.rb                        |  15 +-
     config/locales/client.ar.yml                       |  45 +-
     config/locales/client.bs_BA.yml                    |  28 +-
     config/locales/client.cs.yml                       |   9 -
     config/locales/client.da.yml                       | 168 +++++-
     config/locales/client.de.yml                       |  65 ++-
     config/locales/client.en.yml                       |  42 +-
     config/locales/client.es.yml                       |  35 +-
     config/locales/client.fa_IR.yml                    |   9 -
     config/locales/client.fi.yml                       | 125 ++++-
     config/locales/client.fr.yml                       |  56 +-
     config/locales/client.he.yml                       | 575 +++++++++++----------
     config/locales/client.it.yml                       | 133 +++--
     config/locales/client.ja.yml                       |   9 -
     config/locales/client.ko.yml                       | 496 +++++++++---------
     config/locales/client.nb_NO.yml                    |  16 +-
     config/locales/client.nl.yml                       |  43 +-
     config/locales/client.pl_PL.yml                    |  66 ++-
     config/locales/client.pt.yml                       |  37 +-
     config/locales/client.pt_BR.yml                    | 215 +++++++-
     config/locales/client.ro.yml                       |   8 -
     config/locales/client.ru.yml                       | 172 ++++--
     config/locales/client.sq.yml                       |   9 -
     config/locales/client.sv.yml                       |   9 -
     config/locales/client.te.yml                       |   8 -
     config/locales/client.tr_TR.yml                    |  11 +-
     config/locales/client.uk.yml                       |   6 -
     config/locales/client.zh_CN.yml                    |  22 +-
     config/locales/client.zh_TW.yml                    |  11 +-
     config/locales/server.ar.yml                       |  61 ++-
     config/locales/server.bs_BA.yml                    |   2 -
     config/locales/server.cs.yml                       |   1 -
     config/locales/server.da.yml                       | 107 +++-
     config/locales/server.de.yml                       | 238 ++++++++-
     config/locales/server.en.yml                       |  37 +-
     config/locales/server.es.yml                       | 134 ++++-
     config/locales/server.fa_IR.yml                    |   2 -
     config/locales/server.fi.yml                       |  85 ++-
     config/locales/server.fr.yml                       |   4 -
     config/locales/server.he.yml                       |  21 +-
     config/locales/server.it.yml                       |  44 +-
     config/locales/server.ja.yml                       |   2 -
     config/locales/server.ko.yml                       |   2 -
     config/locales/server.nb_NO.yml                    |   1 -
     config/locales/server.nl.yml                       |   9 +-
     config/locales/server.pl_PL.yml                    | 236 ++++++++-
     config/locales/server.pt.yml                       |  31 +-
     config/locales/server.pt_BR.yml                    |  14 +-
     config/locales/server.ru.yml                       |  48 +-
     config/locales/server.sq.yml                       |   2 -
     config/locales/server.sv.yml                       |   3 +-
     config/locales/server.te.yml                       |   1 -
     config/locales/server.tr_TR.yml                    |   4 -
     config/locales/server.zh_CN.yml                    |  23 +-
     config/locales/server.zh_TW.yml                    |  38 +-
     config/routes.rb                                   |   7 +-
     config/site_settings.yml                           |  26 +-
     .../20150914021445_create_user_profile_views.rb    |  15 +
     .../20150914034541_add_views_to_user_profile.rb    |   5 +
     ...0917071017_add_category_id_to_user_histories.rb |   6 +
     .../20150924022040_add_fancy_title_to_topic.rb     |   5 +
     .../20150925000915_exclude_whispers_from_badges.rb |  22 +
     docs/INSTALL-cloud.md                              |  59 +--
     docs/VAGRANT.md                                    |   2 +-
     lib/cooked_post_processor.rb                       |  27 +-
     lib/discourse.rb                                   |   6 +-
     lib/discourse_redis.rb                             |   7 +-
     lib/edit_rate_limiter.rb                           |   6 +-
     lib/email.rb                                       |   9 +-
     lib/email/message_builder.rb                       |   2 +-
     lib/email/renderer.rb                              |   4 +-
     lib/email/sender.rb                                |   4 +-
     lib/email/styles.rb                                |  14 +-
     lib/file_store/base_store.rb                       |   6 +-
     lib/freedom_patches/i18n_fallbacks.rb              |   2 +
     lib/freedom_patches/pool_drainer.rb                |  11 +-
     lib/guardian.rb                                    |   2 +-
     lib/guardian/category_guardian.rb                  |   7 +-
     lib/guardian/post_guardian.rb                      |   2 +-
     lib/html_prettify.rb                               | 407 +++++++++++++++
     lib/onebox/engine/discourse_local_onebox.rb        |  11 +-
     lib/oneboxer.rb                                    |  20 +-
     lib/plugin/auth_provider.rb                        |  21 +-
     lib/plugin/instance.rb                             |  10 +-
     lib/post_creator.rb                                |  21 +-
     lib/post_revisor.rb                                |  10 +-
     lib/pretty_text.rb                                 |  21 +
     lib/rate_limiter.rb                                |  11 +-
     lib/rate_limiter/limit_exceeded.rb                 |  25 +-
     lib/search.rb                                      |   2 +-
     lib/site_setting_extension.rb                      |   1 +
     lib/tasks/assets.rake                              |  27 +-
     lib/tasks/db.rake                                  |   2 +
     lib/tasks/posts.rake                               |  20 +-
     lib/topic_creator.rb                               |   4 +-
     lib/topic_query.rb                                 |   9 +-
     lib/topic_view.rb                                  |   6 +-
     lib/version.rb                                     |   4 +-
     plugins/poll/config/locales/client.ar.yml          |  74 ++-
     plugins/poll/config/locales/client.bs_BA.yml       |  13 +-
     plugins/poll/config/locales/client.cs.yml          |   3 -
     plugins/poll/config/locales/client.da.yml          |  14 +-
     plugins/poll/config/locales/client.de.yml          |  12 +-
     plugins/poll/config/locales/client.en.yml          |  12 +-
     plugins/poll/config/locales/client.es.yml          |  12 +-
     plugins/poll/config/locales/client.fa_IR.yml       |   3 -
     plugins/poll/config/locales/client.fi.yml          |  12 +-
     plugins/poll/config/locales/client.fr.yml          |   3 -
     plugins/poll/config/locales/client.he.yml          |  12 +-
     plugins/poll/config/locales/client.id.yml          |   3 -
     plugins/poll/config/locales/client.it.yml          |  12 +-
     plugins/poll/config/locales/client.ja.yml          |   3 -
     plugins/poll/config/locales/client.ko.yml          |   3 -
     plugins/poll/config/locales/client.nb_NO.yml       |   3 -
     plugins/poll/config/locales/client.nl.yml          |   9 +-
     plugins/poll/config/locales/client.pl_PL.yml       |  15 +-
     plugins/poll/config/locales/client.pt.yml          |  12 +-
     plugins/poll/config/locales/client.pt_BR.yml       |  18 +-
     plugins/poll/config/locales/client.ro.yml          |   3 -
     plugins/poll/config/locales/client.ru.yml          |  46 +-
     plugins/poll/config/locales/client.sq.yml          |   3 -
     plugins/poll/config/locales/client.sv.yml          |   3 -
     plugins/poll/config/locales/client.tr_TR.yml       |   3 -
     plugins/poll/config/locales/client.zh_CN.yml       |   9 +-
     plugins/poll/config/locales/server.ar.yml          |  54 +-
     plugins/poll/config/locales/server.bs_BA.yml       |   5 +-
     plugins/poll/config/locales/server.cs.yml          |   2 -
     plugins/poll/config/locales/server.da.yml          |   8 +-
     plugins/poll/config/locales/server.de.yml          |   8 +-
     plugins/poll/config/locales/server.en.yml          |  11 +-
     plugins/poll/config/locales/server.es.yml          |   8 +-
     plugins/poll/config/locales/server.fa_IR.yml       |   2 -
     plugins/poll/config/locales/server.fi.yml          |   8 +-
     plugins/poll/config/locales/server.fr.yml          |   2 -
     plugins/poll/config/locales/server.he.yml          |   8 +-
     plugins/poll/config/locales/server.it.yml          |   8 +-
     plugins/poll/config/locales/server.ja.yml          |   4 +-
     plugins/poll/config/locales/server.ko.yml          |   2 -
     plugins/poll/config/locales/server.nb_NO.yml       |   2 -
     plugins/poll/config/locales/server.nl.yml          |   8 +-
     plugins/poll/config/locales/server.pl_PL.yml       |  10 +-
     plugins/poll/config/locales/server.pt.yml          |   8 +-
     plugins/poll/config/locales/server.pt_BR.yml       |  11 +-
     plugins/poll/config/locales/server.ru.yml          |  52 +-
     plugins/poll/config/locales/server.sq.yml          |   2 -
     plugins/poll/config/locales/server.sv.yml          |   2 -
     plugins/poll/config/locales/server.tr_TR.yml       |   2 -
     plugins/poll/config/locales/server.zh_CN.yml       |   6 +-
     .../db/migrate/20151016163051_merge_polls_votes.rb |  20 +
     plugins/poll/plugin.rb                             |  62 ++-
     .../poll/spec/controllers/posts_controller_spec.rb |  57 +-
     public/403.ar.html                                 |   4 +-
     public/403.it.html                                 |   2 +-
     public/403.zh_CN.html                              |   2 +-
     public/500.zh_CN.html                              |   2 +-
     public/images/welcome/reply-post-2x.png            | Bin 549 -> 430 bytes
     .../welcome/topic-notification-control-2x.png      | Bin 39580 -> 50219 bytes
     public/javascripts/pikaday.js                      |   6 +-
     script/import_scripts/base.rb                      |  21 +-
     script/import_scripts/lithium.rb                   |  22 +-
     script/import_scripts/mbox.rb                      |  52 +-
     script/import_scripts/mybb.rb                      |  38 +-
     .../import_scripts/phpbb3/database/database_3_0.rb |   2 +-
     .../phpbb3/database/database_base.rb               |   2 +-
     script/import_scripts/phpbb3/importer.rb           |   8 +-
     .../phpbb3/importers/message_importer.rb           |  11 +-
     .../phpbb3/importers/post_importer.rb              |   4 +
     .../phpbb3/importers/user_importer.rb              |  11 +-
     script/import_scripts/vbulletin.rb                 |   4 +-
     spec/components/cooked_post_processor_spec.rb      |  23 +-
     spec/components/email/receiver_spec.rb             |   8 +-
     spec/components/email/sender_spec.rb               |   5 +-
     spec/components/guardian_spec.rb                   |  20 +-
     spec/components/html_prettify_spec.rb              |  30 ++
     .../onebox/engine/discourse_local_onebox_spec.rb   |   7 +-
     spec/components/post_creator_spec.rb               |  36 +-
     spec/components/pretty_text_spec.rb                |  15 +-
     spec/components/topic_creator_spec.rb              |  33 +-
     spec/controllers/categories_controller_spec.rb     |  13 +
     spec/controllers/manifest_json_controller_spec.rb  |  12 +
     spec/controllers/permalinks_controller_spec.rb     |  10 +
     .../post_action_users_controller_spec.rb           |  34 ++
     spec/controllers/post_actions_controller_spec.rb   |  35 --
     spec/controllers/posts_controller_spec.rb          |  41 +-
     spec/controllers/session_controller_spec.rb        |   1 +
     spec/controllers/users_controller_spec.rb          |  30 +-
     spec/fabricators/category_group_fabricator.rb      |   5 +
     spec/fabricators/post_fabricator.rb                |  17 +-
     spec/fixtures/emails/paragraphs.cooked             |   2 +-
     spec/helpers/i18n_fallbacks_spec.rb                |  52 ++
     spec/models/category_spec.rb                       |   9 +
     spec/models/color_scheme_spec.rb                   |   9 +-
     spec/models/post_action_spec.rb                    |  16 +
     spec/models/screened_ip_address_spec.rb            |  61 ++-
     spec/models/site_spec.rb                           |   3 +
     spec/models/topic_link_spec.rb                     |   2 +-
     spec/models/topic_spec.rb                          |  21 +-
     spec/models/topic_tracking_state_spec.rb           |  16 -
     spec/models/user_email_observer_spec.rb            |  43 +-
     spec/models/user_profile_view_spec.rb              |  39 ++
     spec/models/user_spec.rb                           |  14 +-
     spec/services/post_alerter_spec.rb                 |  14 +
     spec/services/staff_action_logger_spec.rb          |  77 +++
     .../acceptance/category-edit-test.js.es6           |   2 +-
     .../controllers/admin-user-badges-test.js.es6      |  11 +-
     test/javascripts/components/d-editor-test.js.es6   | 461 +++++++++++++++++
     test/javascripts/components/d-link-test.js.es6     |   4 -
     test/javascripts/helpers/component-test.js.es6     |  12 +-
     test/javascripts/lib/discourse-test.js.es6         |   7 +
     test/javascripts/lib/markdown-test.js.es6          |   4 +
     test/javascripts/models/post-stream-test.js.es6    |   2 +-
     test/javascripts/test_helper.js                    |   3 +
     test/stylesheets/test_helper.css                   |   8 +
     vendor/gems/rails_multisite/.gitignore             |  17 -
     vendor/gems/rails_multisite/Gemfile                |  14 -
     vendor/gems/rails_multisite/Guardfile              |   9 -
     vendor/gems/rails_multisite/LICENSE                |  22 -
     vendor/gems/rails_multisite/README.md              |  29 --
     vendor/gems/rails_multisite/Rakefile               |   7 -
     vendor/gems/rails_multisite/lib/rails_multisite.rb |   3 -
     .../lib/rails_multisite/connection_management.rb   | 190 -------
     .../rails_multisite/lib/rails_multisite/railtie.rb |  23 -
     .../rails_multisite/lib/rails_multisite/version.rb |   3 -
     vendor/gems/rails_multisite/lib/tasks/db.rake      |  31 --
     .../gems/rails_multisite/lib/tasks/generators.rake |  26 -
     .../gems/rails_multisite/rails_multisite.gemspec   |  20 -
     .../spec/connection_management_rack_spec.rb        |  47 --
     .../spec/connection_management_spec.rb             |  99 ----
     .../rails_multisite/spec/fixtures/database.yml     |   6 -
     .../gems/rails_multisite/spec/fixtures/two_dbs.yml |   6 -
     vendor/gems/rails_multisite/spec/spec_helper.rb    |  38 --
     456 files changed, 7519 insertions(+), 3458 deletions(-)
     create mode 100644 app/assets/javascripts/discourse/components/d-editor-modal.js.es6
     create mode 100644 app/assets/javascripts/discourse/components/d-editor.js.es6
     delete mode 100644 app/assets/javascripts/discourse/components/pagedown-editor.js.es6
     create mode 100644 app/assets/javascripts/discourse/lib/emoji/emoji-groups.js.es6
     create mode 100644 app/assets/javascripts/discourse/routes/build-static-route.js.es6
     create mode 100644 app/assets/javascripts/discourse/templates/components/d-editor-modal.hbs
     create mode 100644 app/assets/javascripts/discourse/templates/components/d-editor.hbs
     delete mode 100644 app/assets/javascripts/discourse/templates/components/pagedown-editor.hbs
     create mode 100644 app/assets/javascripts/discourse/templates/login-preferences.hbs
     create mode 100644 app/assets/javascripts/discourse/templates/modal/dismiss-read.hbs
     create mode 100644 app/assets/stylesheets/common/d-editor.scss
     create mode 100644 app/assets/stylesheets/mobile/emoji.scss
     create mode 100644 app/controllers/manifest_json_controller.rb
     create mode 100644 app/controllers/post_action_users_controller.rb
     create mode 100644 app/models/anon_site_json_cache_observer.rb
     create mode 100644 app/models/user_profile_view.rb
     create mode 100644 db/migrate/20150914021445_create_user_profile_views.rb
     create mode 100644 db/migrate/20150914034541_add_views_to_user_profile.rb
     create mode 100644 db/migrate/20150917071017_add_category_id_to_user_histories.rb
     create mode 100644 db/migrate/20150924022040_add_fancy_title_to_topic.rb
     create mode 100644 db/migrate/20150925000915_exclude_whispers_from_badges.rb
     create mode 100644 lib/html_prettify.rb
     create mode 100644 plugins/poll/db/migrate/20151016163051_merge_polls_votes.rb
     create mode 100644 spec/components/html_prettify_spec.rb
     create mode 100644 spec/controllers/manifest_json_controller_spec.rb
     create mode 100644 spec/controllers/post_action_users_controller_spec.rb
     create mode 100644 spec/fabricators/category_group_fabricator.rb
     create mode 100644 spec/helpers/i18n_fallbacks_spec.rb
     create mode 100644 spec/models/user_profile_view_spec.rb
     create mode 100644 test/javascripts/components/d-editor-test.js.es6
     create mode 100644 test/javascripts/lib/discourse-test.js.es6
     delete mode 100644 vendor/gems/rails_multisite/.gitignore
     delete mode 100644 vendor/gems/rails_multisite/Gemfile
     delete mode 100644 vendor/gems/rails_multisite/Guardfile
     delete mode 100644 vendor/gems/rails_multisite/LICENSE
     delete mode 100644 vendor/gems/rails_multisite/README.md
     delete mode 100755 vendor/gems/rails_multisite/Rakefile
     delete mode 100644 vendor/gems/rails_multisite/lib/rails_multisite.rb
     delete mode 100644 vendor/gems/rails_multisite/lib/rails_multisite/connection_management.rb
     delete mode 100644 vendor/gems/rails_multisite/lib/rails_multisite/railtie.rb
     delete mode 100644 vendor/gems/rails_multisite/lib/rails_multisite/version.rb
     delete mode 100644 vendor/gems/rails_multisite/lib/tasks/db.rake
     delete mode 100644 vendor/gems/rails_multisite/lib/tasks/generators.rake
     delete mode 100644 vendor/gems/rails_multisite/rails_multisite.gemspec
     delete mode 100644 vendor/gems/rails_multisite/spec/connection_management_rack_spec.rb
     delete mode 100644 vendor/gems/rails_multisite/spec/connection_management_spec.rb
     delete mode 100644 vendor/gems/rails_multisite/spec/fixtures/database.yml
     delete mode 100644 vendor/gems/rails_multisite/spec/fixtures/two_dbs.yml
     delete mode 100644 vendor/gems/rails_multisite/spec/spec_helper.rb

    I, [2015-10-23T15:53:58.134756 #42]  INFO -- : > cd /var/www/discourse && git fetch origin tests-passed
    From https://github.com/discourse/discourse
     * branch            tests-passed -> FETCH_HEAD
    I, [2015-10-23T15:54:04.068910 #42]  INFO -- :
    I, [2015-10-23T15:54:04.069344 #42]  INFO -- : > cd /var/www/discourse && git checkout tests-passed
    Switched to a new branch 'tests-passed'
    I, [2015-10-23T15:54:04.200168 #42]  INFO -- : Branch tests-passed set up to track remote branch tests-passed from origin.

    I, [2015-10-23T15:54:04.200518 #42]  INFO -- : > cd /var/www/discourse && mkdir -p tmp/pids
    I, [2015-10-23T15:54:04.205068 #42]  INFO -- :
    I, [2015-10-23T15:54:04.205515 #42]  INFO -- : > cd /var/www/discourse && mkdir -p tmp/sockets
    I, [2015-10-23T15:54:04.209201 #42]  INFO -- :
    I, [2015-10-23T15:54:04.209397 #42]  INFO -- : > cd /var/www/discourse && touch tmp/.gitkeep
    I, [2015-10-23T15:54:04.213544 #42]  INFO -- :
    I, [2015-10-23T15:54:04.213795 #42]  INFO -- : > cd /var/www/discourse && mkdir -p                    /shared/log/rails
    I, [2015-10-23T15:54:04.217537 #42]  INFO -- :
    I, [2015-10-23T15:54:04.217765 #42]  INFO -- : > cd /var/www/discourse && bash -c "touch -a           /shared/log/rails/{production,production_errors,unicorn.stdout,unicorn.stderr}.log"
    I, [2015-10-23T15:54:04.222814 #42]  INFO -- :
    I, [2015-10-23T15:54:04.223049 #42]  INFO -- : > cd /var/www/discourse && bash -c "ln    -s           /shared/log/rails/{production,production_errors,unicorn.stdout,unicorn.stderr}.log /var/www/discourse/log"
    I, [2015-10-23T15:54:04.229000 #42]  INFO -- :
    I, [2015-10-23T15:54:04.229490 #42]  INFO -- : > cd /var/www/discourse && bash -c "mkdir -p           /shared/{uploads,backups}"
    I, [2015-10-23T15:54:04.236051 #42]  INFO -- :
    I, [2015-10-23T15:54:04.236497 #42]  INFO -- : > cd /var/www/discourse && bash -c "ln    -s           /shared/{uploads,backups} /var/www/discourse/public"
    I, [2015-10-23T15:54:04.242560 #42]  INFO -- :
    I, [2015-10-23T15:54:04.242977 #42]  INFO -- : > cd /var/www/discourse && chown -R discourse:www-data /shared/log/rails /shared/uploads /shared/backups
    I, [2015-10-23T15:54:04.249820 #42]  INFO -- :
    I, [2015-10-23T15:54:04.250574 #42]  INFO -- : Replacing # redis with sv start redis || exit 1 in /etc/service/unicorn/run
    I, [2015-10-23T15:54:04.254889 #42]  INFO -- : > cd /var/www/discourse/plugins && mkdir -p plugins
    I, [2015-10-23T15:54:04.261446 #42]  INFO -- :
    I, [2015-10-23T15:54:04.261965 #42]  INFO -- : > cd /var/www/discourse/plugins && git clone https://github.com/discourse/docker_manager.git
    Cloning into 'docker_manager'...
    I, [2015-10-23T15:54:06.823958 #42]  INFO -- :
    I, [2015-10-23T15:54:06.826947 #42]  INFO -- : > cp /var/www/discourse/config/nginx.sample.conf /etc/nginx/conf.d/discourse.conf
    I, [2015-10-23T15:54:06.834182 #42]  INFO -- :
    I, [2015-10-23T15:54:06.834792 #42]  INFO -- : > rm /etc/nginx/sites-enabled/default
    I, [2015-10-23T15:54:06.839072 #42]  INFO -- :
    I, [2015-10-23T15:54:06.839549 #42]  INFO -- : > mkdir -p /var/nginx/cache
    I, [2015-10-23T15:54:06.843773 #42]  INFO -- :
    I, [2015-10-23T15:54:06.845326 #42]  INFO -- : Replacing pid /run/nginx.pid; with daemon off; in /etc/nginx/nginx.conf
    I, [2015-10-23T15:54:06.846966 #42]  INFO -- : Replacing (?m-ix:upstream[^\}]+\}) with upstream discourse { server 127.0.0.1:3000; } in /etc/nginx/conf.d/discourse.conf
    I, [2015-10-23T15:54:06.848224 #42]  INFO -- : Replacing (?-mix:server_name.+$) with server_name _ ; in /etc/nginx/conf.d/discourse.conf
    I, [2015-10-23T15:54:06.849445 #42]  INFO -- : Replacing (?-mix:client_max_body_size.+$) with client_max_body_size $upload_size ; in /etc/nginx/conf.d/discourse.conf
    I, [2015-10-23T15:54:06.851315 #42]  INFO -- : > echo "done configuring web"
    I, [2015-10-23T15:54:06.856465 #42]  INFO -- : done configuring web

    I, [2015-10-23T15:54:06.858840 #42]  INFO -- : > cd /var/www/discourse && gem update bundler
    ERROR:  While executing gem ... (Gem::RemoteFetcher::FetchError)
        hostname "rubygems.global.ssl.fastly.net" does not match the server certificate (https://rubygems.global.ssl.fastly.net/specs.4.8.gz)
    I, [2015-10-23T15:54:27.329080 #42]  INFO -- : Updating installed gems

    I, [2015-10-23T15:54:27.330007 #42]  INFO -- : Terminating async processes
    I, [2015-10-23T15:54:27.330217 #42]  INFO -- : Sending INT to HOME=/var/lib/postgresql USER=postgres exec chpst -u postgres:postgres:ssl-cert -U postgres:postgres:ssl-cert /usr/lib/postgresql/9.3/bin/postmaster -D /etc/postgresql/9.3/main pid: 112
    2015-10-23 15:54:27 UTC [112-2] LOG:  received fast shutdown request
    2015-10-23 15:54:27 UTC [112-3] LOG:  aborting any active transactions
    2015-10-23 15:54:27 UTC [119-2] LOG:  autovacuum launcher shutting down
    2015-10-23 15:54:27 UTC [116-1] LOG:  shutting down
    I, [2015-10-23T15:54:27.330394 #42]  INFO -- : Sending TERM to exec chpst -u redis -U redis /usr/bin/redis-server /etc/redis/redis.conf pid: 240
    240:signal-handler (1445615667) Received SIGTERM scheduling shutdown...
    240:M 23 Oct 15:54:27.359 # User requested shutdown...
    240:M 23 Oct 15:54:27.359 * Saving the final RDB snapshot before exiting.
    240:M 23 Oct 15:54:27.371 * DB saved on disk
    240:M 23 Oct 15:54:27.371 # Redis is now ready to exit, bye bye...
    2015-10-23 15:54:31 UTC [116-2] LOG:  database system is shut down


    FAILED
    --------------------
    RuntimeError: cd /var/www/discourse && gem update bundler failed with return #<Process::Status: pid 335 exit 1>
    Location of failure: /pups/lib/pups/exec_command.rb:105:in `spawn'
    exec failed with the params {"cd"=>"$home", "hook"=>"web", "cmd"=>["gem update bundler", "chown -R discourse $home"]}
    035a935af484328809d3399e2bfca421f5de3165b113fedc7c8dfe76dd7a07f1
    ** FAILED TO BOOTSTRAP ** please scroll up and look for earlier error messages, there may be more than one
