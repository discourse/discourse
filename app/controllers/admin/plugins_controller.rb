# frozen_string_literal: true

class Admin::PluginsController < Admin::StaffController
  def index
    render_serialized(
      Discourse.plugins_sorted_by_name(enabled_only: false),
      AdminPluginSerializer,
      root: "plugins",
    )
  end
end
