# frozen_string_literal: true

# name: discourse-rss-polling
# about: This plugin enables support for importing embedded content from multiple RSS/ATOM feeds
# version: 0.0.1
# authors: xrav3nz
# url: https://github.com/discourse/discourse/tree/main/plugins/discourse-rss-polling

enabled_site_setting :rss_polling_enabled
add_admin_route "rss_polling.title", "rss_polling"
register_asset "stylesheets/rss-polling.scss"
register_svg_icon "floppy-disk"

module ::DiscourseRssPolling
  PLUGIN_NAME = "discourse_rss_polling"
end

require_relative "lib/discourse_rss_polling/engine"

Discourse::Application.routes.append do
  mount DiscourseRssPolling::Engine, at: "/admin/plugins/rss_polling"
end
