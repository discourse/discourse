class Admin::PluginsController < Admin::AdminController

  def index
    render_serialized(Discourse.visible_plugins, AdminPluginSerializer, root: 'plugins')
  end

end
