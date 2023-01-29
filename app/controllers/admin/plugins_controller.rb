# frozen_string_literal: true

class Admin::PluginsController < Admin::StaffController
  def index
    render_serialized(Discourse.visible_plugins, AdminPluginSerializer, root: "plugins")
  end
end
