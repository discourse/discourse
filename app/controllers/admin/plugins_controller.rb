class Admin::PluginsController < Admin::AdminController

  def index
    render_serialized(Discourse.display_plugins, AdminPluginSerializer, root: 'plugins')
  end

end
