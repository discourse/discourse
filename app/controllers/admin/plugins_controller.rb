# frozen_string_literal: true

class Admin::PluginsController < Admin::StaffController
  def index
    render_serialized(
      Discourse.plugins_sorted_by_name(enabled_only: false),
      AdminPluginSerializer,
      root: "plugins",
    )
  end

  def show
    plugin = Discourse.plugins_by_name[params[:plugin_id]]

    # An escape hatch in case a plugin is using an un-prefixed
    # version of their plugin name for a route.
    plugin = Discourse.plugins_by_name["discourse-#{params[:plugin_id]}"] if !plugin

    raise Discourse::NotFound if !plugin&.visible?

    render_serialized(plugin, AdminPluginSerializer, root: nil)
  end
end
