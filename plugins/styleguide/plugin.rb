# frozen_string_literal: true

# name: styleguide
# about: Preview how Widgets are Styled in Discourse
# meta_topic_id: 167293
# version: 0.2
# author: Robin Ward

register_asset "stylesheets/styleguide.scss"
enabled_site_setting :styleguide_enabled

module ::Styleguide
  PLUGIN_NAME = "styleguide"
end

require_relative "lib/styleguide/engine"

Discourse::Application.routes.append { mount Styleguide::Engine, at: "/styleguide" }

after_initialize do
  add_to_class(:guardian, :can_see_styleguide?) do
    SiteSetting.styleguide_enabled && in_any_groups?(SiteSetting.styleguide_allowed_groups_map)
  end

  add_to_serializer(:site, :can_see_styleguide) { scope.can_see_styleguide? }

  register_asset_filter do |type, request, opts|
    path = opts[:path]

    # Keep this plugin's assets off unrelated pages. The QUnit page is the one caller that
    # resolves plugin JS without a request, leaving no path to judge; treating that as "not my
    # page" dropped the plugin before its test bundle was collected, which made this plugin's
    # own JS tests unrunnable. Narrowed to JS on purpose — stylesheet precompilation also
    # resolves CSS without a request, and that should stay excluded.
    (type == :js && path.blank?) || path.to_s.start_with?("#{Discourse.base_path}/styleguide")
  end
end
