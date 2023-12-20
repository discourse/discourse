# frozen_string_literal: true

class Admin::PluginsController < Admin::StaffController
  def index
    render_serialized(
      Discourse.visible_plugins.sort_by { |p| p.name.downcase.delete_prefix("discourse-") },
      AdminPluginSerializer,
      root: "plugins",
    )
  end

  private

  def preload_additional_json
    store_preloaded(
      "enabledPluginAdminRoutes",
      MultiJson.dump(Discourse.visible_plugins.filter(&:enabled?).map(&:admin_route).compact),
    )
  end
end
