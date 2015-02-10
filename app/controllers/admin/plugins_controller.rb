class Admin::PluginsController < Admin::AdminController

  def index
    render_serialized(Discourse.plugins, AdminPluginSerializer, root: 'plugins')
  end

end
