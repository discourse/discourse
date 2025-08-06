# frozen_string_literal: true

# name: discourse-rss-polling
# about: This plugin enables support for importing embedded content from multiple RSS/ATOM feeds
# version: 0.0.1
# authors: xrav3nz
# url: https://github.com/discourse/discourse/tree/main/plugins/discourse-rss-polling

require_relative "lib/discourse_rss_polling/engine"

enabled_site_setting :rss_polling_enabled
add_admin_route "rss_polling.title", "rss_polling"
register_asset "stylesheets/rss-polling.scss"
register_svg_icon "floppy-disk" if respond_to?(:register_svg_icon)

Discourse::Application.routes.append do
  mount ::DiscourseRssPolling::Engine, at: "/admin/plugins/rss_polling"
end
