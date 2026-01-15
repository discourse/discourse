# frozen_string_literal: true

# name: checklist
# about: Add checklist support to Discourse
# version: 1.0
# authors: Discourse Team
# meta_topic_id: 36362
# url: https://github.com/discourse/discourse/tree/main/plugins/checklist

enabled_site_setting :checklist_enabled

register_asset "stylesheets/checklist.scss"
register_svg_icon "spinner"

module ::Checklist
  PLUGIN_NAME = "checklist"
end

require_relative "lib/checklist/engine"

after_initialize do
  Discourse::Application.routes.append { mount Checklist::Engine, at: "/checklist" }
end
