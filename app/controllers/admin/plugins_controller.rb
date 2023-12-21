# frozen_string_literal: true

class Admin::PluginsController < Admin::StaffController
  def index
    render_serialized(
      Discourse.plugins_sorted_by_name(enabled_only: false),
      AdminPluginSerializer,
      root: "plugins",
    )
  end

  private

  def preload_additional_json
    store_preloaded(
      "enabledPluginAdminRoutes",
      MultiJson.dump(Discourse.plugins_sorted_by_name.map(&:admin_route).compact),
    )
  end
end
