# frozen_string_literal: true

# name: discourse-styleguide
# about: Preview how Widgets are Styled in Discourse
# version: 0.1
# author: Robin Ward

register_asset "stylesheets/styleguide.scss"
enabled_site_setting :styleguide_enabled

load File.expand_path('../lib/discourse_styleguide/engine.rb', __FILE__)

Discourse::Application.routes.append do
  mount ::DiscourseStyleguide::Engine, at: '/styleguide'
end
